# Unit tests for p2p_trading_ies_wave2_revenue.rego (seller-discom policy)
#
# Run:  cd specification/policies && opa test p2p_trading_ies_wave2_revenue.rego p2p_trading_ies_wave2_revenue_test.rego -v

package deg.contracts.p2p_trading

import rego.v1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_all_roles := [
	{"role": "buyerPlatform", "participantId": "buyerapp.example.com"},
	{"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
	{"role": "buyerDiscom", "participantId": "buyer-discom-ledger.example.com"},
	{"role": "sellerDiscom", "participantId": "seller-discom-ledger.example.com"},
]

_participants_full(seller_utility, buyer_utility) := [
	{"role": "buyerPlatform", "participantAttributes": {"utilityId": buyer_utility}},
	{"role": "sellerPlatform", "participantAttributes": {"utilityId": seller_utility}},
]

_participants(buyer_utility) := _participants_full("TEST_DISCOM_SELLER", buyer_utility)

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

_input_on(action, network_id, buyer_utility, intervals) := {
	"context": {"action": action, "networkId": network_id},
	"message": {"contract": {
		"contractAttributes": {"roles": _all_roles},
		"participants": _participants(buyer_utility),
		"commitments": [{"id": "commitment-p2p-001", "commitmentAttributes": _ts(intervals)}],
	}},
}

# Default test-network input.
_input(action, buyer_utility, intervals) := _input_on(action, "nfh.global/testnet-deg", buyer_utility, intervals)

# Production-network input with an applicable seller discom (TPDDL).
_input_prod(action, buyer_utility, intervals) := json.patch(
	_input_on(action, "indiaenergystack.in/ies-p2p-trading-network", buyer_utility, intervals),
	[{
		"op": "replace",
		"path": "/message/contract/participants",
		"value": _participants_full("TPDDL", buyer_utility),
	}],
)

# ---------------------------------------------------------------------------
# Allowlist
# ---------------------------------------------------------------------------

test_allowlisted_buyer_no_violations_at_init if {
	count(violations) == 0 with input as _input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)])
}

test_intra_discom_trade_allowed if {
	count(violations) == 0 with input as _input("init", "TEST_DISCOM_SELLER", [_iv_pre(0, 12.5, 20)])
}

test_blocked_buyer_discom_violation_at_init if {
	vs := violations with input as _input("init", "TEST_DISCOM_OUTSIDER", [_iv_pre(0, 12.5, 20)])
	count(vs) == 1
	some msg in vs
	contains(msg, "TEST_DISCOM_OUTSIDER")
	contains(msg, "not allowed to trade")
}

# environments with the TEST environment's allowlist enforcement switched off
# (production untouched — the switch is per-environment).
_envs_test_allowlist_off := json.patch(environments, [{
	"op": "replace", "path": "/test/enforce_allowlist", "value": false,
}])

test_allowlist_disabled_lets_outsider_through if {
	inp := _input("init", "TEST_DISCOM_OUTSIDER", [_iv_pre(0, 12.5, 20)])
	count(violations) == 0 with input as inp with environments as _envs_test_allowlist_off
}

test_allowlist_disabled_skips_missing_buyer_discom_check if {
	# Drop only the buyerPlatform participant (index 0) — the seller stays,
	# so the (allowlist-independent) applicability check is satisfied.
	inp := json.remove(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
		["/message/contract/participants/0"],
	)
	count(violations) == 0 with input as inp with environments as _envs_test_allowlist_off
}

test_allowlist_disable_is_per_environment if {
	# Same switch state, but traffic on the PRODUCTION network: still enforced.
	inp := _input_prod("init", "TEST_DISCOM_OUTSIDER", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp with environments as _envs_test_allowlist_off
	count(vs) == 1
}

# ---------------------------------------------------------------------------
# Discom ledger endpoints
# ---------------------------------------------------------------------------

_canonical_ledger := "https://ies-p2p-energy-ledger.beckn.io"

# Appends buyerDiscom + sellerDiscom participants carrying the given ledgerUrl.
_with_discom_ledgers(inp, url) := json.patch(inp, [{
	"op": "replace",
	"path": "/message/contract/participants",
	"value": array.concat(inp.message.contract.participants, [
		{"role": "buyerDiscom", "participantAttributes": {"utilityId": "TEST_DISCOM_BUYER", "ledgerUrl": url}},
		{"role": "sellerDiscom", "participantAttributes": {"utilityId": "TEST_DISCOM_SELLER", "ledgerUrl": url}},
	]),
}])

test_canonical_ledger_url_ok if {
	inp := _with_discom_ledgers(_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]), _canonical_ledger)
	count(violations) == 0 with input as inp
}

test_devkit_local_ledger_url_ok_on_test_network if {
	inp := _with_discom_ledgers(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
		"http://buyer-discom-ledger.example.com:9000",
	)
	count(violations) == 0 with input as inp
}

test_rogue_ledger_url_is_violation if {
	inp := _with_discom_ledgers(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
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
	inp := json.patch(_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]), [{
		"op": "replace",
		"path": "/message/contract/participants/0",
		"value": {"role": "buyerDiscom", "participantAttributes": {"utilityId": "TEST_DISCOM_BUYER"}},
	}])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "buyerDiscom participant is missing participantAttributes.ledgerUrl")
}

# ---------------------------------------------------------------------------
# Catalog publish (message.catalogs shape)
# ---------------------------------------------------------------------------

_catalog_offer(provider_utility, ccy) := {
	"id": "offer-1",
	"provider": {"providerAttributes": {"utilityId": provider_utility}},
	"offerAttributes": {
		"contractAttributes": {"policy": {
			"url": "https://api.dedi.global/dedi/lookup/indiaenergystack.in/ies-policies/x",
			"queryPath": "data.deg.contracts.p2p_trading",
		}},
		"commitmentAttributes": {"payloadDescriptors": [
			{"payloadType": "PRICE_PER_KWH", "currency": ccy},
			{"payloadType": "AVAILABLE_QTY", "units": "KWH"},
		]},
	},
}

_catalog_input(provider_utility, ccy) := {
	"context": {"action": "catalog/publish", "networkId": "nfh.global/testnet-deg"},
	"message": {"catalogs": [{"offers": [_catalog_offer(provider_utility, ccy)]}]},
}

# The crucial regression guard: a clean catalog must produce ZERO violations
# — no buyer-allowlist, roles-completeness, or ledger rules may leak into
# the catalog shape.
test_publish_clean_catalog_no_violations if {
	count(violations) == 0 with input as _catalog_input("TEST_DISCOM_SELLER", "INR")
}

test_publish_inapplicable_provider_is_violation if {
	vs := violations with input as _catalog_input("OTHER_DISCOM", "INR")
	count(vs) == 1
	some msg in vs
	contains(msg, "does not apply to seller discom \"OTHER_DISCOM\"")
}

test_publish_wrong_currency_is_violation if {
	vs := violations with input as _catalog_input("TEST_DISCOM_SELLER", "EUR")
	count(vs) == 1
	some msg in vs
	contains(msg, "settlement currency \"EUR\" is not permitted")
}

test_publish_offer_missing_provider_is_violation if {
	inp := json.remove(
		_catalog_input("TEST_DISCOM_SELLER", "INR"),
		["/message/catalogs/0/offers/0/provider"],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "cannot verify policy applicability")
}

test_publish_unknown_network_is_violation if {
	inp := json.patch(
		_catalog_input("TEST_DISCOM_SELLER", "INR"),
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
	inp := json.patch(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
		[{
			"op": "replace",
			"path": "/message/contract/participants",
			"value": _participants_full("OTHER_DISCOM", "TEST_DISCOM_BUYER"),
		}],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "does not apply to seller discom \"OTHER_DISCOM\"")
}

test_missing_seller_discom_is_violation if {
	inp := json.remove(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
		["/message/contract/participants"],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "cannot determine seller discom")
}

test_non_inr_currency_is_violation if {
	inp := json.patch(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
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
	inp := _input_on("init", "rogue.example/some-network", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "not a recognized IES P2P trading network")
}

test_missing_network_id_is_violation if {
	inp := json.remove(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
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

test_test_only_partner_blocked_on_prod_network if {
	inp := _input_prod("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	count(vs) == 1
	some msg in vs
	contains(msg, "on the production network")
}

test_prod_partner_not_in_test_allowlist_blocked_on_test_network if {
	inp := _input("init", "BRPL", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "on the test network")
}

test_missing_buyer_discom_is_violation if {
	inp := json.remove(
		_input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)]),
		["/message/contract/participants"],
	)
	vs := violations with input as inp
	some msg in vs
	contains(msg, "cannot determine buyer discom")
}

test_missing_role_violation if {
	base := _input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)])
	inp := object.union(base, {"message": {"contract": {
		"contractAttributes": {"roles": array.slice(_all_roles, 0, 3)},
		"participants": _participants("TEST_DISCOM_BUYER"),
		"commitments": base.message.contract.commitments,
	}}})
	vs := violations with input as inp
	some msg in vs
	contains(msg, "missing required role \"sellerDiscom\"")
}

# ---------------------------------------------------------------------------
# Pre-settlement: no flows injected, settlement checks stay quiet
# ---------------------------------------------------------------------------

test_no_revenue_flows_before_settlement if {
	not revenue_flows with input as _input("init", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)])
}

test_settlement_checks_do_not_fire_at_confirm if {
	count(violations) == 0 with input as _input("confirm", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)])
}

# ---------------------------------------------------------------------------
# Settlement: charges, itemization, net-zero
# ---------------------------------------------------------------------------

# One settled interval: 20 kWh delivered of 20.5 requested @ 12.5 INR/kWh.
#   trade value       = 250
#   wheeling buyer    = 0.0 × 20  = 0
#   wheeling seller   = 0.0 × 20  = 0
#   penalty           = 0.0 × 0.5 = 0
_settled_input := _input("on_status", "TEST_DISCOM_BUYER", [_iv_settled(0, 12.5, 20.5, 20)])

test_charges_computed_from_rates if {
	wheeling_charge_buyer == 0 with input as _settled_input
	wheeling_charge_seller == 0 with input as _settled_input
	penalty_charge == 0 with input as _settled_input
	total_shortfall_kwh == 0.5 with input as _settled_input
}

test_revenue_flows_values if {
	flows := revenue_flows with input as _settled_input
	count(flows) == 4
	flows[0].value == -250 # buyer pays 250 + 0 wheeling
	flows[1].value == 250 # seller: 250 − 0 wheeling − 0 penalty
	flows[2].value == 0 # buyer discom wheeling
	flows[3].value == 0 # seller discom wheeling + penalty
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
	inp := _input("on_status", "TEST_DISCOM_BUYER", [_iv_settled(0, 12.5, 20, 20)])
	penalty_charge == 0 with input as inp
}

test_over_delivery_is_not_negative_penalty if {
	inp := _input("on_status", "TEST_DISCOM_BUYER", [_iv_settled(0, 12.5, 20, 25)])
	penalty_charge == 0 with input as inp
}

# ---------------------------------------------------------------------------
# Settlement integrity is scoped to on_status
# ---------------------------------------------------------------------------

test_no_final_alloc_violation_only_on_status if {
	inp := _input("on_status", "TEST_DISCOM_BUYER", [_iv_pre(0, 12.5, 20)])
	vs := violations with input as inp
	some msg in vs
	contains(msg, "no FINAL_ALLOC intervals")
}
