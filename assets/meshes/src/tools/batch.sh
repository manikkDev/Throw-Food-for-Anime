#!/usr/bin/env bash
# One batch: sync header, build + convert + measure, one contact sheet, (foods) icons, manifest.
#   bash assets/meshes/src/tools/batch.sh foods sheetname Food_a Food_b ...
#   bash assets/meshes/src/tools/batch.sh gear  sheetname Equip_a ...   (gear sheet adds the character box)
set -e
GAME="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$GAME"
kind="$1"; sheet="$2"; shift 2
T=assets/meshes/src/tools
node $T/sync_header.mjs > /dev/null
node $T/build.mjs "$kind" "$@" 2>&1 | cut -c1-700
glbs=(); labels=""
for n in "$@"; do glbs+=("assets/meshes/$kind/$n.glb"); labels="$labels${labels:+,}${n#*_}"; done
if [ "$kind" = gear ]; then extra="--char --az 0 --el 14 --spin 20 --gap 1.5"; else extra="--az 0 --el 24 --spin 30 --gap 0.8"; fi
"$BLENDER" --background --python $T/render.py -- --mode row $extra --size 2400 --labels "$labels" --out "work/models/$kind/$sheet.png" "${glbs[@]}" 2>&1 | grep -iE "error|traceback" -A3 || true
if [ "$kind" = foods ]; then
  "$BLENDER" --background --python $T/render.py -- --mode icons --size 256 --outdir assets/ui/food_icons "${glbs[@]}" 2>&1 | grep -iE "error|traceback" -A3 || true
fi
node $T/manifest.mjs
