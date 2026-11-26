# Hand-built hero auras

The imported pack auras (`design/auras.json` templates with a `source`) are converted by
`tools/studio/build_auras.luau`. A hero can instead wear an aura authored from scratch with the
roblox-vfx skill's authoring route: own textures, its own Studio builder, judged in Studio.

| Aura | Hero | Textures | Builder |
|---|---|---|---|
| `ButterflyDance` | Shinobu Kocho (`butterfly_swordswoman`) | `tools/auras/butterfly_dance/make_tex.py` -> `assets/auras/butterfly_dance/` (ids in `ids.json`) | `tools/studio/auras/build_butterfly_dance.luau` |
| `HawkEye` | Mihawk (`hawkeye_swordsman`) | `tools/auras/hawk_eye/make_tex.py` -> `assets/auras/hawk_eye/` (+ ButterflyDance's wisp, glint, glow) | `tools/studio/auras/build_hawk_eye.luau` |
| `TheAlmighty` | Yhwach (`blood_war_king`) | `tools/auras/almighty/make_tex.py` + `make_cloak.py` (a real cloak MESH: obj -> `obj_to_fbx_one.py` -> Model upload -> `ServerStorage.AuraSources.TheAlmighty.Cloak`, never delete) -> `assets/auras/almighty/` | `tools/studio/auras/build_almighty.luau` (its CLOAK DATA block is written by make_cloak.py) |
| `DemonCircle` | Anos Voldigoad (`tyrant_demon_lord`) | `tools/auras/demon_circle/make_tex.py` (own rune alphabet) -> `assets/auras/demon_circle/` (+ HawkEye's crack, ButterflyDance's glint) | `tools/studio/auras/build_demon_circle.luau` |
| `CompassNeedle` | Akaza (`crimson_fist_demon`) | `tools/auras/compass_needle/make_tex.py` -> `assets/auras/compass_needle/` (+ ButterflyDance's glint) | `tools/studio/auras/build_compass_needle.luau` |
| `AceEater` | Don Lorenzo (`number_one_striker`) | `tools/auras/ace_eater/make_tex.py` -> `assets/auras/ace_eater/` (+ ButterflyDance's glint) | `tools/studio/auras/build_ace_eater.luau` |
| `GoldExperience` | Giorno (`gold_gang_boss`) | `tools/auras/gold_experience/make_tex.py` -> `assets/auras/gold_experience/` (+ ButterflyDance's upright ribbon, glint) | `tools/studio/auras/build_gold_experience.luau` |
| `CrowGenjutsu` | Itachi Uchiha (`crow_illusionist`) | `tools/auras/crow_genjutsu/make_tex.py` -> `assets/auras/crow_genjutsu/` (+ the roblox-vfx library lightning flipbook) | `tools/studio/auras/build_crow_genjutsu.luau` |
| `ShadowArise` | Sung Jinwoo (`shadow_monarch`) | `tools/auras/shadow_monarch/make_tex.py` -> `assets/auras/shadow_monarch/` (+ CrowGenjutsu's lightning) | `tools/studio/auras/build_shadow_monarch.luau` |
| `DemonKing` | Muzan (`demon_progenitor`) | `tools/auras/demon_king/make_tex.py` -> `assets/auras/demon_king/` (+ ShadowArise's eye flare) | `tools/studio/auras/build_demon_king.luau` |
| `ControlDevil` | Makima (`demon_lord_heir`) | `tools/auras/control_devil/make_tex.py` -> `assets/auras/control_devil/` (+ ShadowArise's spark and eye flare) | `tools/studio/auras/build_control_devil.luau` |
| `ConquerorsHaki` | Shanks (`red_haired_emperor`) | `tools/auras/conquerors_haki/make_tex.py` -> `assets/auras/conquerors_haki/` (+ ShadowArise's streak) | `tools/studio/auras/build_conquerors_haki.luau` |
| `DarkSlash` | Yami Sukehiro (`dark_slash_captain`) | `tools/auras/dark_slash/make_tex.py` -> `assets/auras/dark_slash/` | `tools/studio/auras/build_dark_slash.luau` |
| `CurseManipulation` | Geto (`curse_manipulator`) | `tools/auras/curse_manipulation/make_tex.py` -> `assets/auras/curse_manipulation/` | `tools/studio/auras/build_curse_manipulation.luau` |
| `StarPlatinum` | Jotaro Kujo (`star_delinquent`) | `tools/auras/star_platinum/make_tex.py` -> `assets/auras/star_platinum/` (`upload.py`) | `tools/studio/auras/build_star_platinum.luau` |
| `Hogyoku` | Sosuke Aizen (`void_empress`, Premium) | `tools/auras/hogyoku/make_tex.py` -> `assets/auras/hogyoku/` (`upload.py`) | `tools/studio/auras/build_hogyoku.luau` |
| `SkillHunter` | Chrollo Lucilfer (`spider_thief_boss`, Legendary) | `tools/auras/skill_hunter/make_tex.py` -> `assets/auras/skill_hunter/` (`upload.py`) | `tools/studio/auras/build_skill_hunter.luau` (assembled by hand from build_hogyoku's scaffolding) |
| `DemonsExtract` | Esdeath (`ice_general`, Epic) | `tools/auras/demons_extract/make_tex.py` -> `assets/auras/demons_extract/` (`upload.py`) | `tools/studio/auras/build_demons_extract.luau` (assembled from build_hogyoku's scaffolding) |
| `EmperorThorns` | Michael Kaiser (`emperor_striker`) | `tools/auras/emperor_thorns/make_tex.py` -> `assets/auras/emperor_thorns/` (`upload.py`) | `tools/studio/auras/build_emperor_thorns.luau` |
| `SunBreathing` | Yoriichi Tsugikuni (`sakura_shogun`, Premium) | `tools/auras/sun_breathing/make_tex.py` -> `assets/auras/sun_breathing/` (`upload.py`; + EmperorThorns's helpers; body = the Solar Flare pack verbatim) | `tools/studio/auras/build_sun_breathing.luau` |
| `AntiMagic` | Liebe (`devil_knight`) | `tools/auras/anti_magic/make_tex.py` -> `assets/auras/anti_magic/` (`upload.py`; body = the one winged angel pack verbatim) | `tools/studio/auras/build_anti_magic.luau` |
| `DragonMonarch` | Antares (`dragon_monarch`) | `tools/auras/dragon_monarch/make_tex.py` -> `assets/auras/dragon_monarch/` (`upload.py`; body = the Cinder pack verbatim) | `tools/studio/auras/build_dragon_monarch.luau` |
| `HeavenlyRestriction` | Toji Fushiguro (`sorcerer_hunter`) | `tools/auras/heavenly_restriction/make_tex.py` -> `assets/auras/heavenly_restriction/` (`upload.py`; body = the Dummy pack verbatim) | `tools/studio/auras/build_heavenly_restriction.luau` |
| `MalevolentShrine` | Ryomen Sukuna (`curse_king`, Mythic) | `tools/auras/malevolent_shrine/make_tex.py` -> `assets/auras/malevolent_shrine/` (`upload.py`; body = KingOfCurses verbatim) | `tools/studio/auras/build_malevolent_shrine.luau` |
| `Limitless` | Satoru Gojo (`limitless_teacher`, Mythic) | RETIRED (owner kept his tuned aura):  `tools/auras/limitless/make_tex.py` -> `assets/auras/limitless/` (`upload.py`; body = the owner's tuned Crimson Moon + infinity symbol) | `tools/studio/auras/build_limitless.luau` |
| `Geass` | Lelouch (`rebel_emperor`, Epic) | `tools/auras/geass/make_tex.py` -> `assets/auras/geass/` (`upload.py`; the kings are `generate_mesh` MeshParts in `ServerStorage.AuraSources.Geass`, never delete) | `tools/studio/auras/build_geass.luau` |

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

## ButterflyDance layers (Insect Breathing; key art: violet light, cyan glints, glass-like shards)

SIGIL (turning SurfaceGui plate: glow pool, indigo ink outline, violet stained-glass ring with eight butterflies) ·
SWARM (four release points on a ring turning at 1.05 rad/s: flapping spirit butterflies spiral up, glint trails,
two tapered light ribbons) · HAORI (white/black/teal butterflies off her back) · MANTLE (eight points on a turning
ring at the silhouette's edge: violet + cyan flame tongues over a dark indigo copy, ZOffset -2.3..-2.8 so the
front ones draw behind her) · BACKLIGHT halo · SCALES (cyan/lilac glints, turning glass shards) · violet light.
About 121 live particles (Epic tier C budget 200). Judged in daylight (the game's 13:12), at night, and on the
preview yard's lit stands.

Lessons: a ParticleEmitter Disc with ShapeStyle Surface emits nothing; edit-mode emitters only simulate near the
camera (park it with `run_zone.py look`, then capture with NO camera position); a positioned `screen_capture`
shows an empty aura; additive (LightEmission ~1) violet vanishes in daylight: keep it 0.25-0.35 with a dark
under-layer.

## EmperorThorns layers (Michael Kaiser; Blue Lock: the blue-rose tattoo, its thorn stem, the crown, Kaiser Impact)

SIGIL (a head-on blue rose on a thorn wreath, a gold ring with four keyhole crowns, turning opposite ways) · ROSES
(three blue roses blooming in turn round his feet on a turning frame; the thorn vines that once spiralled up him
were removed at the owner's request, 2026-11-25) · CREST (three blue roses blooming behind his head and shoulders, ZOffset
-2.2, the middle one behind the crown) · CROWN (eight gold prong panels, SurfaceGui both faces, in the HEAD group so it
rides the head) · PETALS (a turning ring of release points; more peeling off the tattoo at the left of his neck) · no flames (owner: flames on every
hero are repetitive) · IMPACT (blue lightning at the legs, a
VelocityPerpendicular shock ring snapping out from the feet, speed streaks) · sapphire glints, backlight, blue light.
About 115 live particles (Legendary tier D budget 260). Judged in daylight on the preview yard.

Lessons: a Beam's texture is squeezed into its Width: a stem drawn at 17% of a 0.6-stud beam is 0.1 stud and simply
does not show; draw the stem fat (~30%) and widen the beam (1.1 studs at the root). Pale tones (LIGHT/CYAN body) on a
FaceCamera beam read as a foggy sash: keep the body DEEP/BLUE with one thin light line. A bloom flipbook placed
where a rotating vine passes in front of the face covers it: put flowers at the root or behind (ZOffset < -2).
The yard's edit camera can be moved by the owner while you work: hold a view for a capture with a short
RenderStepped loop that disconnects itself after ~30 s. One such hold (timed with `os.clock()`) kept pulling the
camera back for minutes after its limit, fighting the other sessions; the cause is not pinned down (`os.clock()` was
measured to advance in execute_luau). A loop cannot be stopped from a later call: if one outlives its limit, swap in a
new `Workspace.Camera` (same CFrame, Fixed) and detach the old one. execute_luau also restores the camera at the end
of a call: only a `task.delay`'d move sticks. Never count FRAMES to end a hold: Studio renders at ~15 fps when unfocused,
so a 2400-frame "40 s" hold pinned the shared camera for ~3 min; end it on `os.clock()` elapsed time. Wait ~8 s for emitters to fill, then capture with no position.

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

## SunBreathing layers (Yoriichi Tsugikuni, Premium): the ORIGINAL Solar Flare + the SUN SEAL base

The owner rejected v1 (flat ukiyo-e cel fire: "looks like cartoon") and v2 (the Solar Flare re-lit with god rays,
fire arcs and sweeps on his body): "the original one looks way better, bring it back and create a perfect base
for him". v3: his body wears the original pack aura (POF:RE AURA SOLAR FLARE) copied VERBATIM from its preview
conversion (`ServerStorage.AuraPreview.Templates.P99`: Burst, Flam, Spark, Glow, Dust, Dust2, light; the builder
asserts it exists), and the builder adds only the BASE: SEAL (pre-coloured on a SurfaceGui: a gold double rim,
a band of kanji 日の呼吸 (Yu Gothic Bold), the 13th form as twelve curling flame commas, turning slowly) · SUN (the
hanafuda sun of his earrings, crimson disc, gold rim, sixteen rays, turning the other way) · BREATH (a flat
ring of light every 1.6 s) · GLINT (two sun glints racing round the rim with spark trails) · FIRE (a continuous
ring of fire on the rim, 24 points, in layers: a floor glow, a white-hot base band, the body of one-shot flame licks
(`flame_lick_4x4`: born, licks up, tip tears off, burns away), taller tongues on every third point, spitting
sparks) · embers. Seal diameter 7.4: on the game's 3.8-stud pedestals it reaches past the edge
as a disc of light 0.4 above the deck (pedestals are 9.6 apart). About 215 live (tier E budget 320).

Lessons: when the owner already likes a hero's aura, keep it EXACTLY and add around it (a base, a motif),
never re-light it. A floor seal drawn PRE-COLOURED on a SurfaceGui keeps its colours on any floor; additive
ground layers go white on pale stands and against the 13:12 sky. Additive pale gold on that sky goes white;
saturated (#FF5500 range) reads as fire.
A ParticleEmitter Disc with ShapePartial 0.93 (meant as a thin ring) emitted almost nothing in Studio: emit a
ring of fire from N attachments round the circle (flames wider than the gaps). Additive flames vanish over a bright
gold seal: the flame body at LightEmission ~0.5 shows its colour over it. FacingCameraWorldUp quads are centred on
the particle: lift each flame layer by half its Size so the flame's base sits on the floor.

BEAM TEXTURES (all auras): Roblox lays a Beam's texture with its VERTICAL axis along the beam (image top =
Attachment0, bottom = Attachment1; checked 2026-11-25 in Studio and on the DevForum). A strip drawn
horizontally (U along the length, the roblox-vfx skill's `beams/*` library included) renders sideways:
stored rotated 90 degrees (`.rotate(-90, expand=True)`). EmperorThorns' vine and SunBreathing's fire strip
were both sideways until then.

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

## AntiMagic layers (Liebe, Legendary): his one winged angel + the grimoire seal

His body keeps the pack aura he wore (Pack9 "one winged angel": a black wing mesh with black mist and feathers),
copied VERBATIM from `ServerStorage.AuraPreview.Templates.P8`; the single black wing is how anti-magic first shows
in Black Clover. Added round it: SEAL (pre-coloured SurfaceGui, turning: a black five-leaf clover, his grimoire,
silver edges, blood-red veins, a red devil's eye at its heart, white anti-magic crackle in a black band) ·
CLOVERS (five black five-leaf clovers with silver edges and red veins gliding round him on a slow orbit,
turning smoothly and fading in and out; single leaves come away and float up) · SLASHES (black anti-magic sword cuts, crescents with an ash
edge and a red line, flashing beside him) · CRACKLE (black lightning beside him and crawling flat over the seal) ·
SHARDS (black flakes drifting up) · a dim blood-red light at his feet. Every added layer is pre-coloured,
LightEmission 0 (a dark aura must not glow). No flames and no flame-shaped wisps: the owner asked for something
other than flames for him (v1's black miasma tongues read as fire), then for the five-leaf clover moving
smoothly instead of v2's flipping grimoire pages.

## DragonMonarch layers (Antares, Legendary): his Cinder + dragon wings and the Monarch's seal

His body keeps the pack aura he wore (Pack1 "Cinder"), copied VERBATIM from `ServerStorage.AuraPreview.Templates.P22`.
Added, all dragon imagery and no more fire: WINGS (a pair of crimson dragon wings, black finger bones, glowing
scalloped edges, beating in a 2 s cycle; `wing_r/l_4x4` flipbooks, one per wing for resolution, the mirror drawn
separately) · SEAL (pre-coloured SurfaceGui, turning: a dark stone disc torn by three molten dragon-claw gouges, red
cracks spreading, a ring of dragon scales) · FEAR (a dark red pressure wave over the floor every 2.4 s) · SCALES
(crimson scales drifting up). About 69 live (tier D budget 260).

Lessons: wings as particles go on planes FIXED to his back, not camera-facing sprites: VelocityPerpendicular with
EmissionDirection Back and Speed 0.001, LockedToPart (checked in Studio: the texture lies upright, its root edge at
the shoulder, Rotation 0). Two copies born exactly one flipbook cycle apart (Rate 2/life, life = 2 cycles,
FlipbookStartRandom false) always show the same frame, so the wing never blinks or doubles. A wing at Size 2.0
barely cleared his head; 2.9 reads as a dragon's.

## HeavenlyRestriction layers (Toji Fushiguro, Legendary): his Dummy pack + raw physical power

His body keeps the pack aura he wore (Pack3 "Dummy", beams included), copied VERBATIM from
`ServerStorage.AuraPreview.Templates.P49`; it already spends the whole Legendary budget (260). Toji has NO cursed
energy, so nothing added glows and it costs almost nothing: CRATER (the floor caved in under him, a cracked stone
bowl with fractures running out past its rim and rubble; a pre-coloured SurfaceGui lit by the scene, no particles)
· CUTS (razor-thin straight cuts flashing across the air beside him, then splitting into two edges) · DEBRIS (grey
dust off the rim, stone chips hopping up and falling back). About 266 live.

Lessons: a template with Beams must be cloned as ONE piece before its children are moved, or the Beams keep
pointing into the ServerStorage template; the preview re-dress moves Beams last, after their attachments. Open
Cloud refuses an asset name over ~50 characters ("Asset name length is invalid"): keep upload prefixes short.

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

## MalevolentShrine layers (Ryomen Sukuna, Mythic): his KingOfCurses + Dismantle, Cleave and the Shrine

His body keeps the KingOfCurses aura he wore, copied VERBATIM from `ReplicatedStorage.Assets.Auras.KingOfCurses`
into a new key (other heroes still wear KingOfCurses untouched); it already spends the Mythic budget (320).
Added, drawn the way the anime shows his technique (research: Dismantle = fast, normally invisible slashes that
cut cleanly through everything; Cleave = a cut that adapts to its target; the Malevolent Shrine = a domain with no
barrier): DISMANTLE (volleys of five razor-thin straight slashes, mostly parallel, one crossing, cut in over a
frame and a half with a white hit flash, beside him and above his head) · CLEAVE (a heavy X whose cuts open a
black void line in the air, white-edged, glowing red) · FLOOR (Dismantle cutting flat across the domain floor) ·
DOMAIN (pre-coloured SurfaceGui: a blood pool, a ring of fangs, slash scars, the kanji 伏魔御廚子 with skulls).
No shrine behind him: the owner had the silhouette removed. About 324 live. Every slash is pre-coloured: a white core, a crimson fringe and a black
hairline, so it reads on the bright sky (a slash under ~0.009 core width went pink-thin there).

Lessons: a backdrop drawn for the space AROUND a hero: his body hides the middle-bottom of the image, so the
feature that must show (the maw) goes in the upper third. A long inline Python heredoc with kanji in it broke the
Bash tool twice: write such scripts to a file first.

## Limitless layers (Satoru Gojo, Mythic): the owner's tuned aura + his Limitless

**RETIRED 2026-11-25 (owner: "bring back the default one which i had already set").** Gojo wears only his tuned
aura from the preview yard (`tools/aura_assign.py`: `P:82` + `P52` infinity symbol + his PALETTES entry). The builder and
textures below stay on disk for reference; they are NOT registered in `design/auras.json` or `CUSTOM`.

His body keeps the aura the owner tuned for him, rebuilt EXACTLY as the preview yard builds it: the Crimson Moon pack
(`Templates.P82`) painted with his palette (the builder's PALETTE mirrors `tools/aura_assign.py`
PALETTES["limitless_teacher"]: keep the two in step), plus Infinite Reality (`P52`) cut to its "Infinity Symbol"
emitters and painted the same way. v2 (2026-11-25; v1's static orbs and flat floor were rejected as low effort),
every layer an ANIMATED, hand-painted texture from `make_tex.py` (polar noise sampled along spirals, so swirls turn
into or out of a centre and loop seamlessly):
- ORBS: Lapse Blue (white-hot heart, cobalt body, navy edge, cyan rim, swirl bands turning inward) and Reversal Red
  (white core, gold/orange/crimson, tendrils flung out, sparks) on one turning frame at chest height, opposite each
  other. 4x4 flipbooks at 16 fps; each is two locked copies born one loop apart (life 2, rate 1), so they never
  double or blink. LightEmission 0.1: the navy edge must stay dark against the white dome.
- PURPLE: Hollow Purple every 6 s above his head, at the knot of the infinity symbol: one 16-frame one-shot (Blue and
  Red spiral in, flash, a crackling sphere of imaginary mass, implosion into a shock ring).
- HALO: the void's black hole stood UPRIGHT behind his head (`VoidHalo`, a SurfaceGui, centre y 2.25, z 1.05, d 6.6,
  turning 0.3 rad/s about its own Z): the black disc frames his white hair like an eclipse, a white photon ring, a
  saturated cobalt/violet accretion disc with rays. On the floor his legs hid it; a pale disc washed out on the dome.
- VOID floor (turning SurfaceGui: deep space, galaxies, kanji 無量空処) + an animated flat flipbook of information
  streams rushing inward. EYES: anamorphic cyan flares at the Six Eyes. STREAKS: light rising inside the dome.
About 352 live (the tuned aura alone is ~330 of the Mythic 320).

## DemonsExtract layers (Esdeath, Epic tier C; Akame ga Kill!: her Teigu makes ice out of thin air)

HOARFROST (ground seal: frost ferns in six-fold symmetry round an ice crest; a ring of outward ice crystals spreads
across the ground every ~3.5 s) · ERUPTIONS (eight points
round her, none in front: an ice cluster bursts up, glints, cracks and shatters, a 16-frame one-shot with its base at
0.94 of the frame; each point has its own rate so they roll round her) · HAGELSPRUNG (ice shards falling, point
first) · SNOW (three snowflake designs, diamond dust) · COLD (pale blue ground mist, cyan light). About 72 live
particles (cap 200).

Lessons: ice reads on the dark floor by itself (bright cyan/white), unlike dark auras. v1 had a glacier crown of ice spires
behind her: removed (owner).

## Geass layers (Lelouch, Epic): the Heaven pack + his Geass and the chessboard

His body keeps Heaven (`Templates.P58`, Pack4: cream light beams up every limb, flashes) VERBATIM, cloned as one
piece (its beams must keep their attachments). Added (about 15 live; total ~70 of the Epic 200):
- BOARD: a round chessboard SurfaceGui (black and royal-purple lacquer, bevels, a gloss sweep, gold inlay, a
  lacquer border with gold diamonds), the Geass bird ENGRAVED at its centre. The bird is our own drawing (tapered
  bezier strokes: a drop body, swept wings with inner feathers, tail hooks), not the show's emblem.
- SIGIL: the engraving lit by a SECOND SurfaceGui painted on the board's own canvas (`sigil_lit.png`), so it lies
  exactly on it. A flipbook laid flat (VelocityPerpendicular, emitted up) was tried first and REJECTED: a flat
  particle's in-plane turn is not stable (it lay at an angle to the engraving and turned with the view). Motion
  comes from symmetric flat layers instead: a crimson glow breathing under the bird, a ring rolling out over the board.
- EYE: the sigil white-hot at his LEFT eye's red iris (-X; the face decal already draws a red Geass iris there:
  `EYE` = (-0.29, 1.56, -0.62)), ZOffset 1, and a small crimson PointLight on his face.
- CAST: every 2.5 s the eye flares and a train of rings (one texture of three concentric rings, flown forward
  along -Z and grown) leaves it. The flare and the wave share one Rate, so they fire together.
- KINGS: the black king (Zero) floating at his right hand, tilted 9 degrees and turning (Spin on a tilted RootCF
  precesses), over a crimson glow; the generated texture came out grey marble, so a SurfaceAppearance over the same
  map tints it black. The white king lies toppled on the board's front-left edge (his opponent resigned).
- MOTES: crimson diamond glints rising off the board.

