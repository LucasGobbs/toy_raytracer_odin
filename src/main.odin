package main

import "core:c"
import "core:fmt"
import "core:math/rand"
import "core:thread"
import "core:time"
import "utils"
import rl "vendor:raylib"

main :: proc() {

	image_upscale := 2.0
	cam := camera_create(
		ratio = 16.0 / 9.0,
		image_width = 1600.0 / image_upscale,
		position = Point3{-2, 2, 1},
		look_at = Point3{.0, .0, -1.5},
		max_depth = 50,
		samples = 100,
		defocus_angle = 1.0,
		focus_dist = 3.4,
		vfov = 50,
	)
	pixels := make([]u8, int(cam.image_width * cam.image_height * 4))
	defer delete(pixels)

	world := world_create(60)
	defer world_destroy(&world)
	world_append_sphere(
		&world,
		Sphere {
			center = Point3{-1.1, .0, -1.5},
			radius = .5,
			material = DieletricMaterial{refraction_index = 1.5},
		},
	)
	world_append_sphere(
		&world,
		Sphere {
			center = Point3{-1.1, .0, -1.5},
			radius = .4,
			material = DieletricMaterial{refraction_index = 1.0 / 1.5},
		},
	)
	world_append_sphere(
		&world,
		Sphere {
			center = Point3{.0, .0, -1.5},
			radius = .5,
			material = LambertianMaterial{albedo = Color{.8, .3, .3}},
		},
	)
	world_append_sphere(
		&world,
		Sphere {
			center = Point3{2.1, .0, -1.5},
			radius = 1.0,
			material = MetalMaterial{albedo = Color{.9, .2, .1}, fuzz = .001},
		},
	)
	world_append_sphere(
		&world,
		Sphere {
			center = Point3{.0, -100.5, -1},
			radius = 100.0,
			material = MetalMaterial{albedo = Color{.4, .4, .4}},
		},
	)

	for i in -5 ..< 5 {
		for j in -5 ..< 5 {
			random_sphere := sphere_random(
				center = utils.Interval(f64){-0.5, 0.5},
				radius = utils.Interval(f64){.05, .2},
			)
			random_sphere.center += Vec3{cast(f64)i, .0, cast(f64)j}
			world_append_sphere(&world, random_sphere)
		}
	}

	interactive_preview(cam, &world, pixels, image_upscale)
}
