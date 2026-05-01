# DEG Contract Policy — Demand Flex Vendor-Telemetry Revenue Flows (UC2)
#
# Differs from demand_flex_revenue.rego (UC1) in two ways:
#   1. Settlement is computed per VENDOR DEVICE (EV charger / battery /
#      heat pump etc) rather than per grid-side meter. Baseline is
#      vendor-rated charger power published by the DISCOM in the first
#      on_status; USAGE arrives from the aggregator via the on_status
#      reply to DISCOM's status call.
#   2. Carbon credit value (verified kWh × gridEmissionFactor × carbon
#      price) accrues to the SELLER on top of the demand-response
#      incentive. The buyer (DISCOM) pays the bundled amount; net-zero
#      across two roles. Carbon-credit terms are read from
#      offerAttributes.inputs[buyer].inputs.carbonCredit and gated by
#      `enabled: true`; when disabled the carbon component is zero and
#      settlement is incentive-only.
#
# Input: full beckn contract payload, identical envelope to UC1 plus:
#   - offerAttributes.inputs[buyer].inputs.carbonCredit:
#       { enabled, gridEmissionFactorKgPerKwh, creditPricePerTonneCO2e,
#         methodology }
#   - offerAttributes.inputs[seller].inputs.vendorDevices[]:
#       per-device metadata (deviceId, ratedPowerKw, …)
#   - performance[0].performanceAttributes.meters[*].telemetry payloads
#     may include SOC_END, POWER, GPS_LAT, GPS_LON in addition to
#     BASELINE and USAGE — only BASELINE and USAGE are consulted for
#     settlement; the rest are inert here and fenced by the network rego.
#
# Exported rules (mirroring UC1 surface plus carbon additions):
#   revenue_flows          — [{role, value, currency, description}]
#   settlement_components  — per-device [{lineId, lineSummary, value, currency}]
#   total_settlement       — sum of all device incentives (excludes carbon)
#   total_co2_avoided_kg   — sum of (deviceReductionKwh × emissionFactor)
#   total_carbon_value     — co2-avoided × creditPricePerTonneCO2e (INR/tCO2e)
#   event_hours            — derived from eventWindow
#   net_zero_ok            — bool: sum of revenue_flows == 0
#   violations             — set of error/warning strings

package deg.contracts.demand_flex_uc2

import rego.v1

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

ns_per_hour := (1000 * 1000 * 1000) * 60 * 60

kg_per_tonne := 1000

# ---------------------------------------------------------------------------
# Input extraction
# ---------------------------------------------------------------------------

_commitment := input.message.contract.commitments[0]

_offer_attrs := _commitment.offer.offerAttributes

_inputs := _offer_attrs.inputs

_buyer_inputs := [i.inputs | some i in _inputs; i.role == "buyer"][0]

_incentive_per_kwh := _buyer_inputs.incentivePerKwh

_currency := _buyer_inputs.currency

_perf_attrs := input.message.contract.performance[0].performanceAttributes

_meters := _perf_attrs.meters

_event_window := _commitment.resources[0].resourceAttributes.eventWindow

# ---------------------------------------------------------------------------
# Roles — extracted from contractAttributes (DEGContract)
# ---------------------------------------------------------------------------

_contract_attrs := input.message.contract.contractAttributes

_roles := {r.role | some r in _contract_attrs.roles}

# ---------------------------------------------------------------------------
# Carbon-credit terms (gated by `enabled` flag, defaults to disabled)
# ---------------------------------------------------------------------------

_carbon := object.get(_buyer_inputs, "carbonCredit", {"enabled": false})

_carbon_enabled if _carbon.enabled == true

default _emission_factor := 0.0

_emission_factor := _carbon.gridEmissionFactorKgPerKwh if _carbon_enabled

default _carbon_price_per_tonne := 0.0

_carbon_price_per_tonne := _carbon.creditPricePerTonneCO2e if _carbon_enabled

# ---------------------------------------------------------------------------
# Event hours
# ---------------------------------------------------------------------------

_start_ns := time.parse_rfc3339_ns(_event_window.startDate)

_end_ns := time.parse_rfc3339_ns(_event_window.endDate)

event_hours := (_end_ns - _start_ns) / ns_per_hour

# ---------------------------------------------------------------------------
# BecknTimeSeries readers (same as UC1; vendor types like SOC_END/POWER/GPS
# are inert here — not consulted for settlement)
# ---------------------------------------------------------------------------

_payload_values(meter, ptype) := vals if {
	vals := [v |
		some interval in meter.telemetry.intervals
		some payload in interval.payloads
		payload.type == ptype
		some v in payload.values
	]
}

_payload_mean(meter, ptype) := mean if {
	vals := _payload_values(meter, ptype)
	count(vals) > 0
	mean := sum(vals) / count(vals)
}

_has_actual(meter) if count(_payload_values(meter, "USAGE")) > 0

# ---------------------------------------------------------------------------
# Per-device settlement (vendor device, e.g. EV charger)
# ---------------------------------------------------------------------------

_clamp_zero(x) := x if x >= 0

_clamp_zero(x) := 0 if x < 0

_meter_settlement[i] := result if {
	meter := _meters[i]
	_has_actual(meter)
	baseline_kw := _payload_mean(meter, "BASELINE")
	actual_kw := _payload_mean(meter, "USAGE")
	reduction_kw := _clamp_zero(baseline_kw - actual_kw)
	reduction_kwh := reduction_kw * event_hours
	incentive := reduction_kwh * _incentive_per_kwh
	co2_kg := reduction_kwh * _emission_factor
	result := {
		"deviceId": meter.meterId,
		"baselineKw": baseline_kw,
		"actualKw": actual_kw,
		"reductionKw": reduction_kw,
		"reductionKwh": reduction_kwh,
		"incentive": incentive,
		"co2AvoidedKg": co2_kg,
	}
}

# ---------------------------------------------------------------------------
# Per-device line items
# ---------------------------------------------------------------------------

settlement_components := [comp |
	some i
	s := _meter_settlement[i]
	comp := {
		"lineId": sprintf("incentive-%s", [s.deviceId]),
		"lineSummary": sprintf("%s: (%v - %v) kW × %vh × %v %s/kWh = %v %s | %v kg CO2e avoided",
			[s.deviceId, s.baselineKw, s.actualKw, event_hours, _incentive_per_kwh, _currency, s.incentive, _currency, s.co2AvoidedKg]),
		"value": s.incentive,
		"currency": _currency,
	}
]

total_settlement := sum([s.incentive | some i; s := _meter_settlement[i]])

total_co2_avoided_kg := sum([s.co2AvoidedKg | some i; s := _meter_settlement[i]])

# Carbon credit cash value (INR), derived from kg → tCO2e × price/tonne
total_carbon_value := total_co2_avoided_kg * _carbon_price_per_tonne / kg_per_tonne

# ---------------------------------------------------------------------------
# Revenue flows by role — net-zero across (buyer, seller)
#
#   buyer (DISCOM)      pays incentive + carbon  → −(total_settlement + total_carbon_value)
#   seller (aggregator) receives both            → +(total_settlement + total_carbon_value)
# ---------------------------------------------------------------------------

_total_kwh := sum([s.reductionKwh | some i; s := _meter_settlement[i]])

_buyer_value := -1 * (total_settlement + total_carbon_value)

_seller_value := total_settlement + total_carbon_value

_buyer_desc := sprintf("Incentive (%v) + carbon credit (%v) payable for %v kWh / %v kg CO2e avoided",
	[total_settlement, total_carbon_value, _total_kwh, total_co2_avoided_kg]) if _carbon_enabled

_buyer_desc := sprintf("Incentive payable for %v kWh verified curtailment", [_total_kwh]) if not _carbon_enabled

_seller_desc := sprintf("Incentive (%v) + carbon credit (%v) receivable for %v kWh / %v kg CO2e avoided",
	[total_settlement, total_carbon_value, _total_kwh, total_co2_avoided_kg]) if _carbon_enabled

_seller_desc := sprintf("Incentive receivable for %v kWh verified curtailment", [_total_kwh]) if not _carbon_enabled

_flow_defs := [
	["buyer", _buyer_value, _buyer_desc],
	["seller", _seller_value, _seller_desc],
]

revenue_flows := [flow |
	some def in _flow_defs
	role := def[0]
	value := def[1]
	desc := def[2]
	flow := object.union(
		object.union(
			object.union({"role": role}, {"value": value}),
			{"currency": _currency},
		),
		{"description": desc},
	)
]

_revenue_sum := sum([f.value | some f in revenue_flows])

# IEEE-754 tolerance — sums of incentive + carbon-credit floats can leave
# residue at ~1e-18; treat anything within 1e-6 as net-zero.
_net_zero_epsilon := 0.000001

net_zero_ok if abs(_revenue_sum) < _net_zero_epsilon

# ---------------------------------------------------------------------------
# Violations
# ---------------------------------------------------------------------------

violations contains msg if {
	not "buyer" in _roles
	msg := "no participant with role 'buyer' found"
}

violations contains msg if {
	not "seller" in _roles
	msg := "no participant with role 'seller' found"
}

violations contains msg if {
	some i
	meter := _meters[i]
	not _has_actual(meter)
	msg := sprintf("device %s: missing USAGE telemetry — cannot compute settlement", [meter.meterId])
}

violations contains msg if {
	some i
	meter := _meters[i]
	_has_actual(meter)
	baseline_kw := _payload_mean(meter, "BASELINE")
	actual_kw := _payload_mean(meter, "USAGE")
	actual_kw > baseline_kw
	msg := sprintf("device %s: actualKw (%g) > baselineKw (%g) — reduction clamped to zero",
		[meter.meterId, actual_kw, baseline_kw])
}

violations contains msg if {
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}
