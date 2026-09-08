package utils
import "core:math/rand"

random_f64_between :: proc {
	random_f64_between_values,
	random_f64_between_interval,
}

random_f64_between_values :: #force_inline proc(min: f64, max: f64) -> f64 {
	rand_0_to_1 := rand.float64()
	delta := max - min

	return min + delta * rand_0_to_1
}

random_f64_between_interval :: #force_inline proc(interval: Interval(f64)) -> f64 {
	return random_f64_between_values(interval.min, interval.max)
}
