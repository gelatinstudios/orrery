
package resize_images

import "core:os"
import "core:fmt"
import "core:strings"

import stbi "vendor:stb/image"
import c "core:c/libc"

main :: proc() {
    images_dir :: "images"
    output_dir :: "images/resized"

    handle, errno := os.open(images_dir)
    assert(errno == 0)

    dir, dir_errno := os.read_dir(handle, -1)
    assert(dir_errno == 0)

    fmt.println(
`package orrery`
    )
    
    for entry in dir {
	free_all(context.temp_allocator)

	if entry.is_dir do continue
	
	path := strings.clone_to_cstring(entry.fullpath, context.temp_allocator)

	out_path := fmt.ctprintf("{}/{}", output_dir, entry.name)
	
	x, y, n: c.int
	pixels := stbi.load(path, &x, &y, &n, 4)
	if pixels == nil {
	    fmt.eprintf("ERROR: Couldn't load '{}'\n", path)
	    continue
	}
	defer c.free(pixels)

	out_x := x / 4
	out_y := y / 4
	out_pixels := make([^]byte, out_x*out_y*n)
	
	success := stbi.resize_uint8(pixels, x, y, 0, out_pixels, out_x, out_y, 0, 4)
	if success == 0 {
	    fmt.eprintf("ERROR: couldn't resize '{}'\n", path)
	    continue
	}

	success = stbi.write_png(out_path, out_x, out_y, 4, out_pixels, 0)
	if success == 0 {
	    fmt.eprintf("ERROR: couldn't write out '{}'\n", out_path)
	    continue
	}

	planet_name, _, _ := strings.partition(entry.name, ".")

	pixels_u32 := cast([^]u32)out_pixels
	index := 0
	fmt.printf("{}_image := Image {{\n", planet_name)
	fmt.println("    pixels = []u32{")
	for _ in 0..<out_y {
	    c.printf("        ")
	    for _ in 0..<out_x {
		c.printf("%u,", pixels_u32[index])
		index += 1
	    }
	    c.printf("\n")
	}
	c.fflush(c.stdout)
	fmt.println("    },")
	fmt.printf("    width  = {},\n", out_x)
	fmt.printf("    height = {},\n", out_y)
	fmt.println("}")
    }
}
