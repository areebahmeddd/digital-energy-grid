# Unit tests for demand_flex_revenue.rego role-based settlement
#
# Run:  cd specification/policies && opa test demand_flex_revenue.rego demand_flex_revenue_test.rego -v

package deg.contracts.demand_flex

import rego.v1

# ---------------------------------------------------------------------------
# Helpers: build a mock contract payload with BecknTimeSeries telemetry
#
# For brevity, _meter(meterId, baselineKw, actualKw) wraps the scalars in
# a single-interval BecknTimeSeries; tests stay readable while still
# exercising the policy's BecknTimeSeries readers end-to-end.
# ---------------------------------------------------------------------------

_meter_with_actual(meter_id, baseline_kw, actual_kw) := {
	"meterId": meter_id,
	"telemetry": {
		"@type": "TimeSeries",
		"intervalPeriod": {"start": "2026-04-01T08:30:00Z", "duration": "PT2H"},
		"payloadDescriptors": [
			{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "BASELINE", "units": "KW", "readingType": "DIRECT_READ"},
			{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "USAGE", "units": "KW", "readingType": "DIRECT_READ"},
		],
		"intervals": [{"id": 0, "payloads": [
			{"type": "BASELINE", "values": [baseline_kw]},
			{"type": "USAGE", "values": [actual_kw]},
		]}],
	},
}

_meter_baseline_only(meter_id, baseline_kw) := {
	"meterId": meter_id,
	"telemetry": {
		"@type": "TimeSeries",
		"intervalPeriod": {"start": "2026-04-01T08:30:00Z", "duration": "PT2H"},
		"payloadDescriptors": [
			{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "BASELINE", "units": "KW", "readingType": "DIRECT_READ"},
		],
		"intervals": [{"id": 0, "payloads": [
			{"type": "BASELINE", "values": [baseline_kw]},
		]}],
	},
}

_deg_contract := {
	"@context": "test", "@type": "DEGContract",
	"roles": [{"role": "buyer"}, {"role": "seller"}],
	"policy": {"url": "test", "queryPath": "test"},
}

_default_inputs := [
	{"role": "buyer", "participantId": "utility-test", "inputs": {
		"incentivePerKwh": 3.50,
		"currency": "INR",
		"penaltyRate": 1.50,
		"premiumForGuaranteed": 5.00,
		"maxEventsPerMonth": 5,
		"baselineMethodology": {"bestOf": 5, "outOf": 10},
		"optOutDefault": false,
	}},
	{"role": "seller", "participantId": "agg-test", "inputs": {
		"plannedDemandChange": 150.0,
		"participatingMeters": ["m1", "m2", "m3"],
	}},
]

_default_window := {"startDate": "2026-04-01T08:30:00Z", "endDate": "2026-04-01T10:30:00Z"}

_mock_input(role_inputs, meters, event_window, contract_attrs) := {
	"message": {"contract": {
		"id": "test",
		"status": {"code": "ACTIVE"},
		"commitments": [{
			"id": "c1",
			"status": {"descriptor": {"code": "ACTIVE"}},
			"resources": [{
				"id": "r1",
				"quantity": {"unitCode": "kW", "unitQuantity": 150},
				"resourceAttributes": {
					"@context": "test", "@type": "DemandFlexNeed",
					"direction": "REDUCE", "eventWindow": event_window,
					"capacityType": "CURTAILMENT", "maxCapacityKw": 500,
				},
			}],
			"offer": {
				"id": "o1", "resourceIds": ["r1"],
				"offerAttributes": {
					"@context": "test", "@type": "DemandFlexBuyOffer",
					"inputs": role_inputs,
				},
			},
		}],
		"performance": [{"id": "p1", "status": {"code": "DELIVERY_COMPLETE"}, "commitmentIds": ["c1"], "performanceAttributes": {
			"@context": "test", "@type": "DemandFlexPerformance",
			"eventId": "evt-test", "methodology": "5of10", "meters": meters,
		}}],
		"contractAttributes": contract_attrs,
	}},
}

_std_input(meters) := _mock_input(_default_inputs, meters, _default_window, _deg_contract)

# ---------------------------------------------------------------------------
# Test: happy path — revenue flows sum to zero
# ---------------------------------------------------------------------------

test_revenue_flows_net_zero if {
	inp := _std_input([
		_meter_with_actual("m1", 45.0, 20.0),
		_meter_with_actual("m2", 38.0, 15.0),
		_meter_with_actual("m3", 52.0, 25.0),
	])

	flows := revenue_flows with input as inp
	count(flows) == 2

	some bf in flows; bf.role == "buyer"; bf.value == -525
	some sf in flows; sf.role == "seller"; sf.value == 525

	net_zero_ok with input as inp
	count(violations) == 0 with input as inp
}

# ---------------------------------------------------------------------------
# Test: roles extracted from contractAttributes
# ---------------------------------------------------------------------------

test_roles_detected if {
	inp := _std_input([_meter_with_actual("m1", 45.0, 20.0)])
	roles := _roles with input as inp
	"buyer" in roles
	"seller" in roles
}

# ---------------------------------------------------------------------------
# Test: missing role → violation
# ---------------------------------------------------------------------------

test_missing_seller_violation if {
	no_seller := {"@context": "test", "@type": "DEGContract", "roles": [{"role": "buyer"}], "policy": {"url": "t", "queryPath": "t"}}
	inp := _mock_input(_default_inputs, [_meter_with_actual("m1", 45.0, 20.0)], _default_window, no_seller)
	vs := violations with input as inp
	some v in vs
	contains(v, "seller")
}

# ---------------------------------------------------------------------------
# Test: settlement total
# ---------------------------------------------------------------------------

test_settlement_total if {
	inp := _std_input([
		_meter_with_actual("m1", 45.0, 20.0),
		_meter_with_actual("m2", 38.0, 15.0),
		_meter_with_actual("m3", 52.0, 25.0),
	])
	total_settlement == 525 with input as inp
	count(settlement_components) == 3 with input as inp
}

# ---------------------------------------------------------------------------
# Test: negative reduction clamped
# ---------------------------------------------------------------------------

test_clamped_meter_excluded if {
	inp := _std_input([
		_meter_with_actual("m1", 30.0, 40.0),
		_meter_with_actual("m2", 50.0, 20.0),
	])
	total_settlement == 210 with input as inp
	flows := revenue_flows with input as inp
	some bf in flows; bf.role == "buyer"; bf.value == -210
}

# ---------------------------------------------------------------------------
# Test: 3-hour event scales
# ---------------------------------------------------------------------------

test_3h_event if {
	w3h := {"startDate": "2026-04-01T08:00:00Z", "endDate": "2026-04-01T11:00:00Z"}
	inp := _mock_input(_default_inputs, [_meter_with_actual("m1", 40.0, 20.0)], w3h, _deg_contract)
	flows := revenue_flows with input as inp
	some sf in flows; sf.role == "seller"; sf.value == 210
}

# ---------------------------------------------------------------------------
# Test: BecknTimeSeries with multiple intervals — mean is used
# ---------------------------------------------------------------------------

test_multi_interval_mean if {
	# Two intervals; mean baseline = 45, mean usage = 20 → reduction 25 kW
	# 25 kW × 2h × 3.50 INR/kWh = 175 INR
	multi_interval_meter := {
		"meterId": "m1",
		"telemetry": {
			"@type": "TimeSeries",
			"intervalPeriod": {"start": "2026-04-01T08:30:00Z", "duration": "PT1H"},
			"payloadDescriptors": [
				{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "BASELINE", "units": "KW", "readingType": "DIRECT_READ"},
				{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "USAGE", "units": "KW", "readingType": "DIRECT_READ"},
			],
			"intervals": [
				{"id": 0, "payloads": [
					{"type": "BASELINE", "values": [46.0]},
					{"type": "USAGE", "values": [22.0]},
				]},
				{"id": 1, "payloads": [
					{"type": "BASELINE", "values": [44.0]},
					{"type": "USAGE", "values": [18.0]},
				]},
			],
		},
	}
	inp := _std_input([multi_interval_meter])
	total_settlement == 175 with input as inp
}

# ---------------------------------------------------------------------------
# Test: USAGE absent → meter excluded + violation surfaced
# ---------------------------------------------------------------------------

test_baseline_only_emits_violation if {
	inp := _std_input([
		_meter_baseline_only("m1", 45.0),
		_meter_with_actual("m2", 38.0, 15.0),
	])
	# m1 contributes nothing
	count(settlement_components) == 1 with input as inp
	# A violation mentions the baseline-only meter
	vs := violations with input as inp
	some v in vs
	contains(v, "m1")
}

# ---------------------------------------------------------------------------
# DER-telemetry exclusion: utility perf record alongside a DER perf record
# should pick the utility one for settlement and IGNORE the DER data
# entirely — even if the DER record sits ahead of the utility record in
# the array.
# ---------------------------------------------------------------------------

_der_perf(meters) := {
	"id": "p-der",
	"status": {"code": "REPORT_DELIVERED"},
	"commitmentIds": ["c1"],
	"performanceAttributes": {
		"@context": "test", "@type": "DemandFlexPerformance",
		"eventId": "evt-test",
		"methodology": "DER_TELEMETRY",
		"meters": meters,
	},
}

_utility_perf(meters) := {
	"id": "p-utility",
	"status": {"code": "DELIVERY_COMPLETE"},
	"commitmentIds": ["c1"],
	"performanceAttributes": {
		"@context": "test", "@type": "DemandFlexPerformance",
		"eventId": "evt-test",
		"methodology": "5of10",
		"meters": meters,
	},
}

_input_with_perf_records(perf_records) := {
	"message": {"contract": {
		"id": "test",
		"status": {"code": "ACTIVE"},
		"commitments": [{
			"id": "c1",
			"status": {"descriptor": {"code": "ACTIVE"}},
			"resources": [{
				"id": "r1",
				"quantity": {"unitCode": "kW", "unitQuantity": 150},
				"resourceAttributes": {
					"@context": "test", "@type": "DemandFlexNeed",
					"direction": "REDUCE", "eventWindow": _default_window,
					"capacityType": "CURTAILMENT", "maxCapacityKw": 500,
				},
			}],
			"offer": {
				"id": "o1", "resourceIds": ["r1"],
				"offerAttributes": {
					"@context": "test", "@type": "DemandFlexBuyOffer",
					"inputs": _default_inputs,
				},
			},
		}],
		"performance": perf_records,
		"contractAttributes": _deg_contract,
	}},
}

# Test: DER perf record listed FIRST is ignored; settlement uses the
# utility perf record listed second. Verifies the filter — not the array
# index — is what picks the eligible record.
test_der_perf_record_excluded_from_settlement if {
	der_meter := {
		"meterId": "der://ev/VIN001",
		"telemetry": {
			"@type": "TimeSeries",
			"intervalPeriod": {"start": "2026-04-01T08:30:00Z", "duration": "PT2H"},
			"payloadDescriptors": [
				{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "USAGE", "units": "KW"},
				{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "SOC_END", "units": "KWH"},
			],
			# 99 kW DER USAGE would, if used, blow up settlement
			"intervals": [{"id": 0, "payloads": [
				{"type": "USAGE", "values": [99.0]},
				{"type": "SOC_END", "values": [21.0]},
			]}],
		},
	}
	inp := _input_with_perf_records([
		_der_perf([der_meter]),
		_utility_perf([_meter_with_actual("m1", 45.0, 20.0)]),
	])
	# Settlement uses utility data: (45-20) kW × 2h × 3.5 INR/kWh = 175 INR.
	# If DER data leaked in, total would be different.
	total_settlement == 175 with input as inp
	# And no violations
	count(violations) == 0 with input as inp
}

# Test: payload carrying ONLY a DER-telemetry perf record triggers an
# explicit violation; the rego refuses to compute settlement.
test_der_only_payload_violation if {
	der_meter := {
		"meterId": "der://ev/VIN001",
		"telemetry": {
			"@type": "TimeSeries",
			"intervalPeriod": {"start": "2026-04-01T08:30:00Z", "duration": "PT2H"},
			"payloadDescriptors": [
				{"objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "USAGE", "units": "KW"},
			],
			"intervals": [{"id": 0, "payloads": [
				{"type": "USAGE", "values": [1.0]},
			]}],
		},
	}
	inp := _input_with_perf_records([_der_perf([der_meter])])
	vs := violations with input as inp
	some v in vs
	contains(v, "DER telemetry")
}
