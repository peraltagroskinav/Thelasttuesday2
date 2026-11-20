shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float chromatic_aberration : hint_range(0.0, 0.003) = 0.0012;
uniform float sharpening : hint_range(0.0, 0.4) = 0.24;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.018;
uniform float contrast : hint_range(0.9, 1.2) = 1.08;
uniform float saturation : hint_range(0.8, 1.3) = 1.12;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.28;

float grain_hash(vec2 pixel) {
	return fract(sin(dot(pixel, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - vec2(0.5);
	float radius = length(from_center * vec2(1.0, 1.1));
	vec2 chroma_direction = normalize(from_center + vec2(0.00001));
	vec2 chroma_offset = chroma_direction * chromatic_aberration * radius;

	vec3 center = texture(screen_texture, uv).rgb;
	vec3 color = vec3(
		texture(screen_texture, uv + chroma_offset).r,
		center.g,
		texture(screen_texture, uv - chroma_offset).b
	);

	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec3 neighbors = (
		texture(screen_texture, uv + vec2(pixel.x, 0.0)).rgb
		+ texture(screen_texture, uv - vec2(pixel.x, 0.0)).rgb
		+ texture(screen_texture, uv + vec2(0.0, pixel.y)).rgb
		+ texture(screen_texture, uv - vec2(0.0, pixel.y)).rgb
	) * 0.25;
	color += (color - neighbors) * sharpening;

	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	float warm_highlights = smoothstep(0.48, 0.9, luminance);
	color += vec3(0.045, 0.02, -0.01) * warm_highlights;

	float vignette = 1.0 - vignette_strength * smoothstep(0.24, 0.72, radius);
	color *= vignette;
	vec2 pixel_position = floor(uv / SCREEN_PIXEL_SIZE);
	float grain = grain_hash(pixel_position + vec2(floor(TIME * 24.0)));
	color += (grain - 0.5) * grain_strength;

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
