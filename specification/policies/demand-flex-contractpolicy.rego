# DEG Contract Policy — Demand Flex Revenue Flows (per-interval, per-meter)
#
# The utility (buyer) publishes a DemandFlexNeed time series — one interval per
# tranche, carrying per-slot PRICE and SHORTFALL_PENALTY (and CAPACITY_REQUESTED,
# which is a discovery signal only and NOT used here). The aggregator (seller)
# adds a CAPACITY_OFFERED column on Commitment.commitmentAttributes. Per-meter
# BASELINE / USAGE telemetry arrives on DemandFlexPerformance. All three series
# share one intervalPeriod grid and join on interval id.
#
# Settlement is UTILITY-ONLY and PER-METER, summed per interval:
#   delivered_i = Σ_meter clamp0(BASELINE_i − USAGE_i)          (aggregate kW)
#   eligible_i  = min(delivered_i, CAPACITY_OFFERED_i)
#   pay_i       = eligible_i × durationHours × PRICE_i
#   penalty_i   = clamp0(CAPACITY_OFFERED_i − delivered_i) × durationHours × SHORTFALL_PENALTY_i
#   net_i       = pay_i − penalty_i          →   total = Σ net_i
#
# buyer pays (negative), seller receives (positive), net zero.
# EnergyResource telemetry (methodology RESOURCE_TELEMETRY) is reconciliation-
# only and excluded from settlement.
#
# Exported: revenue_flows, settlement_components, total_settlement,
#           net_zero_ok, violations.

package deg.contracts.demand_flex

import rego.v1

# non-settlement methodologies — perf records authored by the seller's
# EnergyResource fleet (out-of-band vendor APIs), excluded from settlement.
_non_settlement_methodologies := {"RESOURCE_TELEMETRY"}

# --------------------------------------------------------------------------
# Input extraction
# --------------------------------------------------------------------------

_commitment := input.message.contract.commitments[0]

# DemandFlexNeed time series — buyer's CAPACITY_REQUESTED / PRICE / SHORTFALL_PENALTY
_need := _commitment.resources[0].resourceAttributes

# commitment series — seller's CAPACITY_OFFERED column
_offered := _commitment.commitmentAttributes

_buyer_inputs := [i.inputs | some i in _commitment.offer.offerAttributes.inputs; i.role == "buyer"][0]

_currency := object.get(_buyer_inputs, "currency", "INR")

# first settlement-eligible performance record (utility M&V, not RESOURCE_TELEMETRY)
_settlement_perf := perf if {
	some perf in input.message.contract.performance
	not perf.performanceAttributes.methodology in _non_settlement_methodologies
}

_meters := _settlement_perf.performanceAttributes.meters

_roles := {r.role | some r in input.message.contract.contractAttributes.roles}

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# scalar value of payload `ptype` at interval `ivid` in a series' intervals[]
_val(intervals, ivid, ptype) := v if {
	some iv in intervals
	iv.id == ivid
	some p in iv.payloads
	p.type == ptype
	v := p.values[0]
}

_clamp0(x) := x if x >= 0

_clamp0(x) := 0 if x < 0

_numz(s) := to_number(s) if s != ""

_numz("") := 0

# duration of one interval in hours, parsed from ISO 8601 (PT#H / PT#M / PT#H#M)
_dur_hours := h if {
	m := regex.find_all_string_submatch_n(`^PT(?:([0-9]+)H)?(?:([0-9]+)M)?$`, _need.intervalPeriod.duration, 1)[0]
	h := _numz(m[1]) + (_numz(m[2]) / 60)
}

# per-meter clamped reduction at an interval; undefined if BASELINE or USAGE absent
_meter_reduction(meter, ivid) := _clamp0(base - use) if {
	base := _val(meter.telemetry.intervals, ivid, "BASELINE")
	use := _val(meter.telemetry.intervals, ivid, "USAGE")
}

_delivered(ivid) := sum([_meter_reduction(m, ivid) | some m in _meters])

# --------------------------------------------------------------------------
# Per-interval settlement
# --------------------------------------------------------------------------

_settle[ivid] := row if {
	some iv in _need.intervals
	ivid := iv.id
	price := _val(_need.intervals, ivid, "PRICE")
	penalty_rate := _val(_need.intervals, ivid, "SHORTFALL_PENALTY")
	offered := _val(_offered.intervals, ivid, "CAPACITY_OFFERED")
	delivered := _delivered(ivid)
	eligible := min([delivered, offered])
	pay := (eligible * _dur_hours) * price
	penalty := (_clamp0(offered - delivered) * _dur_hours) * penalty_rate
	net := pay - penalty
	row := {
		"id": ivid, "price": price, "offered": offered,
		"delivered": delivered, "eligible": eligible,
		"pay": pay, "penalty": penalty, "net": net,
	}
}

settlement_components := [comp |
	some ivid
	s := _settle[ivid]
	line_id := sprintf("slot-%d", [ivid])
	summary := sprintf("slot %d: min(%v delivered, %v offered) kW x %vh x %v %s/kWh - penalty %v", [ivid, s.delivered, s.offered, _dur_hours, s.price, _currency, s.penalty])
	comp := {"lineId": line_id, "lineSummary": summary, "value": s.net, "currency": _currency}
]

total_settlement := sum([s.net | some ivid; s := _settle[ivid]])

_slot_count := count(_settle)

_buyer_value := total_settlement * -1

_buyer_desc := sprintf("Net payable across %d flex slots", [_slot_count])

_seller_desc := sprintf("Net receivable across %d flex slots", [_slot_count])

revenue_flows := [
	{"role": "buyer", "value": _buyer_value, "currency": _currency, "description": _buyer_desc},
	{"role": "seller", "value": total_settlement, "currency": _currency, "description": _seller_desc},
]

_revenue_sum := sum([f.value | some f in revenue_flows])

net_zero_ok if _revenue_sum == 0

# --------------------------------------------------------------------------
# Violations
# --------------------------------------------------------------------------

violations contains msg if {
	count(input.message.contract.performance) > 0
	not _settlement_perf
	ms := [p.performanceAttributes.methodology | some p in input.message.contract.performance]
	msg := sprintf("no settlement-eligible performance record found — all records are non-settlement (methodologies: %v)", [ms])
}

violations contains msg if {
	not "buyer" in _roles
	msg := "no participant with role 'buyer' found"
}

violations contains msg if {
	not "seller" in _roles
	msg := "no participant with role 'seller' found"
}

# column const (uc1 demand_flex profile) — the schema leaves columns open;
# this rego is the hard lock. Self-skips when the series is absent.
violations contains msg if {
	descs := _need.payloadDescriptors
	cols := {d.payloadType | some d in descs}
	cols != {"CAPACITY_REQUESTED", "PRICE", "SHORTFALL_PENALTY"}
	msg := sprintf("DemandFlexNeed columns must be exactly {CAPACITY_REQUESTED, PRICE, SHORTFALL_PENALTY}, got %v", [cols])
}

violations contains msg if {
	descs := _offered.payloadDescriptors
	cols := {d.payloadType | some d in descs}
	cols != {"CAPACITY_OFFERED"}
	msg := sprintf("commitment column must be exactly {CAPACITY_OFFERED}, got %v", [cols])
}

# shared intervalPeriod grid — CAPACITY_OFFERED series
violations contains msg if {
	_offered.intervalPeriod != _need.intervalPeriod
	msg := "CAPACITY_OFFERED series intervalPeriod does not match the DemandFlexNeed grid"
}

# shared intervalPeriod grid — each meter's telemetry
violations contains msg if {
	some m in _meters
	m.telemetry.intervalPeriod != _need.intervalPeriod
	msg := sprintf("meter %s: telemetry intervalPeriod does not match the DemandFlexNeed grid", [m.meterId])
}

# every slot needs a seller CAPACITY_OFFERED
violations contains msg if {
	some iv in _need.intervals
	not _val(_offered.intervals, iv.id, "CAPACITY_OFFERED")
	msg := sprintf("interval %d: missing CAPACITY_OFFERED", [iv.id])
}

# every meter needs USAGE on every settled slot
violations contains msg if {
	some iv in _need.intervals
	some m in _meters
	not _val(m.telemetry.intervals, iv.id, "USAGE")
	msg := sprintf("meter %s: missing USAGE at interval %d — cannot settle", [m.meterId, iv.id])
}

violations contains msg if {
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}
