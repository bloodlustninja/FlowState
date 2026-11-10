shader_type canvas_item;
render_mode blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float dist = length(p);
	float vig = smoothstep(0.38, 0.75, dist);
	COLOR = vec4(0.02, 0.02, 0.04, vig * intensity);
}
