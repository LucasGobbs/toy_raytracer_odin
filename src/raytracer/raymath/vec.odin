package raymath

import "core:math"
import "core:math/rand"

vec_length :: proc {
	vec3_length,
}
vec_sqlength :: proc {
	vec3_sqlength,
}
vec_cross :: proc {
	vec3_cross,
}
vec_dot :: proc {
	vec3_dot,
}
vec_unit :: proc {
	vec3_unit,
}

Vec3 :: distinct [3]f64
Point3 :: Vec3
Vec3Up :: Vec3{0.0, 1.0, 0.0}
vec3_length :: #force_inline proc(vec: Vec3) -> f64 {
	return math.sqrt(vec3_sqlength(vec))
}

vec3_sqlength :: #force_inline proc(vec: Vec3) -> f64 #no_bounds_check {
	return vec.x * vec.x + vec.y * vec.y + vec.z * vec.z
}

vec3_cross :: #force_inline proc(a: Vec3, b: Vec3) -> Vec3 #no_bounds_check {
	return a.yzx * b.zxy - b.yzx * a.zxy
}
vec3_dot :: #force_inline proc(a: Vec3, b: Vec3) -> f64 #no_bounds_check {
	return a.x * b.x + a.y * b.y + a.z * b.z
}
vec3_unit :: #force_inline proc(vec: Vec3) -> Vec3 {return vec / vec3_length(vec)}

vec3_rand :: proc() -> Vec3 {
	return Vec3{rand.float64(), rand.float64(), rand.float64()}
}

vec3_rand_in_interval :: proc(min: f64, max: f64) -> Vec3 {
	return Vec3 {
		rand.float64_range(min, max),
		rand.float64_range(min, max),
		rand.float64_range(min, max),
	}
}

vec3_rand_unit :: proc() -> Vec3 {
	for {
		vec := vec3_rand_in_interval(-1, 1)
		lensq := vec3_sqlength(vec)
		if 1e-160 < lensq && lensq <= 1 {
			return vec / math.sqrt(lensq)
		}
	}
}

vec3_rand_in_unit_disk :: proc() -> Vec3 {
	for {
		vec := vec3_rand_in_interval(-1, 1)
		vec.z = .0
		lensq := vec3_sqlength(vec)
		if lensq < 1.0 {
			return vec
		}
	}
}

vec3_rand_on_hemisphere :: proc(normal: Vec3) -> Vec3 {
	random_vec := vec3_rand_unit()
	if vec3_dot(random_vec, normal) > 0.0 {
		return random_vec
	}

	return -random_vec
}

vec3_is_near_zero :: #force_inline proc(vec: Vec3) -> bool {
	small := 1e-8
	return math.abs(vec.x) < small && math.abs(vec.y) < small && math.abs(vec.z) < small
}

vec3_reflect :: #force_inline proc(vec: Vec3, normal: Vec3) -> Vec3 {
	return vec - 2 * vec3_dot(vec, normal) * normal
}

vec3_refract :: #force_inline proc(uv: Vec3, normal: Vec3, etai_over_etat: f64) -> Vec3 {
	cos_theta := math.min(vec3_dot(-uv, normal), 1.0)
	r_out_perp := etai_over_etat * (uv + cos_theta * normal)
	r_out_parallel := -math.sqrt(math.abs(1.0 - vec3_sqlength(r_out_perp))) * normal
	return r_out_perp + r_out_parallel
}
