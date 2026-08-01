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

# internal net flows — always defined (0 when nothing settles yet)
_revenue_flows := [
	{"role": "buyer", "value": _buyer_value, "currency": _currency, "description": _buyer_desc},
	{"role": "seller", "value": total_settlement, "currency": _currency, "description": _seller_desc},
]

# Exported for injection ONLY when a settlement-eligible performance record is
# present. Pre-settlement (select / init / confirm) this rule is UNDEFINED, so a
# contractpolicyenforcer step still evaluates `violations` (enforcement) but
# finds no `revenue_flows` and skips injection — no zero-value settlement
# artifact is written onto a pre-settlement contract. net-zero and _revenue_sum
# key off the always-defined _revenue_flows, so their semantics are unchanged.
revenue_flows := _revenue_flows if _settlement_perf

_revenue_sum := sum([f.value | some f in _revenue_flows])

net_zero_ok if _revenue_sum == 0

# --------------------------------------------------------------------------
# Violations
# --------------------------------------------------------------------------
#
# `violations` is the NACK gate. Two families of rule live here, each
# self-skipping when its data is absent so the same set is safe to evaluate
# at every stage the contract enforcer runs (select → init → confirm; and
# the settlement family additionally at the final settled status):
#
#   Formation (safe from init/confirm onward):
#     V1  seller/buyer roles present
#     V2  DemandFlexNeed columns == {CAPACITY_REQUESTED, PRICE, SHORTFALL_PENALTY}
#     V3  commitment column == {CAPACITY_OFFERED}
#     V3a CAPACITY_OFFERED column PRESENT (stage-gated) — backstop for the
#         network policy's rule 3a; catches a fully-dropped commitmentAttributes
#     V4  CAPACITY_OFFERED grid == need grid
#     V5  every need slot carries a CAPACITY_OFFERED value
#   Settlement (only meaningful once telemetry has arrived):
#     V6  a settlement-eligible performance record exists
#     V7  each meter's telemetry grid == need grid
#     V8  every meter carries USAGE on every settled slot
#     V9  revenue flows net to zero
#
# NOTE: V6/V8/V9 legitimately fire on an intermediate on_status (baseline-only
# or resource-telemetry push), so the contract policy is NOT enforced on
# on_status — the network policy owns structural enforcement at status; the
# contract policy is enforced only where settlement is not yet claimed
# (select/init/confirm) plus injected/validated on the final settled status.

# V6 — a settlement-eligible performance record exists
violations contains msg if {
	count(input.message.contract.performance) > 0
	not _settlement_perf
	ms := [p.performanceAttributes.methodology | some p in input.message.contract.performance]
	msg := sprintf("no settlement-eligible performance record found — all records are non-settlement (methodologies: %v)", [ms])
}

# V1 — participant roles present
violations contains msg if {
	not "buyer" in _roles
	msg := "no participant with role 'buyer' found"
}

violations contains msg if {
	not "seller" in _roles
	msg := "no participant with role 'seller' found"
}

# V2 — DemandFlexNeed column constant (uc1 demand_flex profile). The schema
# leaves columns open; this rego is the hard lock. Self-skips when the series
# is absent.
violations contains msg if {
	descs := _need.payloadDescriptors
	cols := {d.payloadType | some d in descs}
	cols != {"CAPACITY_REQUESTED", "PRICE", "SHORTFALL_PENALTY"}
	msg := sprintf("DemandFlexNeed columns must be exactly {CAPACITY_REQUESTED, PRICE, SHORTFALL_PENALTY}, got %v", [cols])
}

# V3 — commitment column constant. Self-skips when commitmentAttributes is
# absent (a dropped column is caught by V3a below, not here).
violations contains msg if {
	descs := _offered.payloadDescriptors
	cols := {d.payloadType | some d in descs}
	cols != {"CAPACITY_OFFERED"}
	msg := sprintf("commitment column must be exactly {CAPACITY_OFFERED}, got %v", [cols])
}

# V3a — CAPACITY_OFFERED column PRESENCE (stage-gated). Settlement backstop
# for the network policy's rule 3a: from init onward every committed
# DemandFlexNeed MUST carry a CAPACITY_OFFERED column. V3/V4/V5 all key off
# _offered and self-skip when commitmentAttributes is dropped wholesale;
# reading the column straight off the commitment (via object.get) closes that
# hole. `select`/`on_select` are excluded — no seller offer exists yet.
_offer_required_actions := {
	"init", "on_init",
	"confirm", "on_confirm",
	"status", "on_status",
	"update", "on_update",
}

violations contains msg if {
	input.context.action in _offer_required_actions
	_need.intervals # a DemandFlexNeed is present
	ca := object.get(_commitment, "commitmentAttributes", {})
	declared := {d.payloadType | some d in object.get(ca, "payloadDescriptors", [])}
	not "CAPACITY_OFFERED" in declared
	msg := sprintf("action %q requires a CAPACITY_OFFERED column on commitmentAttributes, but none is declared", [input.context.action])
}

# V4 — shared intervalPeriod grid, CAPACITY_OFFERED series
violations contains msg if {
	_offered.intervalPeriod != _need.intervalPeriod
	msg := "CAPACITY_OFFERED series intervalPeriod does not match the DemandFlexNeed grid"
}

# V7 — shared intervalPeriod grid, each meter's telemetry
violations contains msg if {
	some m in _meters
	m.telemetry.intervalPeriod != _need.intervalPeriod
	msg := sprintf("meter %s: telemetry intervalPeriod does not match the DemandFlexNeed grid", [m.meterId])
}

# V5 — every need slot carries a seller CAPACITY_OFFERED value
violations contains msg if {
	some iv in _need.intervals
	not _val(_offered.intervals, iv.id, "CAPACITY_OFFERED")
	msg := sprintf("interval %d: missing CAPACITY_OFFERED", [iv.id])
}

# V8 — every meter needs USAGE on every settled slot
violations contains msg if {
	some iv in _need.intervals
	some m in _meters
	not _val(m.telemetry.intervals, iv.id, "USAGE")
	msg := sprintf("meter %s: missing USAGE at interval %d — cannot settle", [m.meterId, iv.id])
}

# V9 — buyer/seller revenue flows must net to zero
violations contains msg if {
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}
