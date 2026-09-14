package raytracer

import "collider"

HitRecord :: struct {
	position:   Point3,
	normal:     Vec3,
	t:          f64,
	front_face: bool,
	material:   Material,
}

hit_objects :: proc(world: ^World, ray: Ray, ray_tmin, ray_tmax: f64) -> (HitRecord, bool) {
	collision, hit := collider.hit_objects(&world.space, ray, ray_tmin, ray_tmax)
	if !hit do return HitRecord{}, false
	return HitRecord {
			position = collision.position,
			normal = collision.normal,
			t = collision.t,
			front_face = collision.front_face,
			material = world.materials[collision.object_index],
		},
		true
}
