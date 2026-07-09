# ============================================================================
# EXAMPLE DISCOM POLICY — annotated template
# ============================================================================
#
# This is the policy of ONE discom ("ACME Discom" here). It governs every P2P
# trade where an ACME prosumer is the seller: the catalog publisher links it
# into the trade via message.contract.contractAttributes.policy, and the
# ONIX settlementflows step evaluates it with the full Beckn message as
# `input`.
#
# Two exported rules matter to the network (keep their names!):
#
#   violations    — set of strings. Non-empty ⇒ 400 NACK on enforced actions
#                   (select/init/confirm in wave2). This is how your
#                   allowlist and trading rules actually block a trade.
#   revenue_flows — [{role, value, currency, description}]. The settlement
#                   split, itemized with your charges. Injected into
#                   on_status payloads once settled intervals exist.
#
# To adopt this template:
#   1. Edit the "DISCOM PARAMETERS" block below — that is your policy.
#   2. Keep the package name (queryPath stays data.deg.contracts.p2p_trading)
#      or rename package + queryPath together.
#   3. Test with `opa test`, publish per the README (checksum → tag → DeDi).
#
# The full production version of this template (multi-interval math,
# completeness checks) is specification/policies/p2p_trading_ies_wave2_revenue.rego.

package deg.contracts.p2p_trading

import rego.v1

# ============================================================================
# DISCOM PARAMETERS — every constant a discom edits lives in THIS section
# ============================================================================
# This is the ONLY part of the file you touch when adopting the template:
#   environments                  — networks, policy applicability, allowlist
#                                   switch + allowlist, per environment
#   allowed_currencies            — permitted settlement currency (INR)
#   wheeling_charge_*_per_kwh     — your wheeling rates
#   penalty_rate_per_kwh          — your under-delivery penalty rate
#   platform_charge_cap_per_kwh   — your platform-fee ceiling
# Everything below the closing line of this section is mechanics — if you
# find yourself editing a rule body, the change probably belongs here as
# data instead.

# THE ENVIRONMENTS MAP — the single place where test and production differ.
#
# Design rule: rules are environment-AGNOSTIC and data is environment-
# SPECIFIC. Every rule below reads its settings through `_env` (the entry
# this message's networkId resolves to), so test and production always run
# the exact same logic — adding an environment or changing one environment's
# behavior means editing THIS map, never forking a rule.
#
# Per-environment settings:
#   network_ids           — context.networkId values that select this
#                           environment. MUST be disjoint across entries
#                           (a networkId in two environments would make
#                           resolution ambiguous). A networkId outside every
#                           entry is a violation → NACK on enforced actions.
#   applicable_seller_discoms — the discoms this policy APPLIES TO, declared
#                           upfront. Several discoms may share one common
#                           policy — list every one of them here. A trade
#                           whose SELLING prosumer belongs to any other
#                           discom is a violation → NACK: it means the
#                           catalog publisher linked the wrong policy, and
#                           blocking is safer than judging a trade under
#                           rules that don't govern it.
#   enforce_allowlist     — the allowlist switch, PER ENVIRONMENT: e.g. keep
#                           production enforced while opening the test
#                           network to everyone during an onboarding drive.
#                           When false, the allowlist rules are never even
#                           evaluated for this environment's traffic.
#   allowed_buyer_discoms — which discoms' customers may BUY from this
#                           discom's prosumers (utilityIds as they appear in
#                           participants[].participantAttributes.utilityId).
#                           The lists are independent on purpose: regulations
#                           gate production, the test list is for piloting —
#                           add a prospective partner there to run trials
#                           before the regulator approves them for the
#                           production list.
#
# NOTE: avoid the `test_` prefix in rule names (e.g. test_network_ids) —
# `opa test` treats `test_`-prefixed rules as unit tests.
environments := {
	"test": {
		"network_ids": {
			"nfh.global/testnet-deg",
			"indiaenergystack.in/test-ies-p2p-trading-network",
		},
		"applicable_seller_discoms": {
			"ACME_DISCOM",
			"TEST_DISCOM_SELLER", # devkit test identity
		},
		"enforce_allowlist": true,
		"allowed_buyer_discoms": {
			"ACME_DISCOM", # your own id: intra-discom trades stay allowed
			"NEIGHBOR_DISCOM_A",
			"NEIGHBOR_DISCOM_B",
			"PROSPECTIVE_PARTNER_DISCOM", # piloting on test net, not yet approved for prod
			"TEST_DISCOM_BUYER", # devkit test identity
		},
	},
	"production": {
		"network_ids": {"indiaenergystack.in/ies-p2p-trading-network"},
		"applicable_seller_discoms": {"ACME_DISCOM"},
		"enforce_allowlist": true,
		"allowed_buyer_discoms": {
			"ACME_DISCOM", # your own id: intra-discom trades stay allowed
			"NEIGHBOR_DISCOM_A",
			"NEIGHBOR_DISCOM_B",
		},
	},
}

# Settlement currency this policy permits. A payload pricing energy in any
# other currency is a violation → NACK. Shared across environments (INR is
# national); move into the environments map via _env if that ever changes.
allowed_currencies := {"INR"}

# Wheeling charge this discom levies on the BUYER side, per settled kWh.
wheeling_charge_buyer_per_kwh := 0.25

# Wheeling charge this discom levies on the SELLER side, per settled kWh.
wheeling_charge_seller_per_kwh := 0.30

# Penalty on under-delivery, per kWh of shortfall
# (shortfall = REQUESTED_QTY − FINAL_ALLOC, clamped at 0).
penalty_rate_per_kwh := 0.50

# Ceiling on what a trading platform may retain per kWh from trades under
# this discom's jurisdiction. Disclosed in the settlement itemization so
# every party sees the cap alongside the net amounts.
platform_charge_cap_per_kwh := 0.42

# ═══════════════════ END OF DISCOM PARAMETERS ═══════════════════
# Everything below is mechanics shared by every discom using this
# template — you should not need to edit past this line.

# ============================================================================
# INPUT EXTRACTION — where the facts come from in the Beckn message
# ============================================================================

_contract := input.message.contract

# The shared timeseries: one interval per delivery slot. PRICE_PER_KWH and
# REQUESTED_QTY are written at init; FINAL_ALLOC appears at settlement.
_commit_ts := _contract.commitments[0].commitmentAttributes

_currency := c if {
	some d in _commit_ts.payloadDescriptors
	d.payloadType == "PRICE_PER_KWH"
	c := d.currency
}

# The buyer prosumer's discom: utilityId of the buyerPlatform participant.
# This is the value checked against the active allowlist.
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

# Environment resolution — the ONLY place environments are told apart.
# context.networkId selects exactly one entry of the environments map, and
# every environment-dependent rule reads its settings through `_env`. An
# unknown networkId matches no entry, so `_env` stays undefined: rules that
# depend on it simply cannot fire (rego treats a failing expression as "this
# rule contributes nothing"), and the unconditional membership violation
# below reports the problem instead — a rule can never silently judge
# against the wrong environment's settings.
_network_id := input.context.networkId

_known_network_ids := {net | some env in environments; some net in env.network_ids}

_environment := name if {
	some name, env in environments
	_network_id in env.network_ids
}

_env := environments[_environment]

# Scalar value of a typed payload within an interval.
_payload_val(interval, ptype) := v if {
	some p in interval.payloads
	p.type == ptype
	v := p.values[0]
}

# Intervals that carry FINAL_ALLOC are "settled".
_settled_interval_ids := {i.id | some i in _commit_ts.intervals; some p in i.payloads; p.type == "FINAL_ALLOC"}

_settled := count(_settled_interval_ids) > 0

_round2(x) := round(x * 100) / 100

# ============================================================================
# VIOLATIONS — the rules that block a trade (NACK at select/init/confirm)
# ============================================================================

# NETWORK MEMBERSHIP: the message must arrive on a network this policy
# recognizes. These two rules are cheap (a set lookup) and unconditional —
# they protect every other environment-dependent decision.
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

# POLICY APPLICABILITY: this policy declared upfront which discoms it
# applies to (applicable_seller_discoms). If the selling prosumer's discom
# is not one of them, the catalog publisher linked the wrong policy — block
# the trade rather than judge it under rules that don't govern it.
violations contains msg if {
	_seller_discom_id
	not _seller_discom_id in _env.applicable_seller_discoms
	msg := sprintf(
		"this policy does not apply to seller discom %q (applies to: %v on the %s network)",
		[_seller_discom_id, sort(_env.applicable_seller_discoms), _environment],
	)
}

# Fail-closed twin: no identifiable seller discom → cannot confirm the
# policy applies → block. (Guarded on _env so it cannot double-report on
# unknown networks — the membership violation already covers those.)
violations contains msg if {
	_env
	not _seller_discom_id
	msg := "cannot determine seller discom: no sellerPlatform participant with participantAttributes.utilityId"
}

# SETTLEMENT CURRENCY: prices must be in a permitted currency. Gated on
# _currency being present (data-shape gate, see README 6.2): fires only when
# the payload actually declares a PRICE_PER_KWH currency, so payloads
# without commitment timeseries are not falsely flagged.
violations contains msg if {
	_currency
	not _currency in allowed_currencies
	msg := sprintf("settlement currency %q is not permitted (allowed: %v)", [_currency, sort(allowed_currencies)])
}

# THE ALLOWLIST RULE — one rule, every environment. It never mentions "test"
# or "production": the environment only supplies data through `_env`. The
# per-environment `enforce_allowlist` switch is the FIRST guard, so when the
# resolved environment has it off, evaluation stops here — nothing below the
# guard (buyer extraction, set lookup) ever runs for its traffic.
violations contains msg if {
	_env.enforce_allowlist
	_buyer_discom_id
	not _buyer_discom_id in _env.allowed_buyer_discoms
	msg := sprintf(
		"buyer discom %q is not allowed to trade with this discom's prosumers on the %s network (allowed: %v)",
		[_buyer_discom_id, _environment, sort(_env.allowed_buyer_discoms)],
	)
}

# Fail-closed on missing data: if we cannot tell who the buyer's discom is,
# we cannot apply the allowlist — block the trade rather than guess. Also
# behind the per-environment switch: with the allowlist off, a missing buyer
# discom is no longer a reason to block.
violations contains msg if {
	_env.enforce_allowlist
	not _buyer_discom_id
	msg := "cannot determine buyer discom: no buyerPlatform participant with participantAttributes.utilityId"
}

# Contract completeness: all four settlement roles must be declared up front.
_required_roles := {"buyerPlatform", "sellerPlatform", "buyerDiscom", "sellerDiscom"}

violations contains msg if {
	some role in _required_roles
	not role in {r.role | some r in _contract.contractAttributes.roles}
	msg := sprintf("missing required role %q in contractAttributes.roles", [role])
}

# IMPORTANT: settlement-integrity checks must be scoped to on_status —
# otherwise "no FINAL_ALLOC yet" would fire at init (where FINAL_ALLOC
# legitimately doesn't exist) and NACK every trade. Pattern:
violations contains "no FINAL_ALLOC intervals — cannot compute revenue flows" if {
	input.context.action == "on_status" # ← the scoping guard
	is_object(_commit_ts)
	not _settled
}

# ============================================================================
# CHARGES — your rates applied to the settled volume
# ============================================================================

trade_value := sum([v |
	some i in _commit_ts.intervals
	i.id in _settled_interval_ids
	v := _payload_val(i, "FINAL_ALLOC") * _payload_val(i, "PRICE_PER_KWH")
])

total_settled_kwh := sum([_payload_val(i, "FINAL_ALLOC") |
	some i in _commit_ts.intervals
	i.id in _settled_interval_ids
])

# Under-delivery across settled intervals, clamped at zero per interval.
total_shortfall_kwh := sum([s |
	some i in _commit_ts.intervals
	i.id in _settled_interval_ids
	s := max([0, _payload_val(i, "REQUESTED_QTY") - _payload_val(i, "FINAL_ALLOC")])
])

default wheeling_charge_buyer := 0

wheeling_charge_buyer := _round2(wheeling_charge_buyer_per_kwh * total_settled_kwh) if _settled

default wheeling_charge_seller := 0

wheeling_charge_seller := _round2(wheeling_charge_seller_per_kwh * total_settled_kwh) if _settled

default penalty_charge := 0

penalty_charge := _round2(penalty_rate_per_kwh * total_shortfall_kwh) if _settled

# ============================================================================
# REVENUE FLOWS — net-zero split, every amount itemized as rate × volume
# ============================================================================
#
# Sign convention: positive = receives, negative = pays. The four values
# must sum to zero — settlement is a redistribution, not value creation.

_trade_value_r := _round2(trade_value)

_buyer_payable := _trade_value_r + wheeling_charge_buyer

_seller_receivable := (_trade_value_r - wheeling_charge_seller) - penalty_charge

# Only exported once settled intervals exist: before settlement there is
# nothing to inject, so init/confirm payloads stay untouched.
revenue_flows := [
	{
		"role": "buyerPlatform",
		"value": _buyer_payable * -1,
		"currency": _currency,
		"description": sprintf(
			"Pays %v %s = energy %v %s + buyer-side wheeling @ %v %s/kWh × %v kWh = %v %s",
			[
				_buyer_payable, _currency, _trade_value_r, _currency,
				wheeling_charge_buyer_per_kwh, _currency, total_settled_kwh,
				wheeling_charge_buyer, _currency,
			],
		),
	},
	{
		"role": "sellerPlatform",
		"value": _seller_receivable,
		"currency": _currency,
		# The platform-charge cap is disclosed here so the itemization that
		# travels with the seller's payable always names the ceiling the
		# trading platform may retain.
		"description": sprintf(
			"Receives %v %s = energy %v %s − seller-side wheeling %v %s − shortfall penalty %v %s; platform charge cap %v %s/kWh applies to trading-platform fees",
			[
				_seller_receivable, _currency, _trade_value_r, _currency,
				wheeling_charge_seller, _currency, penalty_charge, _currency,
				platform_charge_cap_per_kwh, _currency,
			],
		),
	},
	{
		"role": "buyerDiscom",
		"value": wheeling_charge_buyer,
		"currency": _currency,
		"description": sprintf(
			"Buyer-side wheeling charge @ %v %s/kWh × %v settled kWh = %v %s",
			[wheeling_charge_buyer_per_kwh, _currency, total_settled_kwh, wheeling_charge_buyer, _currency],
		),
	},
	{
		"role": "sellerDiscom",
		"value": wheeling_charge_seller + penalty_charge,
		"currency": _currency,
		"description": sprintf(
			"Seller-side wheeling charge @ %v %s/kWh × %v settled kWh = %v %s + delivery penalty %v %s",
			[
				wheeling_charge_seller_per_kwh, _currency, total_settled_kwh,
				wheeling_charge_seller, _currency, penalty_charge, _currency,
			],
		),
	},
] if _settled
