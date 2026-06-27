// Package main provides the plugin entry point for the VC Validator
// middleware. Compiled as a Go plugin (.so) and loaded by beckn-onix at
// runtime.
package main

import (
	"context"
	"net/http"

	vcvalidator "github.com/beckn-one/deg/plugins/vcvalidator"
)

type provider struct{}

func (p provider) New(ctx context.Context, cfg map[string]string) (func(http.Handler) http.Handler, error) {
	return vcvalidator.NewMiddleware(cfg)
}

// Provider is the exported symbol that the beckn-onix plugin manager looks up.
var Provider = provider{}
