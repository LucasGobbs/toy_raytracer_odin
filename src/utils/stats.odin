package utils

import "core:slice"
import "core:time"

// Median of measured durations. Robust for noisy perf runs: one slow outlier
// does not move it, unlike a mean. Sorts a scratch copy; input untouched.
median_duration :: proc(times: []time.Duration) -> time.Duration {
	n := len(times)
	scratch := slice.clone(times)
	defer delete(scratch)
	slice.sort(scratch)

	mid := n / 2
	if n % 2 == 1 {
		return scratch[mid]
	}
	return scratch[mid - 1] + (scratch[mid] - scratch[mid - 1]) / 2
}
