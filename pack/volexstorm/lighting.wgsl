const SUN_LEVEL: f32 = 0.66;
const SKY_LEVEL: f32 = 0.5;

fn direct_light() -> vec3<f32> {
    let l = frame.light_direction;
    let is_sun = dot(l, frame.sun_direction) > 0.0;
    let high = smoothstep(0.0, 0.3, l.y);
    let sun = mix(vec3<f32>(1.0, 0.5, 0.22), vec3<f32>(1.0, 0.95, 0.87), high);
    let moon = vec3<f32>(0.3, 0.42, 0.78) * (0.12 + 0.12 * night_mood);
    let weather = 1.0 - 0.85 * max(frame.wetness, frame.thunder);
    // Fades to nothing at the horizon so the swap from sun to moon never pops.
    return select(moon, sun, is_sun) * smoothstep(0.0, 0.08, l.y) * weather;
}

fn floor_light() -> vec3<f32> {
    return vec3<f32>(0.85, 0.9, 1.0) * 0.03 * (1.0 + 3.0 * frame.brightness);
}

fn face_shade(n: vec3<f32>) -> f32 {
    let a = abs(n);
    if a.y > 0.99 {
        return select(0.5, 1.0, n.y > 0.0);
    }
    if a.z > 0.99 {
        return 0.8;
    }
    if a.x > 0.99 {
        return 0.6;
    }
    return 1.0;
}

fn shadow_ground_size(p: vec3<f32>) -> f32 {
    let l = frame.light_direction;
    let a = normalize(cross(l, select(vec3<f32>(0.0, 1.0, 0.0), vec3<f32>(1.0, 0.0, 0.0), abs(l.y) > 0.9)));
    let b = cross(l, a);
    let s0 = shadow_position(p).xy;
    let da = length(shadow_position(p + a).xy - s0);
    let db = length(shadow_position(p + b).xy - s0);
    return 1.0 / max(0.5 * (da + db) * frame.shadow_resolution, 0.001);
}

// A surface lit at a slant falls away from the light across each texel, so without an offset and a bias
// that grow with the slant the ground shows stripes at low sun.
fn shadow_visibility(p: vec3<f32>, offset_dir: vec3<f32>, ndl: f32) -> f32 {
    if !shadows || frame.has_shadow == 0u {
        return 1.0;
    }
    let dist = length(p);
    if dist > frame.shadow_distance {
        return 1.0;
    }
    let texel_size = shadow_ground_size(p);
    let c = clamp(ndl, 0.05, 1.0);
    let slope = min(sqrt(1.0 - c * c) / c, 8.0);
    let s = shadow_position(p + offset_dir * texel_size * 0.8 * (1.0 + min(slope, 4.0)));
    if any(s.xy <= vec2<f32>(0.0)) || any(s.xy >= vec2<f32>(1.0)) {
        return 1.0;
    }
    let m = frame.shadow_view_proj;
    let depth_per_block = length(vec3<f32>(m[0].z, m[1].z, m[2].z));
    let spread = select(select(2.5, 1.5, shadow_softness == 1u), 0.5, shadow_softness == 0u);
    let z = s.z - depth_per_block * texel_size * (0.7 + (1.0 + spread) * slope);

    // Each compare tap is already a 2x2 bilinear filter, so a fixed grid of them needs no noise.
    let texel = 1.0 / frame.shadow_resolution;
    var lit = 0.0;
    if shadow_softness == 0u {
        lit = textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy, z);
    } else if shadow_softness == 1u {
        for (var i = 0; i < 4; i++) {
            let o = vec2<f32>(f32(i & 1), f32(i >> 1u)) * 2.0 - 1.0;
            lit += textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy + o * texel, z);
        }
        lit *= 0.25;
    } else {
        for (var i = 0; i < 9; i++) {
            let o = vec2<f32>(f32(i % 3), f32(i / 3)) - 1.0;
            lit += textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy + o * 1.5 * texel, z);
        }
        lit /= 9.0;
    }
    return mix(lit, 1.0, smoothstep(0.9, 1.0, dist / frame.shadow_distance));
}

fn block_light(p: vec3<f32>, level: f32, colored: vec3<f32>) -> vec3<f32> {
    var tint = vec3<f32>(1.0, 0.7, 0.42);
    if colored_lights && level > 0.0 {
        let c = block_light_color(p);
        tint = mix(tint, c.rgb, clamp(c.a, 0.0, 1.0));
    }
    return (tint * pow(level, 2.4) * 1.6 + colored) * block_light_strength;
}

fn ambient_light(p: vec3<f32>, n: vec3<f32>, light: vec2<f32>, colored: vec3<f32>) -> vec3<f32> {
    let day = day_amount();
    let day_sky = mix(frame.sky_color, vec3<f32>(0.88, 0.94, 1.0), 0.35) * SKY_LEVEL;
    let night_sky = vec3<f32>(0.04, 0.06, 0.12) * (0.6 + 0.9 * night_mood);
    var sky = mix(night_sky, day_sky, day);
    sky = mix(sky, vec3<f32>(luma(sky)), frame.wetness * 0.6);
    let facing = 0.78 + 0.22 * n.y;
    let from_sky = sky * (light.y * light.y) * facing * ambient_strength;
    // Vanilla shows the brighter of sky and block light, not their sum, so torches fade in daylight.
    let from_blocks = block_light(p, light.x, colored) * (1.0 - 0.8 * light.y * day);
    return from_sky + from_blocks + floor_light();
}

fn lit_terrain(input: MaterialInput) -> vec4<f32> {
    let n = input.normal;
    let l = frame.light_direction;
    let leaf = input.material == MAT_LEAVES;
    let plant = input.material > MAT_LEAVES && input.material <= MAT_VINE;
    let facing = dot(n, l);
    let to_eye = normalize(-input.position);
    let through = pow(max(dot(to_eye, -l), 0.0), 4.0);

    var ndl = max(facing, 0.0) * smoothstep(0.0, 0.2, facing);
    var through_tint = vec3<f32>(1.0);
    if leaf {
        ndl = pow(clamp(facing * 0.5 + 0.5, 0.0, 1.0), 1.5) * 0.85 + through * 0.4;
        through_tint = mix(vec3<f32>(1.0), vec3<f32>(0.85, 1.0, 0.55), through);
    } else if plant {
        ndl = 0.35 + 0.35 * abs(facing) + through * 0.35;
        through_tint = mix(vec3<f32>(1.0), vec3<f32>(0.85, 1.0, 0.55), through);
    }

    var direct = vec3<f32>(0.0);
    if ndl > 0.0 && sun_strength > 0.0 {
        // Thin plants face the light whichever way they turn, so they are offset toward it.
        let offset_dir = select(n, l, plant);
        let slant = select(facing, 1.0, plant);
        let open = smoothstep(0.0, 0.4, input.light.y);
        direct = direct_light() * through_tint * (SUN_LEVEL * sun_strength) * ndl * open
            * shadow_visibility(input.position, offset_dir, slant);
    }

    var albedo = input.albedo.rgb;
    if leaf || plant {
        let tone = vec3<f32>(1.0 + 0.08 * foliage_tone, 1.0, 1.0 - 0.16 * foliage_tone);
        albedo = mix(vec3<f32>(luma(albedo)), albedo, mix(1.0, 0.94, max(foliage_tone, 0.0))) * tone;
    }

    let light = ambient_light(input.position, n, input.light, input.colored_light) + direct;
    // The light above shades each face itself, so vanilla's baked face shade is taken back out.
    let tint = input.tint.rgb / face_shade(n);
    var color = albedo * tint * light;
    color = max(color, input.albedo.rgb * input.tint.rgb * input.emission);
    color = mix(color, input.albedo.rgb * input.tint.rgb, frame.night_vision * 0.85);

    let wet = frame.wetness * wet_surfaces * smoothstep(0.5, 0.95, input.light.y);
    if wet > 0.001 {
        let world = input.position + frame.camera_position;
        let puddle = smoothstep(0.52, 0.72, fbm3(world.xz * 0.35));
        let up = smoothstep(0.75, 0.95, n.y);
        let amount = up * puddle * wet * select(1.0, 0.0, leaf || plant);
        color *= 1.0 - 0.14 * wet;
        let rip = ripple_grad(world.xz, frame.time) * amount;
        let np = normalize(n + vec3<f32>(-rip.x, 0.0, -rip.y) * 0.25);
        let cos_v = clamp(dot(np, to_eye), 0.0, 1.0);
        let fresnel = 0.05 + 0.95 * pow(1.0 - cos_v, 4.0);
        let mirrored = sky_reflection(reflect(-to_eye, np), frame.time) * 0.9;
        color = mix(color, mirrored, amount * (0.3 + 0.6 * fresnel));
    }

    return vec4<f32>(shoulder(color), input.albedo.a);
}
