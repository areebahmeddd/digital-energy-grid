# DEG Network Policy — Demand Flex
#
# Canonical source: specification/policies/demand_flex_network.rego
# This file is a copy. Keep in sync.
#
# Network-level gate evaluated by the BPP's `checkPolicy` step.
# Fires NACK when the queried rule's set is non-empty.
#
# Two query entry points share the same helpers:
#
#   - `violations` (UC1, also fallback for any networkId):
#       BecknTimeSeries cross-field type-coverage. Every `payloadType`
#       used in `intervals[*].payloads[*].type` MUST be declared in
#       `payloadDescriptors[*].payloadType`. Catches typos like
#       "BASELIN" or undocumented signals on the wire.
#
#   - `uc2_violations` (UC2 vendor-telemetry, opt-in via networkPolicy
#     query path): includes everything `violations` reports, plus
#     PER_EVENT / PER_INTERVAL cardinality enforcement against the
#     seller's committed `reportDescriptors[]` from the offer block.
#       PER_EVENT  — payloadType MUST appear in EXACTLY ONE interval
#                    of the meter's BecknTimeSeries (interval 0 by
#                    convention). Used for SOC_END, GPS_LAT, GPS_LON.
#       PER_INTERVAL — payloadType MUST appear in EVERY interval.
#                    Used for BASELINE, USAGE, POWER.
#     Self-skips cardinality when no offer block is on the wire (e.g.
#     the status round-trip carries only commitment ids), so this rule
#     also passes UC1 traffic that lacks a seller `reportDescriptors`
#     declaration.

package deg.policy.demand_flex_network

import rego.v1

# ----- helpers (UC2 cardinality) ---------------------------------------

_seller_descriptors := descs if {
	some perf_input in input.message.contract.commitments[0].offer.offerAttributes.inputs
	perf_input.role == "seller"
	descs := perf_input.inputs.reportDescriptors
}

_seller_descriptors := [] if {
	not _has_seller_inputs
}

_has_seller_inputs if {
	some perf_input in input.message.contract.commitments[0].offer.offerAttributes.inputs
	perf_input.role == "seller"
	perf_input.inputs.reportDescriptors
}

_per_event_types := {d.payloadType |
	some d in _seller_descriptors
	d.cardinality == "PER_EVENT"
}

_per_interval_types := {d.payloadType |
	some d in _seller_descriptors
	d.cardinality != "PER_EVENT"
}

_count_payloads(meter, ptype) := n if {
	rows := [1 |
		some interval in meter.telemetry.intervals
		some payload in interval.payloads
		payload.type == ptype
	]
	n := count(rows)
}

# ----- UC1: cross-field type-coverage ---------------------------------

violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	declared_types := {d.payloadType | some d in meter.telemetry.payloadDescriptors}
	some interval in meter.telemetry.intervals
	some payload in interval.payloads
	not payload.type in declared_types
	msg := sprintf("meter %s: payload type '%s' used in intervals but not declared in payloadDescriptors", [meter.meterId, payload.type])
}

# ----- UC2: superset — type-coverage + PER_EVENT/PER_INTERVAL ----------

uc2_violations contains msg if {
	some msg in violations
}

uc2_violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	some ptype in _per_event_types
	n := _count_payloads(meter, ptype)
	n != 1
	declared := {d.payloadType | some d in meter.telemetry.payloadDescriptors}
	ptype in declared
	msg := sprintf("device %s: PER_EVENT payload '%s' must appear in exactly 1 interval (found %d)",
		[meter.meterId, ptype, n])
}

uc2_violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	some ptype in _per_interval_types
	declared := {d.payloadType | some d in meter.telemetry.payloadDescriptors}
	ptype in declared
	total := count(meter.telemetry.intervals)
	hits := _count_payloads(meter, ptype)
	hits != total
	msg := sprintf("device %s: PER_INTERVAL payload '%s' must appear in every interval (found %d of %d)",
		[meter.meterId, ptype, hits, total])
}
