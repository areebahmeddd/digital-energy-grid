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
