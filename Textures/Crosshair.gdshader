shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	
	float radius = 0.05 ;
	float smooth_edge = 0.05;
	
	float circle = smoothstep(radius, radius - smooth_edge, dist);
	
	vec4 color = vec4(0.0, 1.0, 0.8, 1.0); // teal
	
	COLOR = vec4(color.rgb, circle);
}