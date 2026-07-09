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
#        - network membership: context.networkId must be a recognized IES
#          P2P trading network (test or production);
#        - policy applicability: the seller's discom must be one of the
#          discoms this policy is declared to apply to
#          (applicable_seller_discoms, per environment);
#        - settlement currency: must be in allowed_currencies (INR);
#        - discom ledger endpoints: buyerDiscom and sellerDiscom must record
#          against a recognized ledger (allowed_ledger_urls, per
#          environment; production = the canonical IES P2P energy ledger
#          https://ies-p2p-energy-ledger.beckn.io);
#        - counterpart allowlist (when the environment's enforce_allowlist
#          is true): the buyer's discom must be in the allowlist of the
#          environment the networkId selects (test vs production);
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
# Discom-tunable knobs — ALL of them live together in the "Discom
# parameters" section right below the package line; nothing after that
# section needs editing:
#   environments                  — ONE map holding everything that differs
#                                   between test and production: the
#                                   networkIds that select the environment,
#                                   the discoms this policy applies to
#                                   (applicable_seller_discoms), a
#                                   per-environment enforce_allowlist switch,
#                                   the per-environment counterpart
#                                   allowlist, and the permitted discom
#                                   ledger endpoints (allowed_ledger_urls).
#                                   All rules are environment-
#                                   agnostic and read their settings through
#                                   this map — the test network can pilot
#                                   partners not yet permitted in production
#                                   without any rule diverging. A networkId
#                                   outside every environment is a violation
#                                   → NACK.
#   allowed_currencies            — permitted settlement currency (INR); any
#                                   other PRICE_PER_KWH currency → NACK
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
# Discom parameters — EVERY constant a discom edits lives in this section.
# Everything after the end-of-parameters line is shared mechanics: if you
# find yourself editing a rule body, the change probably belongs here as
# data instead.
# ---------------------------------------------------------------------------

# Everything environment-specific lives in this ONE map; every rule below is
# environment-agnostic and reads its settings through `_env`. To change how
# an environment behaves, edit its entry here — never fork a rule per
# environment.
#
# Per-environment settings:
#   network_ids           — context.networkId values that select this
#                           environment. Sets MUST be disjoint across
#                           environments (a networkId in two entries would
#                           make environment resolution ambiguous).
#   applicable_seller_discoms — the discoms this policy APPLIES TO, declared
#                           upfront: utilityIds of every discom that shares
#                           this policy as its common seller-discom policy.
#                           A trade whose selling prosumer belongs to any
#                           other discom is a violation → NACK (the catalog
#                           publisher linked the wrong policy).
#   enforce_allowlist     — false switches the counterpart allowlist off for
#                           THIS environment only; the allowlist rules are
#                           then never even evaluated for its traffic.
#   allowed_buyer_discoms — utilityIds whose customers may buy from this
#                           discom's prosumers in this environment. The test
#                           list may be broader than production: pilot with a
#                           prospective partner on the test network before
#                           the regulator approves them for production.
#   allowed_ledger_urls   — permitted ledgerUrl values for the buyerDiscom
#                           and sellerDiscom participants. Both discoms must
#                           record against a recognized ledger endpoint —
#                           the canonical IES P2P energy ledger in
#                           production; the test set additionally lists the
#                           devkit-local ledger endpoints the compose
#                           stack's cascade routing uses.
environments := {
	"test": {
		"network_ids": {
			"nfh.global/testnet-deg",
			"indiaenergystack.in/test-ies-p2p-trading-network",
		},
		"applicable_seller_discoms": {"TEST_DISCOM_SELLER"},
		"enforce_allowlist": true,
		"allowed_buyer_discoms": {
			"TEST_DISCOM_SELLER", # intra-discom trades always allowed
			"TEST_DISCOM_BUYER",
		},
		"allowed_ledger_urls": {
			"https://ies-p2p-energy-ledger.beckn.io",
			# devkit-local ledger endpoints (degledgerrecorder cascade targets)
			"http://buyer-discom-ledger.example.com:9000",
			"http://seller-discom-ledger.example.com:9000",
		},
	},
	"production": {
		"network_ids": {"indiaenergystack.in/ies-p2p-trading-network"},
		"applicable_seller_discoms": {"TPDDL"},
		"enforce_allowlist": true,
		"allowed_buyer_discoms": {
			"TPDDL", # intra-discom trades always allowed
			"BRPL",
			"PVVNL",
		},
		"allowed_ledger_urls": {"https://ies-p2p-energy-ledger.beckn.io"},
	},
}

# Settlement currency this policy permits. Shared across environments (INR
# is national); move into the environments map via _env if that ever changes.
allowed_currencies := {"INR"}

# Charges are shared across environments. If an environment ever needs
# different rates, move them into the environments map and read them via
# _env — same pattern as the allowlist, no per-environment rule forks.

# Wheeling charges this discom levies, in currency units per settled kWh.
wheeling_charge_buyer_per_kwh := 0.25

wheeling_charge_seller_per_kwh := 0.30

# Penalty on under-delivery, per kWh of shortfall (REQUESTED_QTY − FINAL_ALLOC).
penalty_rate_per_kwh := 0.50

# Ceiling on what the trading platform may retain per kWh from trades under
# this discom's jurisdiction. Disclosed in the settlement itemization.
platform_charge_cap_per_kwh := 0.42

# ═══════════════════ END OF DISCOM PARAMETERS ═══════════════════
# Everything below is mechanics — no discom-specific values past this line.

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

# The seller prosumer's discom: utilityId of the sellerPlatform participant.
# Checked against _env.applicable_seller_discoms — this policy must actually
# be the policy of the discom whose prosumer is selling.
_seller_discom_id := id if {
	some p in _contract.participants
	p.role == "sellerPlatform"
	id := p.participantAttributes.utilityId
}

# Environment resolution: context.networkId selects exactly one entry of the
# environments map; every environment-dependent rule reads settings via
# `_env`. An unknown networkId matches no entry, leaving _env undefined — so
# environment-dependent rules simply cannot fire and the (unconditional)
# membership violation reports the problem instead.
_network_id := input.context.networkId

_known_network_ids := {net | some env in environments; some net in env.network_ids}

_environment := name if {
	some name, env in environments
	_network_id in env.network_ids
}

_env := environments[_environment]

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
# Violations — network membership (all actions; cheap)
# ---------------------------------------------------------------------------

violations contains msg if {
	not _network_id
	msg := "context.networkId is missing — cannot determine the trading network"
}

violations contains msg if {
	_network_id
	not _network_id in _known_network_ids
	msg := sprintf(
		"networkId %q is not a recognized IES P2P trading network (known: %v)",
		[_network_id, sort(_known_network_ids)],
	)
}

# ---------------------------------------------------------------------------
# Violations — policy applicability (all environments)
# ---------------------------------------------------------------------------
# This policy declares upfront which discoms it applies to
# (_env.applicable_seller_discoms). If the selling prosumer's discom is not
# one of them, the catalog publisher linked the wrong policy — block the
# trade rather than judge it under rules that don't govern it.

violations contains msg if {
	_seller_discom_id
	not _seller_discom_id in _env.applicable_seller_discoms
	msg := sprintf(
		"this policy does not apply to seller discom %q (applies to: %v on the %s network)",
		[_seller_discom_id, sort(_env.applicable_seller_discoms), _environment],
	)
}

violations contains msg if {
	_env
	not _seller_discom_id
	msg := "cannot determine seller discom: no sellerPlatform participant with participantAttributes.utilityId"
}

# ---------------------------------------------------------------------------
# Violations — discom ledger endpoints
# ---------------------------------------------------------------------------
# Both discoms record the trade against a ledger; their participants'
# ledgerUrl must be a recognized endpoint for the environment (the canonical
# IES P2P energy ledger in production). Shape-gated on the participant being
# present — participant completeness is the schema/network policy's job.

_discom_ledger_roles := {"buyerDiscom", "sellerDiscom"}

violations contains msg if {
	some p in _contract.participants
	p.role in _discom_ledger_roles
	url := p.participantAttributes.ledgerUrl
	not url in _env.allowed_ledger_urls
	msg := sprintf(
		"%s ledgerUrl %q is not a permitted ledger endpoint on the %s network (allowed: %v)",
		[p.role, url, _environment, sort(_env.allowed_ledger_urls)],
	)
}

violations contains msg if {
	_env
	some p in _contract.participants
	p.role in _discom_ledger_roles
	not p.participantAttributes.ledgerUrl
	msg := sprintf("%s participant is missing participantAttributes.ledgerUrl", [p.role])
}

# ---------------------------------------------------------------------------
# Violations — settlement currency
# ---------------------------------------------------------------------------
# Gated on _currency being present (data-shape gate): fires only when the
# payload actually declares a PRICE_PER_KWH currency, so payloads without
# commitment timeseries are not falsely flagged.

violations contains msg if {
	_currency
	not _currency in allowed_currencies
	msg := sprintf("settlement currency %q is not permitted (allowed: %v)", [_currency, sort(allowed_currencies)])
}

# ---------------------------------------------------------------------------
# Violations — trading eligibility (enforced at select/init/confirm)
# ---------------------------------------------------------------------------
# One rule per check, shared by every environment: the environment only
# supplies data (via _env), never its own rule variant.

# The per-environment enforce_allowlist switch is the FIRST guard: when the
# resolved environment has it off, none of the allowlist machinery
# (buyer-discom extraction, set lookup) is evaluated for its traffic.
violations contains msg if {
	_env.enforce_allowlist
	_buyer_discom_id
	not _buyer_discom_id in _env.allowed_buyer_discoms
	msg := sprintf(
		"buyer discom %q is not allowed to trade with this discom's prosumers on the %s network (allowed: %v)",
		[_buyer_discom_id, _environment, sort(_env.allowed_buyer_discoms)],
	)
}

violations contains msg if {
	_env.enforce_allowlist
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
