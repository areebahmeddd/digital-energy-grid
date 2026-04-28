package revenueflows

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

// Config holds configuration for the RevenueFlows plugin.
type Config struct {
	// Enabled controls whether the plugin is active.
	Enabled bool

	// Actions is the list of beckn actions that trigger revenue flow computation.
	// Default: ["on_status"]
	Actions []string

	// CacheTTL is how long a compiled rego policy is cached before re-fetch.
	// Default: 5 minutes.
	CacheTTL time.Duration

	// MaxCacheEntries is the LRU bound on cached compiled policies.
	// Default: 50.
	MaxCacheEntries int

	// PolicyFetchTimeout is the HTTP timeout for fetching rego from a URL.
	// Default: 30 seconds.
	PolicyFetchTimeout time.Duration

	// MaxPolicySize is the maximum rego file size in bytes.
	// Default: 1 MB.
	MaxPolicySize int64

	// DebugLogging enables verbose logging.
	DebugLogging bool

	// AllowedDomains restricts which domains rego can be fetched from.
	// Empty = allow all. Comma-separated list.
	AllowedDomains []string

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
	//   message.contract.consideration[id=auto-revenue-flows].considerationAttributes
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

// DefaultConfig returns a Config seeded with sensible defaults for the
// non-primary fields. Primary behavior knobs (OutputPath, OutputMode) are
// intentionally left empty — ParseConfig requires them in the YAML.
func DefaultConfig() *Config {
	return &Config{
		Enabled:            true,
		Actions:            []string{"on_status"},
		CacheTTL:           5 * time.Minute,
		MaxCacheEntries:    50,
		PolicyFetchTimeout: 30 * time.Second,
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

	if domains, ok := cfg["allowedDomains"]; ok && domains != "" {
		for _, d := range strings.Split(domains, ",") {
			d = strings.TrimSpace(d)
			if d != "" {
				config.AllowedDomains = append(config.AllowedDomains, d)
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
			return nil, fmt.Errorf("revenueflows: invalid outputMode %q (allowed: %q, %q)",
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
			"revenueflows: outputPath is required (e.g. " +
				"\"message.contract.contractAttributes.revenueFlows\" or " +
				"\"message.contract.consideration[id=auto-revenue-flows].considerationAttributes\")")
	}
	if config.OutputMode == "" {
		return nil, fmt.Errorf(
			"revenueflows: outputMode is required (allowed: %q, %q)",
			OutputModeRaw, OutputModeJSONLD)
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

// IsDomainAllowed checks if the URL domain is in the allowed list.
// Returns true if no domain restriction is configured.
func (c *Config) IsDomainAllowed(url string) bool {
	if len(c.AllowedDomains) == 0 {
		return true
	}
	for _, d := range c.AllowedDomains {
		if strings.Contains(url, d) {
			return true
		}
	}
	return false
}
