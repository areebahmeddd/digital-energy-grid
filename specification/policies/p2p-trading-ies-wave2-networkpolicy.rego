# DEG Network Policy — P2P Trading IES (wave2)
#
# Validates all beckn messages for the inter-discom P2P energy trading
# network. Rules are gated by message structure so they apply automatically
# to the relevant actions (on_select, init, on_status, …) without false
# positives on lighter payloads (discover, status ping, catalog/publish).
#
# ── common (all actions) ──
#
# C1.  Version: context.version must be "2.0.0".
# NET1. Network membership: context.networkId must be exactly the production
#       network or one of the recognized test networks — no other names.
#
# ── contract validation (when message.contract exists) ──
#
# N1.  Required roles: buyerPlatform, sellerPlatform, buyerDiscom, sellerDiscom
#      must all be present in contractAttributes.roles; no unknown values allowed.
#      (participants[] are role-less, keyed by id; role -> id is read from roles.)
# N3.  Inter-discom: buyerDiscom and sellerDiscom must be different DISCOMs
#      (their role ids — UPADHI short codes — must differ).
# N4.  commitmentAttributes type: when commitmentAttributes is present it must
#      be @type: TimeSeries.
# N5.  commitmentAttributes payloadTypes: PRICE_PER_KWH must be declared
#      when interval data is present. When action is "init", AVAILABLE_QTY
#      must also be declared (buyer echoes seller offer capacity alongside bid).
# N6.  Offer currency: PRICE_PER_KWH descriptor must carry currency: INR.
# N7.  Offer qty units: AVAILABLE_QTY must carry units: KWH when declared.
#      (AVAILABLE_QTY is required only at init; optional in later messages.)
# N8.  Bid payloadTypes: must declare REQUESTED_QTY when bid interval data is
#      present (i.e. buyer has written at least one REQUESTED_QTY interval).
# N9.  Bid qty units: REQUESTED_QTY descriptor must carry units: KWH.
# N12. No self-trade: buyer and seller meter ids must differ.
# N13. Seller source type must be a generation source (not GRID).
# N14. No offerAttributes in contract messages: offer.offerAttributes must be
#      absent; all data lives in Commitment.commitmentAttributes.
# N15. Beckn semantic alignment: context.bppId and context.bapId must each
#      match a participant `id` in contract.participants[] — or a discom
#      participant's `subscriberId` / `ledgerId` (a discom's id is its UPADHI
#      short code, so its beckn ids — the discom platform id and its ledger
#      TSP id used on cascade legs — live in its attributes). Catches cascade
#      legs that rewrite bap/bppUri but leak original identifiers into ID fields.
# N16. BecknTimeSeries type-coverage: every payloadType used in
#      commitmentAttributes.intervals[*].payloads[*].type must be declared
#      in commitmentAttributes.payloadDescriptors. Catches typos like
#      "REQUESTED_QT" or undocumented signal names on the wire.
# N17. Policy pin: when contractAttributes.policy is present, its queryPath must
#      be exactly "data.deg.contracts.p2p_trading" — the network's single
#      settlement policy entrypoint. Blocks payloads that point the enforcer at
#      an arbitrary rego rule.
#
# ── catalog publish validation (when message.catalogs exists) ──
#
# PUB1. Policy pin: each offer's offerAttributes.contractAttributes.policy.queryPath
#       must be exactly "data.deg.contracts.p2p_trading" (same rule as N17).
#       (DISCOM/meter identity at publish is covered by the network rules below,
#       which read the offer provider too.)
#
# ── performance validation (fires only on final-settlement on_status, i.e.
#    when FINAL_ALLOC is present in commitmentAttributes) ──
#
# P1.  payloadTypes declared: BUYER_DISCOM_ALLOC, SELLER_DISCOM_ALLOC, FINAL_ALLOC.
# P2.  Performance qty units: all three types must carry units: KWH.
# P3.  Interval coverage: FINAL_ALLOC interval ids must be a subset of
#      REQUESTED_QTY interval ids.
# P4.  Settlement consistency: FINAL_ALLOC ≤ min(BUYER_DISCOM_ALLOC,
#      SELLER_DISCOM_ALLOC) per interval.
#
# ── network-gated DISCOM / meter identity rules ──
#
# Applies to every discom id (buyerDiscom/sellerDiscom role ids) and every
# meterId declared in the message (contract + publish).
#
# PROD1. Production DISCOM allowlist: on the production network every discom id
#        must be an approved DISCOM (data.config.allowedDiscomIds or built-in
#        default UPADHI short codes).
# PROD2. Production meters: no meterId may start with "TEST_".
# TEST1. Test meters: on a test network every meterId must start with "TEST_".
#        DISCOM ids are unconstrained by this policy on test networks — the
#        ledger separates test from production by networkId, and the per-network
#        contract policy governs which discoms may transact.
#
# Config:
#   data.config.allowedDiscomIds      — set of approved DISCOM ids (UPADHI codes)
#   data.config.minDeliveryLeadHours  — not enforced here (interval-based
#                                       windows; enforce via catalog policy)

package deg.policy.p2p_trading_network

import rego.v1

# ---------------------------------------------------------------------------
# Config with defaults
# ---------------------------------------------------------------------------

# Approved DISCOM identifiers — the discom participant `id`, which is the CEA
# UPADHI short code. https://upadhi.cea.gov.in/assets/documents/List%20of%20Abbreviations_10%20March'25_UPADHI.pdf
_allowed_discom_ids := {"PaVVNL", "TPDDL", "BRPL"} if {
	not data.config.allowedDiscomIds
} else := data.config.allowedDiscomIds

# The recognized P2P trading networks. context.networkId must be exactly one of
# these; the ledger separates test from production trades by networkId. Test
# networks carry TEST_ meter placeholders; the production network carries real
# meters and only approved DISCOM identities.
_test_networks := {"indiaenergystack.in/test-ies-p2p-trading-network", "nfh.global/testnet-deg"}

_prod_network := "indiaenergystack.in/ies-p2p-trading-network"

_valid_networks := _test_networks | {_prod_network}

_is_test if input.context.networkId in _test_networks

_is_prod if input.context.networkId == _prod_network

# The one settlement-policy entrypoint the network pins for DEGContract.policy.
_required_query_path := "data.deg.contracts.p2p_trading"

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

# NET1 — Network membership: context.networkId must be exactly the test or the
# production P2P trading network. No other network names are accepted.
_common_violations contains msg if {
	nid := object.get(input.context, "networkId", "")
	not nid in _valid_networks
	msg := sprintf("context.networkId %q is not a recognized P2P trading network; must be one of %v", [nid, _valid_networks])
}

# ---------------------------------------------------------------------------
# Contract helpers
# ---------------------------------------------------------------------------

_contract := input.message.contract

_commitment := _contract.commitments[0]

_commit_ts := _commitment.commitmentAttributes

_commit_ts_types := _ts_types(_commit_ts) if {
	is_object(_commit_ts)
}

_bid_interval_ids := {i.id | some i in _commit_ts.intervals; some p in i.payloads; p.type == "REQUESTED_QTY"}

_perf_interval_ids := {i.id | some i in _commit_ts.intervals; some p in i.payloads; p.type == "FINAL_ALLOC"}

# participants[] are role-less (keyed by `id`); the role -> participantId map
# lives in contractAttributes.roles. Resolve a role to its participant via that
# join (role -> roles[].participantId -> participants[].id).
_role_id(role) := pid if {
	some r in _contract.contractAttributes.roles
	r.role == role
	pid := r.participantId
}

_participant_by_role(role) := p if {
	some p in _contract.participants
	p.id == _role_id(role)
}

_seller_p := _participant_by_role("sellerPlatform")

_buyer_p := _participant_by_role("buyerPlatform")

# ---------------------------------------------------------------------------
# N1 — Required roles present + no unknown role values
# ---------------------------------------------------------------------------

_allowed_roles := {"buyerPlatform", "sellerPlatform", "buyerDiscom", "sellerDiscom"}

_contract_violations contains msg if {
	roles_present := {r.role | some r in _contract.contractAttributes.roles}
	missing := _allowed_roles - roles_present
	count(missing) > 0
	msg := sprintf("missing required role(s) in contractAttributes.roles: %v", [missing])
}

_contract_violations contains msg if {
	some r in _contract.contractAttributes.roles
	not r.role in _allowed_roles
	msg := sprintf("unknown role %q in contractAttributes.roles; allowed: %v", [r.role, _allowed_roles])
}

# ---------------------------------------------------------------------------
# N3 — Inter-discom: buyer and seller must be on different DISCOMs. The discom
# is a first-class role now, so this is a direct comparison of the two discom
# role ids (each is a UPADHI short code).
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	b := _role_id("buyerDiscom")
	s := _role_id("sellerDiscom")
	is_string(b)
	is_string(s)
	b == s
	msg := sprintf(
		"buyerDiscom and sellerDiscom are the same (%q); inter-discom trade requires different DISCOMs",
		[s],
	)
}

# ---------------------------------------------------------------------------
# N4 — commitmentAttributes with interval data must be @type: TimeSeries
# ---------------------------------------------------------------------------

_contract_violations contains "commitmentAttributes must have @type: TimeSeries" if {
	ca := _commitment.commitmentAttributes
	is_object(ca)
	ca.intervals # only enforce when timeseries interval data is present
	ca["@type"] != "TimeSeries"
}

# ---------------------------------------------------------------------------
# N5-N7 — Offer-side payloadType and unit validation
# ---------------------------------------------------------------------------

# N5a — PRICE_PER_KWH must be declared when interval data is present
_contract_violations contains "commitmentAttributes payloadDescriptors must include PRICE_PER_KWH" if {
	is_object(_commit_ts)
	count(_commit_ts.intervals) > 0
	not "PRICE_PER_KWH" in _commit_ts_types
}

# N5b — init messages must include AVAILABLE_QTY (buyer echoes offer capacity alongside bid)
_contract_violations contains "commitmentAttributes payloadDescriptors must include AVAILABLE_QTY in init messages" if {
	is_object(_commit_ts)
	input.context.action == "init"
	not "AVAILABLE_QTY" in _commit_ts_types
}

# N6 — PRICE_PER_KWH currency must be INR
_contract_violations contains msg if {
	is_object(_commit_ts)
	"PRICE_PER_KWH" in _commit_ts_types
	c := _ts_currency(_commit_ts, "PRICE_PER_KWH")
	c != "INR"
	msg := sprintf("commitmentAttributes PRICE_PER_KWH currency is %q; must be INR", [c])
}

# N7 — AVAILABLE_QTY units must be KWH when declared (required at init, optional afterwards)
_contract_violations contains msg if {
	is_object(_commit_ts)
	"AVAILABLE_QTY" in _commit_ts_types
	u := _ts_units(_commit_ts, "AVAILABLE_QTY")
	u != "KWH"
	msg := sprintf("commitmentAttributes AVAILABLE_QTY units is %q; must be KWH", [u])
}

# ---------------------------------------------------------------------------
# N8-N9 — commitmentAttributes bid-side payloadType and unit validation
#          (only when buyer bid intervals are present)
# ---------------------------------------------------------------------------

_contract_violations contains "commitmentAttributes payloadDescriptors must include REQUESTED_QTY" if {
	is_object(_commit_ts)
	count(_bid_interval_ids) > 0
	not "REQUESTED_QTY" in _commit_ts_types
}

_contract_violations contains msg if {
	is_object(_commit_ts)
	"REQUESTED_QTY" in _commit_ts_types
	u := _ts_units(_commit_ts, "REQUESTED_QTY")
	u != "KWH"
	msg := sprintf("commitmentAttributes REQUESTED_QTY units is %q; must be KWH", [u])
}

# ---------------------------------------------------------------------------
# N12 — No self-trade: buyer and seller meter ids must differ
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
# N13 — Seller source type must be a generation source, not GRID
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	st := _commitment.resources[0].resourceAttributes.sourceType
	st == "GRID"
	msg := "seller sourceType is GRID; must be a generation source (SOLAR, BATTERY, HYBRID, RENEWABLE)"
}

# ---------------------------------------------------------------------------
# N14 — offer.offerAttributes must be absent in contract messages
# ---------------------------------------------------------------------------

_contract_violations contains "offer.offerAttributes must be absent in contract messages; all data must be in Commitment.commitmentAttributes" if {
	_commitment.offer.offerAttributes
}

# ---------------------------------------------------------------------------
# N15 — Beckn semantic alignment: bppId and bapId in context must match a
# participantId declared in contract.participants[]. This catches cascade
# legs (e.g. seller→sellerDiscom on_confirm forwarding) that rewrite bppUri/
# bapUri but forget to also rewrite the corresponding bppId/bapId, which
# would leave context referring to the original trade-leg parties while the
# transport now targets a new pair.
# ---------------------------------------------------------------------------

# The set of ids that may legitimately appear as context.bppId/bapId: every
# participant `id`, plus each discom participant's `subscriberId` (its beckn
# platform id) and `ledgerId` (its ledger TSP's id — the receiver/caller id on
# the ledger cascade legs the recorder produces). A discom's `id` is its UPADHI
# short code, so the beckn ids used on the wire live in its attributes.
_participant_ids contains id if {
	some p in _contract.participants
	id := p.id
}

_participant_ids contains sid if {
	some p in _contract.participants
	some key in ["subscriberId", "ledgerId"]
	sid := object.get(p.participantAttributes, key, "")
	sid != ""
}

# N15 only applies when the contract carries a participants list. Discom-internal
# meter-data messages (e.g. buyerDiscom → buyerDiscom-ledger) omit participants
# and use domain-local bppId values that are not trade participants.
_contract_violations contains msg if {
	count(_participant_ids) > 0
	bpp_id := object.get(input.context, "bppId", "")
	bpp_id != ""
	not bpp_id in _participant_ids
	msg := sprintf(
		"context.bppId %q does not match any participantId in contract.participants %v",
		[bpp_id, _participant_ids],
	)
}

_contract_violations contains msg if {
	count(_participant_ids) > 0
	bap_id := object.get(input.context, "bapId", "")
	bap_id != ""
	not bap_id in _participant_ids
	msg := sprintf(
		"context.bapId %q does not match any participantId in contract.participants %v",
		[bap_id, _participant_ids],
	)
}

# ---------------------------------------------------------------------------
# N16 — BecknTimeSeries type-coverage: every payloadType used in
#        commitmentAttributes.intervals must be declared in payloadDescriptors.
#        Catches typos and undocumented signal names on the wire.
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	is_object(_commit_ts)
	is_array(_commit_ts.intervals)
	declared_types := {d.payloadType | some d in _commit_ts.payloadDescriptors}
	some interval in _commit_ts.intervals
	some payload in interval.payloads
	not payload.type in declared_types
	msg := sprintf(
		"commitmentAttributes interval %v: payload type %q used in intervals but not declared in payloadDescriptors",
		[interval.id, payload.type],
	)
}

# ---------------------------------------------------------------------------
# N17 — Policy pin: when contractAttributes.policy is present, its queryPath
#        must be exactly the network's settlement policy entrypoint.
# ---------------------------------------------------------------------------

_contract_violations contains msg if {
	pol := _contract.contractAttributes.policy
	is_object(pol)
	qp := object.get(pol, "queryPath", "")
	qp != _required_query_path
	msg := sprintf(
		"contractAttributes.policy.queryPath is %q; must be exactly %q",
		[qp, _required_query_path],
	)
}

# ---------------------------------------------------------------------------
# Performance validation (fires only when FINAL_ALLOC is present, signalling
# a final-settlement report; partial single-discom reports are exempt).
# ---------------------------------------------------------------------------

_performance_violations contains "commitmentAttributes payloadDescriptors must include BUYER_DISCOM_ALLOC" if {
	is_object(_commit_ts)
	count(_perf_interval_ids) > 0
	not "BUYER_DISCOM_ALLOC" in _commit_ts_types
}

_performance_violations contains "commitmentAttributes payloadDescriptors must include SELLER_DISCOM_ALLOC" if {
	is_object(_commit_ts)
	count(_perf_interval_ids) > 0
	not "SELLER_DISCOM_ALLOC" in _commit_ts_types
}

_performance_violations contains msg if {
	is_object(_commit_ts)
	some ptype in {"BUYER_DISCOM_ALLOC", "SELLER_DISCOM_ALLOC", "FINAL_ALLOC"}
	ptype in _commit_ts_types
	u := _ts_units(_commit_ts, ptype)
	u != "KWH"
	msg := sprintf("commitmentAttributes %v units is %q; must be KWH", [ptype, u])
}

_performance_violations contains msg if {
	is_object(_commit_ts)
	count(_perf_interval_ids) > 0
	count(_bid_interval_ids) > 0
	extra := _perf_interval_ids - _bid_interval_ids
	count(extra) > 0
	msg := sprintf(
		"commitmentAttributes FINAL_ALLOC interval ids %v not present in REQUESTED_QTY interval ids %v",
		[extra, _bid_interval_ids],
	)
}

_performance_violations contains msg if {
	is_object(_commit_ts)
	some interval in _commit_ts.intervals
	interval.id in _perf_interval_ids
	final_alloc := _payload_val(interval, "FINAL_ALLOC")
	buyer_alloc := _payload_val(interval, "BUYER_DISCOM_ALLOC")
	seller_alloc := _payload_val(interval, "SELLER_DISCOM_ALLOC")
	min_alloc := min({buyer_alloc, seller_alloc})
	final_alloc > min_alloc
	msg := sprintf(
		"commitmentAttributes interval %v: FINAL_ALLOC %v > min(BUYER_DISCOM_ALLOC %v, SELLER_DISCOM_ALLOC %v)",
		[interval.id, final_alloc, buyer_alloc, seller_alloc],
	)
}

# ---------------------------------------------------------------------------
# Catalog offer + identity collectors
# ---------------------------------------------------------------------------

_catalog_offers contains offer if {
	some cat in input.message.catalogs
	some offer in cat.offers
}

# Every DISCOM id (the buyerDiscom/sellerDiscom role's participantId, a UPADHI
# short code) declared anywhere — contract roles at select/init/… and the
# offer's roles at publish. Null (unbound buyer side at publish) is skipped.
_discom_ids contains id if {
	some r in _contract.contractAttributes.roles
	r.role in {"buyerDiscom", "sellerDiscom"}
	id := r.participantId
	is_string(id)
}

_discom_ids contains id if {
	some offer in _catalog_offers
	some r in offer.offerAttributes.contractAttributes.roles
	r.role in {"buyerDiscom", "sellerDiscom"}
	id := r.participantId
	is_string(id)
}

# Every participant that appears anywhere — contract participants at trade time
# and the offer's seller-side participants at publish.
_all_participants contains p if {
	some p in _contract.participants
}

_all_participants contains p if {
	some offer in _catalog_offers
	some p in object.get(offer.offerAttributes, "participants", [])
}

# Every meterId that appears anywhere in the message (platform participants +
# the catalog provider block). Discom participants carry no meterId.
_all_meter_ids contains mid if {
	some p in _all_participants
	mid := object.get(p.participantAttributes, "meterId", "")
	mid != ""
}

_all_meter_ids contains mid if {
	some offer in _catalog_offers
	mid := object.get(object.get(offer.provider, "providerAttributes", {}), "meterId", "")
	mid != ""
}

# ---------------------------------------------------------------------------
# Production-network identity rules (context.networkId == _prod_network)
# ---------------------------------------------------------------------------

# PROD1 — DISCOM allowlist: on the production network every discom id must be an
# approved DISCOM (a UPADHI short code on the list).
_prod_violations contains msg if {
	_is_prod
	some id in _discom_ids
	not id in _allowed_discom_ids
	msg := sprintf(
		"production network: discom id %q is not an approved DISCOM; must be one of %v",
		[id, _allowed_discom_ids],
	)
}

# PROD2 — No TEST_ meters in production.
_prod_violations contains msg if {
	_is_prod
	some mid in _all_meter_ids
	startswith(mid, "TEST_")
	msg := sprintf("production network: meterId %q must not use a TEST_ prefix", [mid])
}

# ---------------------------------------------------------------------------
# Test-network identity rules (context.networkId == _test_network)
# ---------------------------------------------------------------------------

# TEST1 — Meters must be TEST_ placeholders on the test network. (DISCOM names may
# be real — the ledger separates test trades by networkId.)
_test_violations contains msg if {
	_is_test
	some mid in _all_meter_ids
	not startswith(mid, "TEST_")
	msg := sprintf("test network: meterId %q must start with TEST_", [mid])
}

# ---------------------------------------------------------------------------
# Catalog publish rules (when message.catalogs exists)
# ---------------------------------------------------------------------------

# PUB1 — Policy pin: offer contractAttributes.policy.queryPath must be exact.
_publish_violations contains msg if {
	some offer in _catalog_offers
	ca := offer.offerAttributes.contractAttributes
	is_object(ca)
	qp := object.get(object.get(ca, "policy", {}), "queryPath", "")
	qp != _required_query_path
	msg := sprintf(
		"catalog offer %q: contractAttributes.policy.queryPath is %q; must be exactly %q",
		[object.get(offer, "id", ""), qp, _required_query_path],
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
	"BUYER_DISCOM_ALLOC" in _commit_ts_types
	some msg in _performance_violations
}

violations contains msg if {
	some msg in _prod_violations
}

violations contains msg if {
	some msg in _test_violations
}

violations contains msg if {
	input.message.catalogs
	some msg in _publish_violations
}
