// Package settlementflows is an onix plugin that computes settlement flows
// from a rego policy referenced by the contract and injects them into the message.
//
// It reads the policy URL and query path from
// message.contract.contractAttributes.policy (trade-shaped messages) or from
// each offer's offerAttributes.contractAttributes.policy (catalog publishes),
// resolves the rego source (the URL may serve a bare .rego file or a DeDi
// public-dataset record pointing at one — see source.go), evaluates it
// against the full message, and writes the resulting flows at the configured
// outputPath.
//
// Besides revenue flows, the policy may export a `violations` set (error
// strings). On actions listed in violationActions the step ENFORCES the
// policy: non-empty violations — or any failure to obtain and evaluate the
// policy (fail-closed) — return an error, which the pipeline turns into a
// NACK. This is how a discom's policy (e.g. an allowlist of counterpart
// discoms, or mandated wheeling/penalty charges) blocks non-compliant trades
// at select/init/confirm.
//
// Soft failure everywhere else: on actions not in violationActions, if
// anything goes wrong (fetch, compile, eval), the message passes through
// unmodified with a warning log and delivery is never blocked.
package settlementflows

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/beckn-one/beckn-onix/pkg/log"
	"github.com/beckn-one/beckn-onix/pkg/model"
	"github.com/open-policy-agent/opa/v1/rego"
)

// SettlementFlows is a Step plugin that computes and injects settlement flows.
type SettlementFlows struct {
	config *Config
	cache  *PolicyCache
}

// New creates a new SettlementFlows plugin instance.
func New(cfg map[string]string) (*SettlementFlows, error) {
	config, err := ParseConfig(cfg)
	if err != nil {
		return nil, fmt.Errorf("settlementflows: config: %w", err)
	}

	cache := NewPolicyCache(config)

	fmt.Printf("[SettlementFlows] Enabled=%v, actions=%v, cacheTTL=%s\n",
		config.Enabled, config.Actions, config.CacheTTL)

	return &SettlementFlows{config: config, cache: cache}, nil
}

// Run implements the Step interface.
func (rf *SettlementFlows) Run(ctx *model.StepContext) error {
	if !rf.config.Enabled {
		return nil
	}

	// Check action
	action := ExtractAction(ctx.Request.URL.Path, ctx.Body)
	if !rf.config.IsActionEnabled(action) {
		if rf.config.DebugLogging {
			log.Debugf(ctx, "SettlementFlows: action '%s' not enabled, skipping", action)
		}
		return nil
	}

	// On enforced actions every failure below is fail-closed: the policy
	// gate must not be bypassable by stripping the policy ref or breaking
	// the policy fetch.
	enforced := rf.config.IsViolationEnforced(action)

	// Collect policy references. Trade-shaped messages carry exactly one at
	// message.contract.contractAttributes.policy; catalog publishes carry
	// one per offer at message.catalogs[].offers[].offerAttributes
	// .contractAttributes.policy (deduplicated).
	var refs []*PolicyRef
	if ref := ExtractPolicyRef(ctx.Body); ref != nil {
		refs = append(refs, ref)
	} else {
		refs = ExtractCatalogPolicyRefs(ctx.Body)
	}
	if len(refs) == 0 {
		if enforced {
			return model.NewBadReqErr(fmt.Errorf(
				"settlementflows: action %q requires a policy reference (contractAttributes.policy or per-offer offerAttributes.contractAttributes.policy)", action))
		}
		if rf.config.DebugLogging {
			log.Debug(ctx, "SettlementFlows: no policy reference in message, skipping")
		}
		return nil
	}

	// Parse message as OPA input (once; shared by every policy evaluation).
	var input interface{}
	if err := json.Unmarshal(ctx.Body, &input); err != nil {
		if enforced {
			return model.NewBadReqErr(fmt.Errorf("settlementflows: failed to parse message body: %w", err))
		}
		log.Warnf(ctx, "SettlementFlows: failed to parse message body: %v", err)
		return nil
	}

	// Evaluate every referenced policy; violations accumulate across
	// policies, flows come from the first policy that yields them (trade
	// messages have a single ref anyway).
	var violations []string
	var flows []interface{}
	for _, ref := range refs {
		// Check URL-prefix allowlist
		if !rf.config.IsPolicyURLAllowed(ref.URL) {
			if enforced {
				return model.NewBadReqErr(fmt.Errorf(
					"settlementflows: policy URL does not match allowedPolicyUrlPrefixes: %s", ref.URL))
			}
			log.Warnf(ctx, "SettlementFlows: policy URL does not match allowedPolicyUrlPrefixes: %s", ref.URL)
			continue
		}

		if rf.config.DebugLogging {
			log.Debugf(ctx, "SettlementFlows: evaluating %s with query %s", ref.URL, ref.QueryPath)
		}

		// Get or compile the policy
		pq, err := rf.cache.GetOrCompile(context.Background(), ref.URL, ref.QueryPath)
		if err != nil {
			if enforced {
				return fmt.Errorf("settlementflows: failed to load policy %s: %w", ref.URL, err)
			}
			log.Warnf(ctx, "SettlementFlows: failed to load policy: %v", err)
			continue // soft failure
		}

		// Evaluate
		rs, err := pq.Eval(context.Background(), rego.EvalInput(input))
		if err != nil {
			if enforced {
				return fmt.Errorf("settlementflows: rego evaluation of %s failed: %w", ref.URL, err)
			}
			log.Warnf(ctx, "SettlementFlows: rego evaluation failed: %v", err)
			continue // soft failure
		}

		violations = append(violations, extractViolations(rs)...)
		if flows == nil {
			flows = extractFlows(rs)
		}
	}

	// Violations gate delivery on enforced actions.
	if len(violations) > 0 {
		if enforced {
			log.Warnf(ctx, "SettlementFlows: NACKing %s — %d policy violation(s): %s",
				action, len(violations), strings.Join(violations, "; "))
			return model.NewBadReqErr(fmt.Errorf(
				"settlement policy violations: %s", strings.Join(violations, "; ")))
		}
		log.Warnf(ctx, "SettlementFlows: %d policy violation(s) on %s (not enforced): %s",
			len(violations), action, strings.Join(violations, "; "))
	}
	if flows == nil {
		if rf.config.DebugLogging {
			log.Debug(ctx, "SettlementFlows: no revenue_flows in rego result, skipping injection")
		}
		return nil
	}

	// Inject into message body at the configured outputPath / outputMode.
	modified, err := InjectSettlementFlows(ctx.Body, flows, rf.config)
	if err != nil {
		log.Warnf(ctx, "SettlementFlows: failed to inject revenue_flows: %v", err)
		return nil // soft failure
	}

	ctx.Body = modified
	log.Infof(ctx, "SettlementFlows: injected %d settlement flow(s)", len(flows))
	return nil
}

// Close is a no-op cleanup function.
func (rf *SettlementFlows) Close() {}

// extractFlows pulls revenue_flows from the OPA result set.
// The query evaluates to the full package object; we look for the
// "revenue_flows" key within it.
func extractFlows(rs rego.ResultSet) []interface{} {
	if len(rs) == 0 || len(rs[0].Expressions) == 0 {
		return nil
	}

	val := rs[0].Expressions[0].Value

	// If the query returns the full package, result is a map
	if m, ok := val.(map[string]interface{}); ok {
		if flows, ok := m["revenue_flows"].([]interface{}); ok {
			return flows
		}
		return nil
	}

	// If the query targets revenue_flows directly, result is an array
	if flows, ok := val.([]interface{}); ok {
		return flows
	}

	return nil
}

// extractViolations pulls the policy's `violations` set from the OPA result
// set as strings. Rego sets arrive as JSON arrays. Non-string entries are
// stringified so a malformed policy still produces a readable message.
func extractViolations(rs rego.ResultSet) []string {
	if len(rs) == 0 || len(rs[0].Expressions) == 0 {
		return nil
	}

	val := rs[0].Expressions[0].Value

	// Query returned the full package: look for the "violations" key.
	if m, ok := val.(map[string]interface{}); ok {
		v, ok := m["violations"]
		if !ok {
			return nil
		}
		val = v
	}

	arr, ok := val.([]interface{})
	if !ok {
		return nil
	}

	out := make([]string, 0, len(arr))
	for _, v := range arr {
		if s, ok := v.(string); ok {
			out = append(out, s)
		} else {
			out = append(out, fmt.Sprintf("%v", v))
		}
	}
	return out
}
