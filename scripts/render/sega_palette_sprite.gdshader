shader_type canvas_item;
render_mode unshaded;

// Phase 66: the SEGA logo plane pixels are static palette indices. Only this
// 64-entry CRAM texture changes during PalCycle_Sega.
uniform sampler2D sega_palette : filter_nearest;

void fragment() {
	vec4 encoded = texture(TEXTURE, UV);
	if (encoded.a < 0.5) {
		COLOR = vec4(0.0);
	} else {
		int palette_index = int(floor(encoded.r * 255.0 + 0.5));
		vec4 palette_color = texelFetch(sega_palette, ivec2(palette_index, 0), 0);
		COLOR = vec4(palette_color.rgb, encoded.a);
	}
}
