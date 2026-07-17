# DEG Network Policy — Demand Flex
#
# Canonical source: specification/policies/demand-flex-networkpolicy.rego
# This file is a copy. Keep in sync.
#
# Network-level gate evaluated by the BPP's `checkPolicy` step.
# Fires NACK when `violations` is non-empty.
#
# The `violations` rule combines two checks:
#
#   1. BecknTimeSeries cross-field type-coverage. Every `payloadType`
#      used in `intervals[*].payloads[*].type` MUST be declared in
#      `payloadDescriptors[*].payloadType`. Catches typos like
#      "BASELIN" or undocumented signals on the wire.
#
#   2. PER_EVENT / PER_INTERVAL cardinality against the seller's
#      committed `reportDescriptors[]` from the offer block:
#        PER_EVENT  — payloadType MUST appear in EXACTLY ONE interval
#                     of the meter's BecknTimeSeries (interval 0 by
#                     convention). Used for GPS_LAT, GPS_LON, etc.
#        PER_INTERVAL — payloadType MUST appear in EVERY interval.
#                     Used for BASELINE, USAGE, POWER, SOC_END.
#      Cardinality self-skips when no `reportDescriptors` are on the
#      wire (e.g. a status round-trip carrying only commitment ids,
#      or a grid-meter-only on_status whose meter doesn't declare the
#      vendor payload types in its own `payloadDescriptors`).

package deg.policy.demand_flex_network

import rego.v1

# ----- helpers --------------------------------------------------------

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

# ----- 1) cross-field type-coverage -----------------------------------

violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	declared_types := {d.payloadType | some d in meter.telemetry.payloadDescriptors}
	some interval in meter.telemetry.intervals
	some payload in interval.payloads
	not payload.type in declared_types
	msg := sprintf("meter %s: payload type '%s' used in intervals but not declared in payloadDescriptors", [meter.meterId, payload.type])
}

# ----- 1b) DemandFlexNeed cross-field type-coverage -------------------
# The unified DemandFlexNeed is itself a BecknTimeSeries (carried inline in
# resourceAttributes). The beckn-onix extended schema validator resolves only a
# single @type per object, so it cannot also validate the object against the
# TimeSeries schema — the same structural check (1) is therefore enforced here
# for the need series. Any resourceAttributes carrying `intervals` is treated as
# the need TimeSeries; applies to both the bound contract and catalog publish.
# A need with intervals but no payloadDescriptors flags every used type.

_demand_flex_needs contains ra if {
	some c in input.message.contract.commitments
	some r in c.resources
	ra := r.resourceAttributes
	ra.intervals
}

_demand_flex_needs contains ra if {
	some cat in input.message.catalogs
	some r in cat.resources
	ra := r.resourceAttributes
	ra.intervals
}

violations contains msg if {
	some ra in _demand_flex_needs
	declared_types := {d.payloadType | some d in ra.payloadDescriptors}
	some interval in ra.intervals
	some payload in interval.payloads
	not payload.type in declared_types
	msg := sprintf("DemandFlexNeed: payload type '%s' used in intervals but not declared in payloadDescriptors", [payload.type])
}

# ----- 2a) PER_EVENT — exactly one occurrence across intervals --------

violations contains msg if {
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

# ----- 2b) PER_INTERVAL — present in every interval -------------------

violations contains msg if {
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
