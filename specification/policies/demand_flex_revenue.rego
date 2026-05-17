# DEG Contract Policy — Demand Flex Revenue Flows
#
# Computes per-meter incentive payouts from utility-provided M&V baselines
# and actuals, and produces signed revenue flows per ROLE (buyer/seller),
# not per participant ID.
#
# buyer  (utility/DISCOM) → pays     → negative value
# seller (aggregator)     → receives → positive value
# Sum of all revenue_flows values MUST equal zero (net-zero).
#
# Settlement is UTILITY-ONLY. Only `performance[*]` records whose
# `performanceAttributes` were authored by the utility (BPP) — grid-meter
# BASELINE + USAGE in a BecknTimeSeries — are eligible inputs.
# EnergyResource telemetry (`methodology: "RESOURCE_TELEMETRY"`, emitted
# as a separate `on_status` push carrying per-resource reconciliation
# data — EV chargers, batteries, solar PV, etc.) is EXPLICITLY EXCLUDED
# from this rego's computation. It is allowed on the wire as proof-of-
# performance / reconciliation evidence, but it is not settlement-grade
# and never feeds the revenue flow.
#
# Input: full beckn contract payload with:
#   - contractAttributes.roles[].role             → buyer / seller
#   - commitments[0].offer.offerAttributes.inputs → incentive terms (role-tagged)
#   - commitments[0].resources[0].resourceAttributes.eventWindow → hours
#   - performance[*].performanceAttributes.meters[*].telemetry  → BecknTimeSeries
#
# Per-meter telemetry is a BecknTimeSeries; mean of BASELINE values across
# intervals is used as the meter's baseline kW; mean of USAGE values is used
# as the meter's actual kW (USAGE is absent before the event has completed).
#
# Exported rules:
#   revenue_flows          — [{role, value, currency, description}]
#   settlement_components  — per-meter [{lineId, lineSummary, value, currency}]
#   total_settlement       — sum of all meter incentives
#   event_hours            — derived from eventWindow
#   net_zero_ok            — bool: sum of revenue_flows == 0
#   violations             — set of error/warning strings

package deg.contracts.demand_flex

import rego.v1

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

ns_per_hour := (1000 * 1000 * 1000) * 60 * 60

# ---------------------------------------------------------------------------
# Input extraction
# ---------------------------------------------------------------------------

_commitment := input.message.contract.commitments[0]

_offer_attrs := _commitment.offer.offerAttributes

_inputs := _offer_attrs.inputs

_buyer_inputs := [i.inputs | some i in _inputs; i.role == "buyer"][0]

_incentive_per_kwh := _buyer_inputs.incentivePerKwh

_currency := _buyer_inputs.currency

# Non-settlement methodologies — perf records authored by sources other
# than the utility (currently the seller's EnergyResource fleet via
# out-of-band vendor APIs) carry one of these methodologies and MUST be
# excluded from settlement input. Keep this list short and explicit;
# new non-settlement methodologies must be added here AND documented
# in the devkit README's settlement section.
_non_settlement_methodologies := {"RESOURCE_TELEMETRY"}

# Settlement-eligible perf records: utility-authored M&V data only.
# Filters out EnergyResource (proof-of-performance) telemetry by
# `methodology`. If a payload carries a single utility perf record (the
# common case) this picks it; if multiple are present (e.g. baselines +
# actuals on the same message) the FIRST is used — callers SHOULD
# invoke this rego against the actuals (or settled) message.
_settlement_perf := perf if {
	some perf in input.message.contract.performance
	not perf.performanceAttributes.methodology in _non_settlement_methodologies
}

_perf_attrs := _settlement_perf.performanceAttributes

_meters := _perf_attrs.meters

_event_window := _commitment.resources[0].resourceAttributes.eventWindow

# ---------------------------------------------------------------------------
# Roles — extracted from contractAttributes (DEGContract)
# ---------------------------------------------------------------------------

_contract_attrs := input.message.contract.contractAttributes

_roles := {r.role | some r in _contract_attrs.roles}

# ---------------------------------------------------------------------------
# Event hours
# ---------------------------------------------------------------------------

_start_ns := time.parse_rfc3339_ns(_event_window.startDate)

_end_ns := time.parse_rfc3339_ns(_event_window.endDate)

event_hours := (_end_ns - _start_ns) / ns_per_hour

# ---------------------------------------------------------------------------
# BecknTimeSeries readers
#
# Per-meter telemetry is a BecknTimeSeries. Each interval carries one or
# more typed payloads ({type, values}). For demand-flex, BASELINE is
# always present; USAGE appears once the event has completed.
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
# Per-meter settlement
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
	result := {
		"meterId": meter.meterId,
		"baselineKw": baseline_kw,
		"actualKw": actual_kw,
		"reductionKw": reduction_kw,
		"reductionKwh": reduction_kwh,
		"incentive": incentive,
	}
}

# ---------------------------------------------------------------------------
# Settlement components (per-meter line items)
# ---------------------------------------------------------------------------

settlement_components := [comp |
	some i
	s := _meter_settlement[i]
	comp := {
		"lineId": sprintf("incentive-%s", [s.meterId]),
		"lineSummary": sprintf("%s: (%g - %g) kW × %vh × %g %s/kWh",
			[s.meterId, s.baselineKw, s.actualKw, event_hours, _incentive_per_kwh, _currency]),
		"value": s.incentive,
		"currency": _currency,
	}
]

total_settlement := sum([s.incentive | some i; s := _meter_settlement[i]])

# ---------------------------------------------------------------------------
# Revenue flows by role (the core output)
#
#   buyer pays  → negative
#   seller receives → positive
#   sum = 0
# ---------------------------------------------------------------------------

_total_kwh := sum([s.reductionKwh | some i; s := _meter_settlement[i]])

_buyer_desc := sprintf("Incentive payable for %v kWh verified curtailment", [_total_kwh])

_seller_desc := sprintf("Incentive receivable for %v kWh verified curtailment", [_total_kwh])

_flow_defs := [
	["buyer", -1],
	["seller", 1],
]

revenue_flows := [flow |
	some def in _flow_defs
	role := def[0]
	sign := def[1]
	desc := sprintf("Incentive %s for %v kWh verified curtailment", [_flow_label[role], _total_kwh])
	flow := object.union(
		object.union(
			object.union({"role": role}, {"value": sign * total_settlement}),
			{"currency": _currency},
		),
		{"description": desc},
	)
]

_flow_label["buyer"] := "payable"

_flow_label["seller"] := "receivable"

_revenue_sum := sum([f.value | some f in revenue_flows])

net_zero_ok if _revenue_sum == 0

# ---------------------------------------------------------------------------
# Violations
# ---------------------------------------------------------------------------

violations contains msg if {
	# Defense-in-depth: invoking the rego against a payload whose only
	# perf records are non-settlement (EnergyResource telemetry) is a
	# programming error — the settlement-eligibility filter silently
	# selects nothing and the downstream rules would compute nonsense
	# or NaN. Flag explicitly.
	count(input.message.contract.performance) > 0
	not _settlement_perf
	seen_methodologies := [perf.performanceAttributes.methodology |
		some perf in input.message.contract.performance
	]
	msg := sprintf("no settlement-eligible performance record found — all records are non-settlement (methodologies: %v). Settlement requires utility-provided meter telemetry; EnergyResource telemetry is reconciliation-only.", [seen_methodologies])
}

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
	msg := sprintf("meter %s: missing USAGE telemetry — cannot compute settlement", [meter.meterId])
}

violations contains msg if {
	some i
	meter := _meters[i]
	_has_actual(meter)
	baseline_kw := _payload_mean(meter, "BASELINE")
	actual_kw := _payload_mean(meter, "USAGE")
	actual_kw > baseline_kw
	msg := sprintf("meter %s: actualKw (%g) > baselineKw (%g) — reduction clamped to zero",
		[meter.meterId, actual_kw, baseline_kw])
}

violations contains msg if {
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}

# Cross-field type-coverage (every type used in intervals must be
# declared in payloadDescriptors) lives in the network policy
# (specification/policies/demand_flex_network.rego) — that's the policy
# the BPP's checkPolicy step actually evaluates. This file's `violations`
# set is computed only as enrichment metadata, never gates ACK/NACK.
