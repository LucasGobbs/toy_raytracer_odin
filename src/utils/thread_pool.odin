
package utils
import "core:thread"

thread_pool_create :: proc(pool: ^thread.Pool, pool_size: int) {
	thread.pool_init(pool, context.allocator, pool_size)
	thread.pool_start(pool)
}

thread_pool_destroy :: proc(thread_pool: ^thread.Pool) {
	thread.pool_finish(thread_pool)
	thread.pool_destroy(thread_pool)
}
