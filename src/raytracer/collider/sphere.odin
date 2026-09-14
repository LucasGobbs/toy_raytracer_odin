package collider

import "core:math"

SphereCollider :: struct {
	origin:    Vec3,
	direction: Vec3,
	radius:    f64,
	bbox:      Aabb,
}

sphere_collider_create :: proc(origin, direction: Vec3, radius: f64) -> SphereCollider {
	center := Vec3(origin)
	motion := Vec3(direction)
	rvec := Vec3{radius, radius, radius}

	bbox: Aabb
	if vec3_is_near_zero(motion) {
		bbox = aabb_create(center - rvec, center + rvec)
	} else {
		box1 := aabb_create(center - rvec, center + rvec)
		box2 := aabb_create(center + motion - rvec, center + motion + rvec)
		bbox = aabb_create(box1, box2)
	}

	return SphereCollider{origin = center, direction = motion, radius = radius, bbox = bbox}
}

hit_sphere :: proc(
	sphere: SphereCollider,
	ray: Ray,
	ray_tmin, ray_tmax: f64,
) -> (
	HitRecord,
	bool,
) {
	current_center := sphere.origin + sphere.direction * ray.time
	oc := current_center - ray.origin
	a := vec_sqlength(ray.direction)
	h := vec_dot(ray.direction, oc)
	c := vec_sqlength(oc) - sphere.radius * sphere.radius
	discriminant := h * h - a * c

	if discriminant < .0 do return HitRecord{}, false

	sqrtd := math.sqrt(discriminant)
	root := (h - sqrtd) / a
	if root <= ray_tmin || ray_tmax <= root {
		root = (h + sqrtd) / a
		if root <= ray_tmin || ray_tmax <= root {
			return HitRecord{}, false
		}
	}

	contact_pos := ray_at(ray, root)
	outward_normal := (contact_pos - current_center) / sphere.radius

	normal, front_face := set_front_face(ray, outward_normal)
	record := HitRecord {
		position   = contact_pos,
		normal     = normal,
		front_face = front_face,
		t          = root,
	}

	return record, true
}
