package raytracer

Ray :: struct {
	origin:    Point3,
	direction: Vec3,
}

RayAt :: proc(ray: Ray, t: f64) -> Vec3 {
	return ray.origin + ray.direction * t
}
