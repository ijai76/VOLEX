fn water_normal(xz: vec2<f32>, t: f32, storm: f32) -> vec3<f32> {
    if !water_waves {
        return vec3<f32>(0.0, 1.0, 0.0);
    }
    let e = 0.06;
    let h = wave_field(xz, t, storm);
    let dx = (wave_field(xz + vec2<f32>(e, 0.0), t, storm) - h) / e;
    let dz = (wave_field(xz + vec2<f32>(0.0, e), t, storm) - h) / e;
    let micro = vec2<f32>(
        value_noise(xz * 3.1 + vec2<f32>(t * 0.35, -t * 0.28)) - 0.5,
        value_noise(xz * 3.7 + vec2<f32>(-t * 0.3, t * 0.33) + 9.1) - 0.5,
    ) * (0.08 + 0.2 * storm);
    let slope = -vec2<f32>(dx, dz) * (0.1 + 0.16 * storm) + micro;
    return normalize(vec3<f32>(slope.x, 1.0, slope.y));
}

fn distance_at(screen: vec2<f32>, depth: f32) -> f32 {
    if depth <= 0.0 {
        return 1e4;
    }
    let clip = vec4<f32>(screen.x * 2.0 - 1.0, 1.0 - screen.y * 2.0, depth, 1.0);
    let view = frame.projection_inverse * clip;
    return length(view.xyz / view.w);
}

fn water_surface(input: MaterialInput) -> vec4<f32> {
    let world = input.position + frame.camera_position;
    let t = frame.time;
    let storm = storm_level();
    let to_eye = normalize(-input.position);
    let top = input.face == 1u;
    let flowing = (input.tags & TAG_WATER_FLOW) != 0u;
    let wall = abs(input.normal.y) < 0.5;
    let fall = select(0.0, 1.0, flowing && wall);

    var n = input.normal;
    if top {
        n = water_normal(world.xz, t, storm);
        let rip = ripple_grad(world.xz, t) * frame.wetness * 0.5;
        n = normalize(n + vec3<f32>(-rip.x, 0.0, -rip.y));
        n = select(n, -n, input.normal.y < 0.0);
    }

    let size = vec2<f32>(textureDimensions(opaque_color));
    let bent = clamp(input.screen + n.xz * 0.02, vec2<f32>(0.0), vec2<f32>(1.0));
    let texel = vec2<i32>(min(bent * size, size - 1.0));
    let behind = textureLoad(opaque_color, texel, 0).rgb;
    let thickness = max(distance_at(bent, textureLoad(opaque_depth, texel, 0)) - length(input.position), 0.0);

    let tint_col = input.tint.rgb / max(max(input.tint.r, max(input.tint.g, input.tint.b)), 0.01);
    let ll = luma(input.lightmap);
    let sunlit = day_amount() * smoothstep(0.5, 1.0, input.light.y);
    let crest = wave_field(world.xz, t, storm);
    let deep = vec3<f32>(0.03, 0.17, 0.25) * mix(vec3<f32>(1.0), tint_col * 1.5, 0.5) * (0.3 + 0.7 * ll) * (1.0 - 0.4 * storm);
    let scatter = vec3<f32>(0.05, 0.32, 0.34) * smoothstep(0.0, 0.9, crest) * ll * (0.4 + 0.6 * sunlit) * (1.0 - 0.5 * storm);

    // Light is absorbed red first, then green, so shallow water shows the bed and deep water its own colour.
    let reach = mix(2.0, 14.0, water_clarity);
    let absorb = exp(-thickness / reach * vec3<f32>(2.0, 0.85, 0.55));
    var color = mix(deep + scatter, behind, absorb);

    if frame.eye_in == 1u {
        return vec4<f32>(mix(color, deep * 1.5, 0.3), 1.0);
    }

    let cos_v = clamp(dot(n, to_eye), 0.0, 1.0);
    let fresnel = 0.03 + 0.97 * pow(1.0 - cos_v, 5.0);
    var mirrored = sky_reflection(reflect(-to_eye, n), t) * mix(0.35, 1.0, smoothstep(0.2, 0.9, input.light.y));
    if reflections && top && frame.has_reflection == 1u {
        let ruv = clamp(input.screen + n.xz * 0.03, vec2<f32>(0.0), vec2<f32>(1.0));
        mirrored = textureSampleLevel(reflection, reflection_sampler, ruv, 0.0).rgb;
    }
    mirrored = mix(mirrored, vec3<f32>(luma(mirrored)) * 0.75, storm * 0.5);
    color = mix(color, mirrored, fresnel * smoothstep(0.2, 0.8, input.light.y));

    let foam = smoothstep(0.78, 1.0, crest) * smoothstep(0.35, 0.8, storm) * (0.6 + 0.4 * value_noise(world.xz * 5.0 + t * (1.0 + storm)));
    color += vec3<f32>(0.85, 0.9, 0.95) * foam * (0.25 + 0.75 * ll) * 0.7;

    let tang = normalize(vec2<f32>(-input.normal.z, input.normal.x) + vec2<f32>(1e-5, 0.0));
    let streak = fall * smoothstep(0.5, 0.95, value_noise(vec2<f32>(dot(world.xz, tang) * 2.4, world.y * 0.6 + t * (2.4 + 1.2 * storm))));
    let slope = length(input.normal.xz) / max(abs(input.normal.y), 0.05);
    let downhill = normalize(input.normal.xz + vec2<f32>(1e-5, 0.0));
    let run = select(0.0, smoothstep(0.04, 0.3, slope), flowing && top);
    let runs = run * smoothstep(0.6, 0.95, value_noise((world.xz - downhill * t * (0.6 + 2.5 * slope)) * 3.0));
    color = mix(color, vec3<f32>(0.78, 0.9, 0.96) * (0.35 + 0.65 * ll), fall * 0.3);
    color += vec3<f32>(0.9, 0.95, 1.0) * (streak + runs * 0.5) * (0.3 + 0.7 * ll) * 0.5;

    let sun = direct_light() * sun_strength * shadow_visibility(input.position, vec3<f32>(0.0, 1.0, 0.0), frame.light_direction.y);
    let half_way = normalize(frame.light_direction + to_eye);
    color += sun * pow(max(dot(n, half_way), 0.0), 400.0) * 4.0;
    return vec4<f32>(shoulder(color), 1.0);
}
