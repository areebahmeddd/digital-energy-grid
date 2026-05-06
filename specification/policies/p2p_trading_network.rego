# DEG Network Policy — P2P Trading IES (wave2)
#
# Validates all beckn messages for the inter-discom P2P energy trading
# network. Rules are gated by message structure so they apply automatically
# to the relevant actions (confirm, on_confirm, select, init, on_status, …)
# without false positives on lighter payloads (discover, status ping).
#
# ── common (all actions) ──
#
# C1. Version: context.version must be "2.0.0".
#
# ── contract validation (when message.contract exists) ──
#
# N1.  Required roles: buyer, seller, buyerDiscom, sellerDiscom must all be
#      present in contractAttributes.roles.
# N2.  Participant utilityIds: seller and buyer participants must each have a
#      non-empty utilityId.
# N3.  Inter-discom: buyer and seller must have different utilityIds.
# N4.  offerTimeseries payloadTypes: seller inputs must declare PRICE_PER_KWH
#      and AVAILABLE_QTY in payloadDescriptors.
# N5.  Offer currency: PRICE_PER_KWH descriptor must carry currency: INR.
# N6.  Offer qty units: AVAILABLE_QTY descriptor must carry units: KWH.
# N7.  bidTimeseries payloadTypes: buyer inputs must declare REQUESTED_QTY.
# N8.  Bid qty units: REQUESTED_QTY descriptor must carry units: KWH.
# N9.  Interval id alignment: buyer bid interval ids must be a subset of
#      seller offer interval ids (typo in payloadType names is caught here
#      too, since the interval would carry an undeclared type id).
# N10. Quantity cap: REQUESTED_QTY ≤ AVAILABLE_QTY per matched interval.
# N11. No self-trade: buyer and seller meter ids must differ.
# N12. Seller source type must be a generation source (not GRID).
#
# ── performance validation (on_status with performanceTimeseries) ──
#
# P1.  payloadTypes declared: BUYER_ALLOCATION, SELLER_INJECTION, SETTLED_QTY.
# P2.  Performance qty units: all three types must carry units: KWH.
# P3.  Interval coverage: performance interval ids must be a subset of seller
#      offer interval ids.
# P4.  Settlement consistency: SETTLED_QTY ≤ min(BUYER_ALLOCATION,
#      SELLER_INJECTION) per interval.
#
# ── TEST / PROD separation ──
#
# T1.  Production network: buyer and seller utilityIds must each be an
#      approved DISCOM (data.config.allowedUtilityIds or built-in default).
# T2.  Test consistency: if ANY buyer/seller participant uses a utilityId or
#      meterId that starts with "TEST_", ALL buyer/seller participants must
#      use TEST_ prefixed identifiers.
#
# Config:
#   data.config.productionNetworkIds  — set of production networkId strings
#   data.config.allowedUtilityIds     — set of approved DISCOM utilityIds
#   data.config.minDeliveryLeadHours  — not enforced here (interval-based
#                                       windows; enforce via catalog policy)

package deg.policy.p2p_trading_network

import rego.v1

# ---------------------------------------------------------------------------
# Config with defaults
# ---------------------------------------------------------------------------

_production_network_ids := {"beckn.one:deg:p2p-trading-ies:2.0.0"} if {
	not data.config.productionNetworkIds
} else := data.config.productionNetworkIds

_allowed_utility_ids := {"TPDDL-DL", "BRPL-DL", "PVVNL-DL", "BYPL-DL", "NDMC-DL"} if {
	not data.config.allowedUtilityIds
} else := data.config.allowedUtilityIds

# ---------------------------------------------------------------------------
# Timeseries helpers
# ---------------------------------------------------------------------------

_ts_types(ts) := {d.payloadType | some d in ts.payloadDescriptors}

_ts_units(ts, ptype) := u if {
	some d in ts.payloadDescriptors
	d.payloadType == ptype
	u := d.units
}

_ts_currency(ts, ptype) := c if {
	some d in ts.payloadDescriptors
	d.payloadType == ptype
	c := d.currency
}

_payload_val(interval, ptype) := v if {
	some p in interval.payloads
	p.type == ptype
	v := p.values[0]
}

# ---------------------------------------------------------------------------
# C1 — Version check (all actions)
# ---------------------------------------------------------------------------

_common_violations contains msg if {
	v := object.get(input.context, "version", "")
	v != "2.0.0"
	msg := sprintf("context.version is %q; must be 2.0.0", [v])
}

# ---------------------------------------------------------------------------
# Contract helpers
# ---------------------------------------------------------------------------

_contract := input.message.contract

_commitment := _contract.commitments[0]

_seller_role_inputs := [i | some i in _commitment.offer.offerAttributes.inputs; i.role == "seller"][0]

_buyer_role_inputs := [i | some i in _commitment.offer.offerAttributes.inputs; i.role == "buyer"][0]

_offer_ts := _seller_role_inputs.inputs.offerTimeseries

_bid_ts := _buyer_role_inputs.inputs.bidTimeseries

_offer_interval_ids := {i.id | some i in _offer_ts.intervals}

_bid_interval_ids := {i.id | some i in _bid_ts.intervals}

_participant_by_role(role) := p if {
	some p in _contract.participants
	p.role == role
}

_seller_p := _participant_by_role("seller")

_buyer_p := _participant_by_role("buyer")

# ---------------------------------------------------------------------------
# N1 — Required roles
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	required := {"buyer", "seller", "buyerDiscom", "sellerDiscom"}
	roles_present := {r.role | some r in _contract.contractAttributes.roles}
	missing := required - roles_present
	count(missing) > 0
	msg := sprintf("missing required role(s) in contractAttributes.roles: %v", [missing])
}

# ---------------------------------------------------------------------------
# N2 — Participant utilityIds non-empty
# ---------------------------------------------------------------------------

_contract_violations contains "seller participant utilityId is missing or empty" if {
	_seller_p
	uid := object.get(_seller_p.participantAttributes, "utilityId", "")
	uid == ""
}

_contract_violations contains "buyer participant utilityId is missing or empty" if {
	_buyer_p
	uid := object.get(_buyer_p.participantAttributes, "utilityId", "")
	uid == ""
}

# ---------------------------------------------------------------------------
# N3 — Inter-discom: buyer and seller must be on different DISCOMs
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	_seller_p
	_buyer_p
	s_uid := _seller_p.participantAttributes.utilityId
	b_uid := _buyer_p.participantAttributes.utilityId
	s_uid == b_uid
	msg := sprintf(
		"seller and buyer have the same utilityId %q; inter-discom trade requires different DISCOMs",
		[s_uid],
	)
}

# ---------------------------------------------------------------------------
# N4-N6 — offerTimeseries payloadType and unit validation
# ---------------------------------------------------------------------------

_contract_violations contains "seller offerTimeseries payloadDescriptors must include PRICE_PER_KWH" if {
	_offer_ts
	not "PRICE_PER_KWH" in _ts_types(_offer_ts)
}

_contract_violations contains "seller offerTimeseries payloadDescriptors must include AVAILABLE_QTY" if {
	_offer_ts
	not "AVAILABLE_QTY" in _ts_types(_offer_ts)
}

_contract_violations contains msg if {
	_offer_ts
	"PRICE_PER_KWH" in _ts_types(_offer_ts)
	c := _ts_currency(_offer_ts, "PRICE_PER_KWH")
	c != "INR"
	msg := sprintf("offerTimeseries PRICE_PER_KWH currency is %q; must be INR", [c])
}

_contract_violations contains msg if {
	_offer_ts
	"AVAILABLE_QTY" in _ts_types(_offer_ts)
	u := _ts_units(_offer_ts, "AVAILABLE_QTY")
	u != "KWH"
	msg := sprintf("offerTimeseries AVAILABLE_QTY units is %q; must be KWH", [u])
}

# ---------------------------------------------------------------------------
# N7-N8 — bidTimeseries payloadType and unit validation
# ---------------------------------------------------------------------------

_contract_violations contains "buyer bidTimeseries payloadDescriptors must include REQUESTED_QTY" if {
	_bid_ts
	not "REQUESTED_QTY" in _ts_types(_bid_ts)
}

_contract_violations contains msg if {
	_bid_ts
	"REQUESTED_QTY" in _ts_types(_bid_ts)
	u := _ts_units(_bid_ts, "REQUESTED_QTY")
	u != "KWH"
	msg := sprintf("bidTimeseries REQUESTED_QTY units is %q; must be KWH", [u])
}

# ---------------------------------------------------------------------------
# N9 — Interval id alignment: bid ids ⊆ offer ids
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	_bid_ts
	_offer_ts
	extra := _bid_interval_ids - _offer_interval_ids
	count(extra) > 0
	msg := sprintf(
		"buyer bidTimeseries interval ids %v not present in seller offerTimeseries ids %v",
		[extra, _offer_interval_ids],
	)
}

# ---------------------------------------------------------------------------
# N10 — REQUESTED_QTY ≤ AVAILABLE_QTY per interval
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	_bid_ts
	_offer_ts
	some bi in _bid_ts.intervals
	bi.id in _offer_interval_ids
	req := _payload_val(bi, "REQUESTED_QTY")
	some oi in _offer_ts.intervals
	oi.id == bi.id
	avail := _payload_val(oi, "AVAILABLE_QTY")
	req > avail
	msg := sprintf(
		"bid interval %v: REQUESTED_QTY %v kWh > seller AVAILABLE_QTY %v kWh",
		[bi.id, req, avail],
	)
}

# ---------------------------------------------------------------------------
# N11 — No self-trade: buyer and seller meter ids must differ
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	_seller_p
	_buyer_p
	s_mid := _seller_p.participantAttributes.meterId
	b_mid := _buyer_p.participantAttributes.meterId
	s_mid == b_mid
	msg := sprintf(
		"seller and buyer have the same meterId %q; a prosumer cannot self-trade",
		[s_mid],
	)
}

# ---------------------------------------------------------------------------
# N12 — Seller source type must be a generation source, not GRID
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	st := _seller_role_inputs.inputs.sourceType
	st == "GRID"
	msg := "seller sourceType is GRID; must be a generation source (SOLAR, BATTERY, HYBRID, RENEWABLE)"
}

# ---------------------------------------------------------------------------
# Performance validation (on_status with performanceTimeseries)
# ---------------------------------------------------------------------------

_perf_ts := _contract.performance[0].performanceAttributes.performanceTimeseries

_perf_interval_ids := {i.id | some i in _perf_ts.intervals}

_performance_violations contains "performance timeseries payloadDescriptors must include BUYER_ALLOCATION" if {
	_perf_ts
	not "BUYER_ALLOCATION" in _ts_types(_perf_ts)
}

_performance_violations contains "performance timeseries payloadDescriptors must include SELLER_INJECTION" if {
	_perf_ts
	not "SELLER_INJECTION" in _ts_types(_perf_ts)
}

_performance_violations contains "performance timeseries payloadDescriptors must include SETTLED_QTY" if {
	_perf_ts
	not "SETTLED_QTY" in _ts_types(_perf_ts)
}

_performance_violations contains msg if {
	_perf_ts
	some ptype in {"BUYER_ALLOCATION", "SELLER_INJECTION", "SETTLED_QTY"}
	ptype in _ts_types(_perf_ts)
	u := _ts_units(_perf_ts, ptype)
	u != "KWH"
	msg := sprintf("performance timeseries %v units is %q; must be KWH", [ptype, u])
}

_performance_violations contains msg if {
	_perf_ts
	_offer_ts
	extra := _perf_interval_ids - _offer_interval_ids
	count(extra) > 0
	msg := sprintf(
		"performance timeseries interval ids %v not present in seller offerTimeseries ids %v",
		[extra, _offer_interval_ids],
	)
}

_performance_violations contains msg if {
	_perf_ts
	some pi in _perf_ts.intervals
	settled := _payload_val(pi, "SETTLED_QTY")
	buyer_alloc := _payload_val(pi, "BUYER_ALLOCATION")
	seller_inj := _payload_val(pi, "SELLER_INJECTION")
	min_alloc := min({buyer_alloc, seller_inj})
	settled > min_alloc
	msg := sprintf(
		"performance interval %v: SETTLED_QTY %v > min(BUYER_ALLOCATION %v, SELLER_INJECTION %v)",
		[pi.id, settled, buyer_alloc, seller_inj],
	)
}

# ---------------------------------------------------------------------------
# TEST / PROD separation
# ---------------------------------------------------------------------------

_is_production if input.context.networkId in _production_network_ids

# T1 — Production: buyer and seller utilityIds must be approved DISCOMs
_prod_violations contains msg if {
	_is_production
	some p in _contract.participants
	p.role in {"buyer", "seller"}
	uid := p.participantAttributes.utilityId
	not uid in _allowed_utility_ids
	msg := sprintf(
		"participant %q (role: %s): utilityId %q is not an approved DISCOM; must be one of %v",
		[p.participantId, p.role, uid, _allowed_utility_ids],
	)
}

# T2 — Test consistency: if any buyer/seller uses TEST_ prefix, all must
_any_is_test if {
	some p in _contract.participants
	p.role in {"buyer", "seller"}
	startswith(p.participantAttributes.utilityId, "TEST_")
}

_any_is_test if {
	some p in _contract.participants
	p.role in {"buyer", "seller"}
	startswith(p.participantAttributes.meterId, "TEST_")
}

_test_violations contains msg if {
	_any_is_test
	some p in _contract.participants
	p.role in {"buyer", "seller"}
	not startswith(p.participantAttributes.utilityId, "TEST_")
	msg := sprintf(
		"test consistency: participant %q (role: %s) utilityId %q must start with TEST_",
		[p.participantId, p.role, p.participantAttributes.utilityId],
	)
}

_test_violations contains msg if {
	_any_is_test
	some p in _contract.participants
	p.role in {"buyer", "seller"}
	not startswith(p.participantAttributes.meterId, "TEST_")
	msg := sprintf(
		"test consistency: participant %q (role: %s) meterId %q must start with TEST_",
		[p.participantId, p.role, p.participantAttributes.meterId],
	)
}

# ---------------------------------------------------------------------------
# Public violations API
# ---------------------------------------------------------------------------

violations contains msg if {
	some msg in _common_violations
}

violations contains msg if {
	input.message.contract
	some msg in _contract_violations
}

violations contains msg if {
	input.message.contract
	input.context.action == "on_status"
	some msg in _performance_violations
}

violations contains msg if {
	input.message.contract
	some msg in _prod_violations
}

violations contains msg if {
	input.message.contract
	some msg in _test_violations
}
