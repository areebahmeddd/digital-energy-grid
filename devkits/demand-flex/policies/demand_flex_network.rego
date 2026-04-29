# DEG Network Policy — Demand Flex
#
# Network-level gate evaluated by the BPP's `checkPolicy` step.
# Fires NACK when violations is non-empty.
#
# Current rules:
#   - BecknTimeSeries cross-field type-coverage: every payload type used
#     in intervals[*].payloads[*].type MUST be declared in
#     payloadDescriptors[*].payloadType. Catches typos like "BASELIN" /
#     undocumented signals on the wire.
#
# Canonical source: specification/policies/demand_flex_network.rego

package deg.policy.demand_flex_network

import rego.v1

# Cross-field type-coverage check for every meter's telemetry.
# Iterates only over USED types — declared-but-unused is allowed (e.g. a
# pre-event report that ships full descriptors before USAGE is recorded).
violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	declared_types := {d.payloadType | some d in meter.telemetry.payloadDescriptors}
	some interval in meter.telemetry.intervals
	some payload in interval.payloads
	not payload.type in declared_types
	msg := sprintf("meter %s: payload type '%s' used in intervals but not declared in payloadDescriptors", [meter.meterId, payload.type])
}
