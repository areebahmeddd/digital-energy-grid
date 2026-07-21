package degledgerrecorder

import (
	"testing"
)

// Trimmed wave2 on_confirm body covering the fields the mapper reads.
// participants[] are role-less (keyed by id); the role -> id map is in
// contractAttributes.roles. Platform ids are subscriber ids; discom ids are
// UPADHI short codes. Discom identity carries ledgerId + ledgerUri.
const sampleWave2OnConfirm = `{
  "context": {
    "networkId": "nfh.global/testnet-deg",
    "version": "2.0.0",
    "action": "on_confirm",
    "bapId": "bap.example.com",
    "bapUri": "https://bap.example.com/beckn",
    "bppId": "bpp.example.com",
    "bppUri": "https://bpp.example.com/beckn",
    "transactionId": "txn-p2p-001",
    "messageId": "msg-on-confirm-001",
    "timestamp": "2026-04-25T10:10:05Z"
  },
  "message": {
    "contract": {
      "id": "contract-p2p-001",
      "contractAttributes": {
        "@type": "DEGContract",
        "roles": [
          {"role": "sellerPlatform", "participantId": "TPDDL-DL-seller-001"},
          {"role": "buyerPlatform", "participantId": "BRPL-DL-buyer-001"},
          {"role": "buyerDiscom", "participantId": "BRPL"},
          {"role": "sellerDiscom", "participantId": "TPDDL"}
        ]
      },
      "commitments": [
        {
          "id": "commitment-p2p-001",
          "resources": [
            {
              "id": "energy-resource-solar-001",
              "quantity": {
                "@type": "Quantity",
                "unitCode": "KWH",
                "unitQuantity": 35.0
              }
            }
          ],
          "offer": {
            "id": "offer-p2p-001",
            "offerAttributes": {
              "@type": "EnergyTradeOffer",
              "inputs": [
                {
                  "role": "sellerPlatform",
                  "inputs": {
                    "offers": [
                      {
                        "pricePerKwh": 12,
                        "deliveryWindow": {
                          "@type": "beckn:TimePeriod",
                          "schema:startTime": "2026-04-26T04:30:00Z",
                          "schema:endTime": "2026-04-26T05:30:00Z"
                        }
                      }
                    ]
                  }
                },
                {"role": "buyerPlatform", "inputs": {}}
              ]
            }
          }
        }
      ],
      "participants": [
        {
          "id": "TPDDL-DL-seller-001",
          "participantAttributes": {
            "@type": "EnergyCustomer",
            "meterId": "der://meter/seller-001",
            "utilityCustomerId": "TPDDL-CUST-S-001"
          }
        },
        {
          "id": "BRPL-DL-buyer-001",
          "participantAttributes": {
            "@type": "EnergyCustomer",
            "meterId": "der://meter/buyer-001",
            "utilityCustomerId": "BRPL-CUST-B-001"
          }
        },
        {
          "id": "BRPL",
          "participantAttributes": {
            "@type": "DiscomLedgerProvider",
            "subscriberId": "buyer-discom.example.com",
            "discomUri": "https://buyer-discom.example.com",
            "ledgerId": "buyer-discom-ledger.example.com",
            "ledgerUri": "https://ies-p2p-energy-ledger.beckn.io"
          }
        },
        {
          "id": "TPDDL",
          "participantAttributes": {
            "@type": "DiscomLedgerProvider",
            "subscriberId": "seller-discom.example.com",
            "discomUri": "https://seller-discom.example.com",
            "ledgerId": "seller-discom-ledger.example.com",
            "ledgerUri": "https://ies-p2p-energy-ledger.beckn.io"
          }
        }
      ]
    }
  }
}`

func TestParseOnConfirmWave2_ContextFields(t *testing.T) {
	p, err := ParseOnConfirmWave2([]byte(sampleWave2OnConfirm))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if p.Context.TransactionID != "txn-p2p-001" {
		t.Errorf("transactionId: got %q", p.Context.TransactionID)
	}
	if p.Context.BapID != "bap.example.com" || p.Context.BppID != "bpp.example.com" {
		t.Errorf("bapId/bppId: got %q/%q", p.Context.BapID, p.Context.BppID)
	}
	if len(p.Message.Contract.Commitments) != 1 {
		t.Errorf("commitments: got %d", len(p.Message.Contract.Commitments))
	}
}

func TestMapWave2ToLedgerRecord_AllFields(t *testing.T) {
	p, err := ParseOnConfirmWave2([]byte(sampleWave2OnConfirm))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	records, err := MapWave2ToLedgerRecords(p, "BUYER")
	if err != nil {
		t.Fatalf("map: %v", err)
	}
	if len(records) == 0 {
		t.Fatalf("expected at least one record")
	}
	rec := records[0]

	// Platform ids come from the role -> id join (participants[].id, a subscriber
	// id); discom ids are the buyerDiscom/sellerDiscom role ids (UPADHI codes);
	// meter ids come from the platform participants' meterId.
	checks := []struct{ name, got, want string }{
		{"role", rec.Role, "BUYER"},
		{"transactionId", rec.TransactionID, "txn-p2p-001"},
		{"platformIdBuyer", rec.PlatformIDBuyer, "BRPL-DL-buyer-001"},
		{"platformIdSeller", rec.PlatformIDSeller, "TPDDL-DL-seller-001"},
		{"discomIdBuyer", rec.DiscomIDBuyer, "BRPL"},
		{"discomIdSeller", rec.DiscomIDSeller, "TPDDL"},
		{"buyerId", rec.BuyerID, "der://meter/buyer-001"},
		{"sellerId", rec.SellerID, "der://meter/seller-001"},
		{"tradeTime", rec.TradeTime, "2026-04-25T10:10:05Z"},
		{"deliveryStartTime", rec.DeliveryStartTime, "2026-04-26T04:30:00Z"},
		{"deliveryEndTime", rec.DeliveryEndTime, "2026-04-26T05:30:00Z"},
	}
	for _, c := range checks {
		if c.got != c.want {
			t.Errorf("%s: got %q, want %q", c.name, c.got, c.want)
		}
	}

	if len(rec.TradeDetails) != 1 {
		t.Fatalf("tradeDetails: got %d", len(rec.TradeDetails))
	}
	td := rec.TradeDetails[0]
	if td.TradeQty != 35.0 || td.TradeUnit != "KWH" || td.TradeType != "ENERGY" {
		t.Errorf("tradeDetail: got qty=%v, unit=%q, type=%q", td.TradeQty, td.TradeUnit, td.TradeType)
	}
}

// When the role -> id join yields no platform participant (no roles map / no
// matching id), the mapper falls back to context.bapId/bppId.
func TestMapWave2ToLedgerRecord_FallsBackToContextWhenParticipantIDEmpty(t *testing.T) {
	const noParticipantIDs = `{
	  "context": {"transactionId":"t1","bapId":"bap.fallback.com","bppId":"bpp.fallback.com","timestamp":"2026-04-25T10:10:05Z"},
	  "message": {"contract": {"id":"c1","commitments":[{"id":"co1","resources":[{"quantity":{"unitCode":"KWH","unitQuantity":1}}],"offer":{"id":"o1","offerAttributes":{"inputs":[{"role":"sellerPlatform","inputs":{"offers":[{"deliveryWindow":{"schema:startTime":"2026-04-26T04:30:00Z","schema:endTime":"2026-04-26T05:30:00Z"}}]}}]}}}],"participants":[]}}
	}`
	p, err := ParseOnConfirmWave2([]byte(noParticipantIDs))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	records, err := MapWave2ToLedgerRecords(p, "BUYER")
	if err != nil {
		t.Fatalf("map: %v", err)
	}
	if records[0].PlatformIDBuyer != "bap.fallback.com" {
		t.Errorf("PlatformIDBuyer fallback: got %q", records[0].PlatformIDBuyer)
	}
	if records[0].PlatformIDSeller != "bpp.fallback.com" {
		t.Errorf("PlatformIDSeller fallback: got %q", records[0].PlatformIDSeller)
	}
}

func TestExtractWave2DiscomLedgerURL(t *testing.T) {
	p, err := ParseOnConfirmWave2([]byte(sampleWave2OnConfirm))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if got := ExtractWave2DiscomLedgerURL(p, SideBuyer); got != "https://ies-p2p-energy-ledger.beckn.io" {
		t.Errorf("buyerDiscom ledgerUri: got %q", got)
	}
	if got := ExtractWave2DiscomLedgerURL(p, SideSeller); got != "https://ies-p2p-energy-ledger.beckn.io" {
		t.Errorf("sellerDiscom ledgerUri: got %q", got)
	}
}

// Without a contractAttributes.roles map the discom cannot be resolved by the
// join, so the ledger URI is empty.
func TestExtractWave2DiscomLedgerURL_MissingReturnsEmpty(t *testing.T) {
	const noLedgerURL = `{"context":{"transactionId":"x"},"message":{"contract":{"participants":[{"id":"BRPL","participantAttributes":{}}]}}}`
	p, err := ParseOnConfirmWave2([]byte(noLedgerURL))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if got := ExtractWave2DiscomLedgerURL(p, SideBuyer); got != "" {
		t.Errorf("expected empty, got %q", got)
	}
	if got := ExtractWave2DiscomLedgerURL(p, SideSeller); got != "" {
		t.Errorf("expected empty for missing side, got %q", got)
	}
}

func TestMapWave2_NoCommitmentsErrors(t *testing.T) {
	p := &Wave2OnConfirmPayload{}
	if _, err := MapWave2ToLedgerRecords(p, "BUYER"); err == nil {
		t.Errorf("expected error for empty commitments, got nil")
	}
}
