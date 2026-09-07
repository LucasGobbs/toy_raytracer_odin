package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:sync"
import "core:thread"
import "utils"

Camera :: struct {
	ratio:            f64,
	image_width:      f64,
	image_height:     f64,
	center:           Point3,
	pixel00_location: Point3,
	pixel_delta_u:    Vec3,
	pixel_delta_v:    Vec3,
	samples:          int,
	max_depth:        int,
	vfov:             f64,
	position:         Point3,
	look_at:          Point3,
	vup:              Vec3,
	u, v, w:          Vec3,
}

camera_create :: proc(ratio: f64, image_width: f64, position: Point3, look_at: Point3) -> Camera {
	image_height := math.floor(image_width / ratio)
	image_height = image_height < 1.0 ? 1.0 : image_height

	vfov := 60.0
	vup := Vec3Up
	camera_center := position
	focal_length := vec_length(position - look_at)
	theta := utils.degrees_to_radians(vfov)
	h := math.tan(theta / 2.0)
	viewport_height := 2.0 * h * focal_length
	viewport_width := viewport_height * image_width / image_height

	w := vec_unit(position - look_at)
	u := vec_unit(vec_cross(vup, w))
	v := vec_cross(w, u)

	viewport_u := viewport_width * u
	viewport_v := viewport_height * -v

	pixel_delta_u := viewport_u / image_width
	pixel_delta_v := viewport_v / image_height

	viewport_upper_left := camera_center - (focal_length * w) - viewport_u / 2.0 - viewport_v / 2
	pixel00_location := viewport_upper_left + .5 * (pixel_delta_u + pixel_delta_v)

	camera := Camera {
		ratio            = ratio,
		image_width      = image_width,
		image_height     = image_height,
		center           = camera_center,
		pixel00_location = pixel00_location,
		pixel_delta_u    = pixel_delta_u,
		pixel_delta_v    = pixel_delta_v,
		samples          = 250,
		max_depth        = 225,
		vfov             = vfov,
		position         = position,
		look_at          = look_at,
		vup              = vup,
		w                = w,
		v                = v,
		u                = u,
	}

	return camera
}

camera_render :: proc(cam: Camera, world: ^World, output_buffer: []u8, partitions: int = 8) {
	image_height := cast(int)cam.image_height
	image_width := cast(int)cam.image_width
	rows_per_partition := (image_height + partitions - 1) / partitions
	for partition in 0 ..< partitions {
		min_row := partition * rows_per_partition
		if min_row >= image_height {
			break
		}

		max_row := min_row + rows_per_partition
		max_row = max_row > image_height ? image_height : max_row
		partition_interval := utils.Interval(f64) {
			min = cast(f64)min_row,
			max = cast(f64)(max_row - 1),
		}

		buffer_interval := utils.Interval(int) {
			min = min_row * image_width * 4,
			max = max_row * image_width * 4,
		}
		camera_render_partition(
			cam,
			world,
			output_buffer[buffer_interval.min:buffer_interval.max],
			partition,
			partition_interval,
		)
	}
}

camera_render_threaded :: proc(
	cam: Camera,
	world: ^World,
	output_buffer: []u8,
	partitions: int = 8,
) {

	threadPool: thread.Pool
	thread.pool_init(&threadPool, context.allocator, partitions)
	thread.pool_start(&threadPool)
	defer thread.pool_destroy(&threadPool)
	client_arena: virtual.Arena
	arena_allocator_error := virtual.arena_init_growing(&client_arena, 1 * mem.Byte)
	client_allocator := virtual.arena_allocator(&client_arena)

	image_height := cast(int)cam.image_height
	image_width := cast(int)cam.image_width
	rows_per_partition := (image_height + partitions - 1) / partitions
	for partition in 0 ..< partitions {
		min_row := partition * rows_per_partition
		if min_row >= image_height {
			break
		}

		max_row := min_row + rows_per_partition
		max_row = max_row > image_height ? image_height : max_row
		partition_interval := utils.Interval(f64) {
			min = cast(f64)min_row,
			max = cast(f64)(max_row - 1),
		}

		buffer_interval := utils.Interval(int) {
			min = min_row * image_width * 4,
			max = max_row * image_width * 4,
		}
		task_data := new(RenderTaskData, client_allocator)
		task_data.cam = cam
		task_data.world = world
		task_data.output_buffer = output_buffer[buffer_interval.min:buffer_interval.max]
		task_data.partition_index = partition
		task_data.partition_interval = partition_interval

		thread.pool_add_task(&threadPool, client_allocator, partition_worker, task_data, partition)

	}
	thread.pool_finish(&threadPool)
}

partition_worker :: proc(t: thread.Task) {
	data := (^RenderTaskData)(t.data)
	camera_render_partition(
		data.cam,
		data.world,
		data.output_buffer,
		data.partition_index,
		data.partition_interval,
	)
}
RenderTaskData :: struct {
	cam:                Camera,
	world:              ^World,
	output_buffer:      []u8,
	partition_index:    int,
	partition_interval: utils.Interval(f64),
}
camera_render_partition :: proc(
	cam: Camera,
	world: ^World,
	output_buffer: []u8,
	partition_index: int,
	partition_interval: utils.Interval(f64),
) {
	pixels_sample_scale := 1.0 / cast(f64)cam.samples
	image_width := cast(int)cam.image_width
	for j: f64 = partition_interval.min; j <= partition_interval.max; j += 1.0 {
		row := cast(int)(j - partition_interval.min)
		fmt.println("Remaining Lines (", partition_index, "): ", cam.image_height - j)
		for i: f64 = 0.0; i < cam.image_width; i += 1.0 {
			pixel_index := (row * image_width + cast(int)i) * 4
			pixel_center :=
				cam.pixel00_location + (i * cam.pixel_delta_u) + (j * cam.pixel_delta_v)

			base_ray := Ray {
				direction = pixel_center - cam.center,
				origin    = cam.center,
			}

			pixel_color := Color{}
			for s in 0 ..< cam.samples {
				offset := Vec3{rand.float64() - .5, rand.float64() - .5, .0}
				pixel_sample :=
					cam.pixel00_location +
					((i + offset.x)) * cam.pixel_delta_u +
					((j + offset.y) * cam.pixel_delta_v)

				sampled_ray := Ray {
					direction = pixel_sample - cam.center,
					origin    = cam.center,
				}

				pixel_color += trace_ray(sampled_ray, cam.max_depth, world)

			}

			color_to_buffer(pixel_color * pixels_sample_scale, pixel_index, output_buffer)
		}
	}
}
