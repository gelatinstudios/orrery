
package orrery_appendix

Body_ID :: enum {
    Sun,
    Moon,
    Mercury,
    Venus,
    Earth,
    Mars,
    Jupiter,
    Saturn,
    Uranus,
    Neptune,
}

Planet_Terms :: struct #raw_union {
    using _: struct {
	L_terms: [][][3]f64,
	B_terms: [][][3]f64,
	R_terms: [][][3]f64,
    },
    terms_list: [3][][][3]f64,
}

Planet :: struct {
    id: Body_ID,
    using terms: Planet_Terms,
}

planets := [?]Planet {
    { .Mercury, { terms_list = { Mercury_L, Mercury_B, Mercury_R } } },
    { .Venus,   { terms_list = {   Venus_L,   Venus_B,   Venus_R } } },
    { .Earth,   { terms_list = {   Earth_L,   Earth_B,   Earth_R } } },
    { .Mars,    { terms_list = {    Mars_L,    Mars_B,    Mars_R } } },
    { .Jupiter, { terms_list = { Jupiter_L, Jupiter_B, Jupiter_R } } },
    { .Saturn,  { terms_list = {  Saturn_L,  Saturn_B,  Saturn_R } } },
    { .Uranus,  { terms_list = {  Uranus_L,  Uranus_B,  Uranus_R } } },
    { .Neptune, { terms_list = { Neptune_L, Neptune_B, Neptune_R } } },
}
