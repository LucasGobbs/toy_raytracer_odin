package raytracer
import "../utils"

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:sync"
import "core:thread"

Camera :: struct {
	ratio:            f64,
	image_width:      f64,
	image_height:     f64,
	center:           Point3,
	pixel00_location: Point3,
	pixel_delta_u:    Vec3,
	pixel_delta_v:    Vec3,
	samples:          int,
	max_depth:        int,
	position:         Point3,
	look_at:          Point3,

	// Lensing parameters
	defocus_angle:    f64,
	defocus_disk_u:   Vec3,
	defocus_disk_v:   Vec3,
}

camera_create :: proc(
	raytracer_params: RaytracerParams,
	ratio: f64 = 16.0 / 9.0,
	vfov: f64 = 60.0,
	position: Point3,
	look_at: Point3,
	samples: int = 25,
	max_depth: int = 2,
	defocus_angle: f64 = 0.0,
	focus_dist: f64 = 10.0,
) -> Camera {
	image_width := raytracer_params.image_width
	image_height := raytracer_params.image_height
	camera_center := position
	theta := utils.degrees_to_radians(vfov)
	h := math.tan(theta / 2.0)
	viewport_height := 2.0 * h * focus_dist
	viewport_width := viewport_height * image_width / image_height

	w := vec_unit(position - look_at)
	u := vec_unit(vec_cross(Vec3Up, w))
	v := vec_cross(w, u)

	viewport_u := viewport_width * u
	viewport_v := viewport_height * -v

	pixel_delta_u := viewport_u / image_width
	pixel_delta_v := viewport_v / image_height

	viewport_upper_left := camera_center - (focus_dist * w) - viewport_u / 2.0 - viewport_v / 2
	pixel00_location := viewport_upper_left + .5 * (pixel_delta_u + pixel_delta_v)

	defocus_radius := focus_dist * math.tan(utils.degrees_to_radians(defocus_angle / 2.0))

	camera := Camera {
		ratio            = ratio,
		image_width      = image_width,
		image_height     = image_height,
		center           = camera_center,
		pixel00_location = pixel00_location,
		pixel_delta_u    = pixel_delta_u,
		pixel_delta_v    = pixel_delta_v,
		samples          = samples,
		max_depth        = max_depth,
		position         = position,
		look_at          = look_at,
		defocus_angle    = defocus_angle,
		defocus_disk_u   = u * defocus_radius,
		defocus_disk_v   = v * defocus_radius,
	}

	return camera
}


camera_calculate_ray :: proc(cam: Camera, i: f64, j: f64) -> Ray {
	offset := Vec3{rand.float64() - .5, rand.float64() - .5, .0}
	pixel_sample := camera_calculate_pixel_coordinates(cam, i, j, offset)

	ray_origin := cam.defocus_angle <= .0 ? cam.center : camera_defocus_disk_sample(cam)

	sampled_ray := Ray {
		direction = pixel_sample - ray_origin,
		origin    = ray_origin,
		time      = rand.float64(),
	}

	return sampled_ray
}
camera_calculate_pixel_coordinates :: proc(
	cam: Camera,
	i: f64,
	j: f64,
	offset: Vec3 = Vec3{},
) -> Vec3 {
	return cam.pixel00_location + (i * cam.pixel_delta_u) + (j * cam.pixel_delta_v)
}

camera_defocus_disk_sample :: #force_inline proc(cam: Camera) -> Point3 {
	p := vec3_rand_in_unit_disk()
	return cam.center + (p.x * cam.defocus_disk_u) + (p.y * cam.defocus_disk_v)
}
