
package orrery_os

import "core:os"
import "core:fmt"
import "core:intrinsics"

import orrery ".."

main :: proc() {
    if len(os.args) < 2 {
        fmt.println("bruh") // TODO: usage
        os.exit(1)
    }
    
    output := orrery.make_background(1920, 1080)

    orrery.make_orrery(raw_data(output.pixels), output.width, output.height, u64(intrinsics.read_cycle_counter()))
    
    for arg in os.args[1:] {
        export_image(output, arg)
    }
}
