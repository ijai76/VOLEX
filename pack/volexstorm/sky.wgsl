override sky_style: f32 = 0.8;
override night_mood: f32 = 0.7;

fn sky(input: SkyInput) -> vec4<f32> {
    let d = input.direction;
    var c = input.color.rgb;

    let day = day_amount() * (1.0 - frame.wetness);
    let toward = max(dot(d, frame.sun_direction), 0.0);
    let near_horizon = 1.0 - smoothstep(0.0, 0.5, abs(d.y));
    let halo = pow(toward, 4.0) * 0.5 + near_horizon * toward * toward * 0.4;
    let warm = vec3<f32>(1.0, 0.55, 0.28) * halo * low_sun() * day * sky_style * 1.3;
    let zenith = smoothstep(0.1, 1.0, d.y) * day * 0.14 * sky_style;
    c = c * (vec3<f32>(1.0) - zenith * vec3<f32>(0.55, 0.25, 0.0)) + warm;

    let grey = vec3<f32>(luma(c)) * vec3<f32>(0.9, 0.97, 1.06);
    c = mix(c, grey, frame.wetness * 0.6);
    c *= 1.0 - frame.thunder * 0.35;

    let night = night_amount();
    c = mix(c, c * vec3<f32>(0.7, 0.86, 1.3) + vec3<f32>(0.004, 0.012, 0.035), night * 0.75 * night_mood);
    let moon = max(dot(d, frame.moon_direction), 0.0);
    c += vec3<f32>(0.5, 0.62, 1.0) * (pow(moon, 24.0) * 0.1 + pow(moon, 400.0) * 0.4) * night * night_mood * (1.0 - frame.wetness * 0.8);

    return vec4<f32>(clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
