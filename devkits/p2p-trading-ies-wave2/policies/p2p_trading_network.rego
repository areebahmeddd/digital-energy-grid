# DEG Network Policy — P2P Trading (noop)
#
# Placeholder network policy for p2p-trading-ies-wave2 devkit.
# Imposes no additional network-level constraints. All messages pass.
#
# Replace with real rules as the P2P trading network matures.
# Canonical source: specification/policies/p2p_trading_network.rego

package deg.policy.p2p_trading_network

import rego.v1

# No violations — all messages pass.
violations := set()
