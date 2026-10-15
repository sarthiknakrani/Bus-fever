shader_type canvas_item;

uniform float shine_progress : hint_range(-1.0, 2.0) = -1.0;
uniform float shine_size : hint_range(0.01, 0.5) = 0.16;
uniform float shine_angle : hint_range(0.0, 89.0) = 28.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.05 && shine_progress > -0.8 && shine_progress < 1.8) {
		float angle_rad = radians(shine_angle);
		vec2 dir = vec2(cos(angle_rad), sin(angle_rad));
		float proj = dot(UV, dir);
		float d = abs(proj - shine_progress);
		if (d < shine_size) {
			float intensity = (1.0 - d / shine_size) * 0.45 * tex.a;
			tex.rgb += vec3(intensity);
		}
	}
	COLOR = tex;
}
