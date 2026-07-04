// Package settlementflows is an onix plugin that computes settlement flows
// from a rego policy referenced by the contract and injects them into the message.
//
// It reads the policy URL and query path from
// message.contract.contractAttributes.policy, resolves the rego source (the
// URL may serve a bare .rego file or a DeDi public-dataset record pointing
// at one — see source.go), evaluates it against the full message, and writes
// the resulting flows at the configured outputPath.
//
// Soft failure: if anything goes wrong (fetch, compile, eval), the message
// passes through unmodified with a warning log. Never blocks delivery.
package settlementflows

import (
	"context"
	"encoding/json"
	"fmt"

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

	// Extract policy reference from the message
	ref := ExtractPolicyRef(ctx.Body)
	if ref == nil {
		if rf.config.DebugLogging {
			log.Debug(ctx, "SettlementFlows: no contractAttributes.policy in message, skipping")
		}
		return nil
	}

	// Check URL-prefix allowlist
	if !rf.config.IsPolicyURLAllowed(ref.URL) {
		log.Warnf(ctx, "SettlementFlows: policy URL does not match allowedPolicyUrlPrefixes: %s", ref.URL)
		return nil
	}

	if rf.config.DebugLogging {
		log.Debugf(ctx, "SettlementFlows: evaluating %s with query %s", ref.URL, ref.QueryPath)
	}

	// Get or compile the policy
	pq, err := rf.cache.GetOrCompile(context.Background(), ref.URL, ref.QueryPath)
	if err != nil {
		log.Warnf(ctx, "SettlementFlows: failed to load policy: %v", err)
		return nil // soft failure
	}

	// Parse message as OPA input
	var input interface{}
	if err := json.Unmarshal(ctx.Body, &input); err != nil {
		log.Warnf(ctx, "SettlementFlows: failed to parse message body: %v", err)
		return nil
	}

	// Evaluate
	rs, err := pq.Eval(context.Background(), rego.EvalInput(input))
	if err != nil {
		log.Warnf(ctx, "SettlementFlows: rego evaluation failed: %v", err)
		return nil // soft failure
	}

	// Extract revenue_flows from result
	flows := extractFlows(rs)
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
