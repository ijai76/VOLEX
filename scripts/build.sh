#!/bin/sh
set -eu

pack=pack/volexstorm
out=dist

if ! command -v horizon-shader >/dev/null 2>&1; then
    echo "horizon-shader is not installed or not on PATH." >&2
    exit 1
fi

horizon-shader check "$pack"

version=$(sed -n 's/^version = "\(.*\)"/\1/p' "$pack/horizon-shaders.toml" | head -n 1)
mkdir -p "$out"
horizon-shader pack "$pack" --out "$out/VOLEXSTORM-$version.hshader"

# The importer wants the manifest at the archive root, so the zip is built from inside the pack folder.
rm -f "$out/VOLEXSTORM-$version.zip"
(cd "$pack" && zip -X -D -r "../../$out/VOLEXSTORM-$version.zip" . >/dev/null)
