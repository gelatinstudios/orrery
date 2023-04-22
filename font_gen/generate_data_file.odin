
package generate_data_file

import "core:os"
import "core:fmt"
import c "core:c/libc"

import stbtt "vendor:stb/truetype"

main :: proc() {
    path :: "font/SpaceMono-Regular.ttf"

    ttf_data, ok := os.read_entire_file(path)
    assert(ok)
    
    using stbtt

    info := &fontinfo{}

    fmt.println(
`
package font

Character_Info :: struct {
    bitmap: []byte,
    width, height: i32, 
    xoff, yoff: f32,
}
    
`)

    pixel_height :: 20
    
    if InitFont(info, raw_data(ttf_data), 0) {
        advance_width: c.int
        GetCodepointHMetrics(info, 'a', &advance_width, nil)
        scaled_advance_width := f32(advance_width)*ScaleForPixelHeight(info, pixel_height)
	
        DEGREE_SYMBOL_CODE :: 128
        
        fmt.println("DEGREE_SYMBOL_CODE ::", DEGREE_SYMBOL_CODE)
        fmt.println("ADVANCE_X ::", scaled_advance_width)
        
        fmt.println("characters := [?]Character_Info {")
        
        print_codepoint :: proc(info: ^fontinfo, code: rune) {
            scale := ScaleForPixelHeight(info, pixel_height)
            
            width, height, xoff, yoff: c.int
            bitmap := GetCodepointBitmap(info,
                                         0, scale, code,
                                         &width, &height,
                                         &xoff, &yoff)
            defer c.free(bitmap)

            fmt.println("    {")
            fmt.println("        bitmap = []byte{")
            i : =0
            for y in 0..<height {
                fmt.print("            ")
                for x in 0..<width {
                    b := bitmap[i]
                    //pixel := (u32(b) << 24) | 0xffffff
                    fmt.printf("{},", b)
                    i +=1
                }
                fmt.println()
            }
            fmt.println()
            fmt.println("        },")

            fmt.printf("        width = {},\n", width)
            fmt.printf("        height = {},\n", height)
            fmt.printf("        xoff = {},\n", xoff)
            fmt.printf("        yoff = {},\n", yoff)
            
            fmt.println("    },")
        }
        
        for c in 0..<DEGREE_SYMBOL_CODE {
            character := rune(c)
            print_codepoint(info, character)
        }
        print_codepoint(info, '°')

        fmt.println("}")
    } else {
        fmt.eprintln("Failed to load font '{}'", path)
        os.exit(1)
    }
}
