package degledgerrecorder

import (
	"testing"
)

// Happy path — no error fields set, ACTIVE contract — must NOT skip.
func TestShouldSkipOnConfirmCascade_HappyPath(t *testing.T) {
	body := []byte(sampleWave2OnConfirm)
	p, err := ParseOnConfirmWave2(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if skip, reason := ShouldSkipOnConfirmCascade(p); skip {
		t.Errorf("happy path must not skip, but did: %s", reason)
	}
}

// Beckn 2.0 envelope-level error block (the canonical NACK shape that the
// schema validator actually accepts — Beckn 2.0's `additionalProperties:false`
// rejects fields like `message.ack`).
func TestShouldSkipOnConfirmCascade_EnvelopeError(t *testing.T) {
	body := []byte(`{
	  "context": {"transactionId": "t1"},
	  "message": {"contract": {"id": "c1", "commitments": [{}]}},
	  "error": {"code": "EnergyResource.NotAvailable", "message": "supply unavailable"}
	}`)
	p, err := ParseOnConfirmWave2(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	skip, reason := ShouldSkipOnConfirmCascade(p)
	if !skip {
		t.Fatalf("expected skip on envelope error")
	}
	if reason == "" || reason[:8] != "envelope" {
		t.Errorf("reason should mention envelope error, got: %q", reason)
	}
}

// Envelope `error` with empty code — treat as no error.
func TestShouldSkipOnConfirmCascade_EnvelopeErrorEmptyCodeIsNotSkip(t *testing.T) {
	body := []byte(`{
	  "context": {"transactionId": "t1"},
	  "message": {"contract": {"id": "c1", "status": {"code":"ACTIVE"}, "commitments": [{}]}},
	  "error": {"code": ""}
	}`)
	p, _ := ParseOnConfirmWave2(body)
	if skip, reason := ShouldSkipOnConfirmCascade(p); skip {
		t.Errorf("empty error code must NOT skip, got: %s", reason)
	}
}

func TestShouldSkipOnConfirmCascade_TerminalContractStatus(t *testing.T) {
	for _, code := range []string{"CANCELLED", "CANCELED", "REJECTED", "EXPIRED", "FAILED", "Cancelled", "failed"} {
		body := []byte(`{
		  "context": {"transactionId": "t1"},
		  "message": {"contract": {"id": "c1", "status": {"code": "` + code + `"}, "commitments":[{}]}}
		}`)
		p, _ := ParseOnConfirmWave2(body)
		skip, reason := ShouldSkipOnConfirmCascade(p)
		if !skip {
			t.Errorf("contract.status.code=%q must skip", code)
		}
		if reason == "" {
			t.Errorf("expected reason for status=%q", code)
		}
	}
}

func TestShouldSkipOnConfirmCascade_ActiveContractStatusOK(t *testing.T) {
	body := []byte(`{
	  "context": {"transactionId": "t1"},
	  "message": {"contract": {"id": "c1", "status": {"code": "ACTIVE"}, "commitments":[{}]}}
	}`)
	p, _ := ParseOnConfirmWave2(body)
	if skip, reason := ShouldSkipOnConfirmCascade(p); skip {
		t.Errorf("ACTIVE status must NOT skip, got: %s", reason)
	}
}

// on_status loose-typed status map gets read correctly.
func TestShouldSkipOnStatusCascade_TerminalContractStatus(t *testing.T) {
	body := []byte(`{
	  "context": {"transactionId": "t1"},
	  "message": {"contract": {"id": "c1", "status": {"code": "FAILED"}}}
	}`)
	p, err := ParseOnStatusWave2(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if skip, _ := ShouldSkipOnStatusCascade(p); !skip {
		t.Errorf("on_status with status FAILED must skip")
	}
}

func TestShouldSkipOnStatusCascade_HappyActive(t *testing.T) {
	body := []byte(`{
	  "context": {"transactionId": "t1"},
	  "message": {"contract": {"id": "c1", "status": {"code": "ACTIVE"}}}
	}`)
	p, _ := ParseOnStatusWave2(body)
	if skip, reason := ShouldSkipOnStatusCascade(p); skip {
		t.Errorf("ACTIVE must not skip, got: %s", reason)
	}
}

func TestShouldSkipOnStatusCascade_EnvelopeError(t *testing.T) {
	body := []byte(`{
	  "context": {"transactionId": "t1"},
	  "message": {"contract": {"id": "c1", "status": {"code":"ACTIVE"}}},
	  "error": {"code": "Settlement.Unavailable"}
	}`)
	p, _ := ParseOnStatusWave2(body)
	if skip, _ := ShouldSkipOnStatusCascade(p); !skip {
		t.Errorf("on_status with envelope error must skip")
	}
}

func TestShouldSkipStatusCascade_EnvelopeError(t *testing.T) {
	body := []byte(`{
	  "context": {"transactionId": "t1"},
	  "message": {"contract": {"id": "c1"}},
	  "error": {"code": "Bad.Request"}
	}`)
	p, err := ParseStatusWave2(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if skip, _ := ShouldSkipStatusCascade(p); !skip {
		t.Errorf("status with envelope error must skip")
	}
}

// Sanity: empty/minimal body is not flagged as error — the downstream
// empty-commitments check is what handles the no-trade case.
func TestShouldSkipOnConfirmCascade_EmptyMessageNotFlagged(t *testing.T) {
	body := []byte(`{"context":{}, "message":{}}`)
	p, err := ParseOnConfirmWave2(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if skip, _ := ShouldSkipOnConfirmCascade(p); skip {
		t.Errorf("empty message should not be classified as error-skip")
	}
}
