
package orrery_os

import "core:strings"
import stbi "vendor:stb/image"

import orrery ".."

export_image :: proc(image: orrery.Image, path: string) {
    cpath := strings.clone_to_cstring(path, context.temp_allocator)
    stbi.write_png(cpath, image.width, image.height, 4, raw_data(image.pixels), 0)
}
