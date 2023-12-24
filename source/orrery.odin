
package orrery

import "core:runtime"
import "core:fmt"
import "core:time"
import "core:math"
import "core:strings"
import "core:slice"
import "core:math/rand"
import "core:mem"

import "appendix"
import "font"

Body_ID :: appendix.Body_ID

to_pixel :: proc($color: u32) -> u32 {
    r :: (color >> 16) & 0xff
    g :: (color >>  8) & 0xff
    b :: (color >>  0) & 0xff

    return 0xff << 24 | b << 16 | g << 8 | r
}

BACKGROUND_COLOR := to_pixel(0x010707)
STAR_COLOR       := to_pixel(0xBAF2F5)
TEXT_COLOR       := to_pixel(0xd1f7f9)
//CIRCLE_COLOR     := to_pixel(0x052323)

CIRCLE_COLOR := to_pixel(0x1BC2CB)

MAKE_STARS :: true

TEXT_HEIGHT :: 18 // the actual pixel height of the text is 20, but i want the lines to be more compact...

planet_count :: len(appendix.planets)

Position :: struct { L, B, R: f64 }

// TODO: moon phases! https://www.celestialprogramming.com/snippets/moonPhaseRender.html

get_heliocentric_position :: proc(JD: f64, using planet: appendix.Planet) -> Position {
    using appendix
    
    t := (JD - 2451_545.0) / 365_250
    
    results: [3]f64
    for terms, i in terms.terms_list {
        mult: f64 = 1
        x: f64 = 0
        for xi_terms in terms {
            xi: f64 = 0
            for abc in xi_terms {
                A := abc[0]
                B := abc[1]
                C := abc[2]

                xi += A * math.cos(B + C*t)
            }
            x += mult*xi
            mult *= t
        }
        x /= 100_000_000
        results[i] = x
    }

    result := Position {
        L = results[0],
        B = results[1],
        R = results[2],
    }

    return result
}

to_geocentric_position :: proc(helio, earth: Position) -> Position {
    using math

    using helio

    Lo := earth.L
    Bo := earth.B
    Ro := earth.R

    x := R*cos(B)*cos(L) - Ro*cos(Bo)*cos(Lo)
    y := R*cos(B)*sin(L) - Ro*cos(Bo)*sin(Lo)
    z := R*sin(B)        - Ro*sin(Bo)

    return Position {
        L = atan2(y, x),
        B = atan2(z, sqrt(x*x + y*y)),
        R = sqrt(x*x + y*y + z*z)
    }
}

get_moon_position :: proc(JD: f64) -> Position {
    // idk why this chapter is using degrees and not radians but whatever i'll deal
    sin :: proc(x: f64) -> f64 { return math.sin(math.to_radians(x)) }
    cos :: proc(x: f64) -> f64 { return math.cos(math.to_radians(x)) }

    t := (JD - 2451_545) / 36525

    t2 := t*t
    t3 := t*t*t
    t4 := t*t*t*t
    
    L_ := (218.316_4591 + 481_267.881_342_36*t
           - 0.001_3268*t2 + t3/538_841 - t4/65_194_000)

    D := (297.850_2042 + 445_267.111_5168*t
          - 0.001_6300*t2 + t3/545_868 - t4/113_065_000)

    M := (357.529_1092 + 35_999.050_2909*t
          - 0.000_1536*t2 + t3/24_490_000)

    M_ := (134.963_4114 + 477_198.867_6313*t
           + 0.008_9970*t2 + t3/69_699 - t4/14_712_000)

    F := (93.272_0993 + 483_202.017_5273*t
          - 0.003_4029*t2 - t3/3_526_000 + t4/863_310_000)

    A1 := 119.75 + 131.849*t
    A2 :=  53.09 + 479_264.290*t
    A3 := 313.45 + 481_266.484*t
        
    l: f64 = 0
    r: f64 = 0
    for e in appendix.Table_45A {
        coeff_D  := f64(e.D)
        coeff_M  := f64(e.M)
        coeff_M_ := f64(e.M_)
        coeff_F  := f64(e.F)
        
        l += f64(e.l)*sin(D*coeff_D + M*coeff_M + M_*coeff_M_ + F*coeff_F)
        r += f64(e.r)*cos(D*coeff_D + M*coeff_M + M_*coeff_M_ + F*coeff_F)
    }

    b: f64 = 0
    for e in appendix.Table_45B {
        coeff_D  := f64(e.D)
        coeff_M  := f64(e.M)
        coeff_M_ := f64(e.M_)
        coeff_F  := f64(e.F)

        b += f64(e.b)*sin(D*coeff_D + M*coeff_M + M_*coeff_M_ + F*coeff_F)
    }

    // additives
    l += 3958*sin(A1)
    l += 1962*sin(L_ - F)
    l +=  318*sin(A2)

    b += -2235*sin(L_)
    b +=   382*sin(A3)
    b +=   175*sin(A1 - F)
    b +=   175*sin(A1 + F)
    b +=   127*sin(L_ - M_)
    b +=  -115*sin(L_ + M_)
    
    L := L_ + l/1_000_000
    B := b/1_000_000
    R := 385_000.56 + r/1_000 // in kilometers

    L = math.to_radians(L)
    B = math.to_radians(B)
    
    return Position {
        L = L,
        B = B,
        R = R,
    }
}

Body :: struct {
    id: Body_ID,
    image: Image,
    using position: Position,
}

draw_orbit :: proc(output: Image, bodies: []Body,
                   render_center_x, render_center_y, render_size: i32) {
    slice.sort_by_cmp(bodies, proc(a, b: Body) -> slice.Ordering {
        A := a.id == .Moon ? 0.0000000001 : a.R
        B := b.id == .Moon ? 0.0000000001 : b.R
        return slice.cmp(A, B)
    })

    to_norm_deg :: proc(x: f64) -> f64 {
        degrees := math.to_degrees(x)
        for degrees >= 360 do degrees -= 360
        for degrees < 0 do degrees += 360
        return degrees
    }
    
    radius_delta := render_size / i32(2*(len(bodies)+1))+1
    radius: i32 = 0
    for body, i in bodies {
        using body
        
        // orbit circle
        draw_circle(output, render_center_x, render_center_y, i32(radius))
        
        w := f32(image.width)
        h := f32(image.height)
        
        r := f64(radius)
        center_x := f32(render_center_x) + f32(r * math.cos(L))

        // subtracting instead of adding here flips the y's along the x axis,
        // since y goes down in image-space
        center_y := f32(render_center_y) - f32(r * math.sin(L))

        scale := f32(radius_delta) / f32(min(image.width, image.height))
        
        scaled_width  := w * scale
        scaled_height := h * scale
        
        x := center_x - scaled_width*0.5
        y := center_y - scaled_height*0.5

        dest_rect   := Rectangle {x, y, scaled_width, scaled_height}

        image_draw(output, image, dest_rect)

        if false && i > 0 {
            text := fmt.tprintf("%.0f\xff", to_norm_deg(L))
            width := f32(len(text)-1) * font.ADVANCE_X
            draw_text(output, center_x - width*0.5, y + scaled_height + TEXT_HEIGHT*0.5 + 1, text)
        }
            
        radius += radius_delta
    }

    // draw informational text
    {
        text_height :: TEXT_HEIGHT
        
        x := f32(render_center_x)
        y := f32(render_center_y) - f32(render_size)*0.5

        y -= text_height*7

        get_body_info_text :: proc(using body: Body) -> string {
            r_units := "AU"
            if body.id == .Moon {
                r_units = "km"
            }

            b := to_norm_deg(B)
            if b > 350 do b -= 360 // B should be close to 0, +/-
            return fmt.tprintf("%7s: L = % 6.2f\xff, B = % 5.2f\xff, R = % 2.2f {}",
                               id, to_norm_deg(L), b, R, r_units)
        }

        max_text_width := 0
        for body in bodies {
            free_all(context.temp_allocator)
            text := get_body_info_text(body)
            max_text_width = max(len(text), max_text_width)
        }

        x -= f32(max_text_width)*font.ADVANCE_X*0.5

        for body in bodies[1:] {
            free_all(context.temp_allocator)
            draw_text(output, x, y, get_body_info_text(body))
            y += text_height
        }
    }
}

@export
make_orrery :: proc "c" (pixels: [^]u32, width, height: i32, star_seed: u64) {
    context = runtime.default_context()
    context.allocator = runtime.nil_allocator()

    when ODIN_OS == .JS {
        temp_storage: [1024]byte
        arena:= &mem.Arena{}
        mem.arena_init(arena, temp_storage[:])
        context.temp_allocator = mem.arena_allocator(arena)
    }
    
    output := Image {
        pixels = pixels[:width*height],
        width = width,
        height = height,
    }

    now := time.now()
    
    JD := to_julian_day(now)
    planets := appendix.planets
    
    positions: [planet_count]Position

    for planet, i in planets {
        position := get_heliocentric_position(JD, planet)
        positions[i] = position
    }
    
    planet_images: [planet_count]Image
    planet_images[0] = mercury_image
    planet_images[1] = venus_image
    planet_images[2] = earth_image
    planet_images[3] = mars_image
    planet_images[4] = jupiter_image
    planet_images[5] = saturn_image
    planet_images[6] = uranus_image
    planet_images[7] = neptune_image

    when MAKE_STARS { // make star background
        rand.set_global_seed(star_seed)
        for i in 0..<(output.width*output.height) {
            output.pixels[i] = BACKGROUND_COLOR
        }
        
        star_count := output.width * output.height / 500

        for _ in 0 ..< star_count {
            index := rand.int_max(int(output.width*output.height-1))
            output.pixels[index] = STAR_COLOR
        }
    }
    
    orbit_size := output.width*2/5
    
    { // draw heliocentric orbit
        bodies: [planet_count+1]Body

        bodies[0] = Body {
            id = .Sun,
            image = sun_image
        }

        for position, i in positions[:planet_count] {
            bodies[i+1] = Body {
                id = Body_ID(i + int(Body_ID.Mercury)),
                image = planet_images[i],
                position = position,
            }
        }

        render_size := orbit_size
        
        render_center_x := output.width/4
        render_center_y := output.height/2

        draw_orbit(output, bodies[:],
                   render_center_x, render_center_y,
                   render_size)
    }
    

    //moon_image := load_image("../images/resized/moon.png")
    moon_position := get_moon_position(JD)

    { // draw geocentric orbit
        bodies: [planet_count+2]Body

        earth_index :: 2
        //assert(appendix.planets[earth_index].id == .Earth)
        earth_pos := positions[earth_index]

        for position, i in positions {
            g := to_geocentric_position(position, earth_pos)
            bodies[i] = Body {
                id = Body_ID(i + int(Body_ID.Mercury)),
                image = planet_images[i],
                position = g
            }
        }

        sun_pos := to_geocentric_position({}, earth_pos)
        
        bodies[planet_count] = Body {
            id = .Sun,
            image = sun_image,
            position = sun_pos,
        }

        bodies[planet_count+1] = Body {
            id = .Moon,
            image = moon_image,
            position = moon_position,
        }

        render_size := orbit_size

        render_center_x := output.width*3/4
        render_center_y := output.height/2

        draw_orbit(output, bodies[:], render_center_x, render_center_y, render_size)
    }

    {
        date_text := fmt.tprint(now)
        x := f32(output.width)*0.5 - f32(len(date_text))*font.ADVANCE_X*0.5
        y := f32(output.height)*0.5 + f32(orbit_size)*0.5
        draw_text(output, x, y, date_text)
    }
}
