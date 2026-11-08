override ambient_occlusion: f32 = 0.6;
override fog_density: f32 = 0.6;
override night_mood: f32 = 0.7;
override exposure: f32 = 1.0;
override contrast: f32 = 1.1;
override saturation: f32 = 1.1;
override vignette: f32 = 0.25;

// Normal from the neighbouring depths, so flat ground is not mistaken for a crease.
fn contact_ao(uv: vec2<f32>, depth: f32) -> f32 {
    let px = 1.0 / frame.resolution;
    let p = view_position(uv, depth);
    let dist = length(p);
    let fade = 1.0 - smoothstep(30.0, 80.0, dist);
    if fade <= 0.0 {
        return 0.0;
    }
    let uvr = uv + vec2<f32>(px.x, 0.0);
    let uvd = uv + vec2<f32>(0.0, px.y);
    let dr = depth_at(uvr);
    let dv = depth_at(uvd);
    if abs(dr - depth) > 0.05 * depth || abs(dv - depth) > 0.05 * depth {
        return 0.0;
    }
    var n = normalize(cross(view_position(uvr, dr) - p, view_position(uvd, dv) - p));
    n = select(-n, n, dot(n, -p) >= 0.0);
    let rpx = clamp(0.7 * 0.5 * frame.resolution.y * frame.projection[1][1] / max(dist, 0.5), 2.0, 48.0);
    var occ = 0.0;
    for (var i = 0; i < 6; i++) {
        let a = f32(i) * 1.0471976;
        let r = rpx * select(0.5, 1.0, (i % 2) == 1);
        let suv = uv + vec2<f32>(cos(a), sin(a)) * r * px;
        let sd = depth_at(suv);
        if sd > 0.0 {
            let v = view_position(suv, sd) - p;
            let len = length(v);
            let h = dot(n, v) / max(len, 0.001);
            occ += smoothstep(0.2, 0.6, h) * (1.0 - smoothstep(0.8, 1.6, len));
        }
    }
    return occ / 6.0 * fade;
}

fn post(input: PostInput) -> vec4<f32> {
    var c = input.color.rgb;
    let day = day_amount() * (1.0 - frame.wetness);

    if ambient_occlusion > 0.0 && input.depth > 0.0 && frame.eye_in == 0u {
        let ao = contact_ao(input.uv, input.depth);
        c *= 1.0 - clamp(ao * 1.5, 0.0, 1.0) * 0.5 * ambient_occlusion * mix(0.6, 1.0, day_amount());
    }

    let pv = view_position(input.uv, max(input.depth, 0.0005));

    if fog_density > 0.0 && frame.eye_in == 0u {
        let outdoor = smoothstep(0.1, 0.5, frame.eye_light_smooth.y);
        let storm = clamp(frame.thunder, 0.0, 1.0);
        let wet = max(frame.rain, frame.wetness);
        let dens = fog_density * (0.0022 + 0.007 * wet + 0.012 * storm);
        let wp = pv + frame.camera_position;
        let swirl = 0.7 + 0.6 * fbm2(wp.xz * 0.03 + vec2<f32>(frame.time * 0.02, frame.time * 0.013));
        let amount = (1.0 - exp(-min(length(pv), 400.0) * dens * swirl)) * outdoor * select(1.0, 0.5, input.depth <= 0.0);
        var fog_col = frame.fog_color;
        fog_col = mix(fog_col, vec3<f32>(luma(fog_col)) * vec3<f32>(0.85, 0.92, 1.0), wet * 0.7);
        fog_col = mix(fog_col, vec3<f32>(0.16, 0.19, 0.25) * (0.35 + 0.65 * day_amount()), storm * 0.8);
        c = mix(c, fog_col, amount);
    }

    let toward = max(dot(normalize(pv), frame.sun_direction), 0.0);
    c += vec3<f32>(1.0, 0.8, 0.55) * pow(toward, 8.0) * 0.12 * day;

    c *= mix(vec3<f32>(1.0), vec3<f32>(0.75, 0.95, 1.05), frame.in_water);

    let night = night_amount();
    c = mix(c, c * vec3<f32>(0.86, 0.95, 1.16), night * 0.6 * night_mood);
    c += vec3<f32>(0.006, 0.011, 0.024) * night * night_mood;

    c *= exposure;
    c = mix(vec3<f32>(luma(c)), c, saturation);
    c = clamp(mix(vec3<f32>(0.45), c, contrast), vec3<f32>(0.0), vec3<f32>(1.0));

    if vignette > 0.0 {
        let aspect = frame.resolution.x / frame.resolution.y;
        let corner = length(vec2<f32>(aspect, 1.0) * 0.5);
        let d = length((input.uv - 0.5) * vec2<f32>(aspect, 1.0)) / corner;
        c *= 1.0 - smoothstep(0.5, 1.1, d) * vignette * 0.9;
    }

    return vec4<f32>(c, input.color.a);
}
