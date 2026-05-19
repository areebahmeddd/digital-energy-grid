package deg.policy.p2p_trading_network

import rego.v1

# ----------------------------------------------------------------------------
# Tests for N15: context.bppId/bapId must match a participantId in
# message.contract.participants[]. Targets the dashed-name rego file (active
# runtime policy via opa-network-policies.yaml).
# ----------------------------------------------------------------------------

_base_participants := [
	{
		"role": "seller",
		"participantId": "sellerapp.example.com",
		"participantAttributes": {"meterId": "TEST_METER_SELLER_001", "utilityId": "TEST_DISCOM_SELLER"},
	},
	{
		"role": "buyer",
		"participantId": "buyerapp.example.com",
		"participantAttributes": {"meterId": "TEST_METER_BUYER_001", "utilityId": "TEST_DISCOM_BUYER"},
	},
	{
		"role": "buyerDiscom",
		"participantId": "buyer-discom-ledger.example.com",
		"participantAttributes": {"ledgerUri": "http://buyer-discom-ledger.example.com:9000", "utilityId": "TEST_DISCOM_BUYER"},
	},
	{
		"role": "sellerDiscom",
		"participantId": "seller-discom-ledger.example.com",
		"participantAttributes": {"ledgerUri": "http://seller-discom-ledger.example.com:9000", "utilityId": "TEST_DISCOM_SELLER"},
	},
]

# Minimal contract so the rest of the contract rules don't fire on these
# fixtures. We're only exercising N15 here.
_min_contract := {
	"contractAttributes": {"roles": [{"role": "buyer"}, {"role": "seller"}, {"role": "buyerDiscom"}, {"role": "sellerDiscom"}]},
	"commitments": [{
		"resources": [{"resourceAttributes": {"sourceType": "SOLAR"}}],
		"offer": {"offerAttributes": {"inputs": [{"role": "seller", "payload": {}}]}},
	}],
	"participants": _base_participants,
}

# ---------------------------------------------------------------------------
# Positive cases — bppId/bapId valid against participants.
# ---------------------------------------------------------------------------

test_n15_passes_when_original_trade_ids_match if {
	# Original on_confirm: bppId = seller platform, bapId = buyer platform.
	pl := {
		"context": {"version": "2.0.0", "bppId": "sellerapp.example.com", "bapId": "buyerapp.example.com"},
		"message": {"contract": _min_contract},
	}
	not _has_n15_violation(pl)
}

test_n15_passes_when_cascade_to_seller_discom if {
	# sellerapp -> sellerDiscomLedger cascade: bppId stays sellerapp, bapId becomes the ledger.
	pl := {
		"context": {"version": "2.0.0", "bppId": "sellerapp.example.com", "bapId": "seller-discom-ledger.example.com"},
		"message": {"contract": _min_contract},
	}
	not _has_n15_violation(pl)
}

test_n15_passes_when_cascade_to_buyer_discom if {
	# buyerapp -> buyerDiscomLedger cascade.
	pl := {
		"context": {"version": "2.0.0", "bppId": "buyerapp.example.com", "bapId": "buyer-discom-ledger.example.com"},
		"message": {"contract": _min_contract},
	}
	not _has_n15_violation(pl)
}

# ---------------------------------------------------------------------------
# Negative cases — should produce an N15 violation.
# ---------------------------------------------------------------------------

test_n15_fails_when_bppid_not_in_participants if {
	pl := {
		"context": {"version": "2.0.0", "bppId": "stranger.example.com", "bapId": "buyerapp.example.com"},
		"message": {"contract": _min_contract},
	}
	_has_bppid_violation(pl, "stranger.example.com")
}

test_n15_fails_when_bapid_not_in_participants if {
	pl := {
		"context": {"version": "2.0.0", "bppId": "sellerapp.example.com", "bapId": "stranger.example.com"},
		"message": {"contract": _min_contract},
	}
	_has_bapid_violation(pl, "stranger.example.com")
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_has_n15_violation(pl) if {
	some msg in violations with input as pl
	startswith(msg, "context.bppId")
}

_has_n15_violation(pl) if {
	some msg in violations with input as pl
	startswith(msg, "context.bapId")
}

_has_bppid_violation(pl, id) if {
	some msg in violations with input as pl
	contains(msg, "context.bppId")
	contains(msg, id)
}

_has_bapid_violation(pl, id) if {
	some msg in violations with input as pl
	contains(msg, "context.bapId")
	contains(msg, id)
}
