shader_type canvas_item;

uniform float ripple_speed : hint_range(0.1, 5.0) = 1.0;
uniform float ripple_strength : hint_range(0.01, 0.2) = 0.03;
uniform vec4 water_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);

void fragment() {
    // Generate a scrolling ripple pattern using sine waves
    vec2 uv = UV;
    
    // Time-based offset
    float t = TIME * ripple_speed;
    
    // Distort UVs
    vec2 distorted_uv = uv;
    distorted_uv.x += sin(uv.y * 20.0 + t) * ripple_strength;
    distorted_uv.y += cos(uv.x * 20.0 + t * 0.8) * ripple_strength;
    
    // Sample the base texture (which determines the shape, so we respect alpha)
    vec4 tex_color = texture(TEXTURE, UV);
    
    if (tex_color.a > 0.0) {
        // Create caustic/highlight bands
        float highlight = sin(distorted_uv.x * 30.0 + distorted_uv.y * 30.0 + t * 2.0);
        highlight = smoothstep(0.8, 0.95, highlight);
        
        // Blend base color with highlights
        vec3 final_color = mix(water_color.rgb, highlight_color.rgb, highlight * highlight_color.a);
        
        COLOR = vec4(final_color, tex_color.a);
    } else {
        COLOR = vec4(0.0);
    }
}
