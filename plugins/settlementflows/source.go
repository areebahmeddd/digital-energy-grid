package settlementflows

// Resolution of rego source from a payload policy URL.
//
// Two source shapes are supported:
//   - a bare .rego file served directly at the URL, and
//   - a DeDi public-dataset record (api.dedi.global lookup) whose details
//     carry the rego either inline (data_inline) or by reference (data_url,
//     with optional checksum verification).

import (
	"context"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"hash"
	"io"
	"net/http"
	"strings"
	"time"
)

// retryBaseBackoff is the delay before the first retry; each further retry
// waits one multiple longer (500ms, 1s, ...). A var so tests can shrink it.
var retryBaseBackoff = 500 * time.Millisecond

// sourceFetcher fetches rego source over HTTP with bounded retries.
type sourceFetcher struct {
	timeout     time.Duration // per-attempt HTTP timeout
	maxFileSize int64
	retries     int // retries after the first attempt
}

// dediDetails is the subset of a DeDi public-dataset record we consume.
type dediDetails struct {
	DataURL             string `json:"data_url"`
	DataInline          string `json:"data_inline"`
	DataURLChecksum     string `json:"data_url_checksum"`
	DataURLChecksumType string `json:"data_url_checksum_type"`
}

// ResolvePolicy returns the rego source referenced by policyURL, following a
// DeDi record indirection if the URL serves one.
func (f *sourceFetcher) ResolvePolicy(ctx context.Context, policyURL string) (string, error) {
	body, err := f.fetch(ctx, policyURL)
	if err != nil {
		return "", err
	}
	details, ok := parseDediRecord(body)
	if !ok {
		return string(body), nil // bare rego file
	}
	return f.resolveDedi(ctx, details)
}

// parseDediRecord detects a DeDi lookup response: a JSON envelope carrying
// data.details. Anything else (including bare rego, which is not JSON) is
// not a DeDi record.
func parseDediRecord(body []byte) (*dediDetails, bool) {
	var record struct {
		Data struct {
			Details *dediDetails `json:"details"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &record); err != nil || record.Data.Details == nil {
		return nil, false
	}
	return record.Data.Details, true
}

// resolveDedi extracts the rego source from a DeDi record's details.
func (f *sourceFetcher) resolveDedi(ctx context.Context, d *dediDetails) (string, error) {
	switch {
	case d.DataURL != "" && d.DataInline != "":
		return "", fmt.Errorf("dedi record: exactly one of data_url and data_inline should be non-empty (both are set)")
	case d.DataURL == "" && d.DataInline == "":
		return "", fmt.Errorf("dedi record: exactly one of data_url and data_inline should be non-empty (both are empty)")
	case d.DataInline != "":
		return d.DataInline, nil
	}

	body, err := f.fetch(ctx, d.DataURL)
	if err != nil {
		return "", fmt.Errorf("dedi data_url not accessible: %w", err)
	}
	if d.DataURLChecksumType != "" {
		if err := verifyChecksum(body, d.DataURLChecksumType, d.DataURLChecksum); err != nil {
			return "", fmt.Errorf("dedi data_url integrity: %w", err)
		}
	}
	return string(body), nil
}

// verifyChecksum hashes data with the named algorithm and compares it with
// want (hex, case-insensitive, optional 0x prefix). The weak algorithms
// (md5, sha1) are accepted because the DeDi dataset schema allows them —
// this is integrity checking against the record, not cryptographic trust.
func verifyChecksum(data []byte, algo, want string) error {
	var h hash.Hash
	switch strings.ToLower(strings.TrimSpace(algo)) {
	case "sha256":
		h = sha256.New()
	case "sha384":
		h = sha512.New384()
	case "sha512":
		h = sha512.New()
	case "sha1":
		h = sha1.New()
	case "md5":
		h = md5.New()
	default:
		return fmt.Errorf("unsupported data_url_checksum_type %q", algo)
	}

	want = strings.ToLower(strings.TrimPrefix(strings.TrimSpace(want), "0x"))
	if want == "" {
		return fmt.Errorf("data_url_checksum_type is %q but data_url_checksum is empty", algo)
	}
	h.Write(data)
	if got := hex.EncodeToString(h.Sum(nil)); got != want {
		return fmt.Errorf("%s mismatch: computed %s, record says %s", algo, got, want)
	}
	return nil
}

// fetch GETs url, retrying transient failures (network errors and HTTP 5xx)
// up to f.retries times with linear backoff. Other HTTP errors fail
// immediately — a 404 will not heal on retry.
func (f *sourceFetcher) fetch(ctx context.Context, url string) ([]byte, error) {
	var lastErr error
	for attempt := 0; attempt <= f.retries; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(time.Duration(attempt) * retryBaseBackoff):
			}
		}
		body, retryable, err := f.fetchOnce(ctx, url)
		if err == nil {
			return body, nil
		}
		if !retryable {
			return nil, err
		}
		lastErr = err
	}
	return nil, fmt.Errorf("after %d attempts: %w", f.retries+1, lastErr)
}

func (f *sourceFetcher) fetchOnce(ctx context.Context, url string) (body []byte, retryable bool, err error) {
	reqCtx, cancel := context.WithTimeout(ctx, f.timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, url, nil)
	if err != nil {
		return nil, false, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, true, err // network errors and timeouts are transient
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, resp.StatusCode >= 500, fmt.Errorf("HTTP %d from %s", resp.StatusCode, url)
	}
	body, err = io.ReadAll(io.LimitReader(resp.Body, f.maxFileSize))
	if err != nil {
		return nil, true, err
	}
	return body, false, nil
}
