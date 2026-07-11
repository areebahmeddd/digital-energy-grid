package contractpolicyenforcer

import (
	"encoding/json"
	"reflect"
	"testing"
)

// ---------------------------------------------------------------------------
// ExtractPolicyRef tests
// ---------------------------------------------------------------------------

func TestExtractPolicyRef_Present(t *testing.T) {
	body := []byte(`{
		"message": {
			"contract": {
				"contractAttributes": {
					"policy": {
						"url": "https://example.com/policy.rego",
						"queryPath": "data.test.violations"
					}
				}
			}
		}
	}`)

	ref := ExtractPolicyRef(body)
	if ref == nil {
		t.Fatal("expected non-nil PolicyRef")
	}
	if ref.URL != "https://example.com/policy.rego" {
		t.Errorf("URL = %q, want %q", ref.URL, "https://example.com/policy.rego")
	}
	if ref.QueryPath != "data.test.violations" {
		t.Errorf("QueryPath = %q, want %q", ref.QueryPath, "data.test.violations")
	}
}

func TestExtractPolicyRef_Missing(t *testing.T) {
	body := []byte(`{"message": {"contract": {}}}`)
	ref := ExtractPolicyRef(body)
	if ref != nil {
		t.Errorf("expected nil PolicyRef, got %+v", ref)
	}
}

func TestExtractPolicyRef_PartialMissing(t *testing.T) {
	body := []byte(`{
		"message": {
			"contract": {
				"contractAttributes": {
					"policy": { "url": "https://example.com/policy.rego" }
				}
			}
		}
	}`)
	ref := ExtractPolicyRef(body)
	if ref != nil {
		t.Errorf("expected nil PolicyRef when queryPath missing, got %+v", ref)
	}
}

// ---------------------------------------------------------------------------
// ExtractAction tests
// ---------------------------------------------------------------------------

func TestExtractAction_FromPath(t *testing.T) {
	action := ExtractAction("/bpp/caller/on_status", nil)
	if action != "on_status" {
		t.Errorf("action = %q, want %q", action, "on_status")
	}
}

func TestExtractAction_FromBody(t *testing.T) {
	body := []byte(`{"context": {"action": "on_confirm"}}`)
	action := ExtractAction("/bpp/caller", body)
	if action != "on_confirm" {
		t.Errorf("action = %q, want %q", action, "on_confirm")
	}
}

// ---------------------------------------------------------------------------
// InjectSettlementFlows — legacy contractAttributes shape (raw mode)
// ---------------------------------------------------------------------------

func TestInjectSettlementFlows_LegacyContractAttributes(t *testing.T) {
	body := []byte(`{
		"context": {"action": "on_status"},
		"message": {
			"contract": {
				"contractAttributes": {
					"@type": "DEGContract",
					"policy": {"url": "test", "queryPath": "test"}
				}
			}
		}
	}`)

	flows := []interface{}{
		map[string]interface{}{"role": "buyer", "value": -525.0, "currency": "INR"},
		map[string]interface{}{"role": "seller", "value": 525.0, "currency": "INR"},
	}

	cfg := &Config{
		OutputPath: "message.contract.contractAttributes.revenueFlows",
		OutputMode: OutputModeRaw,
	}
	result, err := InjectSettlementFlows(body, flows, cfg)
	if err != nil {
		t.Fatalf("InjectSettlementFlows failed: %v", err)
	}

	var payload map[string]interface{}
	if err := json.Unmarshal(result, &payload); err != nil {
		t.Fatalf("failed to parse result: %v", err)
	}

	attrs := payload["message"].(map[string]interface{})["contract"].(map[string]interface{})["contractAttributes"].(map[string]interface{})
	rf, ok := attrs["revenueFlows"].([]interface{})
	if !ok {
		t.Fatal("revenueFlows not found or wrong type")
	}
	if len(rf) != 2 {
		t.Errorf("len(revenueFlows) = %d, want 2", len(rf))
	}
	if attrs["@type"] != "DEGContract" {
		t.Errorf("@type lost after injection")
	}
}

// ---------------------------------------------------------------------------
// InjectSettlementFlows — Consideration / JSON-LD mode (find-or-create by id)
// ---------------------------------------------------------------------------

func TestInjectSettlementFlows_Consideration_CreatesEntry(t *testing.T) {
	body := []byte(`{
		"message": {
			"contract": {
				"contractAttributes": {
					"@type": "DEGContract",
					"policy": {"url": "test", "queryPath": "test"}
				}
			}
		}
	}`)
	flows := []interface{}{
		map[string]interface{}{"role": "buyer", "value": -100, "currency": "INR"},
	}
	cfg := &Config{
		OutputPath:       "message.contract.consideration[id=auto-settlement-flows].considerationAttributes",
		OutputMode:       OutputModeJSONLD,
		OutputType:       "RevenueFlow",
		OutputContextURL: "https://example.com/RevenueFlow/v2.0/context.jsonld",
		OutputArrayKey:   "revenueFlows",
		EntryDefaults:    `{"status":{"code":"SETTLED"}}`,
	}
	result, err := InjectSettlementFlows(body, flows, cfg)
	if err != nil {
		t.Fatalf("inject: %v", err)
	}

	var payload map[string]interface{}
	_ = json.Unmarshal(result, &payload)
	contract := payload["message"].(map[string]interface{})["contract"].(map[string]interface{})
	consider := contract["consideration"].([]interface{})
	if len(consider) != 1 {
		t.Fatalf("expected 1 consideration entry, got %d", len(consider))
	}
	entry := consider[0].(map[string]interface{})
	if entry["id"] != "auto-settlement-flows" {
		t.Errorf("entry.id = %q, want auto-settlement-flows", entry["id"])
	}
	status := entry["status"].(map[string]interface{})
	if status["code"] != "SETTLED" {
		t.Errorf("entry.status.code = %v, want SETTLED (entryDefaults)", status["code"])
	}
	ca := entry["considerationAttributes"].(map[string]interface{})
	if ca["@type"] != "RevenueFlow" {
		t.Errorf("@type = %v, want RevenueFlow", ca["@type"])
	}
	if ca["@context"] != "https://example.com/RevenueFlow/v2.0/context.jsonld" {
		t.Errorf("@context = %v", ca["@context"])
	}
	rf := ca["revenueFlows"].([]interface{})
	if len(rf) != 1 {
		t.Errorf("len(revenueFlows) = %d, want 1", len(rf))
	}
}

func TestInjectSettlementFlows_Consideration_ReplacesExistingEntry(t *testing.T) {
	body := []byte(`{
		"message": {
			"contract": {
				"contractAttributes": {"policy": {"url": "test", "queryPath": "test"}},
				"consideration": [
					{
						"id": "auto-settlement-flows",
						"status": {"code": "SETTLED"},
						"considerationAttributes": {
							"@type": "RevenueFlow",
							"revenueFlows": [
								{"role": "buyer", "value": -1, "currency": "INR"}
							]
						}
					}
				]
			}
		}
	}`)
	flows := []interface{}{
		map[string]interface{}{"role": "buyer", "value": -100, "currency": "INR"},
		map[string]interface{}{"role": "seller", "value": 100, "currency": "INR"},
	}
	cfg := &Config{
		OutputPath:    "message.contract.consideration[id=auto-settlement-flows].considerationAttributes",
		OutputMode:    OutputModeJSONLD,
		OutputType:    "RevenueFlow",
		EntryDefaults: `{"status":{"code":"SETTLED"}}`,
	}
	result, err := InjectSettlementFlows(body, flows, cfg)
	if err != nil {
		t.Fatalf("inject: %v", err)
	}

	var payload map[string]interface{}
	_ = json.Unmarshal(result, &payload)
	consider := payload["message"].(map[string]interface{})["contract"].(map[string]interface{})["consideration"].([]interface{})
	if len(consider) != 1 {
		t.Fatalf("expected idempotent replace (1 entry), got %d", len(consider))
	}
	rf := consider[0].(map[string]interface{})["considerationAttributes"].(map[string]interface{})["revenueFlows"].([]interface{})
	if len(rf) != 2 {
		t.Errorf("revenueFlows not replaced: len=%d, want 2", len(rf))
	}
}

// ---------------------------------------------------------------------------
// Path resolver tests
// ---------------------------------------------------------------------------

func TestParsePath_PlainKey(t *testing.T) {
	segs, err := ParsePath("message.contract.contractAttributes.revenueFlows")
	if err != nil {
		t.Fatalf("ParsePath: %v", err)
	}
	if len(segs) != 4 {
		t.Fatalf("got %d segments, want 4", len(segs))
	}
	for _, s := range segs {
		if s.IsArray {
			t.Errorf("segment %q unexpectedly marked array", s.Key)
		}
	}
}

func TestParsePath_BracketForms(t *testing.T) {
	cases := []struct {
		in        string
		wantKey   string
		wantArray bool
		check     func(*testing.T, PathSegment)
	}{
		{"foo[]", "foo", true, func(t *testing.T, s PathSegment) {
			if !s.Append {
				t.Error("expected Append")
			}
		}},
		{"foo[3]", "foo", true, func(t *testing.T, s PathSegment) {
			if !s.IsPositional || s.Index != 3 {
				t.Errorf("expected positional index 3, got %+v", s)
			}
		}},
		{"foo[id=auto-settlement-flows]", "foo", true, func(t *testing.T, s PathSegment) {
			if s.MatchKey != "id" || s.MatchVal != "auto-settlement-flows" {
				t.Errorf("expected k=v match, got %+v", s)
			}
		}},
	}
	for _, c := range cases {
		segs, err := ParsePath(c.in)
		if err != nil {
			t.Fatalf("%q: %v", c.in, err)
		}
		if len(segs) != 1 {
			t.Fatalf("%q: got %d segments", c.in, len(segs))
		}
		s := segs[0]
		if s.Key != c.wantKey || s.IsArray != c.wantArray {
			t.Errorf("%q: key=%q array=%v, want key=%q array=%v", c.in, s.Key, s.IsArray, c.wantKey, c.wantArray)
		}
		c.check(t, s)
	}
}

func TestSetAtPath_FindOrCreate(t *testing.T) {
	payload := map[string]interface{}{
		"message": map[string]interface{}{
			"contract": map[string]interface{}{},
		},
	}
	segs, err := ParsePath("message.contract.consideration[id=x].considerationAttributes")
	if err != nil {
		t.Fatal(err)
	}
	val := map[string]interface{}{"@type": "RevenueFlow"}
	defaults := map[string]interface{}{"status": map[string]interface{}{"code": "SETTLED"}}
	if err := SetAtPath(payload, segs, val, defaults); err != nil {
		t.Fatal(err)
	}
	consider := payload["message"].(map[string]interface{})["contract"].(map[string]interface{})["consideration"].([]interface{})
	if len(consider) != 1 {
		t.Fatalf("got %d entries", len(consider))
	}
	entry := consider[0].(map[string]interface{})
	if entry["id"] != "x" {
		t.Errorf("entry.id = %v", entry["id"])
	}
	if !reflect.DeepEqual(entry["status"], defaults["status"]) {
		t.Errorf("entryDefaults not applied: %v", entry["status"])
	}
	if !reflect.DeepEqual(entry["considerationAttributes"], val) {
		t.Errorf("considerationAttributes wrong: %v", entry["considerationAttributes"])
	}
}

// ---------------------------------------------------------------------------
// Config tests
// ---------------------------------------------------------------------------

func TestParseConfig_RequiresOutputPath(t *testing.T) {
	_, err := ParseConfig(map[string]string{
		"actions":    "on_status",
		"outputMode": OutputModeRaw,
	})
	if err == nil {
		t.Error("expected error when outputPath missing")
	}
}

func TestParseConfig_RequiresOutputMode(t *testing.T) {
	_, err := ParseConfig(map[string]string{
		"actions":    "on_status",
		"outputPath": "message.contract.contractAttributes.revenueFlows",
	})
	if err == nil {
		t.Error("expected error when outputMode missing")
	}
}

func TestParseConfig_LegacyShape(t *testing.T) {
	cfg, err := ParseConfig(map[string]string{
		"actions":    "on_status",
		"outputPath": "message.contract.contractAttributes.revenueFlows",
		"outputMode": "raw",
	})
	if err != nil {
		t.Fatalf("ParseConfig: %v", err)
	}
	if cfg.OutputPath != "message.contract.contractAttributes.revenueFlows" {
		t.Errorf("OutputPath = %q", cfg.OutputPath)
	}
	if cfg.OutputMode != OutputModeRaw {
		t.Errorf("OutputMode = %q", cfg.OutputMode)
	}
}

func TestParseConfig_ConsiderationShape(t *testing.T) {
	cfg, err := ParseConfig(map[string]string{
		"actions":          "on_status",
		"outputPath":       "message.contract.consideration[id=auto-settlement-flows].considerationAttributes",
		"outputMode":       "jsonld",
		"outputType":       "RevenueFlow",
		"outputContextURL": "https://example.com/RevenueFlow/v2.0/context.jsonld",
		"outputArrayKey":   "revenueFlows",
		"entryDefaults":    `{"status":{"code":"SETTLED"}}`,
	})
	if err != nil {
		t.Fatalf("ParseConfig: %v", err)
	}
	if cfg.OutputMode != OutputModeJSONLD {
		t.Errorf("OutputMode = %q", cfg.OutputMode)
	}
	if cfg.OutputType != "RevenueFlow" {
		t.Errorf("OutputType = %q", cfg.OutputType)
	}
}

func TestParseConfig_RejectsInvalidOutputMode(t *testing.T) {
	_, err := ParseConfig(map[string]string{
		"actions":    "on_status",
		"outputPath": "x.y",
		"outputMode": "garbage",
	})
	if err == nil {
		t.Error("expected error on invalid outputMode")
	}
}

func TestIsPolicyURLAllowed(t *testing.T) {
	cfg := &Config{AllowedPolicyURLPrefixes: []string{"https://api.dedi.global/dedi/lookup/indiaenergystack.in"}}
	if !cfg.IsPolicyURLAllowed("https://api.dedi.global/dedi/lookup/indiaenergystack.in/ies-policies/x") {
		t.Error("expected allowed")
	}
	if cfg.IsPolicyURLAllowed("https://api.dedi.global/dedi/lookup/evil.org/policies/x") {
		t.Error("expected blocked: different namespace")
	}
	// Prefix match must not degrade to substring match.
	if cfg.IsPolicyURLAllowed("https://evil.com/?u=https://api.dedi.global/dedi/lookup/indiaenergystack.in") {
		t.Error("expected blocked: allowed prefix appears mid-URL")
	}
	cfg2 := &Config{}
	if !cfg2.IsPolicyURLAllowed("https://anything.com/policy.rego") {
		t.Error("expected allowed when no restrictions")
	}
}

func TestParseConfig_CacheTTLFloor(t *testing.T) {
	_, err := ParseConfig(map[string]string{
		"outputPath": "x.y",
		"outputMode": "raw",
		"cacheTTL":   "60", // 1 minute — below the 1-day floor
	})
	if err == nil {
		t.Error("expected error for cacheTTL below MinCacheTTL")
	}
}

func TestParseConfig_FetchRetriesAndPrefixes(t *testing.T) {
	cfg, err := ParseConfig(map[string]string{
		"outputPath":               "x.y",
		"outputMode":               "raw",
		"fetchRetries":             "3",
		"allowedPolicyUrlPrefixes": "https://a.example, https://b.example",
	})
	if err != nil {
		t.Fatalf("ParseConfig: %v", err)
	}
	if cfg.FetchRetries != 3 {
		t.Errorf("FetchRetries = %d, want 3", cfg.FetchRetries)
	}
	if len(cfg.AllowedPolicyURLPrefixes) != 2 || cfg.AllowedPolicyURLPrefixes[1] != "https://b.example" {
		t.Errorf("AllowedPolicyURLPrefixes = %v", cfg.AllowedPolicyURLPrefixes)
	}

	if _, err := ParseConfig(map[string]string{
		"outputPath":   "x.y",
		"outputMode":   "raw",
		"fetchRetries": "-1",
	}); err == nil {
		t.Error("expected error for negative fetchRetries")
	}
}
