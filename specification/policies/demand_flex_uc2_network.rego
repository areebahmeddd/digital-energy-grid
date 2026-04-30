# DEG Network Policy — Demand Flex Vendor-Telemetry (UC2)
#
# Canonical source. The devkit at devkits/demand-flex/policies/
# demand_flex_uc2_network.rego is a copy of this file.
#
# Network-level gate evaluated by the BPP's `checkPolicy` step for the
# `nfh.global/testnet-deg-vendor` network. Adds two vendor-aware checks
# on top of UC1's type-coverage rule:
#
#   1. Cross-field type-coverage (carried over from UC1).
#   2. GPS-coherence: GPS only permitted when POWER != 0.
#   3. SOC-monotonicity within charge segments.

package deg.policy.demand_flex_uc2_network

import rego.v1

_payload_value(interval, ptype) := v if {
	some payload in interval.payloads
	payload.type == ptype
	v := payload.values[0]
}

violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	declared_types := {d.payloadType | some d in meter.telemetry.payloadDescriptors}
	some interval in meter.telemetry.intervals
	some payload in interval.payloads
	not payload.type in declared_types
	msg := sprintf("device %s: payload type '%s' used in intervals but not declared in payloadDescriptors",
		[meter.meterId, payload.type])
}

violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	some interval in meter.telemetry.intervals

	some payload in interval.payloads
	payload.type in {"GPS_LAT", "GPS_LON"}

	power_val := _payload_value(interval, "POWER")
	power_val == 0

	msg := sprintf("device %s interval %v: GPS reported while POWER == 0 — drop GPS or report non-zero POWER",
		[meter.meterId, interval.id])
}

violations contains msg if {
	some perf in input.message.contract.performance
	some meter in perf.performanceAttributes.meters
	intervals := meter.telemetry.intervals

	some i
	some j
	j == i + 1
	i_iv := intervals[i]
	j_iv := intervals[j]

	p_i := _payload_value(i_iv, "POWER")
	p_j := _payload_value(j_iv, "POWER")
	p_i > 0
	p_j > 0

	soc_i := _payload_value(i_iv, "SOC")
	soc_j := _payload_value(j_iv, "SOC")

	soc_j < soc_i

	msg := sprintf("device %s: SOC dropped from %g%% to %g%% across consecutive charging intervals (%v → %v)",
		[meter.meterId, soc_i, soc_j, i_iv.id, j_iv.id])
}
