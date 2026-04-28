# DEG Contract Policy — P2P Trading Revenue Flows (wave2, multi-window)
#
# Computes the net revenue flow between the four roles in an inter-discom
# P2P energy trade and emits signed revenueFlows that sum to zero.
#
#   buyer        (energy consumer, BAP-side prosumer) → pays     → negative
#   seller       (energy producer, BPP-side prosumer) → receives → positive
#   buyerDiscom  (regulated LP for buyer's discom)    → receives → positive (wheeling)
#   sellerDiscom (regulated LP for seller's discom)   → receives → positive (wheeling + penalty)
#
# Multi-window: a single contract may span multiple delivery windows. The
# seller's inputs.offers[] carries one tuple per window
# {pricePerKwh, availableQuantity, deliveryWindow}; the contract's
# performance[] carries one settlement entry per delivered window
# {deliveryWindow, settledQuantityKwh, …}. Per-window value is settled_kwh
# × pricePerKwh of the matching seller offer slot (matched by
# deliveryWindow.schema:startTime). Trade value is the sum across all
# performance entries.
#
# Inputs read from the contract payload:
#   commitments[0].offer.offerAttributes.inputs[seller].inputs.offers[*]
#                                                — pricePerKwh per delivery
#                                                  window (matched by
#                                                  startTime)
#   commitments[0].offer.offerAttributes.inputs[seller].inputs.currency
#                                                — single currency for all
#                                                  windows
#   contract.performance[*].performanceAttributes.{deliveryWindow,
#                                                  settledQuantityKwh}
#                                                — per-window settlement
#   contractAttributes.roles                     — must include all four roles
#
# Wheeling and penalty placeholders are 0 today; the structure is in place
# so a future rule (e.g. tariff lookup, default-event detection) can plug
# real values into the same revenueFlows shape without re-shaping callers.
#
# Exported rules:
#   revenue_flows           — [{role, value, currency, description}]
#   trade_value             — sum over windows of (settled_kwh × price_per_kwh)
#   wheeling_charge_buyer   — 0 placeholder
#   wheeling_charge_seller  — 0 placeholder
#   penalty_charge          — 0 placeholder
#   net_zero_ok             — bool: sum of revenue_flows == 0
#   violations              — set of error strings

package deg.contracts.p2p_trading

import rego.v1

# ---------------------------------------------------------------------------
# Input extraction
# ---------------------------------------------------------------------------

_contract := input.message.contract

_offer_attrs := _contract.commitments[0].offer.offerAttributes

_inputs := _offer_attrs.inputs

_seller_inputs := [i.inputs | some i in _inputs; i.role == "seller"][0]

# Seller's per-window slots: [{pricePerKwh, availableQuantity, deliveryWindow}, …]
_seller_offers := _seller_inputs.offers

_currency := _seller_inputs.currency

# Settlement performance entries — one per delivered window.
_perf := _contract.performance

# ---------------------------------------------------------------------------
# Per-window helpers
# ---------------------------------------------------------------------------

# Price for a delivery window, matched by the schema:startTime of the
# seller offer slot. Falls back to 0 when no slot matches (a violation is
# emitted separately so callers know the policy didn't find a price).
_price_for_window(start_time) := price if {
	some s in _seller_offers
	s.deliveryWindow["schema:startTime"] == start_time
	price := s.pricePerKwh
} else := 0

# Per-performance-entry value: settled_kwh × matched_price_per_kwh.
_window_value(p) := value if {
	settled := p.performanceAttributes.settledQuantityKwh
	start_time := p.performanceAttributes.deliveryWindow["schema:startTime"]
	price := _price_for_window(start_time)
	value := settled * price
}

# Per-window settled quantity (used for human-readable description).
_window_settled(p) := q if {
	q := p.performanceAttributes.settledQuantityKwh
}

# ---------------------------------------------------------------------------
# Aggregate trade value across windows
# ---------------------------------------------------------------------------

trade_value := sum([_window_value(p) | some p in _perf])

total_settled_kwh := sum([_window_settled(p) | some p in _perf])

# Per-window human-readable breakdown, used inside revenueFlows descriptions.
_window_breakdown := concat("; ", [s |
	some p in _perf
	settled := p.performanceAttributes.settledQuantityKwh
	start_time := p.performanceAttributes.deliveryWindow["schema:startTime"]
	price := _price_for_window(start_time)
	value := settled * price
	s := sprintf("%v kWh @ %v %s = %v %s [%v]", [settled, price, _currency, value, _currency, start_time])
])

# ---------------------------------------------------------------------------
# Charge placeholders (sum across all windows)
# ---------------------------------------------------------------------------

# Wheeling charges and penalty default to zero. Wire real tariff/penalty
# rules here when the network policy defines them — revenueFlows callers
# do not need to change.
default wheeling_charge_buyer := 0

default wheeling_charge_seller := 0

default penalty_charge := 0

# ---------------------------------------------------------------------------
# Revenue flows by role (the core output)
#
#   buyer pays trade_value + buyer-side wheeling
#   seller receives trade_value − seller-side wheeling − penalty
#   buyerDiscom receives buyer-side wheeling
#   sellerDiscom receives seller-side wheeling + penalty
#   sum = 0
# ---------------------------------------------------------------------------

_buyer_payable := trade_value + wheeling_charge_buyer

_seller_receivable := (trade_value - wheeling_charge_seller) - penalty_charge

_seller_discom_value := wheeling_charge_seller + penalty_charge

_buyer_flow := {
	"role": "buyer",
	"value": _buyer_payable * -1,
	"currency": _currency,
	"description": sprintf(
		"Pays %v %s across %v window(s): [%s]; buyer-side wheeling %v",
		[_buyer_payable, _currency, count(_perf), _window_breakdown, wheeling_charge_buyer],
	),
}

_seller_flow := {
	"role": "seller",
	"value": _seller_receivable,
	"currency": _currency,
	"description": sprintf(
		"Receives %v %s across %v window(s): [%s]; seller-side wheeling %v, penalty %v",
		[_seller_receivable, _currency, count(_perf), _window_breakdown, wheeling_charge_seller, penalty_charge],
	),
}

_buyer_discom_flow := {
	"role": "buyerDiscom",
	"value": wheeling_charge_buyer,
	"currency": _currency,
	"description": "Buyer-side wheeling charge across all windows (placeholder — currently 0)",
}

_seller_discom_flow := {
	"role": "sellerDiscom",
	"value": _seller_discom_value,
	"currency": _currency,
	"description": "Seller-side wheeling charge + any penalty across all windows (placeholders — currently 0)",
}

revenue_flows := [_buyer_flow, _seller_flow, _buyer_discom_flow, _seller_discom_flow]

_revenue_sum := sum([f.value | some f in revenue_flows])

net_zero_ok if _revenue_sum == 0

# ---------------------------------------------------------------------------
# Roles — extracted from contractAttributes (DEGContract)
# ---------------------------------------------------------------------------

_contract_attrs := _contract.contractAttributes

_roles := {r.role | some r in _contract_attrs.roles}

# ---------------------------------------------------------------------------
# Violations
# ---------------------------------------------------------------------------

_required_roles := {"buyer", "seller", "buyerDiscom", "sellerDiscom"}

violations contains msg if {
	some role in _required_roles
	not role in _roles
	msg := sprintf("missing required role %q in contractAttributes.roles", [role])
}

violations contains msg if {
	count(_perf) == 0
	msg := "no performance entries — cannot compute revenue flows"
}

# Per-window: settledQuantityKwh must be present.
violations contains msg if {
	some p in _perf
	not p.performanceAttributes.settledQuantityKwh
	msg := sprintf(
		"missing settledQuantityKwh on performance entry %q",
		[p.id],
	)
}

# Per-window: a seller offer slot must match the performance deliveryWindow.
violations contains msg if {
	some p in _perf
	start_time := p.performanceAttributes.deliveryWindow["schema:startTime"]
	not _matched_seller_offer(start_time)
	msg := sprintf(
		"no seller offer slot matches performance deliveryWindow.schema:startTime %q (entry %q)",
		[start_time, p.id],
	)
}

_matched_seller_offer(start_time) if {
	some s in _seller_offers
	s.deliveryWindow["schema:startTime"] == start_time
}

violations contains msg if {
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}
