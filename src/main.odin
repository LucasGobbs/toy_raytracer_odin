package main

import raytracer "raytracer"
import scene_data "scene"

main :: proc() {
	scene := scene_data.complex_scene()
	defer scene_data.scene_destroy(&scene)

	raytracer_data := raytracer.init(
		image_upscale = 4.0,
		image_width = 1000.0,
		ratio = scene.camera.ratio,
		color_format = 4,
	)
	cam_params, world := raytracer.load_from_scene(&scene)
	defer raytracer.world_destroy(&world)

	pixels := make([]u8, raytracer_data.buffer_size)
	defer delete(pixels)

	interactive_preview(
		&cam_params,
		&world,
		&raytracer_data,
		pixels,
		cast(f64)raytracer_data.image_upscale,
	)
}
