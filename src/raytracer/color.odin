package raytracer
import "core:fmt"
import "core:math"
import "core:math/rand"
Color :: Vec3
Black :: Color{.0, .0, .0}
Red :: Color{1.0, .0, .0}
Green :: Color{.0, 1.0, .0}
Blue :: Color{.0, .0, 1.0}
White :: Color{1.0, 1.0, 1.0}
color_random :: proc() -> Color {return Color{rand.float64(), rand.float64(), rand.float64()}}
color_to_buffer :: proc(color: Color, index: int, buffer: []u8) {
	red := linear_to_gamma(color.r)
	green := linear_to_gamma(color.g)
	blue := linear_to_gamma(color.b)


	buffer[index + 0] = cast(u8)(255.999 * math.clamp(red, 0.000, 0.999))
	buffer[index + 1] = cast(u8)(255.999 * math.clamp(green, 0.000, 0.999))
	buffer[index + 2] = cast(u8)(255.999 * math.clamp(blue, 0.000, 0.999))
	buffer[index + 3] = 255
}

linear_to_gamma :: proc(component: f64) -> f64 {
	if component > .0 {
		return math.sqrt(component)
	}
	return .0
}
