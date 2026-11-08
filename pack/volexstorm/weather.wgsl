override rain_look: f32 = 0.8;

fn weather(input: WeatherInput) -> vec4<f32> {
    let dist = length(input.position);
    let near_fade = smoothstep(0.4, 2.5, dist);
    let far_fade = 1.0 - 0.5 * smoothstep(15.0, 60.0, dist);
    let bright = mix(0.3, 1.0, day_amount()) * (0.45 + 0.55 * input.light.y);
    if input.snow {
        return vec4<f32>(input.color.rgb * mix(0.6, 1.0, bright), input.color.a * near_fade * mix(1.0, 0.7, rain_look));
    }
    let grey = vec3<f32>(luma(input.color.rgb));
    let col = mix(mix(input.color.rgb, grey, 0.65), vec3<f32>(0.82, 0.88, 0.96), 0.5) * bright;
    return vec4<f32>(col, input.color.a * near_fade * far_fade * mix(1.0, 0.12, rain_look));
}
