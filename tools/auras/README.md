# Hand-built hero auras

The imported pack auras (`design/auras.json` templates with a `source`) are converted by
`tools/studio/build_auras.luau`. A hero can instead wear an aura authored from scratch with the
roblox-vfx skill's authoring route: own textures, its own Studio builder, judged in Studio.

| Aura | Hero | Textures | Builder |
|---|---|---|---|
| `StarPlatinum` | Jotaro Kujo (`star_delinquent`) | `tools/auras/star_platinum/make_tex.py` -> `assets/auras/star_platinum/` (`upload.py`) | `tools/studio/auras/build_star_platinum.luau` |
| `Hogyoku` | Sosuke Aizen (`void_empress`, Premium) | `tools/auras/hogyoku/make_tex.py` -> `assets/auras/hogyoku/` (`upload.py`) | `tools/studio/auras/build_hogyoku.luau` |
| `SkillHunter` | Chrollo Lucilfer (`spider_thief_boss`, Legendary) | `tools/auras/skill_hunter/make_tex.py` -> `assets/auras/skill_hunter/` (`upload.py`) | `tools/studio/auras/build_skill_hunter.luau` (assembled by hand from build_hogyoku's scaffolding) |

## Pipeline (one aura)

1. `python tools/auras/<name>/make_tex.py`: textures + `_sheet.jpg` (look at it on dark AND light).
2. Upload each PNG as an **Image**:
   `python ~/.claude/skills/roblox-3d-model/scripts/upload_asset.py --file <png> --name <Aura>_<tex> --asset-type Image`;
   write the ids into `assets/auras/<name>/ids.json` and the builder's `TEX` table.
3. Studio EDIT mode: `python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_<name>.luau`
   -> `ReplicatedStorage.Assets.Auras.<Key>` (HeroAura.luau's template format; writes nothing else). The
   template lives in the PLACE: it is kept only once the place is saved.
4. `design/auras.json`: template `"<Key>": {"custom": "<builder path>", "tier": "<A-E>"}` (gen_auras skips it in
   `work/auras/build.luau`) and the hero's line in `heroes`; `python tools/gen_auras.py`.
5. Preview yard: `CUSTOM` in `tools/aura_assign.py` (hero id -> key), then `python tools/aura_assign.py plan`.

## StarPlatinum layers (Jotaro, Stardust Crusaders; NO stand: the owner removed his Star Platinum figure)

SIGIL (Star Platinum's stat hexagon A A C A A A round the Joestar star, and a clock ring lettered STAR PLATINUM *
THE WORLD, turning opposite ways) · ORBITS (two tilted rings of shooting stars flying round him in opposite
directions: each ring is two Bezier beams, a front and a back half with control arms 4/3 r, carrying a scrolling
UPRIGHT 1:6 comet tile (`comet_v.png`); no particles, and beams animate on the edit-mode preview yard where spinning parts do not) ·
EMBLEM (the Joestar star as an 8.6-stud crest behind his shoulders: gold star in a gold ring, violet-pink rays;
SurfaceGui on both faces, Spin in game) · STARLIGHT (gold-pink glints and small stars born inside him, drawn
behind him) · MENACING (one slanted column of trembling ゴ each side, Grid2x2 jitter flipbook) · ORA (impact
flashes in front of him, an オラ pop now and then) · STARDUST (Joestar stars from his feet, sparkles) · THE WORLD
(time-stop sphere wave + ground ripple every ~6 s) · GLARE (right-eye sparkle) · violet light. About 57 live
particles (Epic tier C budget 200).

Lessons: v1-v3 had violet stand-aura flames round him and the stand: the owner found them bad. A Beam lays its
texture's VERTICAL axis along the beam: draw beam tiles upright (a horizontal 6:1 comet drew sideways, as a striped
band; tip from the Muzan session). Beam curve:
Roblox puts the second control point at Attachment1 - Axis1 * CurveSize1, so a semicircle whose two attachments
share an axis needs CurveSize1 = -CurveSize0. A crest behind a hero must be ~2.7x his shoulder width or his body
hides it. stylua splits long lines: re-read the file before a search-and-replace edit. execute_luau restores the
camera's type AND CFrame at the end of each call: a hold or move only sticks from a task.delay / Heartbeat
connection.

## Hogyoku layers (Aizen, Premium tier E; Bleach, Fake Karakura Town: fused with the Hogyoku)

HOGYOKU (a violet nebula orb billboard in a cross-shaped black seal with glowing cracks on his coat's chest, both
on UpperTorso; an orchid glow, a heartbeat ring, sparks drawn inward from a sphere shell) · THRONE ("I will stand in
heaven": a god-halo of his own powers on two planes behind him: a 12.6-stud sunburst crown of twenty black
Kurohitsugi blades with violet seams and pale edges, and an 8.6-stud Kyoka Suigetsu mirror reflecting Las Noches'
crescent moon, cracked, its rim bursting, ringed by 破道の九十 黒棺; they turn opposite ways in game; glass breaks off
the rim and falls) · REIATSU (violet-white streaks, VelocityParallel, from three strips
beside and behind him, a few dark ones among them, a violet backlight) · KYOKA (mirror shards fading in and out) · SUIGETSU (ground disc:
a broken moon reflected in still water, ripples, 鏡花水月; live ripple rings) · orchid light. About 100 live
particles (cap 320).

Lessons: streaks emitted under the hero blew out his whole lower half (and hid the wings): emit pressure from strips
round him, never in front. v1-v2 had butterfly wings (the fusion's form): the owner wanted something of Aizen's
own, not a butterfly. A halo must carry its own light: black blades and a night-sky mirror vanished against the
yard's dark floor (the camera looks down at a hero), and at 8.8 studs it hid behind his coat and the pillars: 12.6.

## SkillHunter layers (Chrollo, Legendary tier D; Hunter x Hunter: the Phantom Troupe's leader, Skill Hunter)

BANDIT'S SECRET (his grimoire as a 2.3-stud self-lit billboard on RightHand, held up at chest height: dark leather,
gold corners, the crimson handprint, a glyph page; a cold glow and Nen motes off the pages; v1-v2 turned a page over
it every second: removed, owner) · STOLEN PAGES (torn pages with the handprint and an
ability's mark: Sun and Moon, Black Voice's antenna, the order stamp; drifting in two volumes BESIDE him, never in
front) · WEB (a 10.6-stud silver web behind him, TWELVE spokes = the twelve Spiders; MOVEMENT that also shows on the
edit-mode yard: a beam per spoke scrolling an upright pulse tile, so cold light runs out along the threads at twelve
speeds, dew winking on and off, a slow glow breathing behind; turns slowly in game) · SIGIL (the Troupe's twelve-legged
spider in a real top view, FACING FRONT (a Top-face image's top lies toward +Z: the disc is turned half round), no
spin, four inverted crosses, 幻影旅団 / 盗賊の極意) · GYO (thin cold aura
lines born inside him, drawn behind; a low charcoal mist) · cold white light. About 50 live particles (cap 260).

Lessons: pages round the whole body crowded his face: emit props from volumes beside a hero. A capture helper that
hides a stand's sign must skip billboards inside the hero model (it hid the grimoire, which looked like a broken
texture).
