shader_type canvas_item;

uniform bool hide_head = false;
uniform bool hide_torso = false;
uniform bool hide_left_arm = false;
uniform bool hide_right_arm = false;
uniform bool hide_left_leg = false;
uniform bool hide_right_leg = false;

varying vec2 sprite_position;

void vertex() {
	sprite_position = VERTEX;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	bool hidden = false;

	if (hide_head && sprite_position.y < -20.0 && abs(sprite_position.x) < 36.0) {
		hidden = true;
	}
	if (hide_torso && sprite_position.y >= -22.0 && sprite_position.y < 18.0
			&& abs(sprite_position.x) < 24.0) {
		hidden = true;
	}
	if (hide_left_arm && sprite_position.y >= -54.0 && sprite_position.y < 34.0
			&& sprite_position.x < -6.0) {
		hidden = true;
	}
	if (hide_right_arm && sprite_position.y >= -54.0 && sprite_position.y < 34.0
			&& sprite_position.x > 6.0) {
		hidden = true;
	}
	if (hide_left_leg && sprite_position.y >= 10.0 && sprite_position.y < 62.0 && sprite_position.x < 1.0) {
		hidden = true;
	}
	if (hide_right_leg && sprite_position.y >= 10.0 && sprite_position.y < 62.0 && sprite_position.x >= 1.0) {
		hidden = true;
	}

	COLOR = hidden ? vec4(pixel.rgb, 0.0) : pixel;
}
