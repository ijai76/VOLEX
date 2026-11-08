const MAT_LEAVES: u32 = 1u;
const MAT_PLANT: u32 = 2u;
const MAT_TALL_LOWER: u32 = 3u;
const MAT_TALL_UPPER: u32 = 4u;
const MAT_VINE: u32 = 5u;
const TAG_WATER_FLOW: u32 = 1u;

fn luma(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

fn day_amount() -> f32 {
    return select(0.0, smoothstep(-0.08, 0.1, frame.sun_direction.y), frame.dimension == 0);
}

fn night_amount() -> f32 {
    return select(0.0, 1.0 - smoothstep(-0.15, 0.05, frame.sun_direction.y), frame.dimension == 0);
}

fn low_sun() -> f32 {
    return 1.0 - smoothstep(0.0, 0.35, abs(frame.sun_direction.y));
}

// Wetness is rain smoothed over about 30 seconds, so waves and fog change gradually instead of jumping.
fn storm_level() -> f32 {
    return clamp(frame.wetness * 0.45 + frame.thunder * 0.7, 0.0, 1.0);
}

fn shoulder(c: vec3<f32>) -> vec3<f32> {
    let k = max(c - vec3<f32>(0.75), vec3<f32>(0.0));
    return min(c, vec3<f32>(0.75)) + 0.25 * k / (k + vec3<f32>(0.25));
}

// Integer hash: a float hash turns into stripes far from the world origin.
fn hash21(p: vec2<f32>) -> f32 {
    let ip = vec2<i32>(floor(p));
    var h = (bitcast<u32>(ip.x) * 1597334673u) ^ (bitcast<u32>(ip.y) * 3812015801u);
    h = (h ^ (h >> 16u)) * 2246822519u;
    h = (h ^ (h >> 13u)) * 3266489917u;
    h = h ^ (h >> 16u);
    return f32(h >> 8u) * (1.0 / 16777216.0);
}

fn value_noise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    let a = hash21(i);
    let b = hash21(i + vec2<f32>(1.0, 0.0));
    let c = hash21(i + vec2<f32>(0.0, 1.0));
    let d = hash21(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn fbm3(p: vec2<f32>) -> f32 {
    return 0.5 * value_noise(p) + 0.25 * value_noise(p * 2.03 + vec2<f32>(1.7, 9.2)) + 0.125 * value_noise(p * 4.01 + vec2<f32>(8.3, 2.8));
}

fn fbm2(p: vec2<f32>) -> f32 {
    return 0.5 * value_noise(p) + 0.25 * value_noise(p * 2.03 + vec2<f32>(1.7, 9.2));
}

fn ign(pixel: vec2<f32>) -> f32 {
    return fract(52.9829189 * fract(dot(pixel, vec2<f32>(0.06711056, 0.00583715))));
}

// Depends on world position only, so neighbouring blocks meet without seams.
fn wave_field(xz: vec2<f32>, t: f32, storm: f32) -> f32 {
    let speed = 0.5 + 1.8 * storm;
    let w1 = sin(dot(xz, vec2<f32>(0.78, 0.62)) * 0.85 + t * 0.9 * speed);
    let w2 = sin(dot(xz, vec2<f32>(-0.55, 0.83)) * 1.25 + t * 1.25 * speed + 1.7);
    let w3 = sin(dot(xz, vec2<f32>(0.2, -0.98)) * 2.1 - t * 1.7 * speed + 4.2);
    let drift = sin(xz.x * 0.23 + t * 0.11) * sin(xz.y * 0.19 - t * 0.09);
    return clamp(0.5 + (w1 * 0.45 + w2 * 0.3 + w3 * (0.15 + 0.2 * storm) + drift * 0.1) * 0.5, 0.0, 1.0);
}

fn ripple_grad(p: vec2<f32>, t: f32) -> vec2<f32> {
    let cell = floor(p * 1.6);
    let f = fract(p * 1.6) - 0.5;
    let phase = fract(t * 0.7 + hash21(cell));
    let r = length(f);
    let q = (r - phase * 0.5) * 12.0;
    let ring = sin((r - phase * 0.5) * 40.0) * exp(-q * q) * (1.0 - phase);
    return f / max(r, 0.001) * ring * 1.2;
}

fn sky_reflection(r: vec3<f32>, t: f32) -> vec3<f32> {
    let day = day_amount();
    var col = mix(frame.fog_color, frame.sky_color, smoothstep(-0.02, 0.55, r.y));
    let sun_amt = max(dot(r, frame.sun_direction), 0.0);
    col += vec3<f32>(1.0, 0.6, 0.3) * pow(sun_amt, 6.0) * low_sun() * day * 0.5;
    let cuv = r.xz / (max(r.y, 0.02) + 0.2) * 1.2 + vec2<f32>(t * 0.01, 0.0);
    let cl = smoothstep(0.5, 0.78, fbm3(cuv)) * smoothstep(0.03, 0.3, r.y);
    let cloud = mix(vec3<f32>(0.25), vec3<f32>(1.0), day) * (1.0 - frame.wetness * 0.4);
    return mix(col, cloud, cl * 0.5 * (1.0 - frame.wetness * 0.5));
}
