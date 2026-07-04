package settlementflows

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

// Config holds configuration for the SettlementFlows plugin.
type Config struct {
	// Enabled controls whether the plugin is active.
	Enabled bool

	// Actions is the list of beckn actions that trigger settlement flow computation.
	// Default: ["on_status"]
	Actions []string

	// CacheTTL is how long a compiled rego policy is cached before re-fetch.
	// Must be at least MinCacheTTL so registries like DeDi see at most one
	// fetch per policy URL per day. Default: 1 day.
	CacheTTL time.Duration

	// MaxCacheEntries is the LRU bound on cached compiled policies.
	// Default: 50.
	MaxCacheEntries int

	// PolicyFetchTimeout is the per-attempt HTTP timeout for fetching the
	// policy (or the DeDi record / data_url behind it). Default: 30 seconds.
	PolicyFetchTimeout time.Duration

	// FetchRetries is how many times a failed fetch (network error or HTTP
	// 5xx) is retried before the resolver gives up. 4xx responses fail
	// immediately — they will not heal on retry. Default: 2.
	FetchRetries int

	// MaxPolicySize is the maximum rego file size in bytes.
	// Default: 1 MB.
	MaxPolicySize int64

	// DebugLogging enables verbose logging.
	DebugLogging bool

	// AllowedPolicyURLPrefixes restricts which policy URLs the plugin
	// resolves: the payload's policy.url must start with one of these
	// prefixes. Empty = allow all. Comma-separated list in YAML, e.g.
	//   "https://api.dedi.global/dedi/lookup/indiaenergystack.in"
	AllowedPolicyURLPrefixes []string

	// ── output destination (REQUIRED in YAML — no code default) ─────────────
	//
	// OutputPath is the destination path within the message body where the
	// rego output is written. REQUIRED — every devkit MUST declare it
	// explicitly in its plugin config (e.g. set
	// "message.contract.contractAttributes.revenueFlows" for the legacy
	// shape). The plugin errors at startup if this is empty so no caller
	// silently relies on a hidden default.
	//
	// Path mini-grammar (dot-separated segments; brackets at the END of a
	// segment apply to the array stored under that key):
	//
	//   foo.bar              → property navigation (creates intermediate
	//                          objects as needed).
	//   foo[0]               → array positional index. Pads the array with
	//                          empty objects up to the index if shorter.
	//   foo[]                → array append. Always creates a new entry.
	//   foo[key=value]       → array find-or-create by key. If an entry
	//                          where obj[key]==value exists, navigate into
	//                          it. Otherwise create a new entry seeded
	//                          with {key: value} (and any EntryDefaults)
	//                          and navigate into that. Idempotent on retry.
	//
	// Examples:
	//   message.contract.contractAttributes.revenueFlows
	//   message.contract.consideration[id=auto-settlement-flows].considerationAttributes
	//   message.contract.commitments[0].offer.offerAttributes.revenueFlows
	OutputPath string

	// OutputMode controls how the rego result is shaped at OutputPath:
	//   "raw"    → write the rego array directly at the leaf (the legacy
	//              shape for contractAttributes.revenueFlows).
	//   "jsonld" → wrap as
	//                {"@context": <OutputContextURL?>, "@type": <OutputType>,
	//                 <OutputArrayKey>: <flows>}
	//              and write that object at the leaf. Suits JSON-LD-aware
	//              attribute containers (considerationAttributes, etc.).
	// REQUIRED — no code default.
	OutputMode string

	// OutputType is the @type written when OutputMode == "jsonld".
	// Optional in YAML; defaults to "RevenueFlow" if unset.
	OutputType string

	// OutputContextURL is the @context URL written when OutputMode == "jsonld".
	// Optional — if empty the @context key is omitted.
	OutputContextURL string

	// OutputArrayKey is the property name under which the rego array is
	// stored when OutputMode == "jsonld".
	// Optional in YAML; defaults to "revenueFlows" if unset.
	OutputArrayKey string

	// EntryDefaults is a JSON-encoded object merged into newly-created
	// array entries during path traversal (the [key=value] find-or-create
	// form). For example, '{"status":{"code":"SETTLED"}}' makes every new
	// Consideration entry carry the Beckn-required status field. Existing
	// entries are NOT modified.
	EntryDefaults string
}

// Output mode constants.
const (
	OutputModeRaw    = "raw"
	OutputModeJSONLD = "jsonld"
)

// MinCacheTTL is the lowest accepted cacheTTL. Policies change rarely and
// every expiry re-hits the policy registry (DeDi) plus the data_url host,
// so anything below a day is rejected at startup.
const MinCacheTTL = 24 * time.Hour

// DefaultConfig returns a Config seeded with sensible defaults for the
// non-primary fields. Primary behavior knobs (OutputPath, OutputMode) are
// intentionally left empty — ParseConfig requires them in the YAML.
func DefaultConfig() *Config {
	return &Config{
		Enabled:            true,
		Actions:            []string{"on_status"},
		CacheTTL:           MinCacheTTL,
		MaxCacheEntries:    50,
		PolicyFetchTimeout: 30 * time.Second,
		FetchRetries:       2,
		MaxPolicySize:      1 << 20, // 1 MB
		DebugLogging:       false,
		// OutputPath / OutputMode: required, no default.
		OutputType:     "RevenueFlow",
		OutputArrayKey: "revenueFlows",
	}
}

// ParseConfig parses the plugin configuration map.
func ParseConfig(cfg map[string]string) (*Config, error) {
	config := DefaultConfig()

	if enabled, ok := cfg["enabled"]; ok {
		config.Enabled = enabled == "true" || enabled == "1"
	}

	if actions, ok := cfg["actions"]; ok && actions != "" {
		list := strings.Split(actions, ",")
		config.Actions = make([]string, 0, len(list))
		for _, a := range list {
			a = strings.TrimSpace(a)
			if a != "" {
				config.Actions = append(config.Actions, a)
			}
		}
	}

	if ttl, ok := cfg["cacheTTL"]; ok && ttl != "" {
		seconds, err := strconv.Atoi(ttl)
		if err != nil {
			d, err2 := time.ParseDuration(ttl)
			if err2 != nil {
				return nil, err
			}
			config.CacheTTL = d
		} else {
			config.CacheTTL = time.Duration(seconds) * time.Second
		}
	}

	if max, ok := cfg["maxCacheEntries"]; ok && max != "" {
		n, err := strconv.Atoi(max)
		if err != nil {
			return nil, err
		}
		config.MaxCacheEntries = n
	}

	if debug, ok := cfg["debugLogging"]; ok {
		config.DebugLogging = debug == "true" || debug == "1"
	}

	if r, ok := cfg["fetchRetries"]; ok && r != "" {
		n, err := strconv.Atoi(r)
		if err != nil || n < 0 {
			return nil, fmt.Errorf("settlementflows: invalid fetchRetries %q (want integer >= 0)", r)
		}
		config.FetchRetries = n
	}

	if prefixes, ok := cfg["allowedPolicyUrlPrefixes"]; ok && prefixes != "" {
		for _, p := range strings.Split(prefixes, ",") {
			p = strings.TrimSpace(p)
			if p != "" {
				config.AllowedPolicyURLPrefixes = append(config.AllowedPolicyURLPrefixes, p)
			}
		}
	}

	if p, ok := cfg["outputPath"]; ok {
		config.OutputPath = strings.TrimSpace(p)
	}

	if m, ok := cfg["outputMode"]; ok {
		m = strings.TrimSpace(m)
		switch m {
		case OutputModeRaw, OutputModeJSONLD, "":
			config.OutputMode = m
		default:
			return nil, fmt.Errorf("settlementflows: invalid outputMode %q (allowed: %q, %q)",
				m, OutputModeRaw, OutputModeJSONLD)
		}
	}

	if t, ok := cfg["outputType"]; ok && strings.TrimSpace(t) != "" {
		config.OutputType = strings.TrimSpace(t)
	}

	if u, ok := cfg["outputContextURL"]; ok {
		config.OutputContextURL = strings.TrimSpace(u)
	}

	if k, ok := cfg["outputArrayKey"]; ok && strings.TrimSpace(k) != "" {
		config.OutputArrayKey = strings.TrimSpace(k)
	}

	if d, ok := cfg["entryDefaults"]; ok {
		config.EntryDefaults = strings.TrimSpace(d)
	}

	// Required fields — no code defaults. Each devkit's YAML MUST declare
	// the destination explicitly so behavior is visible from the config.
	if config.OutputPath == "" {
		return nil, fmt.Errorf(
			"settlementflows: outputPath is required (e.g. " +
				"\"message.contract.contractAttributes.revenueFlows\" or " +
				"\"message.contract.consideration[id=auto-settlement-flows].considerationAttributes\")")
	}
	if config.OutputMode == "" {
		return nil, fmt.Errorf(
			"settlementflows: outputMode is required (allowed: %q, %q)",
			OutputModeRaw, OutputModeJSONLD)
	}
	if config.CacheTTL < MinCacheTTL {
		return nil, fmt.Errorf(
			"settlementflows: cacheTTL %s is below the minimum %s (policies are fetched from a registry; short TTLs hammer it)",
			config.CacheTTL, MinCacheTTL)
	}

	return config, nil
}

// IsActionEnabled checks if the given action is in the configured list.
func (c *Config) IsActionEnabled(action string) bool {
	for _, a := range c.Actions {
		if a == action {
			return true
		}
	}
	return false
}

// IsPolicyURLAllowed checks if the policy URL starts with one of the
// configured prefixes. Returns true if no restriction is configured.
func (c *Config) IsPolicyURLAllowed(url string) bool {
	if len(c.AllowedPolicyURLPrefixes) == 0 {
		return true
	}
	for _, p := range c.AllowedPolicyURLPrefixes {
		if strings.HasPrefix(url, p) {
			return true
		}
	}
	return false
}
