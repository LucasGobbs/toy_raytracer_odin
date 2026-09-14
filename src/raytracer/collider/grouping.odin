package collider


Grouping :: union #no_nil {
	LinearGrouping,
	Bvh,
}

GroupingKind :: enum {
	Linear,
	BVH,
}

// Stateless marker: brute-force scans every object on each ray.
LinearGrouping :: struct {}

grouping_kind :: proc(grouping: Grouping) -> GroupingKind {
	switch _ in grouping {
	case LinearGrouping:
		return .Linear
	case Bvh:
		return .BVH
	}
	return .Linear
}

grouping_kind_next :: proc(kind: GroupingKind) -> GroupingKind {
	switch kind {
	case .Linear:
		return .BVH
	case .BVH:
		return .Linear
	}
	return .Linear
}

grouping_build :: proc(space: ^ColliderSpace, kind: GroupingKind) {
	grouping_destroy(&space.grouping)
	switch kind {
	case .Linear:
		space.grouping = LinearGrouping{}
	case .BVH:
		bvh: Bvh
		n_s := len(space.spheres)
		n_q := len(space.quads)
		merged := make([]Aabb, n_s + n_q)
		copy(merged[:n_s], space.spheres.bbox[:n_s])
		copy(merged[n_s:], space.quads.bbox[:n_q])
		bvh_build(&bvh, merged)
		delete(merged)
		space.grouping = bvh
	}
}

grouping_destroy :: proc(grouping: ^Grouping) {
	switch &g in grouping {
	case LinearGrouping:
	case Bvh:
		bvh_destroy(&g)
	}
}


hit_objects :: proc(space: ^ColliderSpace, ray: Ray, tmin, tmax: f64) -> (HitRecord, bool) {
	switch &g in space.grouping {
	case LinearGrouping:
		return linear_hit(space, ray, tmin, tmax)
	case Bvh:
		return bvh_hit(&g, space, ray, tmin, tmax)
	}
	return HitRecord{}, false
}

linear_hit :: proc(space: ^ColliderSpace, ray: Ray, tmin, tmax: f64) -> (HitRecord, bool) {
	rec: HitRecord
	hit := false
	closest := tmax
	for sphere, i in space.spheres {
		current, ok := hit_sphere(sphere, ray, tmin, closest)
		if ok {
			hit = true
			closest = current.t
			current.object_index = i
			rec = current
		}
	}

	for quad, j in space.quads {
		current, ok := hit_quad(quad, ray, tmin, closest)
		if ok {
			hit = true
			closest = current.t
			current.object_index = j + len(space.spheres)
			rec = current
		}
	}
	return rec, hit
}
