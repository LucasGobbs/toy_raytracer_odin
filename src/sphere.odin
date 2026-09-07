package main

import "core:math"

Sphere :: struct {
	center:   Point3,
	radius:   f64,
	material: Material,
}

hit_sphere :: proc(
	center: Point3,
	radius: f64,
	ray: Ray,
	ray_tmin: f64,
	ray_tmax: f64,
) -> (
	HitRecord,
	bool,
) {
	oc := center - ray.origin
	a := vec_sqlength(ray.direction)
	h := vec_dot(ray.direction, oc)
	c := vec_sqlength(oc) - radius * radius
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

	contact_pos := RayAt(ray, root)
	outward_normal := (contact_pos - center) / radius

	normal, front_face := set_front_face(ray, outward_normal)
	record := HitRecord {
		position   = contact_pos,
		normal     = normal,
		front_face = front_face,
		t          = root,
	}

	return record, true
}
