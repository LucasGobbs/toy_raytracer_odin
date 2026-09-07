
package utils
import "base:intrinsics"
import "core:math"
Interval :: struct($T: typeid) {
	min: T,
	max: T,
}

IntervalInfinityForward :: Interval(f64) {
	min = -math.F64_MAX,
	max = math.F64_MAX,
}

contains :: proc(interval: Interval($T), value: T) where intrinsics.type.type_is_comparable->bool {
	return interval.min <= value && value <= interval.max
}

surrounds :: proc(
	interval: Interval($T),
	value: T,
) where intrinsics.type.type_is_comparable->bool {
	return interval.min < value && value < interval.max
}
