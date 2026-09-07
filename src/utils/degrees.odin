package utils
import "core:math"

degrees_to_radians :: proc(degrees: f64) -> f64 {
	return degrees * math.PI / 180.0
}
