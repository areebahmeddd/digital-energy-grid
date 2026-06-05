package degledgerrecorder

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/beckn-one/beckn-onix/pkg/log"
	"github.com/beckn-one/beckn-onix/pkg/model"
	"github.com/google/uuid"
)

// DEGLedgerRecorder is a Step plugin that records trade data to the DEG Ledger
// after on_confirm calls.
type DEGLedgerRecorder struct {
	config *Config
	client *LedgerClient

	// wg tracks in-flight async requests for graceful shutdown
	wg sync.WaitGroup

	pendingMu      sync.Mutex
	pendingRetries map[string]pendingBecknPayload
}

const (
	degLedgerWriteFailed          = "DEG_LEDGER_WRITE_FAILED"
	degLedgerURIMissing           = "DEG_LEDGER_URI_MISSING"
	degLedgerContextRewriteFailed = "DEG_LEDGER_CONTEXT_REWRITE_FAILED"
	degLedgerAckInvalid           = "DEG_LEDGER_ACK_INVALID"
	degAsyncAckTimeout            = "DEG_ASYNC_ACK_TIMEOUT"
)

type pendingBecknPayload struct {
	Action        string
	TransactionID string
	TargetURL     string
	CreatedAt     time.Time
	ExpiresAt     time.Time
	Attempts      int
	Body          []byte
}

// New creates a new DEGLedgerRecorder instance.
func New(cfg map[string]string) (*DEGLedgerRecorder, error) {
	config, err := ParseConfig(cfg)
	if err != nil {
		return nil, err
	}

	// Create Beckn signer if signing is configured
	var signer *BecknSigner
	if config.SigningPrivateKey != "" && config.SubscriberID != "" && config.UniqueKeyID != "" {
		signer, err = NewBecknSigner(
			config.SubscriberID,
			config.UniqueKeyID,
			config.SigningPrivateKey,
			config.SignatureValiditySeconds,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to create Beckn signer: %w", err)
		}

		// Log signing configuration source
		configSource := "explicit config"
		if config.SigningFromEnv {
			configSource = "environment variables (Vault/K8s secrets compatible)"
		}
		fmt.Printf("[DEGLedgerRecorder] Beckn signing enabled (subscriber_id=%s, key_id=%s, source=%s)\n",
			config.SubscriberID, config.UniqueKeyID, configSource)
	} else if config.APIKey != "" {
		fmt.Printf("[DEGLedgerRecorder] Simple API key authentication enabled\n")
	} else {
		fmt.Printf("[DEGLedgerRecorder] WARNING: No authentication configured for ledger API calls\n")
	}

	// Log enabled actions, role, and the three required mode flags so the
	// active behavior is visible at startup.
	fmt.Printf("[DEGLedgerRecorder] payloadShape=%s, ledgerUriSource=%s, ledgerApi=%s, role=%s, actions=[%s]\n",
		config.PayloadShape, config.LedgerUriSource, config.LedgerApi, config.Role,
		strings.Join(config.Actions, ", "))

	client := NewLedgerClient(
		config.LedgerHost,
		config.AsyncTimeout,
		config.RetryCount,
		config.APIKey,
		config.AuthHeader,
		config.DebugLogging,
		signer,
	)

	return &DEGLedgerRecorder{
		config:         config,
		client:         client,
		pendingRetries: make(map[string]pendingBecknPayload),
	}, nil
}

// Run implements the Step interface. It processes the request and records
// events to the DEG Ledger based on configured actions.
func (r *DEGLedgerRecorder) Run(ctx *model.StepContext) error {
	// Skip if plugin is disabled
	if !r.config.Enabled {
		log.Debug(ctx, "DEGLedgerRecorder: plugin disabled, skipping")
		return nil
	}

	// Extract the action from the request
	action := ExtractAction(ctx.Request.URL.Path, ctx.Body)

	// Check if this action is enabled
	if !r.config.IsActionEnabled(action) {
		log.Debugf(ctx, "DEGLedgerRecorder: action '%s' not in configured actions %v, skipping", action, r.config.Actions)
		return nil
	}

	// Route to the appropriate handler based on action
	switch action {
	case ActionOnConfirm:
		return r.handleOnConfirm(ctx)
	case ActionOnStatus:
		return r.handleOnStatus(ctx)
	case ActionStatus:
		return r.handleStatus(ctx)
	default:
		log.Debugf(ctx, "DEGLedgerRecorder: no handler for action '%s', skipping", action)
		return nil
	}
}

// handleOnConfirm processes on_confirm events and sends to /ledger/put.
// Branches on PayloadShape (wave1 vs wave2) and resolves the target ledger
// base URL per LedgerUriSource (config vs payload).
func (r *DEGLedgerRecorder) handleOnConfirm(ctx *model.StepContext) error {
	log.Infof(ctx, "DEGLedgerRecorder: processing on_confirm (payloadShape=%s, ledgerUriSource=%s, ledgerApi=%s)",
		r.config.PayloadShape, r.config.LedgerUriSource, r.config.LedgerApi)

	if len(ctx.Body) < 5000 {
		log.Debugf(ctx, "DEGLedgerRecorder DEBUG: raw body:\n%s", string(ctx.Body))
	} else {
		log.Debugf(ctx, "DEGLedgerRecorder DEBUG: raw body (truncated):\n%s...", string(ctx.Body[:5000]))
	}

	switch r.config.PayloadShape {
	case PayloadShapeWave1:
		return r.handleOnConfirmWave1(ctx)
	case PayloadShapeWave2:
		return r.handleOnConfirmWave2(ctx)
	default:
		log.Warnf(ctx, "DEGLedgerRecorder: unsupported payloadShape=%s", r.config.PayloadShape)
		return nil
	}
}

// handleOnConfirmWave1 — legacy wave1 path: parses beckn:Order/orderItems and
// emits one ledger record per order item.
func (r *DEGLedgerRecorder) handleOnConfirmWave1(ctx *model.StepContext) error {
	if r.config.LedgerApi != LedgerApiLegacyLedger {
		log.Warnf(ctx, "DEGLedgerRecorder: wave1 path only supports ledgerApi=legacy_ledger (got %s); skipping",
			r.config.LedgerApi)
		return nil
	}
	payload, err := ParseOnConfirm(ctx.Body)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: failed to parse wave1 on_confirm payload: %v", err)
		return nil
	}

	log.Debugf(ctx, "DEGLedgerRecorder DEBUG: parsed wave1 context - transaction_id=%s, bap_id=%s, bpp_id=%s",
		payload.Context.TransactionID, payload.Context.BapID, payload.Context.BppID)

	records := MapToLedgerRecords(payload, r.config.Role)
	if len(records) == 0 {
		log.Warnf(ctx, "DEGLedgerRecorder: no order items found in on_confirm, skipping")
		return nil
	}

	// wave1 always has ledgerUriSource=config; falling back to LedgerHost.
	baseURL := r.config.LedgerHost
	if r.config.LedgerUriSource != LedgerUriSourceConfig || baseURL == "" {
		log.Warnf(ctx, "DEGLedgerRecorder: wave1 path requires ledgerUriSource=config and a non-empty ledgerHost (have source=%s, host=%q); skipping",
			r.config.LedgerUriSource, baseURL)
		return nil
	}

	log.Infof(ctx, "DEGLedgerRecorder: wave1 mapped %d records (transaction_id=%s) -> %s",
		len(records), payload.Context.TransactionID, baseURL)
	r.sendPutRecordsAsync(ctx, baseURL, records)
	return nil
}

// handleOnConfirmWave2 — wave2 (P2PTrade/v2.0) path: parses
// message.contract.commitments, resolves the target URL from either config or
// the payload's discom participantAttributes, then dispatches to either the
// legacy_ledger PUT shape or the beckn on_confirm forwarder per LedgerApi.
func (r *DEGLedgerRecorder) handleOnConfirmWave2(ctx *model.StepContext) error {
	payload, err := ParseOnConfirmWave2(ctx.Body)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: failed to parse wave2 on_confirm payload: %v", err)
		return nil
	}

	if skip, reason := ShouldSkipOnConfirmCascade(payload); skip {
		log.Infof(ctx, "DEGLedgerRecorder: skipping on_confirm cascade (transaction_id=%s): %s",
			payload.Context.TransactionID, reason)
		return nil
	}

	log.Debugf(ctx, "DEGLedgerRecorder DEBUG: parsed wave2 context - transactionId=%s, bapId=%s, bppId=%s",
		payload.Context.TransactionID, payload.Context.BapID, payload.Context.BppID)

	baseURL, err := r.resolveWave2BaseURL(payload)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: wave2 base URL resolution failed (transaction_id=%s): %v",
			payload.Context.TransactionID, err)
		if r.config.LedgerApi == LedgerApiBeckn {
			return model.NewBadReqErr(fmt.Errorf("%s: %w", degLedgerURIMissing, err))
		}
		return nil
	}

	switch r.config.LedgerApi {
	case LedgerApiLegacyLedger:
		records, err := MapWave2ToLedgerRecords(payload, r.config.Role)
		if err != nil {
			log.Warnf(ctx, "DEGLedgerRecorder: wave2 mapping failed: %v", err)
			return nil
		}
		log.Infof(ctx, "DEGLedgerRecorder: wave2 (legacy_ledger) mapped %d record(s) (transaction_id=%s) -> %s",
			len(records), payload.Context.TransactionID, baseURL)
		r.sendPutRecordsAsync(ctx, baseURL, records)

	case LedgerApiBeckn:
		senderHost := r.config.SenderHost
		if senderHost == "" {
			senderHost = DeriveSenderHostFromWave2(payload, r.config.Role)
		}
		if senderHost == "" {
			log.Warnf(ctx, "DEGLedgerRecorder: beckn mode requires a sender host (config.senderHost or context.bapUri/bppUri); skipping (transaction_id=%s)",
				payload.Context.TransactionID)
			return model.NewBadReqErr(fmt.Errorf("%s: senderHost or context sender URI is required", degLedgerContextRewriteFailed))
		}
		// Sender (BPP-side on this cascade leg) signs as this plugin's configured
		// subscriber id; the receiver (BAP-side) is the discom ledger TSP whose
		// subscriber id lives in participants[role=<side>Discom].participantId.
		// Both are written into context.bppId/bapId so the cascade leg is
		// Beckn-spec-compliant — bap/bppId must identify the current leg's
		// parties, not the original trade's parties.
		senderSubscriberID := r.config.SubscriberID
		var ledgerSide string
		switch r.config.Role {
		case "BUYER":
			ledgerSide = "buyerDiscom"
		case "SELLER":
			ledgerSide = "sellerDiscom"
		}
		ledgerSubscriberID := participantID(findWave2Participant(payload.Message.Contract.Participants, ledgerSide))
		// Build the receiver and caller endpoint URLs once; they're used both
		// in the body's bapUri/bppUri AND as the wire URL the client POSTs to.
		// ledgerEndpoint = <host>/bap/receiver, the ledger's inbound BAP path.
		ledgerEndpoint := BapReceiverEndpoint(baseURL)
		senderEndpoint := BppCallerEndpoint(senderHost)
		rewritten, err := RewriteContextForBeckn(ctx.Body, senderEndpoint, ledgerEndpoint, senderSubscriberID, ledgerSubscriberID)
		if err != nil {
			log.Warnf(ctx, "DEGLedgerRecorder: beckn context rewrite failed: %v", err)
			return model.NewBadReqErr(fmt.Errorf("%s: %w", degLedgerContextRewriteFailed, err))
		}
		log.Infof(ctx, "DEGLedgerRecorder: wave2 (beckn) forwarding on_confirm synchronously (transaction_id=%s) -> %s/on_confirm (sender=%s bppId=%s bapId=%s)",
			payload.Context.TransactionID, ledgerEndpoint, senderEndpoint, senderSubscriberID, ledgerSubscriberID)
		if err := r.sendBecknOnConfirmBlocking(ctx, ledgerEndpoint, rewritten, payload.Context.TransactionID); err != nil {
			return err
		}

	default:
		log.Warnf(ctx, "DEGLedgerRecorder: unsupported ledgerApi=%s", r.config.LedgerApi)
	}
	return nil
}

// sendBecknOnConfirmBlocking forwards a beckn on_confirm body and blocks the
// ONIX pipeline until the ledger TSP ACKs it. Caller routing continues only
// after this returns nil.
func (r *DEGLedgerRecorder) sendBecknOnConfirmBlocking(parentCtx *model.StepContext, baseURL string, body []byte, transactionID string) error {
	resp, err := r.sendBecknWithRetry(parentCtx.Context, "on_confirm", baseURL, transactionID, body, func(ctx context.Context, attempt int) (*LedgerPutResponse, error) {
		return r.client.PostBecknOnConfirmAttempt(ctx, baseURL, body, attempt)
	})
	if err != nil {
		log.Errorf(parentCtx, err,
			"DEGLedgerRecorder: failed to forward beckn on_confirm (transaction_id=%s, base_url=%s): %v",
			transactionID, baseURL, err)
		if strings.Contains(err.Error(), degLedgerAckInvalid) {
			return model.NewBadReqErr(err)
		}
		return model.NewBadReqErr(fmt.Errorf("%s: transaction_id=%s base_url=%s: %w",
			degLedgerWriteFailed, transactionID, baseURL, err))
	}

	log.Infof(parentCtx,
		"DEGLedgerRecorder: successfully forwarded beckn on_confirm (transaction_id=%s, record_id=%s, base_url=%s, message=%s)",
		transactionID, resp.RecordID, baseURL, resp.Message)
	return nil
}

type becknAttemptFunc func(context.Context, int) (*LedgerPutResponse, error)

func (r *DEGLedgerRecorder) sendBecknWithRetry(ctx context.Context, action, baseURL, transactionID string, body []byte, send becknAttemptFunc) (*LedgerPutResponse, error) {
	deadline := time.Now().Add(r.config.RetryMaxTTL)
	maxAttempts := r.config.RetryCount + 1
	if maxAttempts < 1 {
		maxAttempts = 1
	}

	var lastErr error
	for attempt := 0; attempt < maxAttempts; attempt++ {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		timeout := r.config.AsyncTimeout
		if timeout <= 0 || timeout > remaining {
			timeout = remaining
		}
		attemptCtx, cancel := context.WithTimeout(ctx, timeout)
		resp, err := send(attemptCtx, attempt)
		cancel()
		if err == nil {
			return resp, nil
		}
		lastErr = err
		if ctx.Err() != nil {
			return nil, fmt.Errorf("context cancelled: %w", ctx.Err())
		}
		if attempt == maxAttempts-1 {
			break
		}
		backoff := becknRetryBackoff(r.config.RetryBackoff)
		if backoff > time.Until(deadline) {
			backoff = time.Until(deadline)
		}
		if backoff <= 0 {
			break
		}
		fmt.Printf("[DEGLedgerRecorder] retrying beckn %s after %s (attempt %d/%d, transaction_id=%s, base_url=%s): %v\n",
			action, backoff, attempt+1, maxAttempts, transactionID, baseURL, err)
		timer := time.NewTimer(backoff)
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil, fmt.Errorf("context cancelled: %w", ctx.Err())
		case <-timer.C:
		}
	}

	if lastErr == nil {
		lastErr = fmt.Errorf("retry TTL expired after %s", r.config.RetryMaxTTL)
	}
	return nil, fmt.Errorf("beckn %s did not receive ACK after %d attempt(s) within %s: %w",
		action, maxAttempts, r.config.RetryMaxTTL, lastErr)
}

func becknRetryBackoff(backoff time.Duration) time.Duration {
	if backoff <= 0 {
		return 5 * time.Second
	}
	return backoff
}

// sendBecknOnConfirmAsync forwards a beckn on_confirm body in the background.
// Mirrors sendPutRecordsAsync but for the beckn API path.
func (r *DEGLedgerRecorder) sendBecknOnConfirmAsync(parentCtx *model.StepContext, baseURL string, body []byte, transactionID string) {
	r.wg.Add(1)
	go func() {
		defer r.wg.Done()
		ctx, cancel := context.WithTimeout(context.Background(), r.config.AsyncTimeout)
		defer cancel()
		resp, err := r.client.PostBecknOnConfirm(ctx, baseURL, body)
		if err != nil {
			log.Errorf(parentCtx, err,
				"DEGLedgerRecorder: failed to forward beckn on_confirm (transaction_id=%s, base_url=%s): %v",
				transactionID, baseURL, err)
			return
		}
		log.Infof(parentCtx,
			"DEGLedgerRecorder: successfully forwarded beckn on_confirm (transaction_id=%s, record_id=%s, base_url=%s)",
			transactionID, resp.RecordID, baseURL)
	}()
}

// resolveWave2BaseURL picks the target ledger URL according to LedgerUriSource.
// For payload mode, the side is determined by the configured role:
// BUYER → buyerDiscom.ledgerUrl, SELLER → sellerDiscom.ledgerUrl.
func (r *DEGLedgerRecorder) resolveWave2BaseURL(payload *Wave2OnConfirmPayload) (string, error) {
	switch r.config.LedgerUriSource {
	case LedgerUriSourceConfig:
		if r.config.LedgerHost == "" {
			return "", fmt.Errorf("ledgerHost is empty")
		}
		return r.config.LedgerHost, nil
	case LedgerUriSourcePayload:
		var side Side
		switch r.config.Role {
		case "BUYER":
			side = SideBuyer
		case "SELLER":
			side = SideSeller
		default:
			return "", fmt.Errorf("payload-sourced ledger URI requires role BUYER or SELLER, got %s", r.config.Role)
		}
		uri := ExtractWave2DiscomLedgerURL(payload, side)
		if uri == "" {
			return "", fmt.Errorf("no ledgerUrl found in participants[role=%s].participantAttributes", side)
		}
		return uri, nil
	default:
		return "", fmt.Errorf("unsupported ledgerUriSource: %s", r.config.LedgerUriSource)
	}
}

// handleOnStatus processes on_status events.
// For BUYER/SELLER roles with ledgerApi=beckn: forwards to the appropriate
// discom ledger when performance data is present (wave2 path).
// For BUYER_DISCOM/SELLER_DISCOM roles: writes meter readings to /ledger/record (wave1 path).
func (r *DEGLedgerRecorder) handleOnStatus(ctx *model.StepContext) error {
	log.Infof(ctx, "DEGLedgerRecorder: processing on_status (role=%s, ledgerApi=%s, payloadShape=%s)",
		r.config.Role, r.config.LedgerApi, r.config.PayloadShape)

	// Wave2 beckn forwarding path: BUYER or SELLER role forwards on_status with performance data.
	if r.config.PayloadShape == PayloadShapeWave2 && r.config.LedgerApi == LedgerApiBeckn &&
		(r.config.Role == "BUYER" || r.config.Role == "SELLER") {
		return r.handleOnStatusWave2(ctx)
	}

	// Wave1 / DISCOM path: write meter readings to /ledger/record.
	if !r.config.IsDiscomRole() {
		log.Warnf(ctx, "DEGLedgerRecorder: on_status requires BUYER_DISCOM or SELLER_DISCOM role for legacy path, got %s", r.config.Role)
		return nil
	}

	// DEBUG: Log the raw body received
	log.Debugf(ctx, "DEGLedgerRecorder DEBUG: raw body length=%d", len(ctx.Body))
	if len(ctx.Body) < 5000 {
		log.Debugf(ctx, "DEGLedgerRecorder DEBUG: raw body:\n%s", string(ctx.Body))
	} else {
		log.Debugf(ctx, "DEGLedgerRecorder DEBUG: raw body (truncated):\n%s...", string(ctx.Body[:5000]))
	}

	// Parse the on_status payload
	payload, err := ParseOnStatus(ctx.Body)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: failed to parse on_status payload: %v", err)
		return nil
	}

	// DEBUG: Log parsed payload details
	log.Debugf(ctx, "DEGLedgerRecorder DEBUG: parsed context - transaction_id=%s, action=%s",
		payload.Context.TransactionID, payload.Context.Action)
	log.Debugf(ctx, "DEGLedgerRecorder DEBUG: order items count=%d", len(payload.Message.Order.OrderItems))

	// Map to ledger record requests (one per order item with meter readings)
	records := MapToLedgerRecordRequests(payload, r.config.Role)

	// DEBUG: Log mapped records
	for i, rec := range records {
		metricCount := len(rec.BuyerFulfillmentValidationMetrics) + len(rec.SellerFulfillmentValidationMetrics)
		log.Debugf(ctx, "DEGLedgerRecorder DEBUG: record[%d] - transactionId=%s, orderItemId=%s, metrics=%d",
			i, rec.TransactionID, rec.OrderItemID, metricCount)
	}

	if len(records) == 0 {
		log.Warnf(ctx, "DEGLedgerRecorder: no meter readings found in on_status, skipping ledger recording")
		return nil
	}

	log.Infof(ctx, "DEGLedgerRecorder: mapped %d ledger record requests from on_status (transaction_id=%s)",
		len(records), payload.Context.TransactionID)

	// Send records to ledger asynchronously (fire-and-forget)
	r.sendRecordActualsAsync(ctx, records, payload.Context.TransactionID)

	return nil
}

// handleStatus forwards an incoming wave2 beckn `status` request to the
// appropriate discom ledger as a beckn `status` call. The ledger will
// asynchronously call back with `on_status`.
// SELLER role → sellerDiscom.ledgerUrl; BUYER role → buyerDiscom.ledgerUrl.
func (r *DEGLedgerRecorder) handleStatus(ctx *model.StepContext) error {
	log.Infof(ctx, "DEGLedgerRecorder: processing status (role=%s, ledgerApi=%s)", r.config.Role, r.config.LedgerApi)

	if r.config.LedgerApi != LedgerApiBeckn {
		log.Warnf(ctx, "DEGLedgerRecorder: status forwarding only supported with ledgerApi=beckn (got %s); skipping", r.config.LedgerApi)
		return nil
	}

	payload, err := ParseStatusWave2(ctx.Body)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: failed to parse wave2 status payload: %v", err)
		return nil
	}

	if skip, reason := ShouldSkipStatusCascade(payload); skip {
		log.Infof(ctx, "DEGLedgerRecorder: skipping status cascade (transaction_id=%s): %s",
			payload.Context.TransactionID, reason)
		return nil
	}

	var side Side
	switch r.config.Role {
	case "SELLER":
		side = SideSeller
	case "BUYER":
		side = SideBuyer
	default:
		log.Warnf(ctx, "DEGLedgerRecorder: status forwarding requires BUYER or SELLER role, got %s", r.config.Role)
		return nil
	}

	ledgerHostBase := r.config.LedgerHost
	if r.config.LedgerUriSource == LedgerUriSourcePayload {
		ledgerHostBase = ExtractWave2StatusDiscomLedgerURL(payload, side)
	}
	if ledgerHostBase == "" {
		log.Warnf(ctx, "DEGLedgerRecorder: no ledgerUrl resolved for status forwarding (role=%s, side=%s)", r.config.Role, side)
		return nil
	}
	// status is a REQUEST action; Beckn convention is requester=BAP, responder=BPP.
	// This platform is the BAP-caller forwarding the status, ledger is the BPP-receiver.
	// On the wire we POST to <ledger>/bpp/receiver/status; in context.bapUri we
	// advertise the platform's BAP-receiver endpoint (where the on_status callback
	// will land), and in context.bppUri the ledger's BPP-receiver endpoint.
	ledgerEndpoint := BppReceiverEndpoint(ledgerHostBase)

	// platformUrl comes from participants[<own-role>].participantAttributes.platformUrl.
	parts := payload.Message.Contract.Participants
	ownPlatformRole := wave2PlatformRole(r.config.Role)
	ownPlatformURI := ParticipantEndpointURI(parts, ownPlatformRole, "platformUrl")
	if ownPlatformURI == "" {
		log.Warnf(ctx, "DEGLedgerRecorder: own platformUrl not found in participants[%s]; skipping status forward (transaction_id=%s)", ownPlatformRole, payload.Context.TransactionID)
		return nil
	}
	// Use participantId from the participants array for bapId/bppId so they are
	// stable Beckn identities regardless of whether the routing URIs use ngrok
	// tunnels, internal Docker hostnames, or production FQDNs.
	ownParticipantID := participantID(findWave2Participant(parts, ownPlatformRole))
	discomParticipantID := participantID(findWave2Participant(parts, string(side)))
	subTx := SubTxContext{
		BapURI: BapReceiverEndpoint(ownPlatformURI),
		BppURI: ledgerEndpoint,
		BapID:  ownParticipantID,
		BppID:  discomParticipantID,
	}
	rewritten, err := RewriteContextForSubTx(ctx.Body, subTx)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: beckn status context rewrite failed: %v", err)
		return nil
	}

	log.Infof(ctx, "DEGLedgerRecorder: forwarding status (transaction_id=%s, contract_id=%s) -> %s/status (sub-tx bap=%s, bpp=%s)",
		payload.Context.TransactionID, payload.Message.Contract.ID, ledgerEndpoint, subTx.BapURI, subTx.BppURI)
	r.sendBecknStatusAsync(ctx, ledgerEndpoint, rewritten, payload.Context.TransactionID)

	// Prosumer check: in a single-platform topology (buyer and seller are the
	// same app) this node is the only one that will ever call handleStatus, so it
	// must kick off the sub-transaction to the PEER's discom as well. In a normal
	// 2-platform setup peerPlatformURI != ownPlatformURI and none of this runs.
	peerRole := wave2PeerPlatformRole(r.config.Role)
	if ParticipantEndpointURI(parts, peerRole, "platformUrl") != ownPlatformURI {
		return nil // 2-platform topology — peer will handle its own discom
	}

	// Determine the peer's discom role and ledger side.
	peerDiscomRole, peerDiscomSide := "buyerDiscom", SideBuyer
	if r.config.Role == "BUYER" {
		peerDiscomRole, peerDiscomSide = "sellerDiscom", SideSeller
	}

	peerDiscomID := participantID(findWave2Participant(parts, peerDiscomRole))
	if peerDiscomID == discomParticipantID {
		return nil // both roles share one discom — already sent above
	}

	peerLedgerHost := ExtractWave2StatusDiscomLedgerURL(payload, peerDiscomSide)
	if peerLedgerHost == "" {
		log.Warnf(ctx, "DEGLedgerRecorder: prosumer: peer discom ledgerUrl not found in payload participants (transaction_id=%s)", payload.Context.TransactionID)
		return nil
	}

	peerLedgerEndpoint := BppReceiverEndpoint(peerLedgerHost)
	peerSubTx := SubTxContext{
		BapURI: BapReceiverEndpoint(ownPlatformURI),
		BppURI: peerLedgerEndpoint,
		BapID:  ownParticipantID,
		BppID:  peerDiscomID,
	}
	peerRewritten, err := RewriteContextForSubTx(ctx.Body, peerSubTx)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: prosumer: status rewrite failed for peer discom: %v", err)
		return nil
	}
	log.Infof(ctx, "DEGLedgerRecorder: prosumer: forwarding status to peer discom (transaction_id=%s) -> %s/status (sub-tx bap=%s, bpp=%s)",
		payload.Context.TransactionID, peerLedgerEndpoint, peerSubTx.BapURI, peerSubTx.BppURI)
	r.sendBecknStatusAsync(ctx, peerLedgerEndpoint, peerRewritten, payload.Context.TransactionID)
	return nil
}

// handleOnStatusWave2 propagates on_status through the cascade chain so every
// party in the trade receives updated performance data as soon as it is available.
//
// The chain has two rules, decided by who sent the on_status (context.bppId):
//
//	Rule 2a — own discom sent it (bppId == ownDiscomPid):
//	  The discom has just computed its allocation. Pass the payload to the peer
//	  platform so the peer can record it and trigger its own discom cascade.
//
//	  Prosumer variant (buyer and seller share one platform): there is no
//	  separate peer to forward to, so skip the self-loop and cascade directly
//	  to the peer's discom instead. If both roles also share one discom, the
//	  single discom was already notified via handleStatus — terminate here.
//
//	Rule 2b — peer (or any other party) sent it (bppId != ownDiscomPid):
//	  We received the peer's allocation data. Push it to our own discom so it
//	  can record the full bilateral settlement. Skipped when the payload has
//	  no performance data (e.g. a bare status-check ACK).
//
// The asymmetry (discom → platform → discom, never discom → discom) is what
// prevents infinite loops: discoms receive on_status at /bap/receiver, which
// routes to the bap-webhook (ACK only) and never re-cascades.
func (r *DEGLedgerRecorder) handleOnStatusWave2(ctx *model.StepContext) error {
	payload, err := ParseOnStatusWave2(ctx.Body)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: failed to parse wave2 on_status payload: %v", err)
		return nil
	}

	if skip, reason := ShouldSkipOnStatusCascade(payload); skip {
		log.Infof(ctx, "DEGLedgerRecorder: skipping on_status forwarding (transaction_id=%s): %s",
			payload.Context.TransactionID, reason)
		return nil
	}

	var ownDiscomRole string
	var ownDiscomSide Side
	switch r.config.Role {
	case "SELLER":
		ownDiscomRole, ownDiscomSide = "sellerDiscom", SideSeller
	case "BUYER":
		ownDiscomRole, ownDiscomSide = "buyerDiscom", SideBuyer
	default:
		log.Warnf(ctx, "DEGLedgerRecorder: on_status wave2 forwarding requires BUYER or SELLER role, got %s", r.config.Role)
		return nil
	}

	ownDiscomPid := participantIDForRole(payload, ownDiscomRole)
	fromOwnDiscom := ownDiscomPid != "" && payload.Context.BppID == ownDiscomPid

	// Look up this handler's trading-platform URI; rewriting the context for
	// the next leg needs it for both Rule 2a (BPP-side of leg 4) and Rule 2b
	// (BPP-side of leg 5). The platform plays BPP-caller on both forwards.
	parts := payload.Message.Contract.Participants
	ownPlatformRole := wave2PlatformRole(r.config.Role)
	ownPlatformURI := ParticipantEndpointURI(parts, ownPlatformRole, "platformUrl")
	if ownPlatformURI == "" {
		log.Warnf(ctx, "DEGLedgerRecorder: own platformUrl not found in participants[%s] (transaction_id=%s)", ownPlatformRole, payload.Context.TransactionID)
		return nil
	}
	ownBppEndpoint := BppCallerEndpoint(ownPlatformURI)

	var baseURL string
	var subTx SubTxContext
	var branch string
	ownParticipantID := participantID(findWave2Participant(parts, ownPlatformRole))

	if fromOwnDiscom {
		// Rule 2a: our discom just computed its allocation — pass the on_status to
		// the peer so the peer can in turn cascade to its own discom (Rule 2b).
		peerRole := wave2PeerPlatformRole(r.config.Role)
		peerPlatformURI := ParticipantEndpointURI(parts, peerRole, "platformUrl")
		if peerPlatformURI == "" {
			log.Warnf(ctx, "DEGLedgerRecorder: peer platformUrl not found in participants[%s] (transaction_id=%s)", peerRole, payload.Context.TransactionID)
			return nil
		}

		if peerPlatformURI == ownPlatformURI {
			// Prosumer topology: buyer and seller are the same platform, so there
			// is no separate peer node to forward to. Act on behalf of the peer and
			// cascade directly to the peer's discom.
			peerDiscomRole, peerDiscomSide := "buyerDiscom", SideBuyer
			if r.config.Role == "BUYER" {
				peerDiscomRole, peerDiscomSide = "sellerDiscom", SideSeller
			}

			peerDiscomID := participantIDForRole(payload, peerDiscomRole)
			if peerDiscomID == ownDiscomPid {
				// Both roles share one discom — already notified via handleStatus; done.
				log.Debugf(ctx, "DEGLedgerRecorder: prosumer: single discom for both roles, already notified (transaction_id=%s)", payload.Context.TransactionID)
				return nil
			}
			if !Wave2OnStatusHasPerformanceData(payload) {
				log.Debugf(ctx, "DEGLedgerRecorder: prosumer: no performance data; skipping peer discom cascade (transaction_id=%s)", payload.Context.TransactionID)
				return nil
			}
			peerDiscomHost := ExtractWave2OnStatusDiscomLedgerURL(payload, peerDiscomSide)
			if peerDiscomHost == "" {
				log.Warnf(ctx, "DEGLedgerRecorder: prosumer: peer discom ledgerUrl not found in payload participants (transaction_id=%s)", payload.Context.TransactionID)
				return nil
			}
			peerDiscomEndpoint := BapReceiverEndpoint(peerDiscomHost)
			branch = "prosumer-peer-discom"
			baseURL = peerDiscomEndpoint
			subTx = SubTxContext{
				BapURI: peerDiscomEndpoint,
				BppURI: ownBppEndpoint,
				BapID:  participantID(findWave2Participant(parts, peerDiscomRole)),
				BppID:  ownParticipantID,
			}
		} else {
			// Normal 2-platform topology: forward to peer's /bap/receiver.
			peerBapEndpoint := BapReceiverEndpoint(peerPlatformURI)
			branch = "peer"
			baseURL = peerBapEndpoint
			subTx = SubTxContext{
				BapURI: peerBapEndpoint,
				BppURI: ownBppEndpoint,
				BapID:  participantID(findWave2Participant(parts, peerRole)),
				BppID:  ownParticipantID,
			}
		}
	} else {
		// Rule 2b: we received the peer's allocation data. Push it to our own
		// discom so it can record the full bilateral settlement.
		if !Wave2OnStatusHasPerformanceData(payload) {
			log.Debugf(ctx, "DEGLedgerRecorder: on_status has no performance data; skipping discom cascade (transaction_id=%s)", payload.Context.TransactionID)
			return nil
		}
		discomLedgerHost := r.config.LedgerHost
		if r.config.LedgerUriSource == LedgerUriSourcePayload {
			discomLedgerHost = ExtractWave2OnStatusDiscomLedgerURL(payload, ownDiscomSide)
		}
		discomLedgerEndpoint := BapReceiverEndpoint(discomLedgerHost)
		branch = "discom"
		baseURL = discomLedgerEndpoint
		subTx = SubTxContext{
			BapURI: discomLedgerEndpoint,
			BppURI: ownBppEndpoint,
			BapID:  participantID(findWave2Participant(parts, ownDiscomRole)),
			BppID:  ownParticipantID,
		}
	}

	if baseURL == "" {
		log.Warnf(ctx, "DEGLedgerRecorder: no target URI resolved for on_status forwarding (role=%s, bppId=%s, fromOwnDiscom=%v)", r.config.Role, payload.Context.BppID, fromOwnDiscom)
		return nil
	}

	rewritten, err := RewriteContextForSubTx(ctx.Body, subTx)
	if err != nil {
		log.Warnf(ctx, "DEGLedgerRecorder: beckn on_status context rewrite failed: %v", err)
		return nil
	}

	log.Infof(ctx, "DEGLedgerRecorder: forwarding on_status (transaction_id=%s, role=%s, branch=%s) -> %s/on_status (sub-tx bap=%s, bpp=%s)",
		payload.Context.TransactionID, r.config.Role, branch, baseURL, subTx.BapURI, subTx.BppURI)
	r.sendBecknOnStatusAsync(ctx, baseURL, rewritten, ctx.Body, payload.Context.TransactionID)
	return nil
}

// participantIDForRole returns the participantId of the contract participant
// with the given role, or "" if not found.
func participantIDForRole(payload *Wave2OnStatusPayload, role string) string {
	for _, p := range payload.Message.Contract.Participants {
		if p.Role == role {
			return p.ParticipantID
		}
	}
	return ""
}

// swapURLPath replaces the path component of a URL while preserving scheme,
// host, port and query. Used to derive a Beckn-companion endpoint URL — e.g.
// http://seller.beckn-router:9000/bpp/receiver → .../bap/receiver.
func swapURLPath(rawURL, newPath string) string {
	u, err := url.Parse(rawURL)
	if err != nil || u.Host == "" {
		return ""
	}
	u.Path = newPath
	return u.String()
}

// sendBecknStatusAsync forwards a beckn status body in the background.
func (r *DEGLedgerRecorder) sendBecknStatusAsync(parentCtx *model.StepContext, baseURL string, body []byte, transactionID string) {
	pendingID := r.addPendingRetry("status", transactionID, baseURL, body)
	r.wg.Add(1)
	go func() {
		defer r.wg.Done()
		defer r.removePendingRetry(pendingID)

		_, err := r.sendBecknWithRetry(context.Background(), "status", baseURL, transactionID, body, func(ctx context.Context, attempt int) (*LedgerPutResponse, error) {
			r.updatePendingAttempt(pendingID, attempt+1)
			return nil, r.client.PostBecknStatusAttempt(ctx, baseURL, body, attempt)
		})
		if err != nil {
			log.Errorf(parentCtx, err,
				"DEGLedgerRecorder: failed to forward beckn status (transaction_id=%s, base_url=%s): %v",
				transactionID, baseURL, err)
			return
		}
		log.Infof(parentCtx,
			"DEGLedgerRecorder: successfully forwarded beckn status (transaction_id=%s, base_url=%s)",
			transactionID, baseURL)
	}()
}

// sendBecknOnStatusAsync forwards a beckn on_status body in the background.
func (r *DEGLedgerRecorder) sendBecknOnStatusAsync(parentCtx *model.StepContext, baseURL string, body []byte, originalBody []byte, transactionID string) {
	pendingID := r.addPendingRetry("on_status", transactionID, baseURL, body)
	r.wg.Add(1)
	go func() {
		defer r.wg.Done()
		defer r.removePendingRetry(pendingID)

		resp, err := r.sendBecknWithRetry(context.Background(), "on_status", baseURL, transactionID, body, func(ctx context.Context, attempt int) (*LedgerPutResponse, error) {
			r.updatePendingAttempt(pendingID, attempt+1)
			return r.client.PostBecknOnStatusAttempt(ctx, baseURL, body, attempt)
		})
		if err != nil {
			log.Errorf(parentCtx, err,
				"DEGLedgerRecorder: failed to forward beckn on_status (transaction_id=%s, base_url=%s): %v",
				transactionID, baseURL, err)
			r.sendOnStatusRetryFailure(parentCtx, originalBody, baseURL, transactionID, r.pendingAttemptCount(pendingID), err)
			return
		}
		log.Infof(parentCtx,
			"DEGLedgerRecorder: successfully forwarded beckn on_status (transaction_id=%s, record_id=%s, base_url=%s, message=%s)",
			transactionID, resp.RecordID, baseURL, resp.Message)
	}()
}

func (r *DEGLedgerRecorder) addPendingRetry(action, transactionID, targetURL string, body []byte) string {
	id := uuid.NewString()
	now := time.Now()
	bodyCopy := append([]byte(nil), body...)
	r.pendingMu.Lock()
	r.pendingRetries[id] = pendingBecknPayload{
		Action:        action,
		TransactionID: transactionID,
		TargetURL:     targetURL,
		CreatedAt:     now,
		ExpiresAt:     now.Add(r.config.RetryMaxTTL),
		Body:          bodyCopy,
	}
	r.pendingMu.Unlock()
	return id
}

func (r *DEGLedgerRecorder) updatePendingAttempt(id string, attempts int) {
	r.pendingMu.Lock()
	if pending, ok := r.pendingRetries[id]; ok {
		pending.Attempts = attempts
		r.pendingRetries[id] = pending
	}
	r.pendingMu.Unlock()
}

func (r *DEGLedgerRecorder) pendingAttemptCount(id string) int {
	r.pendingMu.Lock()
	defer r.pendingMu.Unlock()
	if pending, ok := r.pendingRetries[id]; ok {
		return pending.Attempts
	}
	return 0
}

func (r *DEGLedgerRecorder) removePendingRetry(id string) {
	r.pendingMu.Lock()
	delete(r.pendingRetries, id)
	r.pendingMu.Unlock()
}

func (r *DEGLedgerRecorder) pendingRetryCount() int {
	r.pendingMu.Lock()
	defer r.pendingMu.Unlock()
	return len(r.pendingRetries)
}

func (r *DEGLedgerRecorder) sendOnStatusRetryFailure(parentCtx *model.StepContext, originalBody []byte, failedTargetURL, transactionID string, attempts int, lastErr error) {
	targetURL, failureBody, err := buildOnStatusRetryFailure(originalBody, failedTargetURL, attempts, r.config.RetryMaxTTL, lastErr)
	if err != nil {
		log.Errorf(parentCtx, err,
			"DEGLedgerRecorder: failed to build on_status retry failure callback (transaction_id=%s): %v",
			transactionID, err)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), r.config.AsyncTimeout)
	defer cancel()
	if _, err := r.client.PostBecknOnStatusAttempt(ctx, targetURL, failureBody, 0); err != nil {
		log.Errorf(parentCtx, err,
			"DEGLedgerRecorder: failed to send on_status retry failure callback (transaction_id=%s, target_url=%s): %v",
			transactionID, targetURL, err)
		return
	}
	log.Infof(parentCtx,
		"DEGLedgerRecorder: sent on_status retry failure callback (transaction_id=%s, target_url=%s)",
		transactionID, targetURL)
}

func buildOnStatusRetryFailure(originalBody []byte, failedTargetURL string, attempts int, ttl time.Duration, lastErr error) (string, []byte, error) {
	var raw map[string]interface{}
	if err := json.Unmarshal(originalBody, &raw); err != nil {
		return "", nil, fmt.Errorf("parse original on_status: %w", err)
	}
	ctxRaw, ok := raw["context"].(map[string]interface{})
	if !ok {
		return "", nil, fmt.Errorf("missing or invalid context")
	}

	originalBapURI := stringValue(ctxRaw["bapUri"])
	originalBppURI := stringValue(ctxRaw["bppUri"])
	originalBapID := stringValue(ctxRaw["bapId"])
	originalBppID := stringValue(ctxRaw["bppId"])
	targetHost := hostBase(originalBppURI)
	senderHost := hostBase(originalBapURI)
	if targetHost == "" {
		return "", nil, fmt.Errorf("cannot derive failure callback target from context.bppUri")
	}
	targetURL := BapReceiverEndpoint(targetHost)
	if originalBppID == "" {
		originalBppID = hostname(targetURL)
	}
	if originalBapID == "" {
		originalBapID = hostname(originalBapURI)
	}

	ctxRaw["action"] = ActionOnStatus
	ctxRaw["messageId"] = uuid.NewString()
	ctxRaw["timestamp"] = time.Now().UTC().Format(time.RFC3339Nano)
	ctxRaw["bapUri"] = targetURL
	ctxRaw["bapId"] = originalBppID
	if senderHost != "" {
		ctxRaw["bppUri"] = BppCallerEndpoint(senderHost)
	}
	ctxRaw["bppId"] = originalBapID
	raw["context"] = ctxRaw
	raw["error"] = map[string]interface{}{
		"code":    degAsyncAckTimeout,
		"message": "on_status forwarding did not receive ACK before retry limit",
		"details": map[string]interface{}{
			"targetAction":  ActionOnStatus,
			"targetUrl":     failedTargetURL,
			"attempts":      attempts,
			"retryMaxTTL":   ttl.String(),
			"lastError":     lastErr.Error(),
			"transactionId": ctxRaw["transactionId"],
		},
	}

	body, err := json.Marshal(raw)
	if err != nil {
		return "", nil, fmt.Errorf("marshal retry failure on_status: %w", err)
	}
	return targetURL, body, nil
}

func stringValue(value interface{}) string {
	if value == nil {
		return ""
	}
	if str, ok := value.(string); ok {
		return str
	}
	return ""
}

// sendPutRecordsAsync sends ledger PUT records in the background without blocking the main flow.
// Used for on_confirm → /ledger/put. baseURL is supplied per-call so the same
// recorder can target different discom ledger TSPs based on payload-sourced URIs.
func (r *DEGLedgerRecorder) sendPutRecordsAsync(parentCtx *model.StepContext, baseURL string, records []LedgerPutRequest) {
	for _, record := range records {
		r.wg.Add(1)
		go func(rec LedgerPutRequest) {
			defer r.wg.Done()

			// Create a new context with timeout for the async operation
			ctx, cancel := context.WithTimeout(context.Background(), r.config.AsyncTimeout)
			defer cancel()

			resp, err := r.client.PutRecord(ctx, baseURL, rec)
			if err != nil {
				log.Errorf(parentCtx, err,
					"DEGLedgerRecorder: failed to PUT record to ledger (transaction_id=%s, order_item_id=%s, base_url=%s): %v",
					rec.TransactionID, rec.OrderItemID, baseURL, err)
				return
			}

			log.Infof(parentCtx,
				"DEGLedgerRecorder: successfully PUT record to ledger (transaction_id=%s, order_item_id=%s, record_id=%s, base_url=%s)",
				rec.TransactionID, rec.OrderItemID, resp.RecordID, baseURL)
		}(record)
	}
}

// sendRecordActualsAsync sends meter readings/validation metrics in the background.
// Used for on_status → /ledger/record
func (r *DEGLedgerRecorder) sendRecordActualsAsync(parentCtx *model.StepContext, records []LedgerRecordRequest, transactionID string) {
	for _, record := range records {
		r.wg.Add(1)
		go func(rec LedgerRecordRequest) {
			defer r.wg.Done()

			// Create a new context with timeout for the async operation
			ctx, cancel := context.WithTimeout(context.Background(), r.config.AsyncTimeout)
			defer cancel()

			resp, err := r.client.RecordActuals(ctx, rec)
			if err != nil {
				log.Errorf(parentCtx, err,
					"DEGLedgerRecorder: failed to RECORD actuals to ledger (transaction_id=%s, order_item_id=%s): %v",
					rec.TransactionID, rec.OrderItemID, err)
				return
			}

			log.Infof(parentCtx,
				"DEGLedgerRecorder: successfully RECORDED actuals to ledger (transaction_id=%s, order_item_id=%s, record_id=%s)",
				rec.TransactionID, rec.OrderItemID, resp.RecordID)
		}(record)
	}
}

// Close gracefully shuts down the recorder, waiting for in-flight requests.
func (r *DEGLedgerRecorder) Close() {
	// Wait for all in-flight requests to complete
	r.wg.Wait()

	// Close the HTTP client
	if r.client != nil {
		r.client.Close()
	}
}
