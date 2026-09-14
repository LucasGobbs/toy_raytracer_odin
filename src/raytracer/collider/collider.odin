package collider

ColliderSpace :: struct {
	objects:  #soa[dynamic]SphereCollider,
	bbox:     Aabb,
	grouping: Grouping,
}

HitRecord :: struct {
	position:     Point3,
	normal:       Vec3,
	t:            f64,
	front_face:   bool,
	object_index: int,
}

set_front_face :: proc(ray: Ray, outward_normal: Vec3) -> (Vec3, bool) {
	front_face := vec_dot(ray.direction, outward_normal) < .0
	normal := front_face ? outward_normal : -outward_normal
	return normal, front_face
}

space_create :: proc() -> ColliderSpace {
	return ColliderSpace{bbox = Aabb{}, grouping = LinearGrouping{}}
}

space_append_sphere :: proc(space: ^ColliderSpace, sphere: SphereCollider) {
	space.bbox = aabb_create(space.bbox, sphere.bbox)
	append_soa(&space.objects, sphere)
}

space_destroy :: proc(space: ^ColliderSpace) {
	delete(space.objects)
	grouping_destroy(&space.grouping)
}
