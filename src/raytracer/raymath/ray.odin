package raymath

Ray :: struct {
	origin:    Point3,
	direction: Vec3,
	time:      f64,
}

ray_at :: proc(ray: Ray, t: f64) -> Vec3 {
	return ray.origin + ray.direction * t
}
