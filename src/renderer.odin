package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import "utils"
RenderTaskData :: struct {
	cam:                Camera,
	world:              ^World,
	output_buffer:      []u8,
	partition_index:    int,
	partition_interval: utils.Interval(f64),
}

renderer_render :: proc(cam: Camera, world: ^World, output_buffer: []u8, partitions: int = 8) {
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
		renderer_render_partition(
			cam,
			world,
			output_buffer[buffer_interval.min:buffer_interval.max],
			partition,
			partition_interval,
		)
	}
}

renderer_render_partition :: proc(
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
			pixel_center := camera_calculate_pixel_coordinates(cam, i, j)

			base_ray := Ray {
				direction = pixel_center - cam.center,
				origin    = cam.center,
			}

			pixel_color := Color{}
			for s in 0 ..< cam.samples {
				offset := Vec3{rand.float64() - .5, rand.float64() - .5, .0}
				pixel_sample := camera_calculate_pixel_coordinates(cam, i, j, offset)

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
