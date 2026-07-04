package settlementflows

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/open-policy-agent/opa/v1/ast"
	"github.com/open-policy-agent/opa/v1/rego"
)

// negativeCacheTTL bounds how long a failed resolution is remembered. While
// a failure is cached, messages referencing that policy URL get the cached
// error instead of re-hitting DeDi / the data_url host on every message.
const negativeCacheTTL = 5 * time.Minute

// cacheEntry holds a compiled OPA query and its metadata.
type cacheEntry struct {
	pq        rego.PreparedEvalQuery
	query     string
	fetchedAt time.Time
}

// failEntry remembers a failed resolution (negative cache).
type failEntry struct {
	err      error
	failedAt time.Time
}

// PolicyCache is a TTL-based LRU cache for compiled rego policies, keyed by
// policy URL. Successful compiles live for the configured TTL; failures are
// remembered for negativeCacheTTL.
type PolicyCache struct {
	mu       sync.RWMutex
	entries  map[string]*cacheEntry
	failures map[string]*failEntry
	maxSize  int
	ttl      time.Duration
	fetcher  *sourceFetcher
}

// NewPolicyCache creates a new cache sized and timed from the plugin config.
func NewPolicyCache(cfg *Config) *PolicyCache {
	return &PolicyCache{
		entries:  make(map[string]*cacheEntry),
		failures: make(map[string]*failEntry),
		maxSize:  cfg.MaxCacheEntries,
		ttl:      cfg.CacheTTL,
		fetcher: &sourceFetcher{
			timeout:     cfg.PolicyFetchTimeout,
			maxFileSize: cfg.MaxPolicySize,
			retries:     cfg.FetchRetries,
		},
	}
}

// GetOrCompile returns a compiled query for the given policy URL and OPA query path.
// Resolves (DeDi lookup and/or rego fetch) and compiles on cache miss or TTL expiry.
func (c *PolicyCache) GetOrCompile(ctx context.Context, url, query string) (rego.PreparedEvalQuery, error) {
	c.mu.RLock()
	entry, ok := c.entries[url]
	fail, failed := c.failures[url]
	c.mu.RUnlock()

	if ok && entry.query == query && time.Since(entry.fetchedAt) < c.ttl {
		return entry.pq, nil
	}
	if failed && time.Since(fail.failedAt) < negativeCacheTTL {
		return rego.PreparedEvalQuery{}, fmt.Errorf("cached failure (retry after %s): %w",
			(negativeCacheTTL - time.Since(fail.failedAt)).Round(time.Second), fail.err)
	}

	return c.resolveAndCompile(ctx, url, query)
}

func (c *PolicyCache) resolveAndCompile(ctx context.Context, url, query string) (rego.PreparedEvalQuery, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Double-check both caches after acquiring the write lock.
	if entry, ok := c.entries[url]; ok && entry.query == query && time.Since(entry.fetchedAt) < c.ttl {
		return entry.pq, nil
	}
	if fail, ok := c.failures[url]; ok && time.Since(fail.failedAt) < negativeCacheTTL {
		return rego.PreparedEvalQuery{}, fail.err
	}

	pq, err := c.compile(ctx, url, query)
	if err != nil {
		c.failures[url] = &failEntry{err: err, failedAt: time.Now()}
		return rego.PreparedEvalQuery{}, err
	}

	// Evict oldest if at capacity.
	if len(c.entries) >= c.maxSize {
		var oldestKey string
		var oldestTime time.Time
		for k, v := range c.entries {
			if oldestKey == "" || v.fetchedAt.Before(oldestTime) {
				oldestKey = k
				oldestTime = v.fetchedAt
			}
		}
		if oldestKey != "" {
			delete(c.entries, oldestKey)
		}
	}

	delete(c.failures, url)
	c.entries[url] = &cacheEntry{pq: pq, query: query, fetchedAt: time.Now()}
	return pq, nil
}

// compile resolves the rego source behind url (bare file or DeDi record) and
// prepares the OPA query.
func (c *PolicyCache) compile(ctx context.Context, url, query string) (rego.PreparedEvalQuery, error) {
	source, err := c.fetcher.ResolvePolicy(ctx, url)
	if err != nil {
		return rego.PreparedEvalQuery{}, fmt.Errorf("resolve %s: %w", url, err)
	}

	compiler, err := ast.CompileModulesWithOpt(map[string]string{"policy.rego": source}, ast.CompileOpts{})
	if err != nil {
		return rego.PreparedEvalQuery{}, fmt.Errorf("compile %s: %w", url, err)
	}

	pq, err := rego.New(
		rego.Query(query),
		rego.Compiler(compiler),
	).PrepareForEval(ctx)
	if err != nil {
		return rego.PreparedEvalQuery{}, fmt.Errorf("prepare query %s: %w", query, err)
	}
	return pq, nil
}
