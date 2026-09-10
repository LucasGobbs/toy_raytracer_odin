package raytracer


HitRecord :: struct {
	position:   Point3,
	normal:     Vec3,
	t:          f64,
	front_face: bool,
	material:   Material,
}

set_front_face :: proc(ray: Ray, outward_normal: Vec3) -> (Vec3, bool) {
	front_face := vec_dot(ray.direction, outward_normal) < .0
	normal := front_face ? outward_normal : -outward_normal
	return normal, front_face
}


hit_objects :: proc(world: ^World, ray: Ray, ray_tmin: f64, ray_tmax: f64) -> (HitRecord, bool) {
	temporary_hit_record := HitRecord{}
	hit_anything := false
	closest_so_far := ray_tmax

	len_spheres := len(world.spheres)
	for idx in 0 ..< len_spheres {
		hit_record, hitted := hit_sphere(
			world.spheres[idx].center,
			world.spheres[idx].radius,
			ray,
			ray_tmin,
			closest_so_far,
		)
		if hitted {
			hit_record.material = world.spheres[idx].material
			hit_anything = true
			closest_so_far = hit_record.t
			temporary_hit_record = hit_record
		}
	}

	return temporary_hit_record, hit_anything
}
