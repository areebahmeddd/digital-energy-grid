# DEG Contract Policy — P2P Trading Revenue Flows
#
# Computes the net revenue flow between the four roles in an inter-discom
# P2P energy trade and emits signed revenueFlows that sum to zero.
#
#   buyer        (energy consumer, BAP-side prosumer) → pays     → negative
#   seller       (energy producer, BPP-side prosumer) → receives → positive
#   buyerDiscom  (regulated LP for buyer's discom)    → receives → positive (wheeling)
#   sellerDiscom (regulated LP for seller's discom)   → receives → positive (wheeling + penalty)
#
# Inputs read from the contract payload:
#   commitments[0].offer.offerAttributes.inputs   — role-tagged price/qty terms
#   contract.performance[0].performanceAttributes — settled qty (Phase 5 reconciliation)
#   contractAttributes.roles                       — must include all four roles
#
# Wheeling and penalty placeholders are 0 today; the structure is in place
# so a future rule (e.g. tariff lookup, default-event detection) can plug
# real values into the same revenueFlows shape without re-shaping callers.
#
# Exported rules:
#   revenue_flows           — [{role, value, currency, description}]
#   trade_value             — settled_kwh * price_per_kwh (informational)
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

_commitment := input.message.contract.commitments[0]

_offer_attrs := _commitment.offer.offerAttributes

_inputs := _offer_attrs.inputs

_seller_inputs := [i.inputs | some i in _inputs; i.role == "seller"][0]

_price_per_kwh := _seller_inputs.pricePerKwh

_currency := _seller_inputs.currency

_perf_attrs := input.message.contract.performance[0].performanceAttributes

_settled_kwh := _perf_attrs.settledQuantityKwh

# ---------------------------------------------------------------------------
# Roles — extracted from contractAttributes (DEGContract)
# ---------------------------------------------------------------------------

_contract_attrs := input.message.contract.contractAttributes

_roles := {r.role | some r in _contract_attrs.roles}

# ---------------------------------------------------------------------------
# Trade value & charge placeholders
# ---------------------------------------------------------------------------

trade_value := _settled_kwh * _price_per_kwh

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
		"Pays %v %s for %v kWh delivered (incl. buyer-side wheeling %v)",
		[_buyer_payable, _currency, _settled_kwh, wheeling_charge_buyer],
	),
}

_seller_flow := {
	"role": "seller",
	"value": _seller_receivable,
	"currency": _currency,
	"description": sprintf(
		"Receives %v %s for %v kWh delivered (net of seller-side wheeling %v and penalty %v)",
		[_seller_receivable, _currency, _settled_kwh, wheeling_charge_seller, penalty_charge],
	),
}

_buyer_discom_flow := {
	"role": "buyerDiscom",
	"value": wheeling_charge_buyer,
	"currency": _currency,
	"description": "Buyer-side wheeling charge (placeholder — currently 0)",
}

_seller_discom_flow := {
	"role": "sellerDiscom",
	"value": _seller_discom_value,
	"currency": _currency,
	"description": "Seller-side wheeling charge + any penalty (placeholders — currently 0)",
}

revenue_flows := [_buyer_flow, _seller_flow, _buyer_discom_flow, _seller_discom_flow]

_revenue_sum := sum([f.value | some f in revenue_flows])

net_zero_ok if _revenue_sum == 0

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
	not _settled_kwh
	msg := "missing performance.performanceAttributes.settledQuantityKwh — cannot compute revenue flows"
}

violations contains msg if {
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}
