package raytracer

World :: struct {
	spheres: #soa[dynamic]Sphere,
	bbox:    Aabb,
}

world_create :: proc(capacity: int = 50) -> World {
	return World{bbox = Aabb{}}
}

world_append_sphere :: proc(world: ^World, object: Sphere) {
	world.bbox = aabb_create_from_bboxes(world.bbox, object.bbox)
	append_soa(&world.spheres, object)
}

world_destroy :: proc(world: ^World) {
	delete(world.spheres)
}
