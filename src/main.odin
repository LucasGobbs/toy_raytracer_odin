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
		position = Point3{-4, 2, .8},
		look_at = Point3{0, 0, -1},
		max_depth = 25,
		samples = 15,
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
			center = Point3{.0, -50.5, 1},
			radius = 50.0,
			material = MetalMaterial{albedo = Color{.4, .4, .4}},
		},
	)

	for i in -20 ..< 20 {
		for j in -20 ..< 20 {
			material_idx := rand.float32()
			material: Material = ---
			if material_idx < .4 {
				material = MetalMaterial {
					albedo = color_random(),
					fuzz   = 0.0,
				}
			} else if material_idx <= .8 {
				material = LambertianMaterial {
					albedo = color_random(),
				}
			} else {
				material = DieletricMaterial {
					refraction_index = 1.5,
				}
			}
			world_append_sphere(
				&world,
				Sphere {
					center = Point3 {
						cast(f64)i + utils.random_f64_in_interval(-0.5, 0.5),
						utils.random_f64_in_interval(-.3, -.6),
						cast(f64)j + utils.random_f64_in_interval(-0.5, 0.5),
					},
					radius = utils.random_f64_in_interval(.05, .2),
					material = material,
				},
			)
		}
	}

	start := time.tick_now()
	cores := 16
	// camera_render_threaded(cam, &world, pixels, cores)
	elapsed := time.tick_since(start)

	fmt.println("Taked: ", elapsed)
	screen_width: c.int = cast(c.int)(cam.image_width * image_upscale)
	screen_height: c.int = cast(c.int)(cam.image_height * image_upscale)
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(screen_width, screen_height, "Odin Raylib Gradient")
	if (rl.GetMonitorCount() > 1) {
		rl.SetWindowMonitor(1)
	}
	defer rl.CloseWindow()

	image := rl.Image {
		data    = raw_data(pixels),
		width   = cast(c.int)cam.image_width,
		height  = cast(c.int)cam.image_height,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	texture := rl.LoadTextureFromImage(image)
	defer rl.UnloadTexture(texture)
	rl.SetTextureFilter(texture, .POINT)

	camera := rl.Camera{}
	camera.position = rl.Vector3{0.0, 10.0, 10.0}
	camera.target = rl.Vector3{0.0, 0.0, 0.0}
	camera.up = rl.Vector3{0.0, 1.0, 0.0}
	camera.fovy = 45.0
	camera.projection = rl.CameraProjection.PERSPECTIVE
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		// rl.DrawTexture(texture, 0, 0, rl.WHITE)
		rl.DrawTextureEx(texture, rl.Vector2{0, 0}, 0.0, cast(f32)image_upscale, rl.WHITE)
		rl.BeginMode3D(camera)
		rl.DrawSphere(rl.Vector3{-1.0, 0.0, -2.0}, 1.0, rl.GREEN)
		rl.EndMode3D()
		rl.EndDrawing()
	}
}
