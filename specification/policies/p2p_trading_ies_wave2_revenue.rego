# DEG Contract Policy — P2P Trading Revenue Flows (wave2, timeseries)
#
# Computes the net revenue flow between the four roles in an inter-discom
# P2P energy trade and emits signed revenueFlows that sum to zero.
#
#   buyer        (energy consumer, BAP-side prosumer) → pays     → negative
#   seller       (energy producer, BPP-side prosumer) → receives → positive
#   buyerDiscom  (regulated LP for buyer's discom)    → receives → positive (wheeling)
#   sellerDiscom (regulated LP for seller's discom)   → receives → positive (wheeling + penalty)
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
# Wheeling and penalty placeholders are 0 today.
#
# Exported rules:
#   revenue_flows          — [{role, value, currency, description}]
#   trade_value            — total INR value across all settled intervals
#   total_settled_kwh      — total kWh settled across all intervals
#   wheeling_charge_buyer  — 0 placeholder
#   wheeling_charge_seller — 0 placeholder
#   penalty_charge         — 0 placeholder
#   net_zero_ok            — bool: sum of revenue_flows == 0
#   violations             — set of error strings

package deg.contracts.p2p_trading

import rego.v1

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

# ---------------------------------------------------------------------------
# Per-interval value
# ---------------------------------------------------------------------------

_interval_value(i) := v if {
	alloc := _payload_val(i, "FINAL_ALLOC")
	price := _price_by_id[i.id]
	v := alloc * price
}

# ---------------------------------------------------------------------------
# Aggregate trade value across settled intervals
# ---------------------------------------------------------------------------

trade_value := sum([_interval_value(i) | some i in _commit_ts.intervals; i.id in _settled_interval_ids])

total_settled_kwh := sum([_payload_val(i, "FINAL_ALLOC") | some i in _commit_ts.intervals; i.id in _settled_interval_ids])

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
# Charge placeholders
# ---------------------------------------------------------------------------

default wheeling_charge_buyer := 0

default wheeling_charge_seller := 0

default penalty_charge := 0

# ---------------------------------------------------------------------------
# Revenue flows by role
# ---------------------------------------------------------------------------

_buyer_payable := trade_value + wheeling_charge_buyer

_seller_receivable := (trade_value - wheeling_charge_seller) - penalty_charge

_seller_discom_value := wheeling_charge_seller + penalty_charge

_buyer_flow := {
	"role": "buyerPlatform",
	"value": _buyer_payable * -1,
	"currency": _currency,
	"description": sprintf(
		"Pays %v %s across %v settled interval(s): [%s]; buyer-side wheeling %v",
		[_buyer_payable, _currency, count(_settled_interval_ids), _window_breakdown, wheeling_charge_buyer],
	),
}

_seller_flow := {
	"role": "sellerPlatform",
	"value": _seller_receivable,
	"currency": _currency,
	"description": sprintf(
		"Receives %v %s across %v settled interval(s): [%s]; seller-side wheeling %v, penalty %v",
		[_seller_receivable, _currency, count(_settled_interval_ids), _window_breakdown, wheeling_charge_seller, penalty_charge],
	),
}

_buyer_discom_flow := {
	"role": "buyerDiscom",
	"value": wheeling_charge_buyer,
	"currency": _currency,
	"description": "Buyer-side wheeling charge across all intervals (placeholder — currently 0)",
}

_seller_discom_flow := {
	"role": "sellerDiscom",
	"value": _seller_discom_value,
	"currency": _currency,
	"description": "Seller-side wheeling charge + any penalty across all intervals (placeholders — currently 0)",
}

revenue_flows := [_buyer_flow, _seller_flow, _buyer_discom_flow, _seller_discom_flow]

_revenue_sum := sum([f.value | some f in revenue_flows])

net_zero_ok if _revenue_sum == 0

# ---------------------------------------------------------------------------
# Roles — extracted from contractAttributes
# ---------------------------------------------------------------------------

_contract_attrs := _contract.contractAttributes

_roles := {r.role | some r in _contract_attrs.roles}

# ---------------------------------------------------------------------------
# Violations
# ---------------------------------------------------------------------------

_required_roles := {"buyerPlatform", "sellerPlatform", "buyerDiscom", "sellerDiscom"}

violations contains msg if {
	some role in _required_roles
	not role in _roles
	msg := sprintf("missing required role %q in contractAttributes.roles", [role])
}

violations contains "no FINAL_ALLOC intervals in commitmentAttributes — cannot compute revenue flows" if {
	is_object(_commit_ts)
	count(_settled_interval_ids) == 0
}

violations contains msg if {
	some i in _commit_ts.intervals
	i.id in _settled_interval_ids
	not _price_by_id[i.id]
	msg := sprintf("settled interval %v has no matching PRICE_PER_KWH interval", [i.id])
}

violations contains msg if {
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
