override shadows: bool = true;
override shadow_softness: u32 = 1u;
override sun_strength: f32 = 1.0;
override ambient_strength: f32 = 1.0;
override block_light_strength: f32 = 1.0;
override colored_lights: bool = true;
override reflections: bool = true;
override water_clarity: f32 = 0.5;
override foliage_tone: f32 = 0.3;
override wet_surfaces: f32 = 0.7;
override night_mood: f32 = 0.7;

fn material(input: MaterialInput) -> Surface {
    if input.fluid == 2u {
        return Surface(vec4<f32>(input.albedo.rgb * input.tint.rgb * 1.05, input.albedo.a));
    }
    if frame.dimension != 0 {
        let base = input.albedo.rgb * input.tint.rgb;
        let color = base * (input.lightmap + input.colored_light * block_light_strength);
        return Surface(vec4<f32>(shoulder(max(color, base * input.emission)), input.albedo.a));
    }
    if input.fluid == 1u {
        return Surface(water_surface(input));
    }
    return Surface(lit_terrain(input));
}
