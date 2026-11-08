# VOLEXSTORM

A shader pack for Horizon Android, written in WGSL. VOLEXSTORM draws sun and moon shadows from a shadow map, makes water reflect and refract the world, sways leaves and grass in the vertex stage, and changes the water, the fog and the rain with the weather.

## What it does

### Shadows

The sun and the moon cast shadows from a shadow map. The distance is 64, 96, 128 or 160 blocks (128 blocks, eight chunks, by default) and the map is 1024, 2048 or 4096 texels wide. The sharp, soft and very soft edges read the map once, four times and nine times. The offset and the bias come from the texel size at each point and from the slant of the surface against the light, so the ground stays free of stripes when the sun is low. Leaves cast whole shadows even though their texture has holes.

### Water

The base colour of water is a dark teal. Red light is absorbed first, so shallow water shows its bed and deep water shows its own colour. Reflections use Horizon's reflection pass. With the option off, water mirrors a sky and clouds computed in the shader. The waves come from three sine waves running in different directions, plus fine noise on the surface normal. In calm weather the waves move slowly. In a storm they get taller and faster, and the crests foam. Water running down a wall (the `water_flow` sprite) moves downward and looks whiter. Sloped water runs downhill.

### Wind

The vertex stage moves the corners of leaf, grass, tall plant and vine blocks. The wind direction swings slowly, gusts travel along it, and the strength rises in a storm. The part of a plant near the ground moves less than its tip. The Wind option sets the strength from 0 to 3.

### Weather

The weather stage turns rain and snow pale and almost transparent. Setting Rain transparency to 0 keeps the vanilla look. In the rain, blocks darken, puddles mirror the sky and ripples appear in puddles and on water. The fog is thin when the weather is clear, thicker in the rain, and thick and dark in a thunderstorm. Its density drifts slowly.

### Light and atmosphere

Sunlight shifts from orange when the sun is low to a warm white when it is high, and moonlight is blue. Block light can be coloured: soul fire blue, redstone red, copper green, lava orange and a few more (the full list is in `[[lights]]` in the manifest). Leaves glow from behind when the camera faces the sun. Contact shadows, a screen-space ambient occlusion, darken creases and the feet of objects. Nights get a cool blue tone with a halo around the moon. Exposure, contrast, saturation and vignette can be set.

## Settings

| Page | Option | Default | Values |
|---|---|---|---|
| Lighting | Shadows | on | on or off |
| Lighting | Shadow edges | Soft | Sharp, Soft, Very soft |
| Lighting | Shadow detail | 2048 | 1024, 2048, 4096 |
| Lighting | Shadow distance | 128 | 64, 96, 128, 160 |
| Lighting | Sunlight | 1.0 | 0.0 to 2.0 |
| Lighting | Sky light | 1.0 | 0.0 to 2.0 |
| Lighting | Block light | 1.0 | 0.0 to 2.0 |
| Lighting | Coloured light | on | on or off |
| Lighting | Contact shadows | 0.6 | 0.0 to 1.5 |
| Water | Reflections | on | on or off |
| Water | Waves | on | on or off |
| Water | Water clarity | 0.5 | 0.0 to 1.0 |
| Nature | Waving plants | on | on or off |
| Nature | Wind | 1.0 | 0.0 to 3.0 |
| Nature | Foliage colour | 0.3 | -1.0 to 1.0 |
| Weather | Rain transparency | 0.8 | 0.0 to 1.0 |
| Weather | Wet ground | 0.7 | 0.0 to 1.0 |
| Weather | Weather fog | 0.6 | 0.0 to 1.0 |
| Atmosphere | Sky colour | 0.8 | 0.0 to 1.0 |
| Atmosphere | Night mood | 0.7 | 0.0 to 1.0 |
| Camera | Exposure | 1.0 | 0.5 to 2.0 |
| Camera | Contrast | 1.1 | 0.8 to 1.4 |
| Camera | Saturation | 1.1 | 0.5 to 1.6 |
| Camera | Vignette | 0.25 | 0.0 to 1.0 |

## Performance

The shadow pass redraws the terrain inside the shadow box every frame, so its cost climbs quickly with distance. If the frame rate drops, lower the shadow distance or detail, or turn shadows off. Reflections add one half-resolution terrain pass. The manifest lists a GPU budget of 3.0 ms as an estimate, not a measurement.

## Limits

- Shadows exist only within the chosen distance. Beyond it everything is lit.
- In the Nether and the End the pack uses a simplified vanilla lighting.
- Leaves and plants are recognised by vanilla sprite names, so blocks from mods do not sway.

## Testing

The shadow function was run on a software GPU against reference shadows computed on the CPU, in a synthetic scene with four sun heights. In that scene fewer than 0.1% of the pixels that should be lit came out dark, and surfaces facing the sun did not shade themselves. The post stage was run on a synthetic scene with the extreme value of every option. The sky, vertex, material and weather stages are validated by `horizon-shader check`, including at the minimum and maximum of each option.

## Repository layout

```
pack/volexstorm/     the pack: manifest and WGSL files
  horizon-shaders.toml
  common.wgsl        helpers shared by every stage
  sky.wgsl           sky
  vertex.wgsl        wind and water waves
  material.wgsl      material entry point
  lighting.wgsl      shadows, sunlight, block light
  water.wgsl         water surface
  weather.wgsl       rain and snow
  post/finish.wgsl   fog, contact shadows, colour grade
scripts/build.sh     check and pack
.github/workflows/   check on GitHub Actions
```

## Credits and license

Thanks for Horizon Android port from Vasysik
All shader code in this repository is original. MIT license, see `LICENSE`.
