// defines medium precision of floats for decent precision at decent speed
#ifdef GL_ES
precision mediump float;
#endif

#define MAX_DIST 200.0

uniform vec2 u_light_pos;
uniform vec2 u_resolution;
uniform float u_factor;
uniform float u_time;
uniform float u_lighting_dist; // intended around 0.3, exposed as a config param so people with visibility issues can increase

bool approx_equal(vec3 color1, vec3 color2) {
    float eps = 0.01;
    vec3 diff = color1 - color2;
    return abs(diff.r) < eps && abs(diff.g) < eps && abs(diff.b) < eps;
}

vec4 effect(vec4 color, Image image, vec2 uvs, vec2 texture_coords) {
    vec4 texture = Texel(image, uvs);
    // set tile background colour 71, 45, 60 to black
    if (approx_equal(texture.rgb, vec3(0.278, 0.176, 0.235))) {
        return vec4(0.0, 0.0, 0.0, 0.0);
    }

    //float dist = distance(u_light_pos / u_resolution, texture_coords / u_resolution);
    vec2 middle = vec2(0.41, 0.51); // approximately where character is
    float pulse = 0.03 * sin(u_time * 3);
    float dist = distance(middle, texture_coords / u_resolution);
    float factor = 1 - pow(dist, u_lighting_dist + pulse);
    float total_factor = factor * (1 - u_factor);
    //float factor = (MAX_DIST - dist) / MAX_DIST;

    // special treatment for red for torch effect
    float red = texture.r * total_factor * (1.1 + pulse);
    return vec4(red, texture.gba * total_factor);
}
