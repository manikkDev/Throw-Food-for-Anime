# VFX progress (section 4)

Updated 2026-11-15 (v2, after the coordinator's in-engine review).

## Done
- All 27 effects authored, stripped, packed. In-engine review: Reveal_* x7, Land_Impact,
  PerfectThrow_Flash, Train_Hit, PowerUp_Burst, Coin_Pop, Slot_Unlock, Zone_Unlock, Rebirth_Nova,
  Summon_Portal accepted as they are.
- The coordinator's `span()` normaliser in `tools/build_templates.template.luau` (Color/Number
  sequences must start at 0 and end at 1) is kept; it is in the regenerated builder.
- v2 FIX 1, auras (`builders/build_auras.py` rewritten): every aura = a bright filled glow disc
  (LightEmission 1, radius ~3.7) + a near-opaque pulsing ring (radius ~3.9, the LowKeep layer) +
  a "special pet" halo glow behind the body (ZOffset -3, so the hero and face stay in front) + a
  rising element shell on a cylinder of radius 2.6 from the feet to the waist, lifted by
  Acceleration, fading before head height. Lifetimes 0.6-1.0 s. Peaks: Golden 52, Flame 49,
  Lightning 38, Galaxy 52, Titan 24 (all < 60). Titan: ripple 7 -> 16 studs across (radius 3.5-8)
  pulsing twice a second + a hard ring pulse + warm base disc. Strips now include a ~60-stud row.
- v2 FIX 2, trails (`build_throw.py`): judged from the chase camera (16 behind, 6 above, riding
  along) over cream / pink / mint floors (strip rows 2-4). Each trail = a solid cel ribbon 3 studs
  wide at the food tapering to 0 + a darker edge copy 3.9 wide (LightEmission 0) + a glow layer + a
  hot centre line + dense crumbs (Basic 70/s stars, Hot puffs + embers, Epic gold stars + rings).
  New texture `tfa/ribbon_solid` (solid band; soft glow strips vanished on pale floors).
- v2 FIX 3, ServerLuck_Sky: two soft green-and-gold aurora ARCS (not a loop), LightEmission 0.15
  so a blue sky no longer shifts them to cyan; green clovers, gold twinkles.
- Checks: 27 kits Lune compile + build OK; `check_templates.luau`: 27/27, no PROP_FAILS;
  `python tools/gate.py`: all gates green.

## Left (coordinator, Studio)
1. Upload the 2 NEW textures as Image, add them to `assets/vfx/ids.json`:
   `lib__sprites__shapes__orb_soft_00.png`, `tfa__ribbon_solid__vt.png` (both in `assets/vfx/upload/`).
2. `python assets/vfx/tools/pack_all.py`, run `work/vfx/build_templates.luau` in edit mode.
3. Re-judge the 5 auras (30 and 60 studs on pedestals), the 3 trails (chase camera) and the sky.
No longer used (ids can stay in ids.json, harmless): speed_streaks_cel_01__vt, streak_soft_00__vt,
ring_soft_08, dot_soft_00.

## Weak / unverified
- Aura shells use a Cylinder emitter shape on the carrier Part (sim: CALIBRATE). If Studio emits
  them from a vertical line or the wrong axis, swap the shell to a Disc at the feet with a higher
  lift (one line in `spe()`).
- The halo relies on ZOffset -3 to stay behind the hero; check it does not tint the face on a
  hero wider than 3 studs.
- ThrowTrail_Hot ignores the food tint (fire stays orange); Basic and Epic take it on every layer
  marked Tint (ribbon, edge as a darker shade, glow, line; Epic's gold stars and sparkle stay gold).

## Resume
```
python assets/vfx/tools/serve_tfa.py              # background, port 8766
for b in assets/vfx/builders/build_*.py; do python $b; done
node assets/vfx/tools/strip.mjs [--grounds=light] [--tw=1000] assets/vfx/effects/<Name>.json
python assets/vfx/tools/pack_all.py --kits
lune run assets/vfx/tools/check_templates.luau
python tools/gate.py
```
