package degledgerrecorder

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestRewriteContextForBeckn_Wave2CamelCase(t *testing.T) {
	body := []byte(sampleWave2OnConfirm)
	// Callers pass full endpoint URIs (host + Beckn role path); the rewriter
	// uses them verbatim. Helper funcs BppCallerEndpoint/BapReceiverEndpoint
	// in the recorder build these from host bases.
	out, err := RewriteContextForBeckn(
		body,
		BppCallerEndpoint("https://bap.example.com"),
		BapReceiverEndpoint("https://ies-p2p-energy-ledger.beckn.io"),
		"", "",
	)
	if err != nil {
		t.Fatalf("rewrite: %v", err)
	}
	var got map[string]interface{}
	if err := json.Unmarshal(out, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	ctx := got["context"].(map[string]interface{})

	if v := ctx["bppUri"]; v != "https://bap.example.com/bpp/caller" {
		t.Errorf("bppUri: got %v", v)
	}
	if v := ctx["bapUri"]; v != "https://ies-p2p-energy-ledger.beckn.io/bap/receiver" {
		t.Errorf("bapUri: got %v", v)
	}
	// Other fields preserved
	if v := ctx["transactionId"]; v != "txn-p2p-001" {
		t.Errorf("transactionId clobbered: got %v", v)
	}
	if v := ctx["bapId"]; v != "bap.example.com" {
		t.Errorf("bapId clobbered: got %v", v)
	}
}

// BapReceiverEndpoint / BppCallerEndpoint trim trailing slashes idempotently —
// callers can pass either "https://host" or "https://host/" and get a clean URL.
func TestEndpointHelpers_TrimTrailingSlashes(t *testing.T) {
	if got := BppCallerEndpoint("https://bap.example.com/"); got != "https://bap.example.com/bpp/caller" {
		t.Errorf("BppCallerEndpoint trim failed: got %v", got)
	}
	if got := BapReceiverEndpoint("https://ledger.example.com//"); got != "https://ledger.example.com/bap/receiver" {
		t.Errorf("BapReceiverEndpoint trim failed: got %v", got)
	}
}

func TestRewriteContextForBeckn_SnakeCaseFallback(t *testing.T) {
	// Wave1-style snake_case context — rewrite must operate on bpp_uri/bap_uri.
	body := []byte(`{"context":{"bpp_uri":"https://x","bap_uri":"https://y","transaction_id":"t1"},"message":{"order":{}}}`)
	out, err := RewriteContextForBeckn(body, "https://sender.com/bpp/caller", "https://ledger.com/bap/receiver", "", "")
	if err != nil {
		t.Fatalf("rewrite: %v", err)
	}
	var got map[string]interface{}
	_ = json.Unmarshal(out, &got)
	ctx := got["context"].(map[string]interface{})
	if v := ctx["bpp_uri"]; v != "https://sender.com/bpp/caller" {
		t.Errorf("bpp_uri: got %v", v)
	}
	if v := ctx["bap_uri"]; v != "https://ledger.com/bap/receiver" {
		t.Errorf("bap_uri: got %v", v)
	}
	// Camel keys must NOT have been added.
	if _, present := ctx["bppUri"]; present {
		t.Errorf("rewrite leaked camel-case bppUri into snake-case payload")
	}
}

func TestRewriteContextForBeckn_MissingContextErrors(t *testing.T) {
	if _, err := RewriteContextForBeckn([]byte(`{}`), "h", "l", "", ""); err == nil {
		t.Errorf("expected error on missing context")
	}
}

func TestDeriveSenderHostFromWave2(t *testing.T) {
	p, err := ParseOnConfirmWave2([]byte(sampleWave2OnConfirm))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if got := DeriveSenderHostFromWave2(p, "BUYER"); got != "https://bap.example.com" {
		t.Errorf("BUYER: got %q", got)
	}
	if got := DeriveSenderHostFromWave2(p, "SELLER"); got != "https://bpp.example.com" {
		t.Errorf("SELLER: got %q", got)
	}
	if got := DeriveSenderHostFromWave2(p, "BUYER_DISCOM"); got != "" {
		t.Errorf("unrecognized role: got %q, want empty", got)
	}
}

func TestDeriveSenderHostFromWave2_MalformedURI(t *testing.T) {
	p := &Wave2OnConfirmPayload{}
	p.Context.BapURI = "not-a-uri"
	if got := DeriveSenderHostFromWave2(p, "BUYER"); got != "" {
		t.Errorf("expected empty for unparseable URI, got %q", got)
	}
}

// Smoke: when senderHost is missing, the recorder must skip with a warning
// rather than POST garbage. We exercise that branch indirectly via the
// helpers — recorder logic is small and reads the same fields here.
func TestDeriveSenderHost_MissingURIInPayload(t *testing.T) {
	p := &Wave2OnConfirmPayload{}
	if got := DeriveSenderHostFromWave2(p, "BUYER"); got != "" {
		t.Errorf("expected empty when bapUri missing, got %q", got)
	}
	if got := DeriveSenderHostFromWave2(p, "SELLER"); got != "" {
		t.Errorf("expected empty when bppUri missing, got %q", got)
	}
}

// When senderSubscriberID + ledgerSubscriberID are supplied, the rewrite must
// also set context.bppId / context.bapId — the Beckn-spec-compliance fix that
// keeps (bppId, bppUri) and (bapId, bapUri) coherent on cascade legs.
func TestRewriteContextForBeckn_RewritesIDsWhenSupplied(t *testing.T) {
	body := []byte(sampleWave2OnConfirm)
	out, err := RewriteContextForBeckn(
		body,
		BppCallerEndpoint("https://sellerapp.example.com"),
		BapReceiverEndpoint("https://seller-discom-ledger.example.com"),
		"sellerapp.example.com",
		"seller-discom-ledger.example.com",
	)
	if err != nil {
		t.Fatalf("rewrite: %v", err)
	}
	var got map[string]interface{}
	if err := json.Unmarshal(out, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	ctx := got["context"].(map[string]interface{})
	if v := ctx["bppId"]; v != "sellerapp.example.com" {
		t.Errorf("bppId: got %v, want sellerapp.example.com", v)
	}
	if v := ctx["bapId"]; v != "seller-discom-ledger.example.com" {
		t.Errorf("bapId: got %v, want seller-discom-ledger.example.com", v)
	}
	if v := ctx["bppUri"]; v != "https://sellerapp.example.com/bpp/caller" {
		t.Errorf("bppUri: got %v", v)
	}
	if v := ctx["bapUri"]; v != "https://seller-discom-ledger.example.com/bap/receiver" {
		t.Errorf("bapUri: got %v", v)
	}
}

// Empty subscriber-id args must leave bppId/bapId unchanged (backward compat
// with callers that only know about URI rewrites).
func TestRewriteContextForBeckn_PreservesIDsWhenEmpty(t *testing.T) {
	body := []byte(sampleWave2OnConfirm)
	out, err := RewriteContextForBeckn(body, "https://x.example.com/bpp/caller", "https://y.example.com/bap/receiver", "", "")
	if err != nil {
		t.Fatalf("rewrite: %v", err)
	}
	var got map[string]interface{}
	_ = json.Unmarshal(out, &got)
	ctx := got["context"].(map[string]interface{})
	// the sample payload has the original bapId/bppId — they should still be there
	if v := ctx["bapId"]; v != "bap.example.com" {
		t.Errorf("bapId mutated despite empty arg: got %v", v)
	}
	if v := ctx["bppId"]; v != "bpp.example.com" {
		t.Errorf("bppId mutated despite empty arg: got %v", v)
	}
}

// Defensive: rewrite leaves message untouched verbatim.
func TestRewriteContextForBeckn_MessagePreserved(t *testing.T) {
	body := []byte(sampleWave2OnConfirm)
	out, err := RewriteContextForBeckn(body, "https://x/bpp/caller", "https://y/bap/receiver", "", "")
	if err != nil {
		t.Fatalf("rewrite: %v", err)
	}
	if !strings.Contains(string(out), `"commitment-p2p-001"`) {
		t.Errorf("rewrite dropped or altered message body")
	}
	if !strings.Contains(string(out), `"der://meter/buyer-001"`) {
		t.Errorf("rewrite dropped participant attributes")
	}
}
