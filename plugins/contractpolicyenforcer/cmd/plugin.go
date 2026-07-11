// Package main provides the plugin entry point for the ContractPolicyEnforcer step.
// Compiled as a Go plugin (.so) and loaded by beckn-onix at runtime.
//
// Wire it as a pipeline Step and list it BEFORE validateSchema and sign so
// the injected flows are part of the payload that gets validated and signed:
//
//   steps:
//     - contractpolicyenforcer
//     - validateSchema
//     - checkPolicy
//     - addRoute
//     - sign
package main

import (
	"context"

	"github.com/beckn-one/beckn-onix/pkg/plugin/definition"
	contractpolicyenforcer "github.com/beckn-one/deg/plugins/contractpolicyenforcer"
)

// provider implements the StepProvider interface for plugin loading.
type provider struct{}

// New creates a new ContractPolicyEnforcer step instance.
// It returns the step, a cleanup function, and any error.
func (p provider) New(ctx context.Context, cfg map[string]string) (definition.Step, func(), error) {
	step, err := contractpolicyenforcer.New(cfg)
	if err != nil {
		return nil, nil, err
	}
	return step, step.Close, nil
}

// Provider is the exported symbol that beckn-onix plugin manager looks up.
// It must be a package-level variable named "Provider".
var Provider = provider{}
