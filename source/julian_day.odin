
package orrery

import "core:time"
import "core:math"

to_julian_day_raw :: proc(year: int, month: int, day: f64) -> f64 {
    // pg 60-61

    Y := year
    M := month
    D := day

    if M == 1 || M == 2 {
	Y -= 1
	M += 12
    }

    A := Y/100
    B := 2 - A + (A/4)

    JD := math.trunc(365.25*f64(Y + 4716)) + math.trunc(30.6001*f64(M+1)) + D + f64(B) - 1524.5

    return JD
}

to_julian_day_time :: proc(t: time.Time) -> f64 {
    using time

    hour, min, sec := clock(t)

    D := f64(day(t)) + f64(hour)/24.0 + f64(min)/(24*60) + f64(sec)/(24*60*60)
    
    return to_julian_day_raw(year(t), int(month(t)), D)
}

to_julian_day :: proc { to_julian_day_raw, to_julian_day_time }

julian_day_to_modified_julian_day :: proc(julian_day: f64) -> f64 {
    return julian_day - 2400_000.5
}

to_modified_julian_day_raw :: proc(year: int, month: int, day: f64) -> f64 {
    return julian_day_to_modified_julian_day(to_julian_day_raw(year, month, day))
}

to_modified_julian_day_time :: proc(t: time.Time) -> f64 {
    return julian_day_to_modified_julian_day(to_julian_day_time(t))
}

to_modified_julian_day :: proc { to_modified_julian_day_raw, to_modified_julian_day_time }
