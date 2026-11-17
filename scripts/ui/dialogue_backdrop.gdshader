shader_type canvas_item;
// The dialogue background when a room has no painting of its own: the room's picture, softened like a camera focused
// on the people in front of it, and a little darker so the words read clearly.

uniform float radius = 3.0;
uniform float dim = 0.78;

void fragment() {
	vec2 step = TEXTURE_PIXEL_SIZE * radius;
	vec4 sum = texture(TEXTURE, UV) * 0.16;
	sum += texture(TEXTURE, UV + vec2(step.x, 0.0)) * 0.09;
	sum += texture(TEXTURE, UV - vec2(step.x, 0.0)) * 0.09;
	sum += texture(TEXTURE, UV + vec2(0.0, step.y)) * 0.09;
	sum += texture(TEXTURE, UV - vec2(0.0, step.y)) * 0.09;
	sum += texture(TEXTURE, UV + step) * 0.06;
	sum += texture(TEXTURE, UV - step) * 0.06;
	sum += texture(TEXTURE, UV + vec2(step.x, -step.y)) * 0.06;
	sum += texture(TEXTURE, UV + vec2(-step.x, step.y)) * 0.06;
	sum += texture(TEXTURE, UV + vec2(step.x * 2.0, 0.0)) * 0.06;
	sum += texture(TEXTURE, UV - vec2(step.x * 2.0, 0.0)) * 0.06;
	sum += texture(TEXTURE, UV + vec2(0.0, step.y * 2.0)) * 0.06;
	sum += texture(TEXTURE, UV - vec2(0.0, step.y * 2.0)) * 0.06;
	COLOR = vec4(sum.rgb * dim, 1.0) * COLOR;
}
