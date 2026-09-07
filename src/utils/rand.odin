package utils
import "core:math/rand"


random_f64_in_interval :: proc(min: f64, max: f64) -> f64 {
	rand_0_to_1 := rand.float64()
	delta := max - min

	return min + delta * rand_0_to_1
}
