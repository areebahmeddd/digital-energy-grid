package contractpolicyenforcer

import (
	"encoding/json"
	"fmt"
	"strings"
)

// PolicyRef holds the policy URL and OPA query path extracted from a message.
type PolicyRef struct {
	URL       string
	QueryPath string
}

// ExtractPolicyRef reads contractAttributes.policy.url and .queryPath from
// the message body. Returns nil if not present.
func ExtractPolicyRef(body []byte) *PolicyRef {
	var envelope struct {
		Message struct {
			Contract struct {
				ContractAttributes struct {
					Policy struct {
						URL       string `json:"url"`
						QueryPath string `json:"queryPath"`
					} `json:"policy"`
				} `json:"contractAttributes"`
			} `json:"contract"`
		} `json:"message"`
	}

	if err := json.Unmarshal(body, &envelope); err != nil {
		return nil
	}

	url := envelope.Message.Contract.ContractAttributes.Policy.URL
	qp := envelope.Message.Contract.ContractAttributes.Policy.QueryPath
	if url == "" || qp == "" {
		return nil
	}

	return &PolicyRef{URL: url, QueryPath: qp}
}

// ExtractCatalogPolicyRefs reads the per-offer policy references from a
// catalog-publish payload: message.catalogs[].offers[].offerAttributes
// .contractAttributes.policy. Returns the deduplicated refs (a catalog may
// carry many offers all pointing at the same discom policy).
func ExtractCatalogPolicyRefs(body []byte) []*PolicyRef {
	var envelope struct {
		Message struct {
			Catalogs []struct {
				Offers []struct {
					OfferAttributes struct {
						ContractAttributes struct {
							Policy struct {
								URL       string `json:"url"`
								QueryPath string `json:"queryPath"`
							} `json:"policy"`
						} `json:"contractAttributes"`
					} `json:"offerAttributes"`
				} `json:"offers"`
			} `json:"catalogs"`
		} `json:"message"`
	}

	if err := json.Unmarshal(body, &envelope); err != nil {
		return nil
	}

	var refs []*PolicyRef
	seen := map[string]bool{}
	for _, c := range envelope.Message.Catalogs {
		for _, o := range c.Offers {
			p := o.OfferAttributes.ContractAttributes.Policy
			if p.URL == "" || p.QueryPath == "" {
				continue
			}
			key := p.URL + "\x00" + p.QueryPath
			if seen[key] {
				continue
			}
			seen[key] = true
			refs = append(refs, &PolicyRef{URL: p.URL, QueryPath: p.QueryPath})
		}
	}
	return refs
}

// ExtractAction reads the beckn action from the URL path or context.action.
func ExtractAction(urlPath string, body []byte) string {
	// Try URL path first (e.g., /bpp/caller/on_status → on_status)
	parts := strings.Split(strings.TrimRight(urlPath, "/"), "/")
	if len(parts) > 0 {
		action := parts[len(parts)-1]
		if action != "" && action != "caller" && action != "receiver" {
			return action
		}
	}

	// Fallback: parse context.action from body
	var envelope struct {
		Context struct {
			Action string `json:"action"`
		} `json:"context"`
	}
	if err := json.Unmarshal(body, &envelope); err == nil && envelope.Context.Action != "" {
		return envelope.Context.Action
	}

	return ""
}

// InjectSettlementFlows writes the rego output into the message body at the
// configured destination. Behavior is fully driven by `cfg`:
//
//   - cfg.OutputPath defines WHERE the value lands (see path.go).
//   - cfg.OutputMode controls the SHAPE of the value:
//       "raw"    — write the rego array directly at the leaf.
//       "jsonld" — wrap as {@context?, @type, <OutputArrayKey>: flows}.
//   - cfg.OutputType / OutputContextURL / OutputArrayKey shape the wrapper
//     when mode == "jsonld".
//   - cfg.EntryDefaults seeds keys on newly-created [k=v] entries (e.g.
//     '{"status":{"code":"SETTLED"}}' for Beckn-required Consideration.status).
//
// Numbers in the existing body are preserved via json.Number.
func InjectSettlementFlows(body []byte, flows interface{}, cfg *Config) ([]byte, error) {
	if cfg == nil {
		return nil, fmt.Errorf("nil config")
	}
	dec := json.NewDecoder(strings.NewReader(string(body)))
	dec.UseNumber()

	var payload map[string]interface{}
	if err := dec.Decode(&payload); err != nil {
		return nil, fmt.Errorf("failed to decode body: %w", err)
	}

	segs, err := ParsePath(cfg.OutputPath)
	if err != nil {
		return nil, fmt.Errorf("invalid outputPath %q: %w", cfg.OutputPath, err)
	}

	var entryDefaults map[string]interface{}
	if strings.TrimSpace(cfg.EntryDefaults) != "" {
		if err := json.Unmarshal([]byte(cfg.EntryDefaults), &entryDefaults); err != nil {
			return nil, fmt.Errorf("invalid entryDefaults JSON: %w", err)
		}
	}

	value, err := buildOutputValue(flows, cfg)
	if err != nil {
		return nil, err
	}

	if err := SetAtPath(payload, segs, value, entryDefaults); err != nil {
		return nil, fmt.Errorf("failed to write at outputPath %q: %w", cfg.OutputPath, err)
	}

	return json.Marshal(payload)
}

// buildOutputValue shapes the rego output according to OutputMode.
func buildOutputValue(flows interface{}, cfg *Config) (interface{}, error) {
	switch cfg.OutputMode {
	case OutputModeRaw, "":
		return flows, nil
	case OutputModeJSONLD:
		key := cfg.OutputArrayKey
		if key == "" {
			key = "revenueFlows"
		}
		typ := cfg.OutputType
		if typ == "" {
			typ = "RevenueFlow"
		}
		out := map[string]interface{}{
			"@type": typ,
			key:     flows,
		}
		if cfg.OutputContextURL != "" {
			out["@context"] = cfg.OutputContextURL
		}
		return out, nil
	default:
		return nil, fmt.Errorf("unknown outputMode %q", cfg.OutputMode)
	}
}
