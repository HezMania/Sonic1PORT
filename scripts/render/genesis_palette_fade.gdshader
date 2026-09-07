shader_type canvas_item;

// Phase 57: source-order Sonic 1 3-bit CRAM fades using an explicit
// BackBufferCopy supplied by GenesisPaletteFade. Every displayed pixel is
// quantized back to the Mega Drive's 0..7 RGB channel domain, transformed by
// the same one-channel-at-a-time ordering as _inc/Palette Fading.asm, then
// converted back to normalized RGB.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int fade_mode = 0; // 0 off, 1 black-in, 2 black-out, 3 white-in, 4 white-out
uniform float fade_step = 0.0; // source channel steps, 0..21

float q3(float c) {
	return floor(clamp(c, 0.0, 1.0) * 7.0 + 0.5);
}

// FadeIn_AddColor: blue -> green -> red.
vec3 fade_from_black(vec3 target, float s) {
	float b = min(target.b, s);
	float rem = max(0.0, s - target.b);
	float g = min(target.g, rem);
	rem = max(0.0, rem - target.g);
	float r = min(target.r, rem);
	return vec3(r, g, b);
}

// FadeOut_DecColor: red -> green -> blue.
vec3 fade_to_black(vec3 target, float s) {
	float r = max(0.0, target.r - s);
	float rem = max(0.0, s - target.r);
	float g = max(0.0, target.g - rem);
	rem = max(0.0, rem - target.g);
	float b = max(0.0, target.b - rem);
	return vec3(r, g, b);
}

// WhiteIn_FromWhite: blue -> green -> red while decreasing toward target.
vec3 fade_from_white(vec3 target, float s) {
	float blue_steps = 7.0 - target.b;
	float b = max(target.b, 7.0 - s);
	float rem = max(0.0, s - blue_steps);
	float green_steps = 7.0 - target.g;
	float g = max(target.g, 7.0 - rem);
	rem = max(0.0, rem - green_steps);
	float r = max(target.r, 7.0 - rem);
	return vec3(r, g, b);
}

// WhiteOut_ToWhite: red -> green -> blue while increasing toward 7.
vec3 fade_to_white(vec3 target, float s) {
	float red_steps = 7.0 - target.r;
	float r = min(7.0, target.r + s);
	float rem = max(0.0, s - red_steps);
	float green_steps = 7.0 - target.g;
	float g = min(7.0, target.g + rem);
	rem = max(0.0, rem - green_steps);
	float b = min(7.0, target.b + rem);
	return vec3(r, g, b);
}

void fragment() {
	vec4 src = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (fade_mode == 0) {
		COLOR = src;
		return;
	}

	vec3 target = vec3(q3(src.r), q3(src.g), q3(src.b));
	float s = clamp(floor(fade_step + 0.5), 0.0, 21.0);
	vec3 outc = target;
	if (fade_mode == 1) {
		outc = fade_from_black(target, s);
	} else if (fade_mode == 2) {
		outc = fade_to_black(target, s);
	} else if (fade_mode == 3) {
		outc = fade_from_white(target, s);
	} else if (fade_mode == 4) {
		outc = fade_to_white(target, s);
	}
	COLOR = vec4(outc / 7.0, src.a);
}
