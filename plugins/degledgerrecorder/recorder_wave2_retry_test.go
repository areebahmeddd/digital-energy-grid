package degledgerrecorder

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/beckn-one/beckn-onix/pkg/model"
)

func TestParseConfig_RetryMaxTTL(t *testing.T) {
	cfg := baseValidCfg()
	cfg["retryCount"] = "3"
	cfg["retryMaxTTL"] = "10m"
	cfg["retryBackoff"] = "5s"

	got, err := ParseConfig(cfg)
	if err != nil {
		t.Fatalf("ParseConfig: %v", err)
	}
	if got.RetryCount != 3 {
		t.Fatalf("RetryCount: got %d", got.RetryCount)
	}
	if got.RetryMaxTTL != 10*time.Minute {
		t.Fatalf("RetryMaxTTL: got %s", got.RetryMaxTTL)
	}
	if got.RetryBackoff != 5*time.Second {
		t.Fatalf("RetryBackoff: got %s", got.RetryBackoff)
	}
}

func TestParseConfig_InvalidRetryMaxTTL(t *testing.T) {
	cfg := baseValidCfg()
	cfg["retryMaxTTL"] = "soon"

	if _, err := ParseConfig(cfg); err == nil {
		t.Fatal("expected invalid retryMaxTTL to fail")
	}
}

func TestParseConfig_InvalidRetryBackoff(t *testing.T) {
	cfg := baseValidCfg()
	cfg["retryBackoff"] = "soon"

	if _, err := ParseConfig(cfg); err == nil {
		t.Fatal("expected invalid retryBackoff to fail")
	}
}

func TestBecknRetryBackoffUsesConfiguredFixedDelay(t *testing.T) {
	for attempt := 0; attempt < 5; attempt++ {
		if got := becknRetryBackoff(5 * time.Second); got != 5*time.Second {
			t.Fatalf("attempt %d: got %s, want 5s", attempt, got)
		}
	}
}

func TestWave2BecknOnConfirmRetriesNACKThenACK(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/bap/receiver/on_confirm" {
			t.Errorf("path: got %q", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		if calls.Add(1) == 1 {
			_, _ = w.Write([]byte(`{"message":{"status":"NACK","messageId":"ack-1"}}`))
			return
		}
		_, _ = w.Write([]byte(`{"message":{"status":"ACK","messageId":"ack-2","ledger":{"success":true,"recordId":"rec-1"}}}`))
	}))
	defer server.Close()

	recorder := newWave2RetryRecorder(t, "on_confirm", 1)
	err := recorder.handleOnConfirmWave2(newWave2StepContext(wave2OnConfirmWithLedgerURI(server.URL), "/bpp/caller/on_confirm"))

	if err != nil {
		t.Fatalf("handleOnConfirmWave2: %v", err)
	}
	if got := calls.Load(); got != 2 {
		t.Fatalf("calls: got %d, want 2", got)
	}
}

func TestWave2StatusAsyncRetriesMissingACKThenACK(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/bpp/receiver/status" {
			t.Errorf("path: got %q", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		if calls.Add(1) == 1 {
			_, _ = w.Write([]byte(`{"message":{}}`))
			return
		}
		_, _ = w.Write([]byte(`{"message":{"status":"ACK","messageId":"ack-status"}}`))
	}))
	defer server.Close()

	recorder := newWave2RetryRecorder(t, "status", 1)
	err := recorder.handleStatus(newWave2StepContext(sampleWave2Status(server.URL), "/bpp/receiver/status"))
	if err != nil {
		t.Fatalf("handleStatus: %v", err)
	}
	recorder.wg.Wait()

	if got := calls.Load(); got != 2 {
		t.Fatalf("calls: got %d, want 2", got)
	}
	if got := recorder.pendingRetryCount(); got != 0 {
		t.Fatalf("pending retries: got %d, want 0", got)
	}
}

func TestParseBecknAckEnvelopeCopiesDetailsMessage(t *testing.T) {
	resp, err := parseBecknAckEnvelope(
		[]byte(`{"message":{"status":"ACK","messageId":"ack-duplicate"},"details":{"message":"Records already exist; skipped duplicate on_confirm"}}`),
		"on_confirm",
	)
	if err != nil {
		t.Fatalf("parseBecknAckEnvelope: %v", err)
	}
	if resp.Message != "Records already exist; skipped duplicate on_confirm" {
		t.Fatalf("Message: got %q", resp.Message)
	}
}

func TestWave2OnStatusAsyncRetriesNACKThenACK(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/bap/receiver/on_status" {
			t.Errorf("path: got %q", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		if calls.Add(1) == 1 {
			_, _ = w.Write([]byte(`{"message":{"status":"NACK","messageId":"ack-1"}}`))
			return
		}
		_, _ = w.Write([]byte(`{"message":{"status":"ACK","messageId":"ack-2","ledger":{"success":true,"recordId":"rec-2"}}}`))
	}))
	defer server.Close()

	recorder := newWave2RetryRecorder(t, "on_status", 1)
	err := recorder.handleOnStatusWave2(newWave2StepContext(sampleWave2OnStatus(server.URL, "http://buyer.example.com"), "/bap/receiver/on_status"))
	if err != nil {
		t.Fatalf("handleOnStatusWave2: %v", err)
	}
	recorder.wg.Wait()

	if got := calls.Load(); got != 2 {
		t.Fatalf("calls: got %d, want 2", got)
	}
	if got := recorder.pendingRetryCount(); got != 0 {
		t.Fatalf("pending retries: got %d, want 0", got)
	}
}

func TestWave2OnStatusRetryExhaustionSendsFailureCallback(t *testing.T) {
	failureReceived := make(chan map[string]interface{}, 1)
	failureServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/bap/receiver/on_status" {
			t.Errorf("failure path: got %q", r.URL.Path)
		}
		var body map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Errorf("decode failure body: %v", err)
		}
		failureReceived <- body
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"message":{"status":"ACK","messageId":"failure-ack"}}`))
	}))
	defer failureServer.Close()

	targetServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/bap/receiver/on_status" {
			t.Errorf("target path: got %q", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"message":{"status":"NACK","messageId":"target-nack"}}`))
	}))
	defer targetServer.Close()

	recorder := newWave2RetryRecorder(t, "on_status", 0)
	err := recorder.handleOnStatusWave2(newWave2StepContext(sampleWave2OnStatus(targetServer.URL, failureServer.URL), "/bap/receiver/on_status"))
	if err != nil {
		t.Fatalf("handleOnStatusWave2: %v", err)
	}
	recorder.wg.Wait()

	body := waitForFailureBody(t, failureReceived)
	errBlock, _ := body["error"].(map[string]interface{})
	if errBlock["code"] != degAsyncAckTimeout {
		t.Fatalf("error code: got %#v, want %s", errBlock["code"], degAsyncAckTimeout)
	}
	if got := recorder.pendingRetryCount(); got != 0 {
		t.Fatalf("pending retries: got %d, want 0", got)
	}
}

func newWave2RetryRecorder(t *testing.T, actions string, retryCount int) *DEGLedgerRecorder {
	t.Helper()
	recorder, err := New(map[string]string{
		"payloadShape":    "wave2",
		"ledgerUriSource": "payload",
		"ledgerApi":       "beckn",
		"role":            "SELLER",
		"actions":         actions,
		"enabled":         "true",
		"asyncTimeout":    "1000",
		"retryCount":      strconv.Itoa(retryCount),
		"retryMaxTTL":     "2s",
		"retryBackoff":    "50ms",
	})
	if err != nil {
		t.Fatalf("New recorder: %v", err)
	}
	return recorder
}

func newWave2StepContext(body, path string) *model.StepContext {
	req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	return &model.StepContext{
		Context:    context.Background(),
		Request:    req,
		Body:       []byte(body),
		RespHeader: make(http.Header),
	}
}

func wave2OnConfirmWithLedgerURI(ledgerURI string) string {
	return strings.ReplaceAll(sampleWave2OnConfirm, "https://ies-p2p-energy-ledger.beckn.io", ledgerURI)
}

func sampleWave2Status(ledgerURI string) string {
	return `{
	  "context": {
	    "networkId": "nfh.global/testnet-deg",
	    "version": "2.0.0",
	    "action": "status",
	    "bapId": "sellerapp.example.com",
	    "bapUri": "http://sellerapp.example.com:9000/bap/receiver",
	    "bppId": "seller-discom-ledger.example.com",
	    "bppUri": "` + ledgerURI + `/bpp/receiver",
	    "transactionId": "txn-p2p-001",
	    "messageId": "msg-status-001",
	    "timestamp": "2026-04-25T10:10:05Z"
	  },
	  "message": {
	    "contract": {
	      "id": "contract-p2p-001",
	      "status": {"code": "ACTIVE"},
	      "contractAttributes": {
	        "@type": "DEGContract",
	        "roles": [
	          {"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
	          {"role": "sellerDiscom", "participantId": "TPDDL"}
	        ]
	      },
	      "participants": [
	        {
	          "id": "sellerapp.example.com",
	          "participantAttributes": {"@type": "EnergyCustomer", "platformUrl": "http://sellerapp.example.com:9000"}
	        },
	        {
	          "id": "TPDDL",
	          "participantAttributes": {"@type": "DiscomLedgerProvider", "ledgerId": "seller-discom-ledger.example.com", "ledgerUri": "` + ledgerURI + `"}
	        }
	      ]
	    }
	  }
	}`
}

func sampleWave2OnStatus(targetLedgerURI, originalSenderURI string) string {
	return `{
	  "context": {
	    "networkId": "nfh.global/testnet-deg",
	    "version": "2.0.0",
	    "action": "on_status",
	    "bapId": "sellerapp.example.com",
	    "bapUri": "http://sellerapp.example.com:9000/bap/receiver",
	    "bppId": "buyerapp.example.com",
	    "bppUri": "` + originalSenderURI + `/bpp/caller",
	    "transactionId": "txn-p2p-001",
	    "messageId": "msg-on-status-001",
	    "timestamp": "2026-04-25T10:10:05Z"
	  },
	  "message": {
	    "contract": {
	      "id": "contract-p2p-001",
	      "status": {"code": "ACTIVE"},
	      "contractAttributes": {
	        "@type": "DEGContract",
	        "roles": [
	          {"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
	          {"role": "sellerDiscom", "participantId": "TPDDL"}
	        ]
	      },
	      "participants": [
	        {
	          "id": "sellerapp.example.com",
	          "participantAttributes": {"@type": "EnergyCustomer", "platformUrl": "http://sellerapp.example.com:9000"}
	        },
	        {
	          "id": "TPDDL",
	          "participantAttributes": {"@type": "DiscomLedgerProvider", "ledgerId": "seller-discom-ledger.example.com", "ledgerUri": "` + targetLedgerURI + `"}
	        }
	      ],
	      "commitments": [
	        {
	          "id": "commitment-p2p-001",
	          "offer": {"id": "offer-p2p-001"},
	          "commitmentAttributes": {
	            "intervals": [
	              {
	                "id": 0,
	                "payloads": [
	                  {"type": "BUYER_DISCOM_ALLOC", "values": [18.5]},
	                  {"type": "BUYER_DISCOM_STATUS", "values": ["COMPLETED"]}
	                ]
	              }
	            ]
	          }
	        }
	      ]
	    }
	  }
	}`
}

func waitForFailureBody(t *testing.T, ch <-chan map[string]interface{}) map[string]interface{} {
	t.Helper()
	select {
	case body := <-ch:
		return body
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for failure callback")
		return nil
	}
}
