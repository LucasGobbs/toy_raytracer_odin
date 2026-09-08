package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:time"
import rl "vendor:raylib"

clamp_unit :: #force_inline proc(v: f64) -> f64 {
	return v < 0 ? 0 : (v > 1 ? 1 : v)
}

albedo_to_rl :: #force_inline proc(col: Color) -> rl.Color {
	return rl.Color {
		u8(clamp_unit(col.r) * 255),
		u8(clamp_unit(col.g) * 255),
		u8(clamp_unit(col.b) * 255),
		255,
	}
}

preview_color :: proc(material: Material) -> rl.Color {
	switch m in material {
	case LambertianMaterial:
		return albedo_to_rl(m.albedo)
	case MetalMaterial:
		return albedo_to_rl(m.albedo)
	case DieletricMaterial:
		return rl.Color{150, 220, 255, 255} // glass
	case:
		return rl.MAGENTA // unknown material: impossible to miss
	}
}

draw_world :: proc(world: ^World) {
	for i in 0 ..< len(world.spheres) {
		radius := cast(f32)world.spheres.radius[i]
		center := rl.Vector3 {
			cast(f32)world.spheres.center[i].x,
			cast(f32)world.spheres.center[i].y,
			cast(f32)world.spheres.center[i].z,
		}
		color := preview_color(world.spheres.material[i])
		switch {
		case radius >= 10:
			// giant ground sphere: wireframe only, otherwise it hides everything
			rl.DrawSphereWires(center, radius, 16, 16, color)
		case radius < 0.3:
			// cheap: the 1600 scattered mini-spheres don't need tessellation
			rl.DrawCubeV(center, rl.Vector3{2 * radius, 2 * radius, 2 * radius}, color)
		case:
			rl.DrawSphere(center, radius, color)
			rl.DrawSphereWires(center, radius, 16, 16, rl.BLACK)
		}
	}
	rl.DrawGrid(40, 1.0)
}

// Marks where the ray tracer's camera is, what it looks at, and its image plane.
draw_tracer_camera :: proc(cam: Camera) {
	p := rl.Vector3{cast(f32)cam.position.x, cast(f32)cam.position.y, cast(f32)cam.position.z}
	l := rl.Vector3{cast(f32)cam.look_at.x, cast(f32)cam.look_at.y, cast(f32)cam.look_at.z}
	rl.DrawCubeV(p, rl.Vector3{0.3, 0.3, 0.3}, rl.YELLOW)
	rl.DrawLine3D(p, l, rl.YELLOW)

	// viewport rectangle from the stored pixel deltas
	du := cam.pixel_delta_u
	dv := cam.pixel_delta_v
	c := [4]Vec3 {
		cam.pixel00_location,
		cam.pixel00_location + du * cam.image_width,
		cam.pixel00_location + du * cam.image_width + dv * cam.image_height,
		cam.pixel00_location + dv * cam.image_height,
	}
	for k in 0 ..< 4 {
		a := rl.Vector3{cast(f32)c[k].x, cast(f32)c[k].y, cast(f32)c[k].z}
		b := rl.Vector3 {
			cast(f32)c[(k + 1) % 4].x,
			cast(f32)c[(k + 1) % 4].y,
			cast(f32)c[(k + 1) % 4].z,
		}
		rl.DrawLine3D(a, b, rl.SKYBLUE)
	}
}

// 3D scene preview; SPACE runs the (blocking) raytraced render, BACKSPACE goes back.
interactive_preview :: proc(
	cam: Camera,
	world: ^World,
	pixels: []u8,
	image_upscale: f64,
	cores: int = 16,
) {
	screen_width: c.int = cast(c.int)(cam.image_width * image_upscale)
	screen_height: c.int = cast(c.int)(cam.image_height * image_upscale)
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(screen_width, screen_height, "Ray Tracer Preview")
	if rl.GetMonitorCount() > 1 {
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

	// recover the tracer's vertical fov from its viewport geometry
	focal_length := vec_length(cam.position - cam.look_at)
	viewport_height := vec_length(cam.pixel_delta_v) * cam.image_height
	tracer_vfov_deg := cast(f32)(2 *
		math.atan(viewport_height / (2 * focal_length)) *
		180 /
		math.PI)

	// orbit state: same view direction as the tracer camera, pulled back for an overview
	offset := cam.position - cam.look_at
	distance := cast(f32)vec_length(offset) * 3.5
	yaw := cast(f32)math.atan2(offset.z, offset.x)
	pitch := cast(f32)math.asin(cast(f64)offset.y / vec_length(offset))
	target := rl.Vector3{cast(f32)cam.look_at.x, cast(f32)cam.look_at.y, cast(f32)cam.look_at.z}

	raytraced := false
	elapsed: time.Duration
	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.F12) {
			rl.TakeScreenshot(fmt.ctprintf("raypreview_%d.png", time.now()._nsec))
		}
		if !raytraced {
			if rl.IsMouseButtonDown(.LEFT) {
				d := rl.GetMouseDelta()
				yaw -= d.x * 0.005
				pitch -= d.y * 0.005
				pitch = clamp(pitch, -1.5, 1.5)
			}
			distance -= rl.GetMouseWheelMove() * 0.8
			distance = clamp(distance, 1.0, 120.0)

			if rl.IsKeyPressed(.SPACE) {
				// flush a "Rendering..." frame before the blocking call
				rl.BeginDrawing()
				rl.ClearBackground(rl.BLACK)
				rl.DrawText("Rendering...", 10, 10, 24, rl.ORANGE)
				rl.EndDrawing()

				start := time.tick_now()
				camera_render_threaded(cam, world, pixels, cores)
				elapsed = time.tick_since(start)
				fmt.println("Taked: ", elapsed)

				rl.UnloadTexture(texture)
				texture = rl.LoadTextureFromImage(image)
				rl.SetTextureFilter(texture, .POINT)
				raytraced = true
			}
		} else {
			if rl.IsKeyPressed(.BACKSPACE) {
				raytraced = false
			}
			if rl.IsKeyPressed(.SPACE) {
				raytraced = false // re-render path comes back through preview
			}
		}

		orb := rl.Vector3 {
			math.cos(pitch) * math.cos(yaw),
			math.sin(pitch),
			math.sin(yaw) * math.cos(pitch),
		}
		cam3d := rl.Camera3D {
			position   = target + orb * distance,
			target     = target,
			up         = rl.Vector3{0, 1, 0},
			fovy       = tracer_vfov_deg,
			projection = .PERSPECTIVE,
		}

		rl.BeginDrawing()
		if raytraced {
			rl.ClearBackground(rl.BLACK)
			rl.DrawTextureEx(texture, rl.Vector2{0, 0}, 0, cast(f32)image_upscale, rl.WHITE)
			rl.DrawText("BACKSPACE: back to preview  |  SPACE: re-render", 10, 10, 20, rl.RAYWHITE)
		} else {
			rl.ClearBackground(rl.Color{25, 25, 35, 255})
			rl.BeginMode3D(cam3d)
			draw_world(world)
			draw_tracer_camera(cam)
			rl.EndMode3D()
			rl.DrawText(
				"DRAG: orbit  |  WHEEL: zoom  |  SPACE: raytrace  |  F12: screenshot",
				10,
				10,
				20,
				rl.RAYWHITE,
			)
			rl.DrawText(
				fmt.ctprintf(
					"spheres: %v   tracer_cam: %v   look_at: %v   last render: %v",
					len(world.spheres),
					cam.position,
					cam.look_at,
					elapsed,
				),
				10,
				34,
				18,
				rl.LIGHTGRAY,
			)
		}
		rl.EndDrawing()
	}
}
