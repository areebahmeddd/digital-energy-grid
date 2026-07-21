package deg.policy.p2p_trading_network

import rego.v1

# ----------------------------------------------------------------------------
# Tests for the network-gated identity rules (NET1 membership, PROD1 DISCOM
# allowlist, PROD2 no-TEST_ meters, TEST1 TEST_ meters) and the policy queryPath
# pin (N17 / PUB1). Targets the dashed-name rego file (active runtime policy via
# opa-network-policies.yaml).
# ----------------------------------------------------------------------------

_test_net := "indiaenergystack.in/test-ies-p2p-trading-network"

_testnet_deg := "nfh.global/testnet-deg"

_prod_net := "indiaenergystack.in/ies-p2p-trading-network"

_good_query_path := "data.deg.contracts.p2p_trading"

_mk_contract(participants, query_path) := {
	"contractAttributes": {"policy": {"url": "https://example.com/p", "queryPath": query_path}},
	"participants": participants,
}

_participant(role, utility_id, meter_id) := {
	"role": role,
	"participantId": sprintf("%s.example.com", [role]),
	"participantAttributes": {"meterId": meter_id, "utilityId": utility_id},
}

_contract_payload(network, participants) := {
	"context": {"version": "2.0.0", "networkId": network, "bppId": "sellerPlatform.example.com", "bapId": "buyerPlatform.example.com"},
	"message": {"contract": _mk_contract(participants, _good_query_path)},
}

_has(pl, needle) if {
	some msg in violations with input as pl
	contains(msg, needle)
}

# ---------------------------------------------------------------------------
# NET1 — network membership
# ---------------------------------------------------------------------------

test_net1_passes_on_test_ies_network if {
	pl := _contract_payload(_test_net, [_participant("sellerPlatform", "TEST_DISCOM_SELLER", "TEST_METER_1")])
	not _has(pl, "not a recognized P2P trading network")
}

test_net1_passes_on_nfh_testnet_deg if {
	pl := _contract_payload(_testnet_deg, [_participant("sellerPlatform", "TEST_DISCOM_SELLER", "TEST_METER_1")])
	not _has(pl, "not a recognized P2P trading network")
}

test_net1_passes_on_production_network if {
	pl := _contract_payload(_prod_net, [_participant("sellerPlatform", "TPDDL", "REAL_METER_1")])
	not _has(pl, "not a recognized P2P trading network")
}

test_net1_fails_on_unknown_network if {
	pl := _contract_payload("some.other/network", [_participant("sellerPlatform", "TPDDL", "REAL_METER_1")])
	_has(pl, "not a recognized P2P trading network")
}

# ---------------------------------------------------------------------------
# PROD1 — production DISCOM allowlist
# ---------------------------------------------------------------------------

test_prod1_passes_on_allowlisted_discoms if {
	pl := _contract_payload(_prod_net, [_participant("sellerPlatform", "TPDDL", "M1"), _participant("buyerDiscom", "BRPL", "M2")])
	not _has(pl, "is not an approved DISCOM")
}

test_prod1_fails_on_unlisted_discom if {
	pl := _contract_payload(_prod_net, [_participant("sellerPlatform", "TPDDL", "M1"), _participant("buyerDiscom", "FAKE-DISCOM", "M2")])
	_has(pl, "FAKE-DISCOM")
	_has(pl, "is not an approved DISCOM")
}

test_prod1_fails_on_test_discom_name if {
	pl := _contract_payload(_prod_net, [_participant("sellerPlatform", "TEST_DISCOM_SELLER", "M1")])
	_has(pl, "is not an approved DISCOM")
}

# ---------------------------------------------------------------------------
# PROD2 — no TEST_ meters in production
# ---------------------------------------------------------------------------

test_prod2_fails_on_test_meter_in_prod if {
	pl := _contract_payload(_prod_net, [_participant("sellerPlatform", "TPDDL", "TEST_METER_1")])
	_has(pl, "must not use a TEST_ prefix")
}

test_prod2_passes_on_real_meter if {
	pl := _contract_payload(_prod_net, [_participant("sellerPlatform", "TPDDL", "REAL_METER_1")])
	not _has(pl, "must not use a TEST_ prefix")
}

# ---------------------------------------------------------------------------
# TEST1 — meters must be TEST_ on test networks; discoms unconstrained
# ---------------------------------------------------------------------------

test_test1_passes_with_test_meters if {
	pl := _contract_payload(_test_net, [_participant("sellerPlatform", "TEST_DISCOM_SELLER", "TEST_METER_1")])
	not _has(pl, "must start with TEST_")
}

test_test1_allows_real_discom_on_test if {
	# Real DISCOM name is fine on a test network (no allowlist there); meter is TEST_.
	pl := _contract_payload(_test_net, [_participant("sellerPlatform", "TPDDL", "TEST_METER_1")])
	not _has(pl, "is not an approved DISCOM")
	not _has(pl, "must start with TEST_")
}

test_test1_fails_on_real_meter_on_test if {
	pl := _contract_payload(_testnet_deg, [_participant("sellerPlatform", "TEST_DISCOM_SELLER", "REAL_METER_1")])
	_has(pl, "must start with TEST_")
}

# ---------------------------------------------------------------------------
# N17 / PUB1 — policy queryPath pin
# ---------------------------------------------------------------------------

test_n17_fails_on_wrong_query_path if {
	pl := {
		"context": {"version": "2.0.0", "networkId": _test_net},
		"message": {"contract": _mk_contract([_participant("sellerPlatform", "TEST_DISCOM_SELLER", "TEST_METER_1")], "data.deg.contracts.other")},
	}
	_has(pl, "queryPath is")
	_has(pl, "must be exactly")
}

_publish_payload(network, provider_utility_id, provider_meter_id, query_path) := {
	"context": {"version": "2.0.0", "networkId": network},
	"message": {"catalogs": [{"offers": [{
		"id": "offer-1",
		"provider": {"providerAttributes": {"utilityId": provider_utility_id, "meterId": provider_meter_id}},
		"offerAttributes": {"contractAttributes": {"policy": {"queryPath": query_path}}},
	}]}]},
}

test_pub1_fails_on_wrong_query_path if {
	pl := _publish_payload(_test_net, "TEST_DISCOM_SELLER", "TEST_METER_1", "data.deg.contracts.other")
	_has(pl, "queryPath is")
	_has(pl, "must be exactly")
}

test_publish_prod1_checks_provider_discom if {
	pl := _publish_payload(_prod_net, "FAKE-DISCOM", "REAL_METER_1", _good_query_path)
	_has(pl, "FAKE-DISCOM")
	_has(pl, "is not an approved DISCOM")
}

test_publish_test1_checks_provider_meter if {
	pl := _publish_payload(_test_net, "TPDDL", "REAL_METER_1", _good_query_path)
	_has(pl, "must start with TEST_")
}
