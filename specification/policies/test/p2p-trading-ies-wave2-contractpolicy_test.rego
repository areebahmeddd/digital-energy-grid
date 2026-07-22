# Unit tests for p2p-trading-ies-wave2-contractpolicy.rego (seller-discom policy)
#
# Run:  cd specification/policies && opa test p2p-trading-ies-wave2-contractpolicy.rego test/p2p-trading-ies-wave2-contractpolicy_test.rego -v
#
# Model: participants[] are role-less (keyed by id); the role -> participantId
# map is in contractAttributes.roles. A discom's id is its UPADHI short code
# (test devkit: sellerDiscom=PaVVNL, buyerDiscom varies). Meters stay TEST_.

package deg.contracts.p2p_trading

import rego.v1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_mk_roles(seller_discom, buyer_discom) := [
	{"role": "buyerPlatform", "participantId": "buyerapp.example.com"},
	{"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
	{"role": "buyerDiscom", "participantId": buyer_discom},
	{"role": "sellerDiscom", "participantId": seller_discom},
]

# Platform participants — role-less, keyed by id; identity is meterId (no utilityId).
_platform_participants := [
	{"id": "buyerapp.example.com", "participantAttributes": {"@type": "EnergyCustomer", "meterId": "TEST_METER_BUYER_001"}},
	{"id": "sellerapp.example.com", "participantAttributes": {"@type": "EnergyCustomer", "meterId": "TEST_METER_SELLER_001"}},
]

# Pre-settlement interval: price + requested qty, no FINAL_ALLOC yet.
_iv_pre(iid, price, req) := {"id": iid, "payloads": [
	{"type": "PRICE_PER_KWH", "values": [price]},
	{"type": "REQUESTED_QTY", "values": [req]},
]}

# Settled interval: FINAL_ALLOC present.
_iv_settled(iid, price, req, alloc) := {"id": iid, "payloads": [
	{"type": "PRICE_PER_KWH", "values": [price]},
	{"type": "REQUESTED_QTY", "values": [req]},
	{"type": "FINAL_ALLOC", "values": [alloc]},
]}

_ts(intervals) := {
	"payloadDescriptors": [
		{"payloadType": "PRICE_PER_KWH", "currency": "INR"},
		{"payloadType": "REQUESTED_QTY", "units": "KWH"},
		{"payloadType": "BUYER_DISCOM_ALLOC", "units": "KWH"},
		{"payloadType": "SELLER_DISCOM_ALLOC", "units": "KWH"},
		{"payloadType": "BUYER_DISCOM_STATUS"},
		{"payloadType": "SELLER_DISCOM_STATUS"},
		{"payloadType": "FINAL_ALLOC", "units": "KWH"},
	],
	"intervals": intervals,
}

_input_on(action, network_id, seller_discom, buyer_discom, intervals) := {
	"context": {"action": action, "networkId": network_id},
	"message": {"contract": {
		"contractAttributes": {"roles": _mk_roles(seller_discom, buyer_discom)},
		"participants": _platform_participants,
		"commitments": [{"id": "commitment-p2p-001", "commitmentAttributes": _ts(intervals)}],
	}},
}

# Default test-network input: seller discom PaVVNL (applicable on test).
_input(action, buyer_discom, intervals) := _input_on(action, "nfh.global/testnet-deg", "PaVVNL", buyer_discom, intervals)

# Production-network input with an applicable seller discom (TPDDL).
_input_prod(action, buyer_discom, intervals) := _input_on(action, "indiaenergystack.in/ies-p2p-trading-network", "TPDDL", buyer_discom, intervals)

_discom_role_id(inp, role) := pid if {
	some r in inp.message.contract.contractAttributes.roles
	r.role == role
	pid := r.participantId
}

# Appends buyerDiscom + sellerDiscom participants (ids matching the roles)
# carrying the given ledgerUri.
_with_discom_ledgers(inp, url) := json.patch(inp, [{
	"op": "replace",
	"path": "/message/contract/participants",
	"value": array.concat(inp.message.contract.participants, [
		{"id": _discom_role_id(inp, "buyerDiscom"), "participantAttributes": {"@type": "DiscomLedgerProvider", "ledgerUri": url}},
		{"id": _discom_role_id(inp, "sellerDiscom"), "participantAttributes": {"@type": "DiscomLedgerProvider", "ledgerUri": url}},
	]),
}])

# ---------------------------------------------------------------------------
# Allowlist  (test env: seller PaVVNL; allowed buyer discoms {PaVVNL, BRPL})
# ---------------------------------------------------------------------------

test_allowlisted_buyer_no_violations_at_init if {
	count(violations) == 0 with input as _input("init", "BRPL", [_iv_pre(0, 12.5, 20)])
}

test_intra_discom_trade_allowed if {
	count(violations) == 0 with input as _input("init", "PaVVNL", [_iv_pre(0, 12.5, 20)])
}

# Test env additionally allows the TEST_* placeholder discoms.
test_test_placeholder_buyer_discom_allowed_on_test if {
	count(violations) == 0 with input as _input("init", "TEST_BUYER_DISCOM", [_iv_pre(0, 12.5, 20)])
}

test_test_placeholder_seller_discom_applicable_on_test if {
	inp := _input_on("init", "nfh.global/testnet-deg", "TEST_SELLER_DISCOM", "BRPL", [_iv_pre(0, 12.5, 20)])
	count(violations) == 0 with input as inp
}

# But the TEST_* placeholders are NOT in the production allowlist.
test_test_placeholder_discom_blocked_on_prod if {
	inp := _input_prod("init", "TEST_BUYER_DISCOM", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	count(vs) == 1
	some msg in vs
	contains(msg, "on the production network")
}

test_blocked_buyer_discom_violation_at_init if {
	vs := violations with input as _input("init", "TEST_OUTSIDE_DISCOM", [_iv_pre(0, 12.5, 20)])
	count(vs) == 1
	some msg in vs
	contains(msg, "TEST_OUTSIDE_DISCOM")
	contains(msg, "not allowed to trade")
}

# environments with the TEST environment's allowlist enforcement switched off.
_envs_test_allowlist_off := json.patch(environments, [{"op": "replace", "path": "/test/enforce_allowlist", "value": false}])

test_allowlist_disabled_lets_outsider_through if {
	inp := _input("init", "TEST_OUTSIDE_DISCOM", [_iv_pre(0, 12.5, 20)])
	count(violations) == 0 with input as inp with environments as _envs_test_allowlist_off
}

test_allowlist_disabled_skips_missing_buyer_discom_check if {
	# Null out the buyerDiscom role id: role present (completeness OK) but the
	# buyer discom is undeterminable. With the allowlist off, that check is skipped.
	inp := json.patch(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		[{"op": "replace", "path": "/message/contract/contractAttributes/roles/2/participantId", "value": null}],
	)
	count(violations) == 0 with input as inp with environments as _envs_test_allowlist_off
}

test_allowlist_disable_is_per_environment if {
	# Same switch state, but traffic on the PRODUCTION network: still enforced.
	# TEST_OUTSIDE_DISCOM is not an approved discom, so it stays blocked on production.
	inp := _input_prod("init", "TEST_OUTSIDE_DISCOM", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp with environments as _envs_test_allowlist_off
	count(vs) == 1
}

# ---------------------------------------------------------------------------
# Discom ledger endpoints
# ---------------------------------------------------------------------------

_canonical_ledger := "https://ies-p2p-energy-ledger.beckn.io"

test_canonical_ledger_url_ok if {
	inp := _with_discom_ledgers(_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]), _canonical_ledger)
	count(violations) == 0 with input as inp
}

test_devkit_local_ledger_url_ok_on_test_network if {
	inp := _with_discom_ledgers(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		"http://buyer-discom-ledger.example.com:9000",
	)
	count(violations) == 0 with input as inp
}

test_rogue_ledger_url_is_violation if {
	inp := _with_discom_ledgers(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		"http://rogue-ledger.example.com",
	)
	vs := violations with input as inp
	count(vs) == 2 # both discom participants flagged
	some msg in vs
	contains(msg, "not a permitted ledger endpoint")
}

test_local_ledger_url_blocked_on_prod_network if {
	inp := _with_discom_ledgers(
		_input_prod("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		"http://buyer-discom-ledger.example.com:9000",
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "not a permitted ledger endpoint on the production network")
}

test_missing_ledger_url_is_violation if {
	inp := json.patch(_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]), [{
		"op": "add",
		"path": "/message/contract/participants/-",
		"value": {"id": "BRPL", "participantAttributes": {"@type": "DiscomLedgerProvider"}},
	}])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "buyerDiscom participant is missing participantAttributes.ledgerUri")
}

# ---------------------------------------------------------------------------
# Catalog publish (message.catalogs shape)
# ---------------------------------------------------------------------------

_catalog_offer(seller_discom, ccy) := {
	"id": "offer-1",
	"provider": {"id": "sellerapp.example.com"},
	"offerAttributes": {
		"contractAttributes": {
			"roles": [
				{"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
				{"role": "sellerDiscom", "participantId": seller_discom},
				{"role": "buyerPlatform", "participantId": null},
				{"role": "buyerDiscom", "participantId": null},
			],
			"policy": {
				"url": "https://api.dedi.global/dedi/lookup/indiaenergystack.in/ies-policies/x",
				"queryPath": "data.deg.contracts.p2p_trading",
			},
		},
		"commitmentAttributes": {"payloadDescriptors": [
			{"payloadType": "PRICE_PER_KWH", "currency": ccy},
			{"payloadType": "AVAILABLE_QTY", "units": "KWH"},
		]},
	},
}

_catalog_input(seller_discom, ccy) := {
	"context": {"action": "catalog/publish", "networkId": "nfh.global/testnet-deg"},
	"message": {"catalogs": [{"offers": [_catalog_offer(seller_discom, ccy)]}]},
}

# The crucial regression guard: a clean catalog must produce ZERO violations.
test_publish_clean_catalog_no_violations if {
	count(violations) == 0 with input as _catalog_input("PaVVNL", "INR")
}

test_publish_inapplicable_provider_is_violation if {
	vs := violations with input as _catalog_input("TEST_OUTSIDE_DISCOM", "INR")
	count(vs) == 1
	some msg in vs
	contains(msg, "does not apply to seller discom \"TEST_OUTSIDE_DISCOM\"")
}

test_publish_wrong_currency_is_violation if {
	vs := violations with input as _catalog_input("PaVVNL", "EUR")
	count(vs) == 1
	some msg in vs
	contains(msg, "settlement currency \"EUR\" is not permitted")
}

test_publish_offer_missing_seller_discom_is_violation if {
	inp := json.remove(
		_catalog_input("PaVVNL", "INR"),
		["/message/catalogs/0/offers/0/offerAttributes/contractAttributes/roles/1"],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "cannot verify policy applicability")
}

test_publish_unknown_network_is_violation if {
	inp := json.patch(
		_catalog_input("PaVVNL", "INR"),
		[{"op": "replace", "path": "/context/networkId", "value": "rogue.example/net"}],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "not a recognized IES P2P trading network")
}

# ---------------------------------------------------------------------------
# Policy applicability (seller discom) + settlement currency
# ---------------------------------------------------------------------------

test_policy_not_applicable_to_seller_discom if {
	inp := _input_on("init", "nfh.global/testnet-deg", "TEST_OUTSIDE_DISCOM", "BRPL", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "does not apply to seller discom \"TEST_OUTSIDE_DISCOM\"")
}

test_missing_seller_discom_is_violation if {
	inp := json.patch(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		[{"op": "replace", "path": "/message/contract/contractAttributes/roles/3/participantId", "value": null}],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "cannot determine seller discom")
}

test_non_inr_currency_is_violation if {
	inp := json.patch(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		[{
			"op": "replace",
			"path": "/message/contract/commitments/0/commitmentAttributes/payloadDescriptors/0/currency",
			"value": "EUR",
		}],
	)
	vs := violations with input as inp
	count(vs) == 1
	some msg in vs
	contains(msg, "settlement currency \"EUR\" is not permitted")
}

# ---------------------------------------------------------------------------
# Network membership + per-environment allowlists
# ---------------------------------------------------------------------------

test_unknown_network_is_violation if {
	inp := _input_on("init", "rogue.example/some-network", "PaVVNL", "BRPL", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "not a recognized IES P2P trading network")
}

test_missing_network_id_is_violation if {
	inp := json.remove(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		["/context/networkId"],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "context.networkId is missing")
}

test_prod_network_uses_prod_allowlist if {
	inp := _input_prod("init", "BRPL", [_iv_pre(0, 12.5, 20)])
	count(violations) == 0 with input as inp
}

test_outsider_blocked_on_prod_network if {
	# TEST_OUTSIDE_DISCOM is not an approved discom (the allowlist is shared test/prod).
	inp := _input_prod("init", "TEST_OUTSIDE_DISCOM", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	count(vs) == 1
	some msg in vs
	contains(msg, "on the production network")
}

test_outsider_blocked_on_test_network if {
	# TEST_OUTSIDE_DISCOM is not an approved discom; the allowlist is the same on test and prod.
	inp := _input("init", "TEST_OUTSIDE_DISCOM", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "on the test network")
}

test_missing_buyer_discom_is_violation if {
	inp := json.patch(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		[{"op": "replace", "path": "/message/contract/contractAttributes/roles/2/participantId", "value": null}],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "cannot determine buyer discom")
}

test_missing_role_violation if {
	inp := json.patch(
		_input("init", "BRPL", [_iv_pre(0, 12.5, 20)]),
		[{"op": "remove", "path": "/message/contract/contractAttributes/roles/3"}],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "missing required role \"sellerDiscom\"")
}

# ---------------------------------------------------------------------------
# Pre-settlement: no flows injected, settlement checks stay quiet
# ---------------------------------------------------------------------------

test_no_revenue_flows_before_settlement if {
	not revenue_flows with input as _input("init", "BRPL", [_iv_pre(0, 12.5, 20)])
}

test_settlement_checks_do_not_fire_at_confirm if {
	count(violations) == 0 with input as _input("confirm", "BRPL", [_iv_pre(0, 12.5, 20)])
}

# ---------------------------------------------------------------------------
# Settlement: charges, itemization, net-zero
# ---------------------------------------------------------------------------

_settled_input := _input("on_status", "BRPL", [_iv_settled(0, 12.5, 20.5, 20)])

test_charges_computed_from_rates if {
	wheeling_charge_buyer == 0 with input as _settled_input
	wheeling_charge_seller == 0 with input as _settled_input
	penalty_charge == 0 with input as _settled_input
	total_shortfall_kwh == 0.5 with input as _settled_input
}

test_revenue_flows_values if {
	flows := revenue_flows with input as _settled_input
	count(flows) == 4
	flows[0].value == -250
	flows[1].value == 250
	flows[2].value == 0
	flows[3].value == 0
}

test_net_zero_and_no_violations_when_settled if {
	net_zero_ok with input as _settled_input
	count(violations) == 0 with input as _settled_input
}

test_itemization_discloses_rates if {
	flows := revenue_flows with input as _settled_input
	contains(flows[1].description, "wheeling @ 0 INR/kWh")
	contains(flows[1].description, "platform charge cap 0.42 INR/kWh")
	contains(flows[2].description, "wheeling charge @ 0 INR/kWh")
	contains(flows[3].description, "wheeling charge @ 0 INR/kWh")
}

test_no_penalty_when_fully_delivered if {
	inp := _input("on_status", "BRPL", [_iv_settled(0, 12.5, 20, 20)])
	penalty_charge == 0 with input as inp
}

test_over_delivery_is_not_negative_penalty if {
	inp := _input("on_status", "BRPL", [_iv_settled(0, 12.5, 20, 25)])
	penalty_charge == 0 with input as inp
}

# ---------------------------------------------------------------------------
# Settlement integrity is scoped to on_status
# ---------------------------------------------------------------------------

test_no_final_alloc_violation_only_on_status if {
	inp := _input("on_status", "BRPL", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "no FINAL_ALLOC intervals")
}
