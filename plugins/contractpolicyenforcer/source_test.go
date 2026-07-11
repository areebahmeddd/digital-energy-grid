package contractpolicyenforcer

// Tests for policy source resolution: bare rego, DeDi record indirection,
// checksum verification, retry behavior, and the policy cache built on top.
// All HTTP traffic goes to local httptest servers.

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

const testRego = `package deg.contracts.p2p_trading

revenue_flows := [{"role": "seller", "value": 100}]
`

func testFetcher() *sourceFetcher {
	return &sourceFetcher{timeout: 2 * time.Second, maxFileSize: 1 << 20, retries: 2}
}

// fastBackoff shrinks the retry backoff for the duration of a test.
func fastBackoff(t *testing.T) {
	t.Helper()
	orig := retryBaseBackoff
	retryBaseBackoff = time.Millisecond
	t.Cleanup(func() { retryBaseBackoff = orig })
}

// serve returns an httptest server responding with body and a request counter.
func serve(t *testing.T, status int, body string) (*httptest.Server, *atomic.Int32) {
	t.Helper()
	var count atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count.Add(1)
		w.WriteHeader(status)
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return srv, &count
}

// dediBody builds a DeDi lookup response whose data.details carries the
// given dataset fields.
func dediBody(t *testing.T, details map[string]string) string {
	t.Helper()
	b, err := json.Marshal(map[string]interface{}{
		"message": "Resource retrieved successfully",
		"data":    map[string]interface{}{"details": details},
	})
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func sha256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

// ---------------------------------------------------------------------------
// ResolvePolicy — source shapes
// ---------------------------------------------------------------------------

func TestResolvePolicy_BareRego(t *testing.T) {
	srv, _ := serve(t, http.StatusOK, testRego)
	src, err := testFetcher().ResolvePolicy(context.Background(), srv.URL)
	if err != nil {
		t.Fatalf("ResolvePolicy: %v", err)
	}
	if src != testRego {
		t.Errorf("source = %q, want the served rego", src)
	}
}

func TestResolvePolicy_DediInline(t *testing.T) {
	srv, _ := serve(t, http.StatusOK, dediBody(t, map[string]string{"data_inline": testRego}))
	src, err := testFetcher().ResolvePolicy(context.Background(), srv.URL)
	if err != nil {
		t.Fatalf("ResolvePolicy: %v", err)
	}
	if src != testRego {
		t.Errorf("source = %q, want inline rego", src)
	}
}

func TestResolvePolicy_DediDataURL(t *testing.T) {
	regoSrv, _ := serve(t, http.StatusOK, testRego)
	dediSrv, _ := serve(t, http.StatusOK, dediBody(t, map[string]string{"data_url": regoSrv.URL}))
	src, err := testFetcher().ResolvePolicy(context.Background(), dediSrv.URL)
	if err != nil {
		t.Fatalf("ResolvePolicy: %v", err)
	}
	if src != testRego {
		t.Errorf("source = %q, want rego fetched via data_url", src)
	}
}

func TestResolvePolicy_DediBothSetIsError(t *testing.T) {
	srv, _ := serve(t, http.StatusOK, dediBody(t, map[string]string{
		"data_url": "https://example.com/x.rego", "data_inline": testRego,
	}))
	_, err := testFetcher().ResolvePolicy(context.Background(), srv.URL)
	if err == nil || !strings.Contains(err.Error(), "exactly one of data_url and data_inline") {
		t.Errorf("want 'exactly one of data_url and data_inline' error, got %v", err)
	}
}

func TestResolvePolicy_DediNeitherSetIsError(t *testing.T) {
	srv, _ := serve(t, http.StatusOK, dediBody(t, map[string]string{"name": "empty-record"}))
	_, err := testFetcher().ResolvePolicy(context.Background(), srv.URL)
	if err == nil || !strings.Contains(err.Error(), "exactly one of data_url and data_inline") {
		t.Errorf("want 'exactly one of data_url and data_inline' error, got %v", err)
	}
}

func TestResolvePolicy_DataURLNotAccessible(t *testing.T) {
	deadSrv, _ := serve(t, http.StatusNotFound, "gone")
	dediSrv, _ := serve(t, http.StatusOK, dediBody(t, map[string]string{"data_url": deadSrv.URL}))
	_, err := testFetcher().ResolvePolicy(context.Background(), dediSrv.URL)
	if err == nil || !strings.Contains(err.Error(), "data_url not accessible") {
		t.Errorf("want 'data_url not accessible' error, got %v", err)
	}
}

// ---------------------------------------------------------------------------
// Checksum verification
// ---------------------------------------------------------------------------

func TestResolvePolicy_ChecksumOK(t *testing.T) {
	regoSrv, _ := serve(t, http.StatusOK, testRego)
	dediSrv, _ := serve(t, http.StatusOK, dediBody(t, map[string]string{
		"data_url":               regoSrv.URL,
		"data_url_checksum":      "0x" + strings.ToUpper(sha256Hex(testRego)), // prefix + case tolerated
		"data_url_checksum_type": "sha256",
	}))
	src, err := testFetcher().ResolvePolicy(context.Background(), dediSrv.URL)
	if err != nil {
		t.Fatalf("ResolvePolicy: %v", err)
	}
	if src != testRego {
		t.Errorf("source = %q", src)
	}
}

func TestResolvePolicy_ChecksumMismatch(t *testing.T) {
	regoSrv, _ := serve(t, http.StatusOK, testRego)
	dediSrv, _ := serve(t, http.StatusOK, dediBody(t, map[string]string{
		"data_url":               regoSrv.URL,
		"data_url_checksum":      sha256Hex("something else"),
		"data_url_checksum_type": "sha256",
	}))
	_, err := testFetcher().ResolvePolicy(context.Background(), dediSrv.URL)
	if err == nil || !strings.Contains(err.Error(), "mismatch") {
		t.Errorf("want checksum mismatch error, got %v", err)
	}
}

func TestVerifyChecksum_AlgosAndErrors(t *testing.T) {
	data := []byte(testRego)
	// Every algorithm the DeDi dataset schema allows must be supported.
	for _, algo := range []string{"sha256", "sha384", "sha512", "sha1", "md5"} {
		if err := verifyChecksum(data, algo, "00"); err == nil || !strings.Contains(err.Error(), "mismatch") {
			t.Errorf("%s: want mismatch error, got %v", algo, err)
		}
	}
	if err := verifyChecksum(data, "crc32", "00"); err == nil || !strings.Contains(err.Error(), "unsupported") {
		t.Errorf("want unsupported algorithm error, got %v", err)
	}
	if err := verifyChecksum(data, "sha256", ""); err == nil || !strings.Contains(err.Error(), "empty") {
		t.Errorf("want empty checksum error, got %v", err)
	}
}

// ---------------------------------------------------------------------------
// Retry behavior
// ---------------------------------------------------------------------------

func TestFetch_RetriesTransientThenSucceeds(t *testing.T) {
	fastBackoff(t)
	var count atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if count.Add(1) <= 2 { // first two attempts fail transiently
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		_, _ = w.Write([]byte(testRego))
	}))
	t.Cleanup(srv.Close)

	src, err := testFetcher().ResolvePolicy(context.Background(), srv.URL) // retries: 2
	if err != nil {
		t.Fatalf("expected success after retries, got %v", err)
	}
	if src != testRego || count.Load() != 3 {
		t.Errorf("source ok=%v, attempts=%d (want 3)", src == testRego, count.Load())
	}
}

func TestFetch_ExhaustsRetries(t *testing.T) {
	fastBackoff(t)
	srv, count := serve(t, http.StatusInternalServerError, "boom")
	_, err := testFetcher().ResolvePolicy(context.Background(), srv.URL)
	if err == nil || !strings.Contains(err.Error(), "after 3 attempts") {
		t.Errorf("want 'after 3 attempts' error, got %v", err)
	}
	if count.Load() != 3 {
		t.Errorf("attempts = %d, want 3 (1 + 2 retries)", count.Load())
	}
}

func TestFetch_NoRetryOn4xx(t *testing.T) {
	fastBackoff(t)
	srv, count := serve(t, http.StatusNotFound, "gone")
	_, err := testFetcher().ResolvePolicy(context.Background(), srv.URL)
	if err == nil {
		t.Fatal("expected error")
	}
	if count.Load() != 1 {
		t.Errorf("attempts = %d, want 1 (404 is not retryable)", count.Load())
	}
}

// ---------------------------------------------------------------------------
// PolicyCache — positive and negative caching
// ---------------------------------------------------------------------------

func cacheForTest(t *testing.T) *PolicyCache {
	t.Helper()
	return NewPolicyCache(&Config{
		MaxCacheEntries:    10,
		CacheTTL:           MinCacheTTL,
		PolicyFetchTimeout: 2 * time.Second,
		MaxPolicySize:      1 << 20,
		FetchRetries:       0,
	})
}

func TestCache_SecondCallServedFromCache(t *testing.T) {
	srv, count := serve(t, http.StatusOK, testRego)
	cache := cacheForTest(t)
	query := "data.deg.contracts.p2p_trading"

	for i := 0; i < 2; i++ {
		if _, err := cache.GetOrCompile(context.Background(), srv.URL, query); err != nil {
			t.Fatalf("call %d: %v", i+1, err)
		}
	}
	if count.Load() != 1 {
		t.Errorf("fetches = %d, want 1 (second call must hit the cache)", count.Load())
	}
}

func TestCache_NegativeCachePreventsRefetch(t *testing.T) {
	srv, count := serve(t, http.StatusNotFound, "gone")
	cache := cacheForTest(t)

	_, err1 := cache.GetOrCompile(context.Background(), srv.URL, "data.x")
	_, err2 := cache.GetOrCompile(context.Background(), srv.URL, "data.x")
	if err1 == nil || err2 == nil {
		t.Fatal("expected both calls to fail")
	}
	if !strings.Contains(err2.Error(), "cached failure") {
		t.Errorf("second error should be the cached failure, got %v", err2)
	}
	if count.Load() != 1 {
		t.Errorf("fetches = %d, want 1 (failure must be negative-cached)", count.Load())
	}
}
