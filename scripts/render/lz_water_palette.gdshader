shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D dry_palette : filter_nearest;
uniform sampler2D wet_palette : filter_nearest;
uniform float waterline_px = 10000.0;
uniform float viewport_height = 224.0;

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	float screen_y = SCREEN_UV.y * viewport_height;
	if (screen_y + 0.5 >= waterline_px) {
		float best = 999.0;
		vec3 mapped = source.rgb;
		for (int i = 0; i < 64; i++) {
			vec3 dry = texelFetch(dry_palette, ivec2(i, 0), 0).rgb;
			float d = dot(source.rgb - dry, source.rgb - dry);
			if (d < best) {
				best = d;
				mapped = texelFetch(wet_palette, ivec2(i, 0), 0).rgb;
			}
		}
		// Native source art is nearest-filtered Genesis palette data, so exact
		// palette matches should be effectively zero. Keep non-palette pixels intact.
		if (best < 0.00005) {
			source.rgb = mapped;
		}
	}
	COLOR = source;
}
