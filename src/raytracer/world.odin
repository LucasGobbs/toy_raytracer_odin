package raytracer

import "collider"

// Holds the collision space and materials, in which, together represents the object geometry and looking
World :: struct {
	space:     collider.ColliderSpace,
	materials: [dynamic]Material, // same indexing as space.objects
}

world_create :: proc(capacity: int = 50) -> World {
	return World{space = collider.space_create()}
}

world_append_sphere :: proc(world: ^World, sphere: collider.SphereCollider, material: Material) {
	collider.space_append_sphere(&world.space, sphere)
	append(&world.materials, material)
}

world_append_quad :: proc(world: ^World, quad: collider.QuadCollider, material: Material) {
	collider.space_append_quad(&world.space, quad)
	append(&world.materials, material)
}

world_destroy :: proc(world: ^World) {
	collider.space_destroy(&world.space)
	delete(world.materials)
}
