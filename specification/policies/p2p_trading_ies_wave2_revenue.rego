# DEG Contract Policy — Seller-Discom P2P Trading Policy (wave2, timeseries)
#
# This is the policy of the SELLER's discom (the discom whose prosumer is
# selling energy). The catalog publisher links this policy into every trade
# involving that discom's prosumers via
# message.contract.contractAttributes.policy — so one policy governs each
# trade, authored and published by the seller-side discom.
#
# It does two jobs:
#
#   1. VIOLATIONS — trading rules the discom enforces. The onix
#      settlementflows step NACKs any action listed in its
#      violationActions config (select/init/confirm in wave2) when the
#      `violations` set is non-empty. Today that covers:
#        - counterpart allowlist: the buyer's discom must be in
#          allowed_buyer_discoms;
#        - contract completeness (required roles present);
#        - settlement integrity checks (on_status only).
#
#   2. REVENUE FLOWS — the settlement split between the four roles,
#      itemized with this discom's charges:
#
#        buyer        (energy consumer, BAP-side prosumer) → pays     → negative
#        seller       (energy producer, BPP-side prosumer) → receives → positive
#        buyerDiscom  (regulated LP for buyer's discom)    → receives → positive (wheeling)
#        sellerDiscom (regulated LP for seller's discom)   → receives → positive (wheeling + penalty)
#
# Discom-tunable knobs (edit these when authoring your discom's policy):
#   allowed_buyer_discoms         — utilityIds whose customers may buy here
#   wheeling_charge_buyer_per_kwh — INR/kWh charged to the buyer side
#   wheeling_charge_seller_per_kwh— INR/kWh charged to the seller side
#   penalty_rate_per_kwh          — INR/kWh on delivery shortfall
#                                   (REQUESTED_QTY − FINAL_ALLOC, clamped ≥ 0)
#   platform_charge_cap_per_kwh   — max INR/kWh the trading platform may
#                                   retain; disclosed in the itemization
#
# Multi-window: a single contract spans multiple delivery slots, each
# represented as an interval in Commitment.commitmentAttributes (a shared
# BecknTimeSeries that grows across the lifecycle):
#
#   commitments[0].commitmentAttributes
#       — PRICE_PER_KWH  (currency: INR)      inserted by seller at init
#       — REQUESTED_QTY  (units: KWH)          inserted by buyer at init
#       — BUYER_DISCOM_ALLOC  (units: KWH)     inserted by buyerDiscom post-delivery
#       — SELLER_DISCOM_ALLOC (units: KWH)     inserted by sellerDiscom post-delivery
#       — FINAL_ALLOC    (units: KWH)           inserted by sellerDiscom at settlement
#
# Per-slot trade value = FINAL_ALLOC × PRICE_PER_KWH (matched by interval id).
# Total trade value    = sum across all FINAL_ALLOC intervals.
#
# Exported rules:
#   revenue_flows          — [{role, value, currency, description}];
#                            only exported once settled intervals exist
#                            (so nothing is injected at select/init/confirm)
#   trade_value            — total INR value across all settled intervals
#   total_settled_kwh      — total kWh settled across all intervals
#   total_shortfall_kwh    — total under-delivery across settled intervals
#   wheeling_charge_buyer  — buyer-side wheeling, rate × settled kWh
#   wheeling_charge_seller — seller-side wheeling, rate × settled kWh
#   penalty_charge         — penalty_rate_per_kwh × total_shortfall_kwh
#   net_zero_ok            — bool: sum of revenue_flows ≈ 0
#   violations             — set of error strings

package deg.contracts.p2p_trading

import rego.v1

# ---------------------------------------------------------------------------
# Discom parameters — the knobs a discom edits when authoring its policy
# ---------------------------------------------------------------------------

# utilityIds of discoms whose customers may buy energy from this discom's
# prosumers. A buyer from any other discom is a violation → NACK at
# select/init/confirm.
allowed_buyer_discoms := {
	"TEST_DISCOM_SELLER", # intra-discom trades always allowed
	"TEST_DISCOM_BUYER",
}

# Wheeling charges this discom levies, in currency units per settled kWh.
wheeling_charge_buyer_per_kwh := 0.25

wheeling_charge_seller_per_kwh := 0.30

# Penalty on under-delivery, per kWh of shortfall (REQUESTED_QTY − FINAL_ALLOC).
penalty_rate_per_kwh := 0.50

# Ceiling on what the trading platform may retain per kWh from trades under
# this discom's jurisdiction. Disclosed in the settlement itemization.
platform_charge_cap_per_kwh := 0.42

# ---------------------------------------------------------------------------
# Input extraction
# ---------------------------------------------------------------------------

_contract := input.message.contract

_commit_ts := _contract.commitments[0].commitmentAttributes

_currency := c if {
	some d in _commit_ts.payloadDescriptors
	d.payloadType == "PRICE_PER_KWH"
	c := d.currency
}

# The buyer prosumer's discom: utilityId of the buyerPlatform participant.
_buyer_discom_id := id if {
	some p in _contract.participants
	p.role == "buyerPlatform"
	id := p.participantAttributes.utilityId
}

# ---------------------------------------------------------------------------
# Timeseries helpers
# ---------------------------------------------------------------------------

# Scalar value of a typed payload within an interval.
_payload_val(interval, ptype) := v if {
	some p in interval.payloads
	p.type == ptype
	v := p.values[0]
}

# Interval id → price per kWh.
_price_by_id := {i.id: _payload_val(i, "PRICE_PER_KWH") | some i in _commit_ts.intervals}

# Set of settled interval ids (those that carry FINAL_ALLOC).
_settled_interval_ids := {i.id | some i in _commit_ts.intervals; some p in i.payloads; p.type == "FINAL_ALLOC"}

_settled := count(_settled_interval_ids) > 0

_round2(x) := round(x * 100) / 100

# ---------------------------------------------------------------------------
# Per-interval value
# ---------------------------------------------------------------------------

_interval_value(i) := v if {
	alloc := _payload_val(i, "FINAL_ALLOC")
	price := _price_by_id[i.id]
	v := alloc * price
}

# Under-delivery within a settled interval, clamped at zero.
_interval_shortfall(i) := s if {
	req := _payload_val(i, "REQUESTED_QTY")
	alloc := _payload_val(i, "FINAL_ALLOC")
	s := max([0, req - alloc])
}

# ---------------------------------------------------------------------------
# Aggregates across settled intervals
# ---------------------------------------------------------------------------

trade_value := sum([_interval_value(i) | some i in _commit_ts.intervals; i.id in _settled_interval_ids])

total_settled_kwh := sum([_payload_val(i, "FINAL_ALLOC") | some i in _commit_ts.intervals; i.id in _settled_interval_ids])

total_shortfall_kwh := sum([_interval_shortfall(i) | some i in _commit_ts.intervals; i.id in _settled_interval_ids])

_window_breakdown := concat("; ", [s |
	some i in _commit_ts.intervals
	i.id in _settled_interval_ids
	alloc := _payload_val(i, "FINAL_ALLOC")
	price := _price_by_id[i.id]
	value := alloc * price
	s := sprintf("%v kWh @ %v %s = %v %s [interval %v]", [
		alloc, price, _currency, value, _currency, i.id,
	])
])

# ---------------------------------------------------------------------------
# Charges — this discom's rates applied to the settled volume
# ---------------------------------------------------------------------------

default wheeling_charge_buyer := 0

wheeling_charge_buyer := _round2(wheeling_charge_buyer_per_kwh * total_settled_kwh) if _settled

default wheeling_charge_seller := 0

wheeling_charge_seller := _round2(wheeling_charge_seller_per_kwh * total_settled_kwh) if _settled

default penalty_charge := 0

penalty_charge := _round2(penalty_rate_per_kwh * total_shortfall_kwh) if _settled

# ---------------------------------------------------------------------------
# Revenue flows by role — every amount itemized as rate × volume
# ---------------------------------------------------------------------------

_trade_value_r := _round2(trade_value)

_buyer_payable := _trade_value_r + wheeling_charge_buyer

_seller_receivable := (_trade_value_r - wheeling_charge_seller) - penalty_charge

_seller_discom_value := wheeling_charge_seller + penalty_charge

_buyer_flow := {
	"role": "buyerPlatform",
	"value": _buyer_payable * -1,
	"currency": _currency,
	"description": sprintf(
		"Pays %v %s = energy %v %s across %v settled interval(s) [%s] + buyer-side wheeling @ %v %s/kWh × %v kWh = %v %s",
		[
			_buyer_payable, _currency, _trade_value_r, _currency,
			count(_settled_interval_ids), _window_breakdown,
			wheeling_charge_buyer_per_kwh, _currency, total_settled_kwh,
			wheeling_charge_buyer, _currency,
		],
	),
}

_seller_flow := {
	"role": "sellerPlatform",
	"value": _seller_receivable,
	"currency": _currency,
	"description": sprintf(
		"Receives %v %s = energy %v %s − seller-side wheeling @ %v %s/kWh × %v kWh = %v %s − delivery penalty @ %v %s/kWh × %v kWh shortfall = %v %s; platform charge cap %v %s/kWh applies to trading-platform fees",
		[
			_seller_receivable, _currency, _trade_value_r, _currency,
			wheeling_charge_seller_per_kwh, _currency, total_settled_kwh,
			wheeling_charge_seller, _currency,
			penalty_rate_per_kwh, _currency, total_shortfall_kwh,
			penalty_charge, _currency,
			platform_charge_cap_per_kwh, _currency,
		],
	),
}

_buyer_discom_flow := {
	"role": "buyerDiscom",
	"value": wheeling_charge_buyer,
	"currency": _currency,
	"description": sprintf(
		"Buyer-side wheeling charge @ %v %s/kWh × %v settled kWh = %v %s",
		[wheeling_charge_buyer_per_kwh, _currency, total_settled_kwh, wheeling_charge_buyer, _currency],
	),
}

_seller_discom_flow := {
	"role": "sellerDiscom",
	"value": _seller_discom_value,
	"currency": _currency,
	"description": sprintf(
		"Seller-side wheeling charge @ %v %s/kWh × %v settled kWh = %v %s + delivery penalty %v %s (@ %v %s/kWh × %v kWh shortfall)",
		[
			wheeling_charge_seller_per_kwh, _currency, total_settled_kwh,
			wheeling_charge_seller, _currency,
			penalty_charge, _currency,
			penalty_rate_per_kwh, _currency, total_shortfall_kwh,
		],
	),
}

# Only exported once settled intervals exist — before settlement (select/
# init/confirm) there is nothing to inject, so the settlementflows step
# leaves those payloads untouched.
revenue_flows := [_buyer_flow, _seller_flow, _buyer_discom_flow, _seller_discom_flow] if _settled

_revenue_sum := sum([f.value | some f in revenue_flows])

# Tolerance absorbs float residue from the rounded components.
net_zero_ok if abs(_revenue_sum) < 0.005

# ---------------------------------------------------------------------------
# Roles — extracted from contractAttributes
# ---------------------------------------------------------------------------

_contract_attrs := _contract.contractAttributes

_roles := {r.role | some r in _contract_attrs.roles}

# ---------------------------------------------------------------------------
# Violations — trading eligibility (enforced at select/init/confirm)
# ---------------------------------------------------------------------------

violations contains msg if {
	_buyer_discom_id
	not _buyer_discom_id in allowed_buyer_discoms
	msg := sprintf(
		"buyer discom %q is not allowed to trade with this discom's prosumers (allowed: %v)",
		[_buyer_discom_id, sort(allowed_buyer_discoms)],
	)
}

violations contains msg if {
	not _buyer_discom_id
	msg := "cannot determine buyer discom: no buyerPlatform participant with participantAttributes.utilityId"
}

_required_roles := {"buyerPlatform", "sellerPlatform", "buyerDiscom", "sellerDiscom"}

violations contains msg if {
	some role in _required_roles
	not role in _roles
	msg := sprintf("missing required role %q in contractAttributes.roles", [role])
}

# ---------------------------------------------------------------------------
# Violations — settlement integrity (on_status only, so they can never
# block select/init/confirm where no settlement data exists yet)
# ---------------------------------------------------------------------------

violations contains "no FINAL_ALLOC intervals in commitmentAttributes — cannot compute revenue flows" if {
	input.context.action == "on_status"
	is_object(_commit_ts)
	not _settled
}

violations contains msg if {
	input.context.action == "on_status"
	some i in _commit_ts.intervals
	i.id in _settled_interval_ids
	not _price_by_id[i.id]
	msg := sprintf("settled interval %v has no matching PRICE_PER_KWH interval", [i.id])
}

violations contains msg if {
	input.context.action == "on_status"
	_settled
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}

# ---------------------------------------------------------------------------
# on_status commitmentAttributes completeness
# ---------------------------------------------------------------------------

_required_commitment_payload_types := {
	"PRICE_PER_KWH", "REQUESTED_QTY",
	"BUYER_DISCOM_ALLOC", "SELLER_DISCOM_ALLOC",
	"BUYER_DISCOM_STATUS", "SELLER_DISCOM_STATUS",
	"FINAL_ALLOC",
}

violations contains msg if {
	input.context.action == "on_status"
	some c in _contract.commitments
	_present := {pd.payloadType | some pd in c.commitmentAttributes.payloadDescriptors}
	some ptype in _required_commitment_payload_types
	not ptype in _present
	msg := sprintf(
		"on_status commitment %q commitmentAttributes is missing required payload type %q",
		[c.id, ptype],
	)
}
