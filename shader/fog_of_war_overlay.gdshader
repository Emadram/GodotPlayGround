shader_type spatial;
// Terrain FoW: darken fragments outside any vision circle (XZ). Fed by FogOfWarOverlay each frame.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

/// Each entry: world XZ center in .xy, radius in .z ( .w unused ).
uniform vec4 vision_packed[32];
uniform int vision_count : hint_range(0, 32) = 0;
uniform vec4 fog_color : source_color = vec4(0.012, 0.018, 0.042, 0.84);
uniform float edge_softness : hint_range(0.0, 0.45) = 0.14;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float revealed = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= vision_count) {
			continue;
		}
		vec4 pk = vision_packed[i];
		float radius = max(pk.z, 0.001);
		float d = distance(world_pos.xz, pk.xy);
		float circle = 1.0 - smoothstep(radius * max(1.0 - edge_softness, 0.01), radius, d);
		revealed = max(revealed, circle);
	}
	float fog_mask = (1.0 - revealed);
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * fog_mask;
}
