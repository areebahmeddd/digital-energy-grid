# DEG Network Policy — P2P Trading (noop)
#
# Placeholder network policy for the inter-discom P2P trading network.
# Imposes no additional network-level constraints. All messages pass.
#
# Replace with real rules as the P2P trading network matures.

package deg.policy.p2p_trading_network

import rego.v1

# No violations — all messages pass.
violations := set()
