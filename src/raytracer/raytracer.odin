package raytracer
import "core:math"
RaytracerParams :: struct {
	image_upscale: f64,
	image_width:   f64,
	image_height:  f64,
	color_format:  u8,
	// samples:       int,
	// max_depth:     int,
	buffer_size:   int,
}

init :: proc(
	image_upscale: f64 = 1.0,
	image_width: f64 = 1600.0,
	ratio: f64 = 16.0 / 9.0,
	color_format: u8 = 4.0,
) -> RaytracerParams {
	image_width := image_width / image_upscale
	image_height := math.floor(image_width / ratio)
	image_height = image_height < 1.0 ? 1.0 : image_height
	return RaytracerParams {
		image_upscale = image_upscale,
		image_width = image_width,
		image_height = image_height,
		color_format = color_format,
		buffer_size = int(image_width) * int(image_height) * int(color_format),
	}
}
