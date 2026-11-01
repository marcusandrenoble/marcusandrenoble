#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/render-banner.sh
# Requires macOS, Swift (Xcode command-line tools), and FFmpeg on PATH.
# Only rendered media is published; system font files are not distributed.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$repo_root/.build/banner"
command -v swiftc >/dev/null
command -v ffmpeg >/dev/null
mkdir -p "$build_dir" "$repo_root/assets"

swiftc -O "$repo_root/scripts/render-banner.swift" -o "$build_dir/render"
"$build_dir/render" "$build_dir"
cmp "$build_dir/frames/frame-0000.png" "$build_dir/endpoint.png"

ffmpeg -hide_banner -loglevel warning -y -framerate 25 \
  -i "$build_dir/frames/frame-%04d.png" \
  -filter_complex '[0:v]scale=1200:150:flags=lanczos,split[a][b];[a]palettegen=reserve_transparent=0:stats_mode=full[p];[b][p]paletteuse=dither=none' \
  -frames:v 150 -loop 0 "$build_dir/name.gif"

ffmpeg -hide_banner -loglevel warning -y -framerate 25 \
  -i "$build_dir/frames/frame-%04d.png" -frames:v 150 \
  -vf 'scale=out_color_matrix=bt709:out_range=tv' \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p \
  -movflags +faststart -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  "$build_dir/name.mp4"

cp "$build_dir/name.gif" "$repo_root/assets/name.gif"
cp "$build_dir/name.mp4" "$repo_root/assets/name.mp4"
printf 'Updated assets/name.gif and assets/name.mp4\n'
