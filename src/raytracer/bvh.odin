package raytracer
import "../utils"
import "core:math/rand"
import "core:slice"
BvhNode :: struct {
	box:          Aabb,
	left, right:  int,
	start, count: int,
}

Bvh :: struct {
	nodes:   [dynamic]BvhNode,
	indices: [dynamic]int,
}

bvh_node_create :: proc(objects: []BvhNode, start: int, end: int) -> BvhNode {
	axis := rand.int_range(0, 2)
	comparator := axis == 0 ? bvh_box_x_compare : axis == 1 ? bvh_box_y_compare : bvh_box_z_compare

	object_span := end - start
	left: ^BvhNode = ---
	right: ^BvhNode = ---
	if object_span == 1 {
		left = &objects[start]
	} else if object_span == 2 {
		left = &objects[start]
		right = &objects[start + 1]
	} else {
		slice.sort_by(objects, comparator)
		mid := start + object_span / 2
		left := bvh_node_create(objects, start, mid)
		right := bvh_node_create(objects, mid, end)
	}

	box := aabb_create_from_bboxes(left.box, right.box)
	return BvhNode{box = box, left = left, right = right}
}

bvh_node_hit :: proc(
	bvh_node: BvhNode,
	ray: Ray,
	ray_interval: utils.Interval(f64),
) -> (
	HitRecord,
	bool,
) {
	if !aabb_hit(bvh_node.box, ray, ray_interval) do return HitRecord{}, false

	left_hit_record, hitted_left := bvh_node_hit(bvh_node.left^, ray, ray_interval)
	if hitted_left do return left_hit_record, true

	right_hit_record, hitted_right := bvh_node_hit(bvh_node.right^, ray, ray_interval)
	if hitted_right do return right_hit_record, true

	return HitRecord{}, false
}

bvh_box_compare :: proc(a: BvhNode, b: BvhNode, axis_index: int) -> bool {
	a_axis_interval := aabb_axis_interval(a.box, axis_index)
	b_axis_interval := aabb_axis_interval(b.box, axis_index)
	return a_axis_interval.min < b_axis_interval.min
}

bvh_box_x_compare :: proc(a: BvhNode, b: BvhNode) -> bool {
	return bvh_box_compare(a, b, 0)
}
bvh_box_y_compare :: proc(a: BvhNode, b: BvhNode) -> bool {
	return bvh_box_compare(a, b, 1)
}
bvh_box_z_compare :: proc(a: BvhNode, b: BvhNode) -> bool {
	return bvh_box_compare(a, b, 2)
}
