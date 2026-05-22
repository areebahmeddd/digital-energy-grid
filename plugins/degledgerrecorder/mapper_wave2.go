package degledgerrecorder

import (
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"strings"
)

// Side identifies which discom's ledgerUri to read from the payload.
type Side string

const (
	SideBuyer  Side = "buyerDiscom"
	SideSeller Side = "sellerDiscom"
)

// Wave2OnConfirmPayload is the wave2 (P2PTrade/v2.0) on_confirm body.
// Wave2 uses camelCase context keys and a `message.contract.commitments` shape.
// Beckn 2.0 envelope: optional top-level `error` set on NACK responses (the
// sync ack/nack envelope is a different message, never carried in callback
// bodies — Beckn 2.0 LTS schema marks `message` with additionalProperties:false
// so an `ack` field would be rejected by validateSchema before the recorder
// runs). Contract MAY carry a `status.code` indicating contract lifecycle
// (ACTIVE / CANCELLED / …). ShouldSkipCascade reads both to decide whether
// the recorder should write this trade to the discom ledger.
type Wave2OnConfirmPayload struct {
	Context Wave2Context     `json:"context"`
	Message Wave2Message     `json:"message"`
	Error   *Wave2ErrorBlock `json:"error,omitempty"`
}

// Wave2Message wraps the contract payload. Beckn 2.0 has `additionalProperties:false`
// here, so we don't add anything beyond what the spec allows.
type Wave2Message struct {
	Contract Wave2Contract `json:"contract"`
}

// Wave2ErrorBlock is the Beckn 2.0 envelope-level error block. Presence
// (with a non-empty code) means the message is an error response.
type Wave2ErrorBlock struct {
	Code    string `json:"code,omitempty"`
	Message string `json:"message,omitempty"`
	Path    string `json:"path,omitempty"`
}

// Wave2ContractStatus captures the contract-level status code emitted on
// happy-path messages (ACTIVE) and on terminal-failure states the BPP
// echoes back on the same channel (CANCELLED / REJECTED / EXPIRED / FAILED).
type Wave2ContractStatus struct {
	Code string `json:"code,omitempty"`
}

// Wave2Context — wave2 uses camelCase (bapId, bppId, transactionId), not snake_case.
type Wave2Context struct {
	NetworkID     string `json:"networkId"`
	Version       string `json:"version"`
	Action        string `json:"action"`
	BapID         string `json:"bapId"`
	BapURI        string `json:"bapUri"`
	BppID         string `json:"bppId"`
	BppURI        string `json:"bppUri"`
	TransactionID string `json:"transactionId"`
	MessageID     string `json:"messageId"`
	Timestamp     string `json:"timestamp"`
}

// Wave2Contract is `message.contract`.
type Wave2Contract struct {
	ID                 string                 `json:"id"`
	Status             Wave2ContractStatus    `json:"status"`
	Commitments        []Wave2Commitment      `json:"commitments"`
	Performance        []Wave2Performance     `json:"performance"`
	Participants       []Wave2Participant     `json:"participants"`
	ContractAttributes map[string]interface{} `json:"contractAttributes"`
}

// Wave2Performance is `message.contract.performance[*]`.
type Wave2Performance struct {
	ID                    string                 `json:"id"`
	CommitmentIDs         []string               `json:"commitmentIds"`
	PerformanceAttributes map[string]interface{} `json:"performanceAttributes"`
}

// Wave2Commitment is `message.contract.commitments[*]`.
type Wave2Commitment struct {
	ID                   string                 `json:"id"`
	Resources            []Wave2Resource        `json:"resources"`
	Offer                Wave2Offer             `json:"offer"`
	CommitmentAttributes map[string]interface{} `json:"commitmentAttributes"`
}

// Wave2Resource is `commitments[*].resources[*]`.
type Wave2Resource struct {
	ID       string        `json:"id"`
	Quantity Wave2Quantity `json:"quantity"`
}

// Wave2Quantity captures unitCode + unitQuantity (kWh, kW, etc.).
type Wave2Quantity struct {
	UnitCode     string  `json:"unitCode"`
	UnitQuantity float64 `json:"unitQuantity"`
}

// Wave2Offer is `commitments[*].offer`.
type Wave2Offer struct {
	ID              string                 `json:"id"`
	ResourceIDs     []string               `json:"resourceIds"`
	OfferAttributes map[string]interface{} `json:"offerAttributes"`
}

// Wave2Participant is `contract.participants[*]`. participantAttributes is
// loose-typed because its shape varies by role: EnergyCustomer for buyer/seller,
// DiscomLedgerProvider for buyerDiscom/sellerDiscom.
type Wave2Participant struct {
	Role                  string                 `json:"role"`
	ParticipantID         string                 `json:"participantId"`
	ParticipantAttributes map[string]interface{} `json:"participantAttributes"`
}

// ParseOnConfirmWave2 unmarshals a wave2 on_confirm body.
func ParseOnConfirmWave2(body []byte) (*Wave2OnConfirmPayload, error) {
	var payload Wave2OnConfirmPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse wave2 on_confirm payload: %w", err)
	}
	return &payload, nil
}

// MapWave2ToLedgerRecords builds one LedgerPutRequest per interval found in the
// first commitment's seller offerTimeseries. record_id format:
// {transactionId}_{contractId}_{intervalId}.
func MapWave2ToLedgerRecords(payload *Wave2OnConfirmPayload, role string) ([]LedgerPutRequest, error) {
	if len(payload.Message.Contract.Commitments) == 0 {
		return nil, fmt.Errorf("wave2 payload has no commitments")
	}
	commitment := payload.Message.Contract.Commitments[0]
	if len(payload.Message.Contract.Commitments) > 1 {
		log.Printf("WARNING: wave2 payload has %d commitments; using only the first (txn: %s)",
			len(payload.Message.Contract.Commitments), payload.Context.TransactionID)
	}

	buyerPart := findWave2Participant(payload.Message.Contract.Participants, "buyer")
	sellerPart := findWave2Participant(payload.Message.Contract.Participants, "seller")

	// Platform identity is trade-scoped: read from participants[role=buyer|seller].participantId
	// rather than from transport-level context.bapId/bppId. context.bapId/bppId reflect the
	// current message leg's BAP/BPP (and get rewritten on cascade), while participantId
	// stays put across the chain — this is what we want to record on the ledger as the
	// platform identities for the trade.
	platformIDBuyer := participantID(buyerPart)
	platformIDSeller := participantID(sellerPart)
	if platformIDBuyer == "" {
		log.Printf("WARNING: participants[role=buyer].participantId is empty; falling back to context.bapId (txn: %s)", payload.Context.TransactionID)
		platformIDBuyer = payload.Context.BapID
	}
	if platformIDSeller == "" {
		log.Printf("WARNING: participants[role=seller].participantId is empty; falling back to context.bppId (txn: %s)", payload.Context.TransactionID)
		platformIDSeller = payload.Context.BppID
	}

	deliveryStart, deliveryEnd := extractWave2DeliveryWindow(commitment.Offer.OfferAttributes)
	if deliveryStart == "" {
		log.Printf("WARNING: wave2 deliveryStartTime not found (txn: %s, commitment: %s)",
			payload.Context.TransactionID, commitment.ID)
	}
	if deliveryEnd == "" {
		log.Printf("WARNING: wave2 deliveryEndTime not found (txn: %s, commitment: %s)",
			payload.Context.TransactionID, commitment.ID)
	}

	tradeQty, tradeUnit := extractWave2QuantityAndUnit(commitment.Resources)
	contractID := payload.Message.Contract.ID
	intervalIDs := extractWave2IntervalIDs(commitment.Offer.OfferAttributes)

	// Always emit at least one record even if interval list is empty (id=0).
	if len(intervalIDs) == 0 {
		intervalIDs = []int{0}
	}

	records := make([]LedgerPutRequest, 0, len(intervalIDs))
	for _, intervalID := range intervalIDs {
		orderItemID := fmt.Sprintf("%s_%s_%d", payload.Context.TransactionID, contractID, intervalID)
		records = append(records, LedgerPutRequest{
			Role:              role,
			TransactionID:     payload.Context.TransactionID,
			OrderItemID:       orderItemID,
			PlatformIDBuyer:   platformIDBuyer,
			PlatformIDSeller:  platformIDSeller,
			DiscomIDBuyer:     wave2StringAttr(buyerPart, "utilityId"),
			DiscomIDSeller:    wave2StringAttr(sellerPart, "utilityId"),
			BuyerID:           wave2StringAttr(buyerPart, "meterId"),
			SellerID:          wave2StringAttr(sellerPart, "meterId"),
			TradeTime:         payload.Context.Timestamp,
			DeliveryStartTime: deliveryStart,
			DeliveryEndTime:   deliveryEnd,
			TradeDetails: []TradeDetail{
				{
					TradeQty:  tradeQty,
					TradeType: "ENERGY",
					TradeUnit: normalizeTradeUnit(tradeUnit),
				},
			},
			ClientReference: generateClientReference(payload.Context.TransactionID, orderItemID),
		})
	}
	return records, nil
}

// ExtractWave2DiscomLedgerUri returns the ledgerUri for the requested side from
// `participants[role=buyerDiscom|sellerDiscom].participantAttributes.ledgerUri`.
// Returns "" if the side is missing or has no ledgerUri.
func ExtractWave2DiscomLedgerUri(payload *Wave2OnConfirmPayload, side Side) string {
	part := findWave2Participant(payload.Message.Contract.Participants, string(side))
	return wave2StringAttr(part, "ledgerUri")
}

// findWave2Participant returns the first participant entry matching the role.
func findWave2Participant(participants []Wave2Participant, role string) *Wave2Participant {
	for i := range participants {
		if participants[i].Role == role {
			return &participants[i]
		}
	}
	return nil
}

// participantID returns p.ParticipantID or "" if p is nil. Mirrors wave2StringAttr
// for the top-level participantId field (not nested under participantAttributes).
func participantID(p *Wave2Participant) string {
	if p == nil {
		return ""
	}
	return p.ParticipantID
}

// wave2StringAttr reads a string attribute from a participant's participantAttributes.
func wave2StringAttr(p *Wave2Participant, key string) string {
	if p == nil || p.ParticipantAttributes == nil {
		return ""
	}
	if v, ok := p.ParticipantAttributes[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// extractWave2DeliveryWindow walks
// offerAttributes.inputs[role=seller].inputs.offers[0].deliveryWindow.{schema:startTime, schema:endTime}.
// Returns ("", "") if any hop is missing.
func extractWave2DeliveryWindow(offerAttrs map[string]interface{}) (string, string) {
	if offerAttrs == nil {
		return "", ""
	}
	inputs, ok := offerAttrs["inputs"].([]interface{})
	if !ok {
		return "", ""
	}
	for _, raw := range inputs {
		entry, ok := raw.(map[string]interface{})
		if !ok {
			continue
		}
		if entry["role"] != "seller" {
			continue
		}
		inner, ok := entry["inputs"].(map[string]interface{})
		if !ok {
			continue
		}
		offers, ok := inner["offers"].([]interface{})
		if !ok || len(offers) == 0 {
			continue
		}
		first, ok := offers[0].(map[string]interface{})
		if !ok {
			continue
		}
		dw, ok := first["deliveryWindow"].(map[string]interface{})
		if !ok {
			continue
		}
		start, _ := dw["schema:startTime"].(string)
		end, _ := dw["schema:endTime"].(string)
		return start, end
	}
	return "", ""
}

// extractWave2QuantityAndUnit reads the first resource's quantity. wave2 keeps
// trade qty/unit on commitment.resources[0].quantity; returns 0 / "" if missing.
func extractWave2QuantityAndUnit(resources []Wave2Resource) (float64, string) {
	if len(resources) == 0 {
		return 0, ""
	}
	q := resources[0].Quantity
	return q.UnitQuantity, q.UnitCode
}

// RewriteContextForBeckn rewrites context.bppUri/bapUri AND context.bppId/bapId
// on the raw on_confirm body so that the cascade leg is Beckn-spec-compliant —
// i.e. the (bppId, bppUri) pair identifies the *current* leg's caller (this
// platform), and (bapId, bapUri) identifies the *current* leg's receiver (the
// ledger TSP). The original trade-level platform identities live in
// message.contract.participants[role=buyer|seller].participantId and are NOT
// touched here.
//
// senderEndpointURI / ledgerEndpointURI are the FULL endpoint URLs (host base
// + Beckn role path, e.g. "<sender>/bpp/caller", "<ledger>/bap/receiver");
// they are written verbatim into bppUri/bapUri. Callers build these via
// BppCallerEndpoint / BapReceiverEndpoint so the routing URL (the URL the
// client actually POSTs to) and the URI advertised in context stay coherent.
//
// senderSubscriberID/ledgerSubscriberID are skipped if empty (left as-is).
//
// Other context fields and the message body are preserved verbatim. Handles
// both wave2 (camelCase) and wave1 (snake_case) by detecting which key
// style the original uses.
func RewriteContextForBeckn(body []byte, senderEndpointURI, ledgerEndpointURI, senderSubscriberID, ledgerSubscriberID string) ([]byte, error) {
	var raw map[string]interface{}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, fmt.Errorf("rewriteContext: parse body: %w", err)
	}
	ctxRaw, ok := raw["context"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("rewriteContext: missing or invalid context")
	}

	bppKey, bapKey, bppIDKey, bapIDKey := "bppUri", "bapUri", "bppId", "bapId"
	if _, hasCamel := ctxRaw[bppKey]; !hasCamel {
		if _, hasSnake := ctxRaw["bpp_uri"]; hasSnake {
			bppKey, bapKey, bppIDKey, bapIDKey = "bpp_uri", "bap_uri", "bpp_id", "bap_id"
		}
	}

	ctxRaw[bppKey] = senderEndpointURI
	ctxRaw[bapKey] = ledgerEndpointURI
	if senderSubscriberID != "" {
		ctxRaw[bppIDKey] = senderSubscriberID
	}
	if ledgerSubscriberID != "" {
		ctxRaw[bapIDKey] = ledgerSubscriberID
	}
	raw["context"] = ctxRaw

	return json.Marshal(raw)
}

// BapReceiverEndpoint returns "<hostBase>/bap/receiver" — the inbound endpoint
// where a ledger TSP (or any BAP-role node) receives on_confirm/on_status/
// status cascades. Idempotent against a trailing slash on hostBase.
func BapReceiverEndpoint(hostBase string) string {
	return strings.TrimRight(hostBase, "/") + "/bap/receiver"
}

// BppCallerEndpoint returns "<hostBase>/bpp/caller" — the outbound endpoint
// from which a BPP-role node initiates a cascade (e.g. a ledger pushing an
// on_status callback to a buyer/seller platform).
func BppCallerEndpoint(hostBase string) string {
	return strings.TrimRight(hostBase, "/") + "/bpp/caller"
}

// BppReceiverEndpoint returns "<hostBase>/bpp/receiver" — the inbound endpoint
// where a BPP-role node receives request actions (status, select, init, …).
// Used by the recorder when forwarding a request (e.g. status) to a ledger
// that's playing the BPP-receiver role in that sub-transaction.
func BppReceiverEndpoint(hostBase string) string {
	return strings.TrimRight(hostBase, "/") + "/bpp/receiver"
}

// DeriveSenderHostFromWave2 returns "<scheme>://<host[:port]>" extracted from
// the original payload's bapUri (BUYER role) or bppUri (SELLER role). Used as
// a fallback when SenderHost is not configured explicitly. Returns "" if the
// chosen URI is missing or unparseable.
func DeriveSenderHostFromWave2(payload *Wave2OnConfirmPayload, role string) string {
	var rawURI string
	switch role {
	case "BUYER":
		rawURI = payload.Context.BapURI
	case "SELLER":
		rawURI = payload.Context.BppURI
	default:
		return ""
	}
	return hostBase(rawURI)
}

// hostBase parses a URI and returns "<scheme>://<host[:port]>", or "" if the
// URI is missing or unparseable.
func hostBase(rawURI string) string {
	if rawURI == "" {
		return ""
	}
	u, err := url.Parse(rawURI)
	if err != nil || u.Host == "" {
		return ""
	}
	return u.Scheme + "://" + u.Host
}

// extractWave2IntervalIDs walks offerAttributes.inputs[role=seller].inputs.offerTimeseries.intervals
// and returns each interval's numeric id. Returns nil if the path is missing.
func extractWave2IntervalIDs(offerAttrs map[string]interface{}) []int {
	if offerAttrs == nil {
		return nil
	}
	inputs, ok := offerAttrs["inputs"].([]interface{})
	if !ok {
		return nil
	}
	for _, raw := range inputs {
		entry, ok := raw.(map[string]interface{})
		if !ok || entry["role"] != "seller" {
			continue
		}
		inner, ok := entry["inputs"].(map[string]interface{})
		if !ok {
			continue
		}
		ts, ok := inner["offerTimeseries"].(map[string]interface{})
		if !ok {
			continue
		}
		intervals, ok := ts["intervals"].([]interface{})
		if !ok {
			continue
		}
		ids := make([]int, 0, len(intervals))
		for _, iv := range intervals {
			m, ok := iv.(map[string]interface{})
			if !ok {
				continue
			}
			switch v := m["id"].(type) {
			case float64:
				ids = append(ids, int(v))
			case int:
				ids = append(ids, v)
			}
		}
		return ids
	}
	return nil
}

// -------------------------
// wave2 status types and parsers
// -------------------------

// Wave2StatusPayload is the wave2 `status` request body. The contract carries
// minimum id + participants (with ledgerUri) so the plugin can route to the
// right ledger without a cache lookup. Carries optional ack/error so
// ShouldSkipCascade can stay symmetric across all three message shapes.
type Wave2StatusPayload struct {
	Context Wave2Context       `json:"context"`
	Message Wave2StatusMessage `json:"message"`
	Error   *Wave2ErrorBlock   `json:"error,omitempty"`
}

type Wave2StatusMessage struct {
	Contract Wave2StatusContract `json:"contract"`
}

// Wave2StatusContract carries only what is needed for ledger routing.
type Wave2StatusContract struct {
	ID           string              `json:"id"`
	Status       Wave2ContractStatus `json:"status"`
	Participants []Wave2Participant  `json:"participants"`
}

// ParseStatusWave2 unmarshals a wave2 status body.
func ParseStatusWave2(body []byte) (*Wave2StatusPayload, error) {
	var payload Wave2StatusPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse wave2 status payload: %w", err)
	}
	return &payload, nil
}

// ExtractWave2StatusDiscomLedgerUri returns the ledgerUri for the given side
// from a wave2 status payload's participants array.
func ExtractWave2StatusDiscomLedgerUri(payload *Wave2StatusPayload, side Side) string {
	for i := range payload.Message.Contract.Participants {
		if payload.Message.Contract.Participants[i].Role == string(side) {
			return wave2StringAttr(&payload.Message.Contract.Participants[i], "ledgerUri")
		}
	}
	return ""
}

// DeriveSenderHostFromWave2Status returns the sender host from the status payload context.
func DeriveSenderHostFromWave2Status(payload *Wave2StatusPayload, role string) string {
	switch role {
	case "BUYER":
		return hostBase(payload.Context.BapURI)
	case "SELLER":
		return hostBase(payload.Context.BppURI)
	default:
		return ""
	}
}

// -------------------------
// wave2 on_status types, parsers, and performance guard
// -------------------------

// performancePayloadTypes are the columns emitted by the ledger in on_status.
var performancePayloadTypes = map[string]bool{
	"BUYER_DISCOM_ALLOC":   true,
	"SELLER_DISCOM_ALLOC":  true,
	"BUYER_DISCOM_STATUS":  true,
	"SELLER_DISCOM_STATUS": true,
	"FINAL_ALLOC":          true,
}

// Wave2OnStatusPayload is the wave2 `on_status` body.
type Wave2OnStatusPayload struct {
	Context Wave2Context         `json:"context"`
	Message Wave2OnStatusMessage `json:"message"`
	Error   *Wave2ErrorBlock     `json:"error,omitempty"`
}

type Wave2OnStatusMessage struct {
	Contract Wave2OnStatusContract `json:"contract"`
}

type Wave2OnStatusContract struct {
	ID           string                 `json:"id"`
	Status       map[string]interface{} `json:"status"`
	Commitments  []Wave2Commitment      `json:"commitments"`
	Performance  []Wave2Performance     `json:"performance"`
	Participants []Wave2Participant     `json:"participants"`
}

// ParseOnStatusWave2 unmarshals a wave2 on_status body.
func ParseOnStatusWave2(body []byte) (*Wave2OnStatusPayload, error) {
	var payload Wave2OnStatusPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse wave2 on_status payload: %w", err)
	}
	return &payload, nil
}

// Wave2OnStatusHasPerformanceData returns true if the on_status carries at
// least one non-empty value for a recognised performance payload type — checked
// against (a) commitmentAttributes (wave2 unified timeseries) and (b) the legacy
// performance[*].performanceAttributes shape.
func Wave2OnStatusHasPerformanceData(payload *Wave2OnStatusPayload) bool {
	for _, c := range payload.Message.Contract.Commitments {
		if timeseriesHasPerformanceData(c.CommitmentAttributes) {
			return true
		}
	}
	for _, perf := range payload.Message.Contract.Performance {
		if timeseriesHasPerformanceData(extractPerformanceTimeseries(perf.PerformanceAttributes)) {
			return true
		}
	}
	return false
}

// terminalContractStatusCodes are contract.status.code values that indicate
// the trade did NOT successfully transition to ACTIVE — so the recorder must
// not write it to the discom ledger (or cascade its status / on_status).
// Match is case-insensitive.
var terminalContractStatusCodes = map[string]bool{
	"CANCELLED": true,
	"CANCELED":  true,
	"REJECTED":  true,
	"EXPIRED":   true,
	"FAILED":    true,
}

// shouldSkipFromEnvelope is the shared primitive: given the two error signals
// — Beckn 2.0 envelope `error` block and `message.contract.status.code` —
// return whether the recorder should skip cascading this message, and a
// short reason string for logging.
func shouldSkipFromEnvelope(err *Wave2ErrorBlock, contractStatusCode string) (bool, string) {
	if err != nil && err.Code != "" {
		return true, fmt.Sprintf("envelope error %q", err.Code)
	}
	if terminalContractStatusCodes[strings.ToUpper(contractStatusCode)] {
		return true, fmt.Sprintf("contract.status.code=%s", contractStatusCode)
	}
	return false, ""
}

// ShouldSkipOnConfirmCascade returns true (with a reason) when the on_confirm
// payload signals failure — recorder should not write a trade to the ledger.
func ShouldSkipOnConfirmCascade(p *Wave2OnConfirmPayload) (bool, string) {
	return shouldSkipFromEnvelope(p.Error, p.Message.Contract.Status.Code)
}

// ShouldSkipStatusCascade — same check for an incoming /status request.
func ShouldSkipStatusCascade(p *Wave2StatusPayload) (bool, string) {
	return shouldSkipFromEnvelope(p.Error, p.Message.Contract.Status.Code)
}

// ShouldSkipOnStatusCascade — same check for an incoming /on_status.
// The on_status contract.status is loose-typed (map[string]interface{}), so
// we read the `code` field defensively.
func ShouldSkipOnStatusCascade(p *Wave2OnStatusPayload) (bool, string) {
	code := ""
	if s := p.Message.Contract.Status; s != nil {
		if v, ok := s["code"].(string); ok {
			code = v
		}
	}
	return shouldSkipFromEnvelope(p.Error, code)
}

// timeseriesHasPerformanceData scans a BecknTimeSeries-shaped object for any
// interval payload whose type is a known performance column with a non-empty value.
func timeseriesHasPerformanceData(ts map[string]interface{}) bool {
	if ts == nil {
		return false
	}
	intervals, _ := ts["intervals"].([]interface{})
	for _, iv := range intervals {
		m, ok := iv.(map[string]interface{})
		if !ok {
			continue
		}
		payloads, _ := m["payloads"].([]interface{})
		for _, p := range payloads {
			pm, ok := p.(map[string]interface{})
			if !ok {
				continue
			}
			typ, _ := pm["type"].(string)
			if !performancePayloadTypes[typ] {
				continue
			}
			if vals, _ := pm["values"].([]interface{}); len(vals) > 0 {
				return true
			}
		}
	}
	return false
}

// ExtractWave2OnStatusDiscomLedgerUri returns ledgerUri for the given side.
func ExtractWave2OnStatusDiscomLedgerUri(payload *Wave2OnStatusPayload, side Side) string {
	for i := range payload.Message.Contract.Participants {
		if payload.Message.Contract.Participants[i].Role == string(side) {
			return wave2StringAttr(&payload.Message.Contract.Participants[i], "ledgerUri")
		}
	}
	return ""
}

// DeriveSenderHostFromWave2OnStatus returns the sender host from the on_status context.
func DeriveSenderHostFromWave2OnStatus(payload *Wave2OnStatusPayload, role string) string {
	switch role {
	case "BUYER":
		return hostBase(payload.Context.BapURI)
	case "SELLER":
		return hostBase(payload.Context.BppURI)
	default:
		return ""
	}
}

// ParticipantEndpointURI returns participants[role=<role>].participantAttributes.<key>,
// or "" if missing. Used to look up bapUri/bppUri/ledgerUri for trading platforms
// and discoms when rewriting context for a cascade sub-transaction.
func ParticipantEndpointURI(participants []Wave2Participant, role, key string) string {
	for i := range participants {
		if participants[i].Role == role {
			return wave2StringAttr(&participants[i], key)
		}
	}
	return ""
}

// SubTxContext describes one Beckn sub-transaction's party identifiers. Used
// to rewrite context.bapId/bapUri/bppId/bppUri when a cascade leg crosses a
// transaction boundary (e.g. seller→sellerdiscom is a fresh BAP↔BPP pair).
//
// Set BapID/BppID explicitly from participants[role].participantId so that
// the subscriber IDs are stable Beckn identities regardless of the routing
// URI used (ngrok tunnel, internal Docker hostname, cloud hostname, etc.).
// If BapID/BppID are empty the function falls back to the URI hostname
// convention — acceptable when the URI hostname IS the subscriber ID.
type SubTxContext struct {
	BapURI string
	BppURI string
	BapID  string // explicit subscriber ID; if set, overrides hostname(BapURI)
	BppID  string // explicit subscriber ID; if set, overrides hostname(BppURI)
}

// RewriteContextForSubTx rewrites context.bap*/bpp* fields in `body` to identify
// the parties of the new sub-transaction. Subscriber IDs come from BapID/BppID
// when set; otherwise they are derived from the URL hostname (the Beckn
// convention for production nodes where hostname == subscriberId). Returns the
// rewritten body. Other context fields are preserved verbatim.
func RewriteContextForSubTx(body []byte, tx SubTxContext) ([]byte, error) {
	var raw map[string]interface{}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, fmt.Errorf("rewriteContextSubTx: parse body: %w", err)
	}
	ctxRaw, ok := raw["context"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("rewriteContextSubTx: missing or invalid context")
	}

	bppKey, bapKey, bppIDKey, bapIDKey := "bppUri", "bapUri", "bppId", "bapId"
	if _, hasCamel := ctxRaw[bppKey]; !hasCamel {
		if _, hasSnake := ctxRaw["bpp_uri"]; hasSnake {
			bppKey, bapKey, bppIDKey, bapIDKey = "bpp_uri", "bap_uri", "bpp_id", "bap_id"
		}
	}

	if tx.BapURI != "" {
		ctxRaw[bapKey] = tx.BapURI
		id := tx.BapID
		if id == "" {
			id = hostname(tx.BapURI)
		}
		if id != "" {
			ctxRaw[bapIDKey] = id
		}
	}
	if tx.BppURI != "" {
		ctxRaw[bppKey] = tx.BppURI
		id := tx.BppID
		if id == "" {
			id = hostname(tx.BppURI)
		}
		if id != "" {
			ctxRaw[bppIDKey] = id
		}
	}
	raw["context"] = ctxRaw
	return json.Marshal(raw)
}

// hostname returns just the host part (no port) of a URL — used to derive
// the Beckn subscriberId from an endpoint URL (convention: subscriberId
// equals hostname).
func hostname(rawURL string) string {
	u, err := url.Parse(rawURL)
	if err != nil {
		return ""
	}
	return u.Hostname()
}

// extractPerformanceTimeseries walks performanceAttributes to find performanceTimeseries.
func extractPerformanceTimeseries(attrs map[string]interface{}) map[string]interface{} {
	if attrs == nil {
		return nil
	}
	ts, ok := attrs["performanceTimeseries"].(map[string]interface{})
	if !ok {
		return nil
	}
	return ts
}
