package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:time"
import rayt "raytracer"
import collider "raytracer/collider"
import "utils"
import rl "vendor:raylib"

clamp_unit :: #force_inline proc(v: f64) -> f64 {
	return v < 0 ? 0 : (v > 1 ? 1 : v)
}

albedo_to_rl :: #force_inline proc(col: rayt.Color) -> rl.Color {
	return rl.Color {
		u8(clamp_unit(col.r) * 255),
		u8(clamp_unit(col.g) * 255),
		u8(clamp_unit(col.b) * 255),
		255,
	}
}

preview_color :: proc(material: rayt.Material) -> rl.Color {
	switch m in material {
	case rayt.LambertianMaterial:
		return albedo_to_rl(m.albedo)
	case rayt.MetalMaterial:
		return albedo_to_rl(m.albedo)
	case rayt.DieletricMaterial:
		return rl.Color{150, 220, 255, 255} // glass
	case:
		return rl.MAGENTA // unknown material: impossible to miss
	}
}

draw_world :: proc(world: ^rayt.World) {
	for i in 0 ..< len(world.space.objects) {
		radius := cast(f32)world.space.objects.radius[i]
		center := rl.Vector3 {
			cast(f32)world.space.objects.origin[i].x,
			cast(f32)world.space.objects.origin[i].y,
			cast(f32)world.space.objects.origin[i].z,
		}
		color := preview_color(world.materials[i])
		switch {
		case radius >= 10:
			// giant ground sphere: wireframe only, otherwise it hides everything
			rl.DrawSphereWires(center, radius, 16, 16, color)
		case radius < 0.3:
			// cheap: the scattered mini-spheres don't need tessellation
			rl.DrawCubeV(center, rl.Vector3{2 * radius, 2 * radius, 2 * radius}, color)
		case:
			rl.DrawSphere(center, radius, color)
			rl.DrawSphereWires(center, radius, 16, 16, rl.BLACK)
		}
	}
	rl.DrawGrid(40, 1.0)
}

// Marks where the ray tracer's camera is, what it looks at, and its image plane.
draw_tracer_camera :: proc(cam: rayt.Camera) {
	p := rl.Vector3{cast(f32)cam.position.x, cast(f32)cam.position.y, cast(f32)cam.position.z}
	l := rl.Vector3{cast(f32)cam.look_at.x, cast(f32)cam.look_at.y, cast(f32)cam.look_at.z}
	rl.DrawCubeV(p, rl.Vector3{0.3, 0.3, 0.3}, rl.YELLOW)
	rl.DrawLine3D(p, l, rl.YELLOW)

	// viewport rectangle from the stored pixel deltas
	du := cam.pixel_delta_u
	dv := cam.pixel_delta_v
	c := [4]rayt.Vec3 {
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


UI_PANEL_W: f32 : 260

UI_LABEL_W: f32 : 70

// draw the row's name label and value echo; the slider itself gets no embedded
// text, raygui's own textLeft area clips it at this width
ui_row_frame :: proc(y: f32, label, value_text: cstring) {
	rl.GuiLabel(rl.Rectangle{x = 10, y = y, width = UI_LABEL_W, height = 20}, label)
	rl.GuiLabel(rl.Rectangle{x = UI_PANEL_W - 75, y = y, width = 70, height = 20}, value_text)
}

ui_f64 :: proc(y: ^f32, label: cstring, value: ^f64, min, max: f32) -> bool {
	v := cast(f32)value^
	old := v
	rl.GuiSlider(
		rl.Rectangle {
			x = 10 + UI_LABEL_W,
			y = y^,
			width = UI_PANEL_W - UI_LABEL_W - 90,
			height = 20,
		},
		nil,
		nil,
		&v,
		min,
		max,
	)
	buf: [64]u8
	s := cast(string)fmt.bprintf(buf[:], "%.2f", v)
	if len(s) < len(buf) {
		buf[len(s)] = 0
	}
	ui_row_frame(y^, label, cstring(raw_data(buf[:])))
	y^ += 26
	value^ = cast(f64)v
	return old != v
}

ui_int :: proc(y: ^f32, label: cstring, value: ^int, min, max: f32) -> bool {
	v := cast(f32)value^
	old := v
	rl.GuiSlider(
		rl.Rectangle {
			x = 10 + UI_LABEL_W,
			y = y^,
			width = UI_PANEL_W - UI_LABEL_W - 90,
			height = 20,
		},
		nil,
		nil,
		&v,
		min,
		max,
	)
	v = math.floor(v + 0.5)
	buf: [64]u8
	s := cast(string)fmt.bprintf(buf[:], "%d", cast(int)v)
	if len(s) < len(buf) {
		buf[len(s)] = 0
	}
	ui_row_frame(y^, label, cstring(raw_data(buf[:])))
	y^ += 26
	value^ = cast(int)v
	return old != v
}

// raygui panel with the camera settings; returns true when anything changed
draw_camera_ui :: proc(params: ^rayt.CamParams) -> bool {
	changed := false
	rl.GuiPanel(rl.Rectangle{x = 0, y = 0, width = UI_PANEL_W, height = 400}, "Camera")
	y: f32 = 36
	changed = ui_f64(&y, "pos.x", &params.position.x, -10, 10) || changed
	changed = ui_f64(&y, "pos.y", &params.position.y, -10, 10) || changed
	changed = ui_f64(&y, "pos.z", &params.position.z, -10, 10) || changed
	changed = ui_f64(&y, "look.x", &params.look_at.x, -10, 10) || changed
	changed = ui_f64(&y, "look.y", &params.look_at.y, -10, 10) || changed
	changed = ui_f64(&y, "look.z", &params.look_at.z, -10, 10) || changed
	changed = ui_f64(&y, "vfov", &params.vfov, 1, 120) || changed
	changed = ui_f64(&y, "defocus", &params.defocus_angle, 0, 10) || changed
	changed = ui_f64(&y, "focus", &params.focus_dist, 0.1, 20) || changed
	changed = ui_int(&y, "samples", &params.samples, 1, 500) || changed
	changed = ui_int(&y, "max_depth", &params.max_depth, 1, 50) || changed
	rl.GuiLabel(
		rl.Rectangle{x = 10, y = y, width = UI_PANEL_W - 20, height = 20},
		"tweak sliders, then SPACE",
	)
	return changed
}

// Writes the rendered frame as a NEW png every time. The nanosecond suffix
// makes overwrites impossible; name carries scene, grouping and render time.
save_render :: proc(
	image: rl.Image,
	scene_name: string,
	kind: collider.GroupingKind,
	elapsed: time.Duration,
) {
	millis := time.duration_milliseconds(elapsed)
	filename := fmt.ctprintf(
		"rendered/%s_%v_render_%.2fms_%d.png",
		scene_name,
		kind,
		millis,
		time.to_unix_nanoseconds(time.now()),
	)
	if rl.ExportImage(image, filename) {
		fmt.println("Saved render:", filename)
	} else {
		fmt.println("Could not save render:", filename)
	}
}

// 3D scene preview; SPACE runs the (blocking) raytraced render, BACKSPACE goes back.
interactive_preview :: proc(
	params: ^rayt.CamParams,
	world: ^rayt.World,
	raytracer_data: ^rayt.RaytracerParams,
	pixels: []u8,
	image_upscale: f64,
	scene_name: string,
	amount: int = 1, // renders per SPACE press; saved time = median of runs
	cores: int = 16,
) {
	amount := max(amount, 1)
	cam := rayt.build_camera(params, raytracer_data^)
	screen_width: c.int = cast(c.int)(cam.image_width * image_upscale)
	screen_height: c.int = cast(c.int)(cam.image_height * image_upscale)
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(screen_width, screen_height, "Ray Tracer Preview")
	if rl.GetMonitorCount() > 1 {
		rl.SetWindowMonitor(0)
	}
	rl.SetWindowPosition(0, 0)
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

	// orbit state: same view direction as the tracer camera, pulled back for an overview
	offset := cam.position - cam.look_at
	distance := cast(f32)rayt.vec_length(offset) * 3.5
	yaw := cast(f32)math.atan2(offset.z, offset.x)
	pitch := cast(f32)math.asin(cast(f64)offset.y / rayt.vec_length(offset))
	target := rl.Vector3{cast(f32)cam.look_at.x, cast(f32)cam.look_at.y, cast(f32)cam.look_at.z}

	raytraced := false
	elapsed: time.Duration
	for !rl.WindowShouldClose() {
		if !raytraced {
			orbiting_panel := rl.GetMousePosition().x < UI_PANEL_W
			if rl.IsMouseButtonDown(.LEFT) && !orbiting_panel {
				d := rl.GetMouseDelta()
				yaw -= d.x * 0.005
				pitch -= d.y * 0.005
				pitch = clamp(pitch, -1.5, 1.5)
			}
			distance -= rl.GetMouseWheelMove() * 0.8
			distance = clamp(distance, 1.0, 120.0)
		} else if rl.IsKeyPressed(.BACKSPACE) {
			raytraced = false
		}

		if rl.IsKeyPressed(.G) {
			current := collider.grouping_kind(world.space.grouping)
			next := collider.grouping_kind_next(current)
			start := time.tick_now()
			collider.grouping_build(&world.space, next)
			fmt.println("grouping:", next, "- built in", time.tick_since(start))
		}

		if rl.IsKeyPressed(.SPACE) {
			// flush a "Rendering..." frame before the blocking call
			rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.DrawText("Rendering...", 10, 10, 24, rl.ORANGE)
			rl.EndDrawing()

			runs := make([]time.Duration, amount)
			defer delete(runs)
			for run in 0 ..< amount {
				start := time.tick_now()
				rayt.renderer_render_threaded(raytracer_data^, cam, world, pixels, cores)
				runs[run] = time.tick_since(start)
				fmt.println("render", run + 1, "/", amount, ":", runs[run])
			}
			elapsed = utils.median_duration(runs)
			fmt.println("median:", elapsed)
			save_render(image, scene_name, collider.grouping_kind(world.space.grouping), elapsed)

			rl.UnloadTexture(texture)
			texture = rl.LoadTextureFromImage(image)
			rl.SetTextureFilter(texture, .POINT)
			raytraced = true
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
			fovy       = cast(f32)params.vfov,
			projection = .PERSPECTIVE,
		}

		rl.BeginDrawing()
		if raytraced {
			rl.ClearBackground(rl.BLACK)
			rl.DrawTextureEx(texture, rl.Vector2{0, 0}, 0, cast(f32)image_upscale, rl.WHITE)
		} else {
			rl.ClearBackground(rl.Color{25, 25, 35, 255})
			rl.BeginMode3D(cam3d)
			draw_world(world)
			draw_tracer_camera(cam)
			rl.EndMode3D()
			rl.DrawText(
				"DRAG: orbit  |  WHEEL: zoom  |  SPACE: raytrace  |  G: grouping",
				10,
				10,
				20,
				rl.RAYWHITE,
			)
			rl.DrawText(
				fmt.ctprintf(
					"spheres: %v   tracer_cam: %v   look_at: %v   last render: %v",
					len(world.space.objects),
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
		if !raytraced && draw_camera_ui(params) {
			cam = rayt.build_camera(params, raytracer_data^)
		}
		rl.EndDrawing()
	}
}
