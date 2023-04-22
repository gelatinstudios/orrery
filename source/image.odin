
package orrery

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math/linalg"
import "core:math"
import "core:image/png"
lerp :: linalg.lerp

import "font"

v4 :: [4]f32

Image :: struct {
    pixels: []u32,
    width, height: i32,
}

Rectangle :: struct {
    x, y, width, height: f32
}

pixel_to_v4 :: proc(pixel: u32) -> v4 {
    return v4 {
        f32((pixel >>  0) & 0xff)/255,
        f32((pixel >>  8) & 0xff)/255,
        f32((pixel >> 16) & 0xff)/255,
        f32((pixel >> 24) & 0xff)/255,
    }
}

v4_to_pixel :: proc(v: v4) -> u32 {
    return ((u32(clamp(math.round(v.r*255), 0, 255)) & 0xff) <<  0 |
            (u32(clamp(math.round(v.g*255), 0, 255)) & 0xff) <<  8 |
            (u32(clamp(math.round(v.b*255), 0, 255)) & 0xff) << 16 |
            (u32(clamp(math.round(v.a*255), 0, 255)) & 0xff) << 24)
}

make_background :: proc(width, height: i32) -> Image {
    result := Image {
        pixels = make([]u32, width*height)
        width = width,
        height = height,
    }
    index := 0
    for y in 0 ..< height {
        for x in 0..< width {
            result.pixels[index] = BACKGROUND_COLOR
            index += 1
        }
    }
    return result
}

get_pixel :: #force_inline proc (im: Image, x, y: i32) -> u32 {
    if x >= 0 && x < im.width && y >= 0 && y < im.height {
        return im.pixels[x + y*im.width]
    }
    return 0
}

// NOTE: http://members.chello.at/~easyfilter/Bresenham.pdf
draw_circle :: proc(im: Image, x, y, radius: i32) {
    put_pixel :: #force_inline proc(im: Image, x, y: i32, A: f32) {
        if x >= 0 && x < im.width && y >= 0 && y < im.height {
            dest_index := x + y*im.width
            prev_v := pixel_to_v4(im.pixels[dest_index])
            v := pixel_to_v4(CIRCLE_COLOR)
            v.a = A

            v = lerp(prev_v, v, v.a)
            v.a = prev_v.a
            
            im.pixels[dest_index] = v4_to_pixel(v)
        }
    }
    
    xm := x
    ym := y

    x := radius
    y := i32(0)
    err := 2 - radius*2
    r := 1 - err

    for {
        brightness := 1 - f32(abs(err + 2*(x+y) - 2))/f32(r)
        put_pixel(im, xm+x, ym-y, brightness)
        put_pixel(im, xm+y, ym+x, brightness)
        put_pixel(im, xm-x, ym+y, brightness)
        put_pixel(im, xm-y, ym-x, brightness)
        if x == 0 do break
        e2 := err
        x2 := x - 1
        if err > y {
            brightness := 1 - f32(err + 2*x - 1)/f32(r)
            if brightness >= 0 {
                put_pixel(im,   xm+x, ym-y+1, brightness)
                put_pixel(im, xm+y-1,   ym+x, brightness)
                put_pixel(im,   xm-x, ym+y-1, brightness)
                put_pixel(im, xm-y+1,   ym-x, brightness)
            }
            x -= 1
            err -= x*2 - 1
        }
        if e2 < x2 {
            brightness := 1 - f32(1 - 2*y - e2)/f32(r)
            if brightness >= 0 {
                put_pixel(im, xm+x2, ym-y, brightness)
                put_pixel(im, xm+y, ym+x2, brightness)
                put_pixel(im, xm-x2, ym+y, brightness)
                put_pixel(im, xm-y, ym-x2, brightness)
            }
            y -= 1
            err -= y*2 - 1
        }
    }
}

image_draw :: proc(dest, source: Image, dest_rect: Rectangle) {
    cubic_hermite :: proc(P0, P1, P2, P3: v4, t: f32) -> v4 {
        t2 := t*t;
        t3 := t*t*t;

        B :: f32(1.0/3.0)
        C :: f32(1.0/3.0)
        
        a := (-B/6 - C) *P0 + (-3*B/2 - C + 2)*P1 + (3*B/2 + C - 2)   *P2 + (B/6 + C)*P3
        b := (B/2 + 2*C)*P0 + (2*B + C - 3)   *P1 + (-5*B/2 - 2*C + 3)*P2 - C*P3
        c := (-B/2 - C) *P0 +                                (B/2 + C)*P2                       
        d := (B/6)      *P0 + (-B/3 + 1)      *P1 +              (B/6)*P2
        
        return a*t3 + b*t2 + c*t + d;
    }
    
    start_x := clamp(i32(math.floor(dest_rect.x)), 0, dest.width-1)
    start_y := clamp(i32(math.floor(dest_rect.y)), 0, dest.height-1)

    end_x := clamp(i32(math.ceil(dest_rect.x + dest_rect.width)),  0, dest.width)
    end_y := clamp(i32(math.ceil(dest_rect.y + dest_rect.height)), 0, dest.height)

    for y in start_y ..< end_y {
        for x in start_x ..< end_x {
            u := (f32(x) - dest_rect.x) / (dest_rect.width)
            v := (f32(y) - dest_rect.y) / (dest_rect.height)

            if u < 0 || u > 1 || v < 0 || v > 1 do continue
            
            source_x := u * f32(source.width)
            source_y := v * f32(source.height)
            
            ix := i32(source_x)
            iy := i32(source_y)

            tx := source_x - f32(ix)
            ty := source_y - f32(iy)
            
            sample00 := pixel_to_v4(get_pixel(source, ix - 1, iy - 1))
            sample10 := pixel_to_v4(get_pixel(source, ix + 0, iy - 1))
            sample20 := pixel_to_v4(get_pixel(source, ix + 1, iy - 1))
            sample30 := pixel_to_v4(get_pixel(source, ix + 2, iy - 1))
                                                                         
            sample01 := pixel_to_v4(get_pixel(source, ix - 1, iy + 0))
            sample11 := pixel_to_v4(get_pixel(source, ix + 0, iy + 0))
            sample21 := pixel_to_v4(get_pixel(source, ix + 1, iy + 0))
            sample31 := pixel_to_v4(get_pixel(source, ix + 2, iy + 0))

            sample02 := pixel_to_v4(get_pixel(source, ix - 1, iy + 1))
            sample12 := pixel_to_v4(get_pixel(source, ix + 0, iy + 1))
            sample22 := pixel_to_v4(get_pixel(source, ix + 1, iy + 1))
            sample32 := pixel_to_v4(get_pixel(source, ix + 2, iy + 1))

            sample03 := pixel_to_v4(get_pixel(source, ix - 1, iy + 2))
            sample13 := pixel_to_v4(get_pixel(source, ix + 0, iy + 2))
            sample23 := pixel_to_v4(get_pixel(source, ix + 1, iy + 2))
            sample33 := pixel_to_v4(get_pixel(source, ix + 2, iy + 2))

            samplex0 := cubic_hermite(sample00, sample10, sample20, sample30, tx)
            samplex1 := cubic_hermite(sample01, sample11, sample21, sample31, tx)
            samplex2 := cubic_hermite(sample02, sample12, sample22, sample32, tx)
            samplex3 := cubic_hermite(sample03, sample13, sample23, sample33, tx)

            sample := cubic_hermite(samplex0, samplex1, samplex2, samplex3, ty)
            
            out_index := x + y*dest.width

            dest_sample := pixel_to_v4(dest.pixels[out_index])

            out_sample := lerp(dest_sample, sample, sample.a)
            out_sample.a = dest_sample.a
            
            dest.pixels[out_index] = v4_to_pixel(out_sample)
        }
    }
}

when false {
    font := &stbtt.fontinfo{}

    init_font :: proc() {
        ttf := #load("C:/Windows/Fonts/cour.ttf")
        stbtt.InitFont(font, raw_data(ttf), 0)
    }
} else {
    init_font :: proc(){}
}

// normalize out of range bytes to degree symbol
ch :: proc(c: rune) -> rune {
    if c > 128 {
        //return '°'
        return 128
    }
    return c
}

draw_text :: proc(im: Image, x, y: f32, text: string) {
    x := x
    y := y
    
    for character, i in text {
        c := ch(character)

        when false {
            @(static) u8_buffer: [64*1024]u8
            
            shift_x := x - math.trunc(x)
            shift_y := y - math.trunc(y)
            
            x0, x1, y0, y1: i32
            GetCodepointBitmapBoxSubpixel(font, c, scale, scale, shift_x, shift_y, &x0, &y0, &x1, &y1)
            
            width := x1 - x0
            height := y1 - y0

            assert(width*height <= len(u8_buffer))
            
            MakeCodepointBitmapSubpixel(font, raw_data(u8_buffer[:]), width, height, width, scale, scale, shift_x, shift_y, c)

            advance_width, left_side_bearing: i32
            GetCodepointHMetrics(font, c, &advance_width, &left_side_bearing)

            if i < len(text)-1{
                advance_width += GetCodepointKernAdvance(font, c, ch(rune(text[i+1])))
            }

            character_bitmap := u8_buffer[:]
            
            start_x := i32(x) + x0
            start_y := i32(y) + y0
        } else {
            info := font.characters[int(c)]
            using info

            start_x := i32(x + xoff)
            start_y := i32(y + yoff)

            character_bitmap := bitmap
        }
            
        index := 0
        for y in start_y ..< (start_y + height) {
            for x in start_x ..< (start_x + width) {
                alpha := character_bitmap[index]
                index += 1

                // TODO: do this outside of the loop
                if x < 0 || x >= im.width || y < 0 || y >= im.height {
                    continue
                }

                dest_index := x + y*im.width
                
                prev_color := im.pixels[dest_index]
                color := u32(alpha) << 24 | (TEXT_COLOR & 0xffffff)

                prev_v := pixel_to_v4(prev_color)
                v := pixel_to_v4(color)

                out_v := lerp(prev_v, v, v.a)
                out_v.a = prev_v.a
                
                im.pixels[dest_index] = v4_to_pixel(out_v)
            }
        }
            
        x += font.ADVANCE_X
    }
}
