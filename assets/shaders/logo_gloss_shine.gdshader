shader_type canvas_item;

// Periodic Glossy Shine / Specular Sweep Shader for "BUS FEVER PARTY!" title logo
// Sweeps a bright glossy diagonal shine across the text letters every 2 seconds.

uniform bool use_time_cycle = false;
uniform float cycle_duration : hint_range(0.5, 10.0) = 2.0;   // Every 2.0 seconds
uniform float sweep_duration : hint_range(0.2, 2.0) = 0.70;    // Active sweep time (0.7s sweep + 1.3s pause)
uniform float manual_progress : hint_range(-0.6, 1.6) = -0.5; // Manual control override via Tween

uniform float shine_angle : hint_range(0.0, 89.0) = 28.0;     // Diagonal sweep angle in degrees
uniform float shine_width : hint_range(0.02, 0.5) = 0.08;      // Crisp, thin main glint beam
uniform float shine_softness : hint_range(0.01, 0.4) = 0.04;   // Sleek edge feathering
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Crisp pure glossy white shine

// Secondary trailing gloss beam (casual mobile game standard)
uniform bool enable_secondary_beam = true;
uniform float secondary_offset : hint_range(0.05, 0.4) = 0.09;
uniform float secondary_width : hint_range(0.01, 0.3) = 0.025;
uniform float secondary_alpha : hint_range(0.1, 1.0) = 0.55;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Only process non-transparent pixels of the logo
	if (tex.a > 0.01) {
		float progress = manual_progress;
		if (use_time_cycle) {
			float t_cycle = mod(TIME, cycle_duration);
			if (t_cycle < sweep_duration) {
				float norm_t = t_cycle / sweep_duration;
				// Smooth cubic ease in-out curve
				float smooth_t = smoothstep(0.0, 1.0, norm_t);
				progress = mix(-0.5, 1.5, smooth_t);
			} else {
				progress = -1.0; // Rest offscreen
			}
		}

		// Calculate projection along the tilted normal
		float rad = radians(shine_angle);
		vec2 dir = vec2(cos(rad), sin(rad));
		float proj = dot(UV - vec2(0.5), dir) + 0.5;

		// Main glossy beam intensity (safe ascending smoothstep for Metal/Vulkan)
		float dist_main = abs(proj - progress);
		float inner_main = max(0.0, shine_width - shine_softness);
		float outer_main = shine_width;
		float intensity_main = 1.0 - smoothstep(inner_main, outer_main, dist_main);

		// Secondary trailing beam intensity
		float intensity_sec = 0.0;
		if (enable_secondary_beam) {
			float dist_sec = abs(proj - (progress - secondary_offset));
			float inner_sec = max(0.0, secondary_width - shine_softness * 0.7);
			float outer_sec = secondary_width;
			intensity_sec = (1.0 - smoothstep(inner_sec, outer_sec, dist_sec)) * secondary_alpha;
		}

		float total_shine = clamp(intensity_main + intensity_sec, 0.0, 1.0);

		if (total_shine > 0.001) {
			// Calculate saturation and luminance to focus shine specifically on the text letters
			float max_c = max(tex.r, max(tex.g, tex.b));
			float min_c = min(tex.r, min(tex.g, tex.b));
			float sat = max_c - min_c;
			float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

			// Dark neutral road ribbon has low saturation and low luminance
			float text_mask = 1.0;
			if (sat < 0.18) {
				text_mask = 1.0 - smoothstep(0.20, 0.40, 0.40 - lum);
			}

			// Gloss glint factor: candy letters glint brilliantly
			float glint_factor = (0.6 + 0.6 * lum) * text_mask;

			// Additive glossy glint sheen
			vec3 sheen = shine_color.rgb * (total_shine * shine_color.a * glint_factor);
			tex.rgb = clamp(tex.rgb + sheen * tex.a, 0.0, 1.0);
		}
	}

	COLOR = tex;
}
