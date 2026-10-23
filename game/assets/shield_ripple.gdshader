shader_type spatial;
// Body-hugging Naki shield overlay (v0.12). Drawn as material_overlay on the
// character's own meshes, so it follows the skinned body: not a bubble.
//  * Shield damaged: a hex-cell ripple ring spreads from the impact point.
//  * Shield depleted: the whole body flashes, then a fading cell crackle.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float hit_age = 100.0;
uniform vec3 hit_point = vec3(0.0);
uniform float hit_strength = 0.0;
uniform float break_age = 100.0;
uniform vec4 energy_color : source_color = vec4(0.32, 0.93, 0.45, 1.0);
uniform vec4 break_color : source_color = vec4(0.55, 1.0, 0.65, 1.0);
uniform float regen_strength = 0.0;
uniform float expansion = 0.012;
varying vec3 world_pos;
varying vec3 object_pos;
float hex(vec2 p) {
	vec2 r = vec2(1.0, 1.73205);
	vec2 a = mod(p, r) - r * 0.5;
	vec2 b = mod(p + r * 0.5, r) - r * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	return max(abs(g.x), dot(abs(g), vec2(0.5, 0.866025)));
}
void vertex() {
	VERTEX += NORMAL * expansion;
	object_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	// Cells wrap around the body: angle around the vertical axis and height.
	vec2 cells = vec2(atan(object_pos.x, object_pos.z) * 2.4, object_pos.y * 7.5);
	float edge = smoothstep(0.40, 0.47, hex(cells));
	// Damage ripple: ring expanding from the impact point plus a bright core.
	float d = distance(world_pos, hit_point);
	float radius = hit_age * 2.6;
	float ring = exp(-pow((d - radius) / 0.11, 2.0));
	float core = exp(-d * 5.0) * exp(-hit_age * 9.0);
	float fade = exp(-hit_age * 3.2);
	// Ring + bright core at the impact, and the body's hex cells briefly lit.
	float ripple = hit_strength * fade * (ring * (0.45 + edge * 1.1) + core * 1.2 + edge * 0.22 + rim * 0.25);
	// Break: white-blue flash over the whole body, then crackling cells.
	float flash = exp(-break_age * 9.0);
	float crackle = exp(-break_age * 3.2) * edge * (0.55 + 0.45 * sin(TIME * 70.0 + cells.x * 3.0 + cells.y * 2.0));
	float broken = flash * (0.45 + rim * 0.8) + crackle * 0.7;
	float arc = 1.0-smoothstep(0.015,0.055,abs(sin(cells.y*2.8+sin(cells.x*4.0+TIME*9.0)*1.4+TIME*6.0)));
	float healing = regen_strength * arc * (0.4+0.6*rim) * (0.6+0.4*sin(TIME*17.0+cells.y));
	vec3 color = energy_color.rgb * (ripple+healing) + break_color.rgb * broken;
	ALBEDO = color * 1.35;
	ALPHA = clamp(ripple + broken + healing, 0.0, 0.9);
}
