# 06 Animation, VFX, camera and sound

Specs: `design/animations.json`, `design/vfx.json`, `design/sfx.json`. Built in section 4 with
`roblox-animation`, `roblox-vfx`, `roblox-sfx`. Free first, built where nothing free fits (the
user pre-authorised building on 2026-11-14).

## 1. The throw sequence (the thing people will film)

| t (s) | What happens | Animation | VFX | Sound | Camera |
|---|---|---|---|---|---|
| hold | bar fills, food glows brighter | Throw wind-up held | LuckyThrow_Charge if armed | throw_charge | slight push-in |
| 0.0 | release | Throw release | PerfectThrow_Flash if perfect | throw_whoosh, perfect_ding | cut to follow-cam behind the food |
| 0.0 to 1.1-2.2 | flight through the zones; gates flash as it passes | - | ThrowTrail by food tier | zone ambience fades in | chases the food, speed lines at the screen edge |
| land | food bounces once | - | Land_Impact | food_land | orbit 30 degrees |
| +0.2 | beam rises and climbs through rarity colours, stops at the result | - | Reveal_<rarity> | reveal_drumroll then the rarity sting | slow push-in |
| +reveal | hero drops in, eats, poses | RevealLand, Eat | burst | eat_munch | hold |
| end | hero dashes down the lane to the plot; card closes | default run | DashHome_Trail | dash_whoosh | back to the player in 0.4 s |
| arrive | hero on its pedestal | its Idle clip | Coin_Pop, aura if mutated | coin_tick | - |

Total 3 to 7 s by rarity (`Rarities[].RevealSeconds`); tap skips to "arrive"; Fast Reveal halves
it. Other players see the food fly and a short reveal without the camera move.
The server has already granted the hero when the sequence starts: skipping or leaving loses nothing.

## 2. Animation (14 clips, R15, 30 fps)

Player: Throw, TrainStrike, TrainPush, TrainMeditate, Celebrate. Heroes: seven idles (Cool,
Cheer, Blade, Ninja, Power, Shy, Float), Eat, RevealLand. Walk, run and jump stay Roblox
defaults; dash-home uses default run at high speed.

Method per clip: look up real reference for the pose first (how a sword is actually carried, how
an overhand throw is actually timed) and write it into `_intent`; author in FK on the calibrated
rig; render the contact sheet and judge it against `_intent`, not against itself; check it
in-engine on a real dressed hero (a clip that looks right on the bare rig can put a sleeve
through a katana). Idles are authored at **Core** priority so default leg motion still shows
when a hero moves; action clips at Action.

Publishing: clips made in Studio are session-local until saved to Roblox, and a live server only
plays animations owned by the place owner. Section 4 tries the Open Cloud upload; if the key or
API cannot upload animations, the one manual step is the owner saving each clip to Roblox
(14 right-clicks), listed in 08 under inputs.

Variety without more clips: each hero has one idle from the seven plus a random Roblox emote
(the free ones in `animations.json`) every 20 to 40 s.

## 3. VFX (27 effects)

Authored in the `roblox-vfx` simulator with the installed texture library, judged frame by
frame, exported as the kit; harvest from a free pack first where one matches. Called only
through VfxController (pcall-isolated: a missing effect can never stop a throw).

| Group | Effects | Notes |
|---|---|---|
| Reveal | Reveal_Common ... Reveal_Secret | one definition, 7 parameter sets; scale and duration rise with rarity; Mythic adds a screen-edge flash and camera shake |
| Auras | Aura_Golden, Aura_Flame, Aura_Lightning, Aura_Galaxy, Aura_Titan | loops on the root; must read at 60 studs and not hide the hero; at most 24 live, ring fallback in low detail |
| Throw | ThrowTrail_Basic/Hot/Epic, Land_Impact, PerfectThrow_Flash, LuckyThrow_Charge | trail colour follows the food |
| Home | DashHome_Trail, Coin_Pop, Slot_Unlock, Train_Hit, PowerUp_Burst | small, frequent, cheap |
| Big moments | Rebirth_Nova, Summon_Portal, ServerLuck_Sky, Zone_Unlock | rare, large, everyone nearby sees them |

Budget: 220 particles per effect, no effect blanks the screen, every effect seen firing in play
and grepped for a caller before section 4 closes.

## 4. Sound (34 roles)

Creator Store audio by id through `roblox-sfx`: search, prove each candidate loads and measure
its real length in Studio, pick, emit the SoundBank. Reveal stings rise with rarity so the ear
knows before the eye. Music: music_home loop, music_festival_hour during Festival Hour, six
zone ambiences under the follow-cam. Volumes from Settings. Nothing in the pipeline can hear, so
the pre-handover matrix marks every role "heard by the user" or UNTESTED.

## 5. Player character

Players keep their own avatar (R15 forced). The equipped food model is held in the right hand
(grip point at the hand origin, asserted in code). Training gear is a plot prop, not a tool.
