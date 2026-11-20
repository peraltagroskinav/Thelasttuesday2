shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 fog_color : source_color = vec3(0.72, 0.78, 0.79);
uniform float opacity : hint_range(0.0, 1.0) = 0.6;

float random_value(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float lower = mix(
		random_value(cell),
		random_value(cell + vec2(1.0, 0.0)),
		fraction.x
	);
	float upper = mix(
		random_value(cell + vec2(0.0, 1.0)),
		random_value(cell + vec2(1.0, 1.0)),
		fraction.x
	);
	return mix(lower, upper, fraction.y);
}

float fog_noise(vec2 point) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 3; octave++) {
		value += value_noise(point) * amplitude;
		point *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 drift = vec2(TIME * 0.035, -TIME * 0.018);
	float broad_clouds = fog_noise(UV * vec2(5.2, 2.8) + drift);
	float fine_clouds = value_noise(UV * vec2(14.0, 7.0) - drift * 1.7);
	float density = smoothstep(0.34, 0.7, broad_clouds * 0.78 + fine_clouds * 0.22);
	float vertical_fade = smoothstep(0.0, 0.17, UV.y) * (1.0 - smoothstep(0.83, 1.0, UV.y));
	float horizontal_fade = smoothstep(0.0, 0.06, UV.x) * (1.0 - smoothstep(0.94, 1.0, UV.x));
	ALBEDO = fog_color;
	ALPHA = density * vertical_fade * horizontal_fade * opacity;
}
