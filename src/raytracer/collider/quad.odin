package collider

import "../../utils"
import "core:math"
QuadCollider :: struct {
	corner:         Vec3,
	edge_u, edge_v: Vec3,
	normal:         Vec3,
	planar_w:       Vec3, // cross(u,v) / |cross(u,v)|^2 — basis for alpha/beta containment
	D:              f64,
	bbox:           Aabb,
}

quad_collider_create :: proc(corner, edge_u, edge_v: Vec3) -> QuadCollider {
	bbox_diagonal1 := aabb_create(corner, corner + edge_u + edge_v)
	bbox_diagonal2 := aabb_create(corner + edge_u, corner + edge_v)

	bbox := aabb_create(bbox_diagonal1, bbox_diagonal2)

	n := vec_cross(edge_u, edge_v)
	normal := vec_unit(n)
	planar_w := n / vec_dot(n, n)
	D := vec_dot(normal, corner)
	return QuadCollider {
		corner = corner,
		edge_u = edge_u,
		edge_v = edge_v,
		normal = normal,
		planar_w = planar_w,
		D = D,
		bbox = bbox,
	}
}

hit_quad :: proc(quad: QuadCollider, ray: Ray, ray_tmin, ray_tmax: f64) -> (HitRecord, bool) {
	denom := vec_dot(quad.normal, ray.direction)

	if math.abs(denom) < 1e-8 do return not_hitted()

	// Hit point outside ray interval
	t := (quad.D - vec_dot(quad.normal, ray.origin)) / denom
	if !utils.contains(ray_tmin, ray_tmax, t) do return not_hitted()

	intersection := ray_at(ray, t)

	// Plane hit is not enough: the point must lie inside the parallelogram.
	// alpha/beta are the point's coordinates in the [0,1] corner basis.
	planar_point := intersection - quad.corner
	alpha := vec_dot(quad.planar_w, vec_cross(planar_point, quad.edge_v))
	beta := vec_dot(quad.planar_w, vec_cross(quad.edge_u, planar_point))
	if !utils.contains(0.0, 1.0, alpha) || !utils.contains(0.0, 1.0, beta) do return not_hitted()

	normal, front_face := set_front_face(ray, quad.normal)
	record := HitRecord {
		position   = intersection,
		normal     = normal,
		front_face = front_face,
		t          = t,
	}


	return record, true
}
