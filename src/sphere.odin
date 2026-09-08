package main

import "core:math"
import "core:math/rand"
import "utils"
Sphere :: struct {
	center:   Point3,
	radius:   f64,
	material: Material,
}

sphere_random :: proc(center: utils.Interval(f64), radius: utils.Interval(f64)) -> Sphere {
	get_random_material_interface :: proc() -> Material
	material_options := []get_random_material_interface {
		lambertian_random,
		metal_random,
		dieletric_random,
	}
	material_chosen := rand.choice(material_options)
	return Sphere {
		center = vec3_rand_in_interval(center.min, center.max),
		radius = utils.random_f64_between(radius),
		material = material_chosen(),
	}
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
