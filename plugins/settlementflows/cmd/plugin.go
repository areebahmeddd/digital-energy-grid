// Package main provides the plugin entry point for the SettlementFlows middleware.
// Compiled as a Go plugin (.so) and loaded by beckn-onix at runtime.
package main

import (
	"context"
	"net/http"

	settlementflows "github.com/beckn-one/deg/plugins/settlementflows"
)

type provider struct{}

func (p provider) New(ctx context.Context, cfg map[string]string) (func(http.Handler) http.Handler, error) {
	return settlementflows.NewMiddleware(cfg)
}

// Provider is the exported symbol that beckn-onix plugin manager looks up.
var Provider = provider{}
