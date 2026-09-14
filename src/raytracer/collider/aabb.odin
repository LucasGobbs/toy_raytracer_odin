package collider
import "../../utils"

Aabb :: struct {
	x, y, z: utils.Interval(f64),
}

aabb_create :: proc {
	aabb_create_from_vectors,
	aabb_create_from_bboxes,
}

// Create from any structure that implements [3]f64 rm.Vec3,rm.Point3)
aabb_create_from_vectors :: proc(a, b: $T/[3]f64) -> Aabb {
	return Aabb {
		x = (a[0] <= b[0]) ? utils.Interval(f64){a[0], b[0]} : utils.Interval(f64){b[0], a[0]},
		y = (a[1] <= b[1]) ? utils.Interval(f64){a[1], b[1]} : utils.Interval(f64){b[1], a[1]},
		z = (a[2] <= b[2]) ? utils.Interval(f64){a[2], b[2]} : utils.Interval(f64){b[2], a[2]},
	}
}
aabb_create_from_bboxes :: proc(box0: Aabb, box1: Aabb) -> Aabb {
	return Aabb {
		x = utils.interval_merge(box0.x, box1.x),
		y = utils.interval_merge(box0.y, box1.y),
		z = utils.interval_merge(box0.z, box1.z),
	}
}

aabb_axis_interval :: proc(aabb: Aabb, n: int) -> utils.Interval(f64) {
	if n == 1 do return aabb.y
	if n == 2 do return aabb.z
	return aabb.x
}


aabb_hit :: proc(
	aabb: Aabb,
	ray_origin, ray_direction: $T/[3]f64,
	ray_interval: utils.Interval(f64),
) -> bool {
	ray_interval := ray_interval
	ray_origin := ray_origin
	ray_direction := ray_direction

	for axis := 0; axis < 3; axis += 1 {
		ax := aabb_axis_interval(aabb, axis)
		adinv := 1.0 / ray_direction[axis]

		t0 := (ax.min - ray_origin[axis]) * adinv
		t1 := (ax.max - ray_origin[axis]) * adinv

		if t0 < t1 {
			if t0 > ray_interval.min do ray_interval.min = t0
			if t1 < ray_interval.max do ray_interval.max = t1
		} else {
			if t1 > ray_interval.min do ray_interval.min = t1
			if t0 < ray_interval.max do ray_interval.max = t0
		}

		if ray_interval.max <= ray_interval.min {
			return false
		}
	}
	return true
}

aabb_longest_axis :: proc(aabb: Aabb) -> int {
	x_size := utils.interval_size(aabb.x)
	y_size := utils.interval_size(aabb.y)
	z_size := utils.interval_size(aabb.z)
	if x_size > y_size {
		return x_size > z_size ? 0 : 2
	} else {
		return y_size > z_size ? 1 : 2
	}
}
