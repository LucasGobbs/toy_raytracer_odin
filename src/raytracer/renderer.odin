package raytracer
import "../utils"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:sync"
import "core:thread"

RenderTaskData :: struct {
	raytracer_params: RaytracerParams,
	cam:              Camera,
	world:            ^World,
	output_buffer:    []u8,
	partition:        RenderPartition,
}

RenderPartition :: struct {
	index:              int,
	partition_interval: utils.Interval(f64),
	buffer_interval:    utils.Interval(int),
}


renderer_render :: proc(
	raytracer_params: RaytracerParams,
	cam: Camera,
	world: ^World,
	output_buffer: []u8,
	partitions: int = 8,
) {
	for idx in 0 ..< partitions {
		partition := renderer_build_partition(raytracer_params, idx, partitions)
		renderer_render_partition(
			raytracer_params,
			cam,
			world,
			output_buffer[partition.buffer_interval.min:partition.buffer_interval.max],
			partition,
		)
	}
}

renderer_render_threaded :: proc(
	raytracer_params: RaytracerParams,
	cam: Camera,
	world: ^World,
	output_buffer: []u8,
	partitions: int = 8,
) {
	thread_pool: thread.Pool
	utils.thread_pool_create(&thread_pool, partitions)
	defer utils.thread_pool_destroy(&thread_pool)
	client_arena: virtual.Arena
	arena_allocator_error := virtual.arena_init_growing(&client_arena, 1 * mem.Byte)
	client_allocator := virtual.arena_allocator(&client_arena)

	for idx in 0 ..< partitions {
		partition := renderer_build_partition(raytracer_params, idx, partitions)
		task_data := new(RenderTaskData)
		task_data.cam = cam
		task_data.world = world
		task_data.output_buffer = output_buffer[partition.buffer_interval.min:partition.buffer_interval.max]
		task_data.partition = partition
		task_data.raytracer_params = raytracer_params
		thread.pool_add_task(
			&thread_pool,
			client_allocator,
			partition_worker,
			task_data,
			partition.index,
		)
	}
}

@(private = "file")
renderer_render_partition :: proc(
	raytracer_params: RaytracerParams,
	cam: Camera,
	world: ^World,
	output_buffer: []u8,
	partition: RenderPartition,
) {
	partition_interval := partition.partition_interval
	partition_index := partition.index
	pixels_sample_scale := 1.0 / cast(f64)cam.samples
	image_width := cast(int)cam.image_width
	for j: f64 = partition_interval.min; j <= partition_interval.max; j += 1.0 {
		row := cast(int)(j - partition_interval.min)
		fmt.println("Remaining Lines (", partition_index, "): ", cam.image_height - j)
		for i: f64 = 0.0; i < cam.image_width; i += 1.0 {
			pixel_index := (row * image_width + cast(int)i) * 4

			pixel_color := Color{}
			for _ in 0 ..< cam.samples {
				sampled_ray := camera_calculate_ray(cam, i, j)

				pixel_color += trace_ray(sampled_ray, cam.max_depth, world)
			}

			color_to_buffer(pixel_color * pixels_sample_scale, pixel_index, output_buffer)
		}
	}
}

@(private = "file")
renderer_build_partition :: proc(
	raytracer_params: RaytracerParams,
	index: int,
	partition_count: int,
) -> RenderPartition {
	image_height := cast(int)raytracer_params.image_height
	image_width := cast(int)raytracer_params.image_width
	rows_per_partition := (image_height + partition_count - 1) / partition_count

	min_row := index * rows_per_partition
	max_row := min_row + rows_per_partition
	max_row = max_row > image_height ? image_height : max_row

	return RenderPartition {
		index = index,
		partition_interval = utils.Interval(f64) {
			min = cast(f64)min_row,
			max = cast(f64)(max_row - 1),
		},
		buffer_interval = utils.Interval(int) {
			min = min_row * image_width * 4,
			max = max_row * image_width * 4,
		},
	}
}


partition_worker :: proc(t: thread.Task) {
	data := (^RenderTaskData)(t.data)
	renderer_render_partition(
		data.raytracer_params,
		data.cam,
		data.world,
		data.output_buffer,
		data.partition,
	)
}
