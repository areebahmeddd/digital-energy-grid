# Unit tests for demand-flex-networkpolicy.rego
#
# Run:  cd specification/policies && opa test demand-flex-networkpolicy.rego test/demand-flex-networkpolicy_test.rego -v

package deg.policy.demand_flex_network

import rego.v1

# Helper: minimal on_status payload with one meter
_payload(meter) := {"message": {"contract": {"performance": [
	{"performanceAttributes": {"meters": [meter]}},
]}}}

# Test: clean payload (every used type declared) → no violations
test_clean_payload if {
	meter := {
		"meterId": "der://meter/001",
		"telemetry": {
			"payloadDescriptors": [
				{"payloadType": "BASELINE"},
				{"payloadType": "USAGE"},
			],
			"intervals": [{"payloads": [
				{"type": "BASELINE", "values": [46.0]},
				{"type": "USAGE", "values": [22.0]},
			]}],
		},
	}
	count(violations) == 0 with input as _payload(meter)
}

# Test: typo in interval (BASELIN instead of BASELINE) → violation
test_typo_baselin_in_interval if {
	meter := {
		"meterId": "der://meter/001",
		"telemetry": {
			"payloadDescriptors": [
				{"payloadType": "BASELINE"},
				{"payloadType": "USAGE"},
			],
			"intervals": [{"payloads": [
				{"type": "BASELIN", "values": [46.0]},
				{"type": "USAGE", "values": [22.0]},
			]}],
		},
	}
	vs := violations with input as _payload(meter)
	count(vs) == 1
	some v in vs
	contains(v, "BASELIN")
	contains(v, "der://meter/001")
}

# Test: declared-but-unused (USAGE in descriptors, only BASELINE in intervals) → no violation
test_declared_but_unused_is_allowed if {
	meter := {
		"meterId": "der://meter/001",
		"telemetry": {
			"payloadDescriptors": [
				{"payloadType": "BASELINE"},
				{"payloadType": "USAGE"},
			],
			"intervals": [{"payloads": [
				{"type": "BASELINE", "values": [46.0]},
			]}],
		},
	}
	count(violations) == 0 with input as _payload(meter)
}

# Test: action without telemetry (e.g. on_select) → no violation
test_no_performance_no_violation if {
	inp := {"message": {"contract": {"id": "c1"}}}
	count(violations) == 0 with input as inp
}

# Test: typo on one meter, others clean → exactly one violation, naming the bad meter
test_typo_isolated_to_one_meter if {
	good := {
		"meterId": "der://meter/002",
		"telemetry": {
			"payloadDescriptors": [{"payloadType": "BASELINE"}],
			"intervals": [{"payloads": [{"type": "BASELINE", "values": [40.0]}]}],
		},
	}
	bad := {
		"meterId": "der://meter/001",
		"telemetry": {
			"payloadDescriptors": [{"payloadType": "BASELINE"}],
			"intervals": [{"payloads": [{"type": "BASLN", "values": [46.0]}]}],
		},
	}
	inp := {"message": {"contract": {"performance": [
		{"performanceAttributes": {"meters": [good, bad]}},
	]}}}
	vs := violations with input as inp
	count(vs) == 1
	some v in vs
	contains(v, "der://meter/001")
	contains(v, "BASLN")
}

# ---------------------------------------------------------------------------
# 1b) DemandFlexNeed cross-field type-coverage (need is itself a TimeSeries)
# ---------------------------------------------------------------------------

_valid_need := {
	"intervalPeriod": {"start": "2026-04-01T08:30:00Z", "duration": "PT30M"},
	"payloadDescriptors": [
		{"objectType": "EVENT_PAYLOAD_DESCRIPTOR", "payloadType": "CAPACITY_REQUESTED"},
		{"objectType": "EVENT_PAYLOAD_DESCRIPTOR", "payloadType": "PRICE"},
		{"objectType": "EVENT_PAYLOAD_DESCRIPTOR", "payloadType": "SHORTFALL_PENALTY"},
	],
	"intervals": [
		{"id": 0, "payloads": [{"type": "CAPACITY_REQUESTED", "values": [150]}, {"type": "PRICE", "values": [3.5]}, {"type": "SHORTFALL_PENALTY", "values": [1.5]}]},
	],
}

_need_input(ra) := {"message": {"contract": {"commitments": [{"resources": [{"resourceAttributes": ra}]}]}}}

# clean need → no violations
test_need_type_coverage_ok if {
	count(violations) == 0 with input as _need_input(_valid_need)
}

# undeclared payload type in the need → violation naming DemandFlexNeed + the type
test_need_type_coverage_violation if {
	bad := json.patch(_valid_need, [{"op": "add", "path": "/intervals/0/payloads/-", "value": {"type": "MYSTERY", "values": [1]}}])
	vs := violations with input as _need_input(bad)
	some v in vs
	contains(v, "DemandFlexNeed")
	contains(v, "MYSTERY")
}

# need missing payloadDescriptors → every used type flagged
test_need_missing_descriptors_violation if {
	bad := json.patch(_valid_need, [{"op": "remove", "path": "/payloadDescriptors"}])
	vs := violations with input as _need_input(bad)
	some v in vs
	contains(v, "DemandFlexNeed")
}

# same check applies at catalog publish time
test_need_type_coverage_catalog if {
	bad := json.patch(_valid_need, [{"op": "add", "path": "/intervals/0/payloads/-", "value": {"type": "MYSTERY", "values": [1]}}])
	inp := {"message": {"catalogs": [{"resources": [{"resourceAttributes": bad}]}]}}
	vs := violations with input as inp
	some v in vs
	contains(v, "MYSTERY")
}
