package settlementflows

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// PathSegment is one parsed step in an output path.
//
// The bracket form (if any) is captured by exactly one of:
//   - Append      = true            for "[]"
//   - Index       = N (>=0)         for "[N]"  (IsPositional set)
//   - MatchKey    = k, MatchVal = v for "[k=v]"
type PathSegment struct {
	Key          string // property name on the parent map; required.
	IsArray      bool   // segment uses bracket syntax (one of the three forms below).
	Append       bool   // "[]" form
	IsPositional bool   // "[N]" form
	Index        int    // when IsPositional
	MatchKey     string // when "[k=v]" form
	MatchVal     string // when "[k=v]" form
}

var bracketRe = regexp.MustCompile(`^([^\[\]]+?)(\[(.*?)\])?$`)

// ParsePath parses a dotted output path into segments.
//
// Grammar:
//   path     := segment ("." segment)*
//   segment  := key | key "[" expr "]"
//   expr     := "" | digits | k "=" v
//   key      := non-bracket, non-dot identifier (any chars allowed except [].)
func ParsePath(p string) ([]PathSegment, error) {
	if strings.TrimSpace(p) == "" {
		return nil, fmt.Errorf("empty path")
	}
	parts := strings.Split(p, ".")
	segs := make([]PathSegment, 0, len(parts))
	for i, raw := range parts {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			return nil, fmt.Errorf("segment %d is empty in path %q", i, p)
		}
		m := bracketRe.FindStringSubmatch(raw)
		if m == nil || m[1] == "" {
			return nil, fmt.Errorf("segment %q in path %q is malformed", raw, p)
		}
		seg := PathSegment{Key: m[1]}
		if m[2] != "" { // bracket present
			seg.IsArray = true
			inside := m[3]
			switch {
			case inside == "":
				seg.Append = true
			case strings.Contains(inside, "="):
				kv := strings.SplitN(inside, "=", 2)
				k := strings.TrimSpace(kv[0])
				v := strings.TrimSpace(kv[1])
				if k == "" {
					return nil, fmt.Errorf("segment %q has empty match key", raw)
				}
				seg.MatchKey = k
				seg.MatchVal = v
			default:
				idx, err := strconv.Atoi(strings.TrimSpace(inside))
				if err != nil || idx < 0 {
					return nil, fmt.Errorf("segment %q has invalid array index %q", raw, inside)
				}
				seg.IsPositional = true
				seg.Index = idx
			}
		}
		segs = append(segs, seg)
	}
	return segs, nil
}

// SetAtPath walks `payload` along `segs` and sets `value` at the leaf.
//
// Behavior:
//   - Plain key segments create intermediate maps if missing.
//   - "[N]" pads the array with empty maps up to length N+1 and navigates
//     into the entry at index N (or sets value there if leaf).
//   - "[]" always appends. Non-leaf appends create a fresh empty map and
//     navigate into it; leaf appends append `value` itself.
//   - "[k=v]" finds an existing entry whose obj[k]==v; if absent, appends
//     a new entry seeded with {k: v} (and any keys from `entryDefaults`).
//     Idempotent on retry.
//
// `entryDefaults` is a map merged into each NEWLY-created [k=v] entry
// (existing entries are not modified). Pass nil if no defaults are wanted.
func SetAtPath(payload map[string]interface{}, segs []PathSegment, value interface{}, entryDefaults map[string]interface{}) error {
	if len(segs) == 0 {
		return fmt.Errorf("no segments")
	}
	// `current` is always a map (the parent we're navigating from).
	current := payload
	for i, seg := range segs {
		last := i == len(segs)-1
		if seg.Key == "" {
			return fmt.Errorf("segment %d has empty key", i)
		}

		if !seg.IsArray {
			// Plain property
			if last {
				current[seg.Key] = value
				return nil
			}
			child, ok := current[seg.Key].(map[string]interface{})
			if !ok || child == nil {
				child = map[string]interface{}{}
				current[seg.Key] = child
			}
			current = child
			continue
		}

		// Array forms — fetch / create the array on the parent.
		arr, _ := current[seg.Key].([]interface{})
		if arr == nil {
			arr = []interface{}{}
		}

		switch {
		case seg.Append:
			if last {
				arr = append(arr, value)
				current[seg.Key] = arr
				return nil
			}
			newEntry := map[string]interface{}{}
			arr = append(arr, newEntry)
			current[seg.Key] = arr
			current = newEntry

		case seg.IsPositional:
			for len(arr) <= seg.Index {
				arr = append(arr, map[string]interface{}{})
			}
			if last {
				arr[seg.Index] = value
				current[seg.Key] = arr
				return nil
			}
			child, ok := arr[seg.Index].(map[string]interface{})
			if !ok || child == nil {
				child = map[string]interface{}{}
				arr[seg.Index] = child
			}
			current[seg.Key] = arr
			current = child

		case seg.MatchKey != "":
			idx := -1
			for j, raw := range arr {
				obj, ok := raw.(map[string]interface{})
				if !ok {
					continue
				}
				if v, ok := obj[seg.MatchKey]; ok && fmt.Sprint(v) == seg.MatchVal {
					idx = j
					break
				}
			}
			if idx < 0 {
				newEntry := map[string]interface{}{seg.MatchKey: seg.MatchVal}
				for k, v := range entryDefaults {
					if _, exists := newEntry[k]; !exists {
						newEntry[k] = v
					}
				}
				arr = append(arr, newEntry)
				idx = len(arr) - 1
			}
			if last {
				arr[idx] = value
				current[seg.Key] = arr
				return nil
			}
			child, ok := arr[idx].(map[string]interface{})
			if !ok || child == nil {
				child = map[string]interface{}{}
				arr[idx] = child
			}
			current[seg.Key] = arr
			current = child

		default:
			return fmt.Errorf("segment %d has empty bracket", i)
		}
	}
	return nil
}
