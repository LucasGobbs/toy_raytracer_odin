
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

contains :: #force_inline proc(
	interval: Interval($T),
	value: T,
) where intrinsics.type.type_is_comparable->bool {
	return interval.min <= value && value <= interval.max
}

surrounds :: #force_inline proc(
	interval: Interval($T),
	value: T,
) where intrinsics.type.type_is_comparable->bool {
	return interval.min < value && value < interval.max
}

clamp :: #force_inline proc(
	interval: Interval($T),
	value: T,
) where intrinsics.type.type_is_comparable->T {
	if value < interval.min do return interval.min
	if value > interval.max do return interval.max
	return value
}

expand :: #force_inline proc(
	interval: Interval($T),
	delta: T,
) where intrinsics.type.type_is_numeric->Interval(T) {
	padding := delta / 2.0
	return Interval(T){min = interval.min - padding, max = interval.max + padding}
}
