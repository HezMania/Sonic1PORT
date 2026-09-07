shader_type canvas_item;
render_mode unshaded;

// Phase 72: palette-indexed background path for GHZ. The source pattern/layout
// image stores the 6-bit Genesis CRAM index in an R8 texture; only this 64-entry
// palette texture changes when PalCycle_GHZ rotates the water colors.
uniform sampler2D genesis_palette : filter_nearest;

void fragment() {
	float encoded = texture(TEXTURE, UV).r;
	int palette_index = int(floor(encoded * 255.0 + 0.5));
	if (palette_index == 0) {
		COLOR = vec4(0.0);
	} else {
		vec4 palette_color = texelFetch(genesis_palette, ivec2(palette_index, 0), 0);
		COLOR = vec4(palette_color.rgb, 1.0);
	}
}
