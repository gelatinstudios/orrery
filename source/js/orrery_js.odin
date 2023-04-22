
package orrery_js

import ".."

image_memory_buffer: [1920*1080]u32

@export
image_memory_buffer_ptr :: proc() -> rawptr {
    return &image_memory_buffer[0]
}

main :: proc(){}
