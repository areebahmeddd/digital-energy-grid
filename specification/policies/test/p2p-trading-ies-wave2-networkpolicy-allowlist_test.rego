package deg.policy.p2p_trading_network

import rego.v1

# ----------------------------------------------------------------------------
# Tests for the network-gated identity rules under the roles/participants model:
# PROD1 (discom-id allowlist, keyed on the UPADHI short-code role id), PROD2
# (no TEST_ meters in prod), TEST1 (TEST_ meters on test), and the policy
# queryPath pin (N17 / PUB1).
# ----------------------------------------------------------------------------

_test_net := "indiaenergystack.in/test-ies-p2p-trading-network"

_prod_net := "indiaenergystack.in/ies-p2p-trading-network"

_good_qp := "data.deg.contracts.p2p_trading"

_mk_roles(seller_discom, buyer_discom) := [
	{"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
	{"role": "buyerPlatform", "participantId": "buyerapp.example.com"},
	{"role": "sellerDiscom", "participantId": seller_discom},
	{"role": "buyerDiscom", "participantId": buyer_discom},
]

_mk_participants(seller_meter, buyer_meter) := [
	{"id": "sellerapp.example.com", "participantAttributes": {"@type": "EnergyCustomer", "meterId": seller_meter}},
	{"id": "buyerapp.example.com", "participantAttributes": {"@type": "EnergyCustomer", "meterId": buyer_meter}},
]

_contract_payload(net, seller_discom, buyer_discom, seller_meter, buyer_meter, qp) := {
	"context": {"version": "2.0.0", "networkId": net},
	"message": {"contract": {
		"contractAttributes": {"roles": _mk_roles(seller_discom, buyer_discom), "policy": {"queryPath": qp}},
		"participants": _mk_participants(seller_meter, buyer_meter),
	}},
}

_has(pl, needle) if {
	some msg in violations with input as pl
	contains(msg, needle)
}

# ---------------------------------------------------------------------------
# PROD1 — production discom-id allowlist
# ---------------------------------------------------------------------------

test_prod1_passes_on_allowlisted_discoms if {
	pl := _contract_payload(_prod_net, "TPDDL", "BRPL", "M-S", "M-B", _good_qp)
	not _has(pl, "is not an approved DISCOM")
}

test_prod1_fails_on_unlisted_discom if {
	pl := _contract_payload(_prod_net, "TPDDL", "FAKE-DISCOM", "M-S", "M-B", _good_qp)
	_has(pl, "FAKE-DISCOM")
	_has(pl, "is not an approved DISCOM")
}

test_prod1_not_enforced_on_test_network if {
	pl := _contract_payload(_test_net, "FAKE-DISCOM", "BRPL", "TEST_M-S", "TEST_M-B", _good_qp)
	not _has(pl, "is not an approved DISCOM")
}

# ---------------------------------------------------------------------------
# PROD2 / TEST1 — meter TEST_ prefix by network
# ---------------------------------------------------------------------------

test_prod2_fails_on_test_meter_in_prod if {
	pl := _contract_payload(_prod_net, "TPDDL", "BRPL", "TEST_M-S", "M-B", _good_qp)
	_has(pl, "must not use a TEST_ prefix")
}

test_prod2_passes_on_real_meters if {
	pl := _contract_payload(_prod_net, "TPDDL", "BRPL", "M-S", "M-B", _good_qp)
	not _has(pl, "must not use a TEST_ prefix")
}

test_test1_passes_with_test_meters if {
	pl := _contract_payload(_test_net, "PaVVNL", "BRPL", "TEST_M-S", "TEST_M-B", _good_qp)
	not _has(pl, "must start with TEST_")
}

test_test1_fails_on_real_meter_on_test if {
	pl := _contract_payload("nfh.global/testnet-deg", "PaVVNL", "BRPL", "REAL_M-S", "TEST_M-B", _good_qp)
	_has(pl, "must start with TEST_")
}

# ---------------------------------------------------------------------------
# N17 — policy queryPath pin
# ---------------------------------------------------------------------------

test_n17_fails_on_wrong_query_path if {
	pl := _contract_payload(_test_net, "PaVVNL", "BRPL", "TEST_M-S", "TEST_M-B", "data.deg.contracts.other")
	_has(pl, "queryPath is")
	_has(pl, "must be exactly")
}

# ---------------------------------------------------------------------------
# PUB1 + publish-time discom/meter checks
# ---------------------------------------------------------------------------

_publish_payload(net, seller_discom, provider_meter, qp) := {
	"context": {"version": "2.0.0", "networkId": net},
	"message": {"catalogs": [{"offers": [{
		"id": "offer-1",
		"provider": {"providerAttributes": {"@type": "EnergyCustomer", "meterId": provider_meter}},
		"offerAttributes": {
			"contractAttributes": {
				"roles": [
					{"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
					{"role": "sellerDiscom", "participantId": seller_discom},
					{"role": "buyerPlatform", "participantId": null},
					{"role": "buyerDiscom", "participantId": null},
				],
				"policy": {"queryPath": qp},
			},
			"participants": [{"id": "sellerapp.example.com", "participantAttributes": {"@type": "EnergyCustomer", "meterId": provider_meter}}],
		},
	}]}]},
}

test_publish_prod1_checks_discom_id if {
	pl := _publish_payload(_prod_net, "FAKE-DISCOM", "M-S", _good_qp)
	_has(pl, "FAKE-DISCOM")
	_has(pl, "is not an approved DISCOM")
}

test_publish_test1_checks_provider_meter if {
	pl := _publish_payload(_test_net, "PaVVNL", "REAL_M-S", _good_qp)
	_has(pl, "must start with TEST_")
}

test_publish_pub1_fails_on_wrong_query_path if {
	pl := _publish_payload(_test_net, "PaVVNL", "TEST_M-S", "data.deg.contracts.other")
	_has(pl, "queryPath is")
	_has(pl, "must be exactly")
}
