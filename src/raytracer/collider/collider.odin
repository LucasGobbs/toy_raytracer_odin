package collider
import "../../utils"

ColliderSpace :: struct {
	spheres:  #soa[dynamic]SphereCollider,
	quads:    #soa[dynamic]QuadCollider,
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
not_hitted :: #force_inline proc() -> (HitRecord, bool) {
	return HitRecord{}, false
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
	append_soa(&space.spheres, sphere)
}

space_append_quad :: proc(space: ^ColliderSpace, quad: QuadCollider) {
	space.bbox = aabb_create(space.bbox, quad.bbox)
	append_soa(&space.quads, quad)
}

space_destroy :: proc(space: ^ColliderSpace) {
	delete(space.spheres)
	delete(space.quads)
	grouping_destroy(&space.grouping)
}

primitive_count :: proc(space: ^ColliderSpace) -> int {
	return len(space.spheres) + len(space.quads)
}

hit_primitive :: proc(
	space: ^ColliderSpace,
	id: int,
	ray: Ray,
	ray_tmin, ray_tmax: f64,
) -> (
	HitRecord,
	bool,
) {
	sphere_amount := len(space.spheres)
	if id < sphere_amount {
		return hit_sphere(space.spheres[id], ray, ray_tmin, ray_tmax)
	}

	new_id := id - sphere_amount
	return hit_quad(space.quads[new_id], ray, ray_tmin, ray_tmax)
}
