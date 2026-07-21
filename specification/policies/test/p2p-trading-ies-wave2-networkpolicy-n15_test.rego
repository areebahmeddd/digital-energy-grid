package deg.policy.p2p_trading_network

import rego.v1

# ----------------------------------------------------------------------------
# Tests for N15: context.bppId/bapId must match a participant `id` in
# message.contract.participants[] — or a discom participant's `subscriberId`.
# Participants are role-less (keyed by id); roles carry the role -> id map.
# ----------------------------------------------------------------------------

_base_participants := [
	{"id": "sellerapp.example.com", "participantAttributes": {"@type": "EnergyCustomer", "meterId": "TEST_METER_SELLER_001"}},
	{"id": "buyerapp.example.com", "participantAttributes": {"@type": "EnergyCustomer", "meterId": "TEST_METER_BUYER_001"}},
	{"id": "PaVVNL", "participantAttributes": {"@type": "DiscomLedgerProvider", "subscriberId": "seller-discom.example.com", "discomUri": "https://seller-discom.example.com", "ledgerId": "seller-discom-ledger.example.com", "ledgerUri": "https://seller-discom-ledger.example.com"}},
	{"id": "BRPL", "participantAttributes": {"@type": "DiscomLedgerProvider", "subscriberId": "buyer-discom.example.com", "discomUri": "https://buyer-discom.example.com", "ledgerId": "buyer-discom-ledger.example.com", "ledgerUri": "https://buyer-discom-ledger.example.com"}},
]

_roles := [
	{"role": "sellerPlatform", "participantId": "sellerapp.example.com"},
	{"role": "buyerPlatform", "participantId": "buyerapp.example.com"},
	{"role": "sellerDiscom", "participantId": "PaVVNL"},
	{"role": "buyerDiscom", "participantId": "BRPL"},
]

# Minimal contract so only N15 is exercised.
_min_contract := {
	"contractAttributes": {"roles": _roles},
	"commitments": [{
		"resources": [{"resourceAttributes": {"sourceType": "SOLAR"}}],
		"offer": {},
	}],
	"participants": _base_participants,
}

# ---------------------------------------------------------------------------
# Positive cases — bppId/bapId valid against participant ids / discom subscriberIds.
# ---------------------------------------------------------------------------

test_n15_passes_when_platform_ids_match if {
	pl := {
		"context": {"version": "2.0.0", "bppId": "sellerapp.example.com", "bapId": "buyerapp.example.com"},
		"message": {"contract": _min_contract},
	}
	not _has_n15_violation(pl)
}

test_n15_passes_when_cascade_to_seller_discom_subscriberid if {
	# sellerapp -> sellerDiscom cascade: bapId becomes the discom's subscriberId.
	pl := {
		"context": {"version": "2.0.0", "bppId": "sellerapp.example.com", "bapId": "seller-discom.example.com"},
		"message": {"contract": _min_contract},
	}
	not _has_n15_violation(pl)
}

test_n15_passes_when_cascade_to_buyer_discom_subscriberid if {
	pl := {
		"context": {"version": "2.0.0", "bppId": "buyerapp.example.com", "bapId": "buyer-discom.example.com"},
		"message": {"contract": _min_contract},
	}
	not _has_n15_violation(pl)
}

# The UPADHI short code id is also accepted (it's a participant id).
test_n15_passes_when_bppid_is_discom_shortcode if {
	pl := {
		"context": {"version": "2.0.0", "bppId": "PaVVNL", "bapId": "buyerapp.example.com"},
		"message": {"contract": _min_contract},
	}
	not _has_n15_violation(pl)
}

# A discom's ledgerId is accepted (it appears as bapId/bppId on ledger cascade legs).
test_n15_passes_when_bapid_is_ledger_id if {
	pl := {
		"context": {"version": "2.0.0", "bppId": "sellerapp.example.com", "bapId": "seller-discom-ledger.example.com"},
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
