package raytracer

World :: struct {
	spheres: #soa[dynamic]Sphere,
}

world_create :: proc(capacity: int = 50) -> World {
	return World{}
}

world_append_sphere :: proc(world: ^World, object: Sphere) {
	append_soa(&world.spheres, object)
}

world_destroy :: proc(world: ^World) {
	delete(world.spheres)
}
