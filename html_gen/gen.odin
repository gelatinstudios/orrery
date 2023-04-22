
package gen

import "core:fmt"
import c "core:c/libc"

main :: proc() {
    using fmt

    println(#load("prelude.html", string))

    // odin's fmt flushes stdout each time or something idk c.printf is just faster bro
    for b in #load("../orrery.wasm") {
	c.printf("%d,", c.int(b))
    }
    c.fflush(c.stdout)
    
    println(#load("footer.html", string))
}
