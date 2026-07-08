// Tests for violation enforcement (violationActions): NACK on policy
// violations and fail-closed behavior on enforced actions.
// All HTTP traffic goes to local httptest servers.
package settlementflows

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/beckn-one/beckn-onix/pkg/model"
	"github.com/open-policy-agent/opa/v1/rego"
)

// resultSetWith wraps a value as a single-expression OPA result set.
func resultSetWith(val interface{}) rego.ResultSet {
	return rego.ResultSet{rego.Result{Expressions: []*rego.ExpressionValue{{Value: val}}}}
}

// enforceTestPolicy flags a violation when the buyer discom is "BLOCKED_DISCOM".
const enforceTestPolicy = `package test.policy

import rego.v1

violations contains msg if {
	input.message.buyerDiscom == "BLOCKED_DISCOM"
	msg := sprintf("buyer discom %q is not in the allowlist", [input.message.buyerDiscom])
}
`

// servePolicy returns an httptest server serving a bare rego policy.
func servePolicy(t *testing.T, policy string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, policy)
	}))
	t.Cleanup(srv.Close)
	return srv
}

// enforceBody builds a message body carrying a policy ref and a buyer discom.
func enforceBody(action, policyURL, buyerDiscom string) []byte {
	return []byte(fmt.Sprintf(`{
		"context": {"action": %q},
		"message": {
			"buyerDiscom": %q,
			"contract": {
				"contractAttributes": {
					"policy": {"url": %q, "queryPath": "data.test.policy"}
				}
			}
		}
	}`, action, buyerDiscom, policyURL))
}

func newEnforcingPlugin(t *testing.T, extra map[string]string) *SettlementFlows {
	t.Helper()
	cfg := map[string]string{
		"actions":          "init,on_status",
		"violationActions": "init",
		"outputPath":       "message.contract.contractAttributes.revenueFlows",
		"outputMode":       "raw",
	}
	for k, v := range extra {
		cfg[k] = v
	}
	p, err := New(cfg)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	return p
}

func stepCtx(t *testing.T, action string, body []byte) *model.StepContext {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/bpp/receiver/"+action, nil)
	return &model.StepContext{Context: context.Background(), Request: req, Body: body}
}

// ---------------------------------------------------------------------------
// Config: violationActions parsing and subset validation
// ---------------------------------------------------------------------------

func TestParseConfig_ViolationActions(t *testing.T) {
	cfg, err := ParseConfig(map[string]string{
		"actions":          "select,init,confirm,on_status",
		"violationActions": "select, init ,confirm",
		"outputPath":       "x.y",
		"outputMode":       "raw",
	})
	if err != nil {
		t.Fatalf("ParseConfig: %v", err)
	}
	want := []string{"select", "init", "confirm"}
	if len(cfg.ViolationActions) != len(want) {
		t.Fatalf("ViolationActions = %v, want %v", cfg.ViolationActions, want)
	}
	for i, a := range want {
		if cfg.ViolationActions[i] != a {
			t.Errorf("ViolationActions[%d] = %q, want %q", i, cfg.ViolationActions[i], a)
		}
	}
	if !cfg.IsViolationEnforced("init") || cfg.IsViolationEnforced("on_status") {
		t.Error("IsViolationEnforced wrong: init should be enforced, on_status should not")
	}
}

func TestParseConfig_ViolationActionsMustBeSubsetOfActions(t *testing.T) {
	_, err := ParseConfig(map[string]string{
		"actions":          "on_status",
		"violationActions": "init",
		"outputPath":       "x.y",
		"outputMode":       "raw",
	})
	if err == nil {
		t.Error("expected error when violationActions is not a subset of actions")
	}
}

// ---------------------------------------------------------------------------
// Run: violations → NACK on enforced actions
// ---------------------------------------------------------------------------

func TestRun_NackOnViolations(t *testing.T) {
	srv := servePolicy(t, enforceTestPolicy)
	p := newEnforcingPlugin(t, nil)

	err := p.Run(stepCtx(t, "init", enforceBody("init", srv.URL, "BLOCKED_DISCOM")))
	if err == nil {
		t.Fatal("expected error on policy violation for enforced action")
	}
	var badReq *model.BadReqErr
	if !errors.As(err, &badReq) {
		t.Errorf("expected *model.BadReqErr (400 NACK), got %T: %v", err, err)
	}
	if !strings.Contains(err.Error(), "not in the allowlist") {
		t.Errorf("error should carry the violation message, got: %v", err)
	}
}

func TestRun_NoViolationsPasses(t *testing.T) {
	srv := servePolicy(t, enforceTestPolicy)
	p := newEnforcingPlugin(t, nil)

	if err := p.Run(stepCtx(t, "init", enforceBody("init", srv.URL, "ALLOWED_DISCOM"))); err != nil {
		t.Fatalf("expected clean payload to pass, got: %v", err)
	}
}

func TestRun_ViolationsNotEnforcedOnOtherActions(t *testing.T) {
	srv := servePolicy(t, enforceTestPolicy)
	p := newEnforcingPlugin(t, nil)

	// on_status is in actions but NOT in violationActions: soft behavior.
	body := enforceBody("on_status", srv.URL, "BLOCKED_DISCOM")
	if err := p.Run(stepCtx(t, "on_status", body)); err != nil {
		t.Fatalf("violations must not block non-enforced actions, got: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Run: fail-closed on enforced actions
// ---------------------------------------------------------------------------

func TestRun_FailClosed_MissingPolicyRef(t *testing.T) {
	p := newEnforcingPlugin(t, nil)

	body := []byte(`{"context":{"action":"init"},"message":{"contract":{}}}`)
	err := p.Run(stepCtx(t, "init", body))
	if err == nil {
		t.Fatal("expected error: enforced action without a policy ref must be blocked")
	}
	var badReq *model.BadReqErr
	if !errors.As(err, &badReq) {
		t.Errorf("expected *model.BadReqErr, got %T: %v", err, err)
	}
}

func TestRun_FailClosed_DisallowedPrefix(t *testing.T) {
	srv := servePolicy(t, enforceTestPolicy)
	p := newEnforcingPlugin(t, map[string]string{
		"allowedPolicyUrlPrefixes": "https://api.dedi.global/dedi/lookup/indiaenergystack.in",
	})

	err := p.Run(stepCtx(t, "init", enforceBody("init", srv.URL, "ALLOWED_DISCOM")))
	if err == nil {
		t.Fatal("expected error: disallowed policy URL prefix on enforced action")
	}
	var badReq *model.BadReqErr
	if !errors.As(err, &badReq) {
		t.Errorf("expected *model.BadReqErr, got %T: %v", err, err)
	}
}

func TestRun_FailClosed_FetchError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "gone", http.StatusNotFound)
	}))
	defer srv.Close()
	p := newEnforcingPlugin(t, nil)

	if err := p.Run(stepCtx(t, "init", enforceBody("init", srv.URL, "ALLOWED_DISCOM"))); err == nil {
		t.Fatal("expected error: unfetchable policy on enforced action must be blocked")
	}
}

func TestRun_SoftFailure_FetchErrorNotEnforced(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "gone", http.StatusNotFound)
	}))
	defer srv.Close()
	p := newEnforcingPlugin(t, nil)

	body := enforceBody("on_status", srv.URL, "ALLOWED_DISCOM")
	if err := p.Run(stepCtx(t, "on_status", body)); err != nil {
		t.Fatalf("fetch failure on non-enforced action must stay soft, got: %v", err)
	}
}

// ---------------------------------------------------------------------------
// extractViolations
// ---------------------------------------------------------------------------

func TestExtractViolations_FromPackageMap(t *testing.T) {
	rs := resultSetWith(map[string]interface{}{
		"violations":    []interface{}{"a", "b"},
		"revenue_flows": []interface{}{},
	})
	got := extractViolations(rs)
	if len(got) != 2 || got[0] != "a" || got[1] != "b" {
		t.Errorf("extractViolations = %v, want [a b]", got)
	}
}

func TestExtractViolations_AbsentAndNonString(t *testing.T) {
	if got := extractViolations(resultSetWith(map[string]interface{}{"revenue_flows": []interface{}{}})); got != nil {
		t.Errorf("expected nil when violations absent, got %v", got)
	}
	got := extractViolations(resultSetWith(map[string]interface{}{"violations": []interface{}{42}}))
	if len(got) != 1 || got[0] != "42" {
		t.Errorf("non-string violation should be stringified, got %v", got)
	}
}
