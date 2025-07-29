shader_type canvas_item;

// Grid settings
uniform float grid_size : hint_range(10.0, 200.0) = 50.0;
uniform float line_width : hint_range(0.5, 10.0) = 2.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_alpha : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    // Use UV coordinates and scale them to create grid
    vec2 grid_uv = UV * vec2(1152.0, 648.0); // Your play area size

    // Calculate grid position
    vec2 grid_pos = mod(grid_uv, grid_size);

    // Calculate distance to nearest grid line
    float dist_to_line = min(
        min(grid_pos.x, grid_size - grid_pos.x),
        min(grid_pos.y, grid_size - grid_pos.y)
    );

    // Create line effect with smooth transition
    float line_factor = 1.0 - smoothstep(0.0, line_width, dist_to_line);

    // Mix background and line colors
    vec3 final_color = mix(background_color.rgb, line_color.rgb, line_factor);
    float final_alpha = mix(background_color.a, line_color.a * line_alpha, line_factor);

    COLOR = vec4(final_color, final_alpha);
}