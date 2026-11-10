shader_type canvas_item;
render_mode blend_mix;

uniform vec4 stripe_color1 : source_color = vec4(1.0, 0.816, 0.0, 1.0); // #FFD000 Warning Yellow
uniform vec4 stripe_color2 : source_color = vec4(0.08, 0.08, 0.10, 1.0); // #14141A Deep Obsidian
uniform float scroll_speed = 30.0;
uniform float stripe_width = 14.0;

void fragment() {
	float pattern = fract((FRAGCOORD.x - FRAGCOORD.y + TIME * scroll_speed) / (stripe_width * 2.0));
	COLOR = (pattern < 0.5) ? stripe_color1 : stripe_color2;
}
