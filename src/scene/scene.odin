package scene

import "../utils"
import "core:math/rand"

MaterialType :: enum {
	lambertian,
	metal,
	dielectric,
}

ObjectType :: enum {
	sphere,
}

SceneMaterial :: struct {
	kind:             MaterialType,
	albedo:           [3]f64,
	fuzz:             f64,
	refraction_index: f64,
}

SceneObject :: struct {
	type:      ObjectType,
	position:  [3]f64,
	direction: [3]f64,
	radius:    f64,
	material:  SceneMaterial,
}

SceneCamera :: struct {
	position:      [3]f64,
	look_at:       [3]f64,
	vfov:          f64,
	ratio:         f64,
	samples:       int,
	max_depth:     int,
	defocus_angle: f64,
	focus_dist:    f64,
}

Scene :: struct {
	camera:  SceneCamera,
	objects: [dynamic]SceneObject,
}

scene_destroy :: proc(scene: ^Scene) {
	delete(scene.objects)
}

scene_camera :: proc(
	position: [3]f64,
	look_at: [3]f64,
	vfov: f64,
	defocus_angle: f64,
	focus_dist: f64,
	samples: int,
	max_depth: int,
) -> SceneCamera {
	return SceneCamera {
		position = position,
		look_at = look_at,
		vfov = vfov,
		ratio = 16.0 / 9.0,
		samples = samples,
		max_depth = max_depth,
		defocus_angle = defocus_angle,
		focus_dist = focus_dist,
	}
}

scene_with_camera :: proc(camera: SceneCamera, capacity: int) -> Scene {
	return Scene{camera = camera, objects = make([dynamic]SceneObject, 0, capacity)}
}

append_ground :: proc(scene: ^Scene) {
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {0, -100.5, -1},
			direction = {.0, .0, .0},
			radius = 100.0,
			material = SceneMaterial{kind = .metal, albedo = {0.4, 0.4, 0.4}},
		},
	)
}

append_material_test_spheres :: proc(scene: ^Scene) {
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {-1.1, 0, -1.5},
			direction = {.0, .0, .0},
			radius = 0.5,
			material = SceneMaterial{kind = .dielectric, refraction_index = 1.5},
		},
	)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {-1.1, 0, -1.5},
			direction = {.0, .0, .0},
			radius = 0.4,
			material = SceneMaterial{kind = .dielectric, refraction_index = 1.0 / 1.5},
		},
	)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {0, 0, -1.5},
			direction = {.0, .0, .0},
			radius = 0.5,
			material = SceneMaterial{kind = .lambertian, albedo = {0.8, 0.3, 0.3}},
		},
	)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {2.1, 0, -1.5},
			direction = {.0, .0, .0},
			radius = 1.0,
			material = SceneMaterial{kind = .metal, albedo = {0.9, 0.2, 0.1}, fuzz = 0.001},
		},
	)
}

// basic_scene is a small, fast scene for checking camera and materials.
basic_scene :: proc() -> Scene {
	scene := scene_with_camera(scene_camera({0, 1, 4}, {0, 0, -1.5}, 45, 0, 5, 25, 10), 5)
	append_ground(&scene)
	append_material_test_spheres(&scene)
	return scene
}

// materials_scene isolates the three material types at different depths.
materials_scene :: proc() -> Scene {
	scene := scene_with_camera(scene_camera({0, 1, 5}, {0, 0, -3}, 40, 0, 6, 50, 20), 4)
	append_ground(&scene)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {-2, 0, -3},
			radius = 1,
			material = SceneMaterial{kind = .lambertian, albedo = {0.8, 0.2, 0.2}},
		},
	)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {0, 0, -3},
			radius = 1,
			material = SceneMaterial{kind = .metal, albedo = {0.8, 0.8, 0.8}, fuzz = 0.05},
		},
	)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {2, 0, -3},
			radius = 1,
			material = SceneMaterial{kind = .dielectric, refraction_index = 1.5},
		},
	)
	return scene
}

// defocus_scene puts objects at several depths to tune aperture and focus_dist.
defocus_scene :: proc() -> Scene {
	scene := scene_with_camera(scene_camera({0, 1.5, 4}, {0, 0, -3}, 40, 6, 5, 50, 20), 5)
	append_ground(&scene)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {-1.5, 0, -1},
			radius = 0.8,
			material = SceneMaterial{kind = .lambertian, albedo = {0.8, 0.2, 0.2}},
		},
	)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {0, 0, -3},
			radius = 0.8,
			material = SceneMaterial{kind = .metal, albedo = {0.8, 0.8, 0.8}, fuzz = 0.05},
		},
	)
	append(
		&scene.objects,
		SceneObject {
			type = .sphere,
			position = {1.5, 0, -6},
			radius = 0.8,
			material = SceneMaterial{kind = .dielectric, refraction_index = 1.5},
		},
	)
	return scene
}

// random_scene contains only the ground and a configurable random grid.
random_scene :: proc(grid_radius: int = 5) -> Scene {
	side := 2 * grid_radius
	capacity := side * side + 1
	scene := scene_with_camera(
		scene_camera({-2, 2, 1}, {0, 0, -1.5}, 50, 0.0, 3.4, 100, 50),
		capacity,
	)
	append_ground(&scene)
	append_random_grid(&scene, grid_radius)
	return scene
}

// complex_scene matches the original scene assembled in main.
complex_scene :: proc() -> Scene {
	scene := random_scene(5)
	append_material_test_spheres(&scene)
	return scene
}

append_random_grid :: proc(scene: ^Scene, grid_radius: int) {
	for i in -grid_radius ..< grid_radius {
		for j in -grid_radius ..< grid_radius {
			append(&scene.objects, random_sphere(i, j))
		}
	}
}

random_color :: proc() -> [3]f64 {
	return {rand.float64(), rand.float64(), rand.float64()}
}

random_sphere :: proc(i, j: int) -> SceneObject {
	material: SceneMaterial
	switch rand.int_max(3) {
	case 0:
		material = SceneMaterial {
			kind   = .lambertian,
			albedo = random_color(),
		}
	case 1:
		material = SceneMaterial {
			kind   = .metal,
			albedo = random_color(),
			fuzz   = rand.float64(),
		}
	case:
		material = SceneMaterial {
			kind             = .dielectric,
			refraction_index = rand.float64(),
		}
	}

	return SceneObject {
		type = .sphere,
		position = {
			cast(f64)i + utils.random_f64_between_values(-0.5, 0.5),
			utils.random_f64_between_values(-0.5, 0.5),
			cast(f64)j + utils.random_f64_between_values(-0.5, 0.5),
		},
		direction = {
			utils.random_f64_between_values(-0.0000001, 0.0000001),
			utils.random_f64_between_values(-0.0000001, 0.0000001),
			utils.random_f64_between_values(-0.0000001, 0.0000001),
		},
		radius = utils.random_f64_between_values(0.05, 0.2),
		material = material,
	}
}
