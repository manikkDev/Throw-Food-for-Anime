# UI v4: what changed for the client

Built by `python tools/ui/build_ui.py` (screens: `tools/ui/screens_v4.py`, system: `tools/ui/mp4.py` on top of
`mp3.py`). Full path diff against v3.4: `work/ui_v4/bindings_v4_diff.txt` (63 removed, 168 added; nearly all the
additions are decoration: `Sunburst`, `Sheen`, `TitleIcon`, sample rows). Every NAME the main-thread controllers bind
is unchanged. Gates: `build_ui.py` 0 project failures, `fit_gate.py` 0 failures at 1280x720 / 1345x611 / 844x390 /
1920x1080, `verify_labels.py` 235/235, `python tools/gate.py` all green.

## The owner's review, as system rules (mp4.py)

| Review point | Rule now |
|---|---|
| thick borders, drop-shadow look | theme `stroke` 4 -> **2** (one UIStroke, Border mode); `shadowOffset` 6 -> 0; every `comic` offset shadow removed (`mp4.normalize` strips it from any spec); panels and cards have **no lip**; buttons keep a 3-4 px lip that has **no stroke of its own** (`Shadow` is a plain darker slab = the press lip) |
| small, unreadable text | type at 1280x720: nothing under 16, chips 18, body 20-22, row titles 24-26, buttons S 22 / M 24 / L 28, window titles 40; text strokes 1.5 px (< 24 px) / 2 px, Contextual |
| text not centred | labels fill their container, centred; window titles are an icon + title row centred in the header; progress text is a full-width centred label over its bar |
| stretching buttons | button height = class (S 44, M 52, L 64), width = text + icon + 0.35 h padding each side; icons are square `ScaleType Fit` slots at 0.6 h; no scale-sized buttons |
| premium look | windows: flat navy face, thin light keyline, a **gradient Header bar** inside the top edge (stripes pattern + diagonal `Sheen`), round red `CloseButton`; cards: coloured gradient faces + `dots` pattern + `Sheen`; `Sunburst` flares (FxSunburst) behind featured icons/portraits; `Sparkle` stars; BEST VALUE / LIMITED / NEW / NEXT ribbons centred on card top edges; Robux price buttons with `IconRobux` + bold price |

New spec nodes (renderer and emitter agree): `sheen` (Frame + UIGradient transparency bands), `ring` (Frame +
UICorner 1 + UIStroke), `strokeGrad` (UIGradient `Rainbow` under a UIStroke), `autoW` (AutomaticSize X frame),
`tint`/`alphaImg` on icons (ImageColor3 / ImageTransparency). The mockup renderer now clips ScrollingFrames and
`ClipsDescendants` frames like Roblox does.

## Path changes (old -> new)

| Screen | Old | New | Client |
|---|---|---|---|
| ALL pages | `Window.Header` = tilted ribbon with `Title` | `Window.Header` = gradient bar inside the window: `Header.TitleRow.TitleIcon` + `Header.TitleRow.Title` | nothing binds it |
| ALL pages | `CloseButton` overhanging the corner | `CloseButton` round 56 px X on the header's right end (still `ClosesPage`) | nothing |
| Squad | `Row.RarityStripe` (thin bar) | `Row.PortraitTile` (78 px rarity-coloured tile, painted frame) with `Thumb` inside it | **done** in `Pages/Squad.luau` (tints `PortraitTile`) |
| Squad | `Row.NameBlock.Stars.Star1..3` | `Row.FuseBadge` (gold `Star` 44 px + `Glow` + `FuseCount`) on the portrait's top-right corner | **done**: badge shown when stars > 0, `FuseCount` = stars when > 1 |
| Squad | `TopBar.AutoSellCommon/AutoSellUncommon/EquipBest` | `BottomBar.AutoSellGroup.AutoSellCommon` / `.AutoSellUncommon` (captions COMMON / UNCOMMON after an `AUTO-SELL:` label), `BottomBar.EquipBest` | nothing (found by name) |
| HeroIndex | `Tile.RarityStripe`, `Tile.Portrait` | stripe removed (the whole card face is the rarity colour); `Tile.PortraitWell.Portrait` | **done** in `Pages/HeroIndex.luau` |
| Store | `PassCard.Icon`, `ProductCard.Icon` | `PassCard.CardIcon`, `ProductCard.CardIcon` (the buy button keeps its own `Icon`; the old name made `FindFirstChild("Icon", true)` order-dependent) | **done** in `Pages/Store.luau` |
| SummonOdds | `OddsRowN` = a list row; `OddsBuyN.Label` = "x1  79" | `OddsRowN` = a hero CARD (164 x 278): `OddsChip.OddsPercent` badge on the top edge, `Portrait`, `HeroName`, `RarityTag.RarityText`, `OddsEarn`; `OddsRow6` (rarest) has a rainbow frame `Stroke.Rainbow` + sparkles; `OddsBuyN` = two-line L buttons `Count` ("BUY x10") over `PriceRow.Icon` + `PriceRow.Price`; `OddsBestValue` ribbon over x10 | **done** in `Pages/SummonOdds.luau` (tier words, Count/Price, rainbow spins while open, sticker hidden when random items are restricted) |
| OfflineEarnings | `Body.EarnedRow` | `Body.EarnedWell.EarnedRow` | nothing |
| SlotSign | `Sign.FromTo` | `Sign.SignHeader.FromTo` | nothing |
| Leaderboard | `Board.TitleRibbon.BoardTitle` | `Board.BoardHeader.BoardTitle` (+ `BoardIcon`, `BoardSub`, sparkles) | nothing required; optional per-board look below |
| TrainingBar | `TrainingPanel.StopButton` | **removed**; `ExitButton` (round red X) replaces it | **done** in `Pages/TrainingBar.luau` (`TrainSet false`) |
| ThrowMeter | `LuckyThrowToggle`/`AutoToggle` 124 px | same names, auto width (LuckyCount samples now `x99`) | nothing |
| Nameplate | fixed-width chips and rows | `TagRow.SizeTagCell.SizeTag.SizeText`, `TagRow.MutationTagCell.MutationTag.MutationText` (AutomaticSize X pills), `BottomRow.YenPerSecond` and `BottomRow.Stars` AutomaticSize X, every row UIListLayout centred | nothing: same names; a hidden pill or star now leaves no gap, so each line stays centred |

## New contracts (exact instance paths, relative to the ScreenGui)

### ThrowMeter
- `CanvasFrame.ExitButton` (TextButton, round red X, 56 px, top-right of the meter area at (950, 14)): **leave the
  throw spot**. Not bound yet: the main thread binds it in `ThrowController` (e.g. `Screens.button(gui,
  "ExitButton").Activated:Connect(function() self:_leaveSpot() end)`, whatever the existing exit path is).

### TrainingBar (training mini-game HUD)
All under `CanvasFrame`:
- `StationTitle` (TextLabel, 36 px, starts ""): the station name, e.g. "STRIKE DUMMY".
- `TimingRing` (Frame 220 x 220, centre (800, 340), attribute `TargetScale = 0.62`):
  - `TimingRing.Target` (Frame, UICorner 1 + UIStroke 8 px gold): the fixed ring, size 0.62 of TimingRing.
  - `TimingRing.Shrink` (Frame, UICorner 1 + UIStroke 5 px white, Size `UDim2.fromScale(1, 1)`, AnchorPoint 0.5,
    centred): the client tweens `Size` from `fromScale(1, 1)` to `fromScale(TargetScale, TargetScale)` each rep; a
    tap when it is on the target is the perfect rep.
  - `TimingRing.RingBack` (dark disc behind the target), `TimingRing.RingIcon` (IconPowerBig): decoration.
- `PerfectLabel` (TextLabel "PERFECT!", 48 px gold, centred on the ring, **Visible=false**): show + pop on a perfect rep.
- `TapHint` (TextLabel "TAP IN THE RING!", static, under the ring).
- `RepPower` (TextLabel, 32 px, right of the ring, starts ""): "+120 POWER" floating text; pop/fade per rep.
- `Combo` (TextLabel, 32 px gold, left of the ring, **Visible=false**): "x3 COMBO".
- `ExitButton` (TextButton, round red X, 56 px, top-right of the ring): leave the station. **Bound** in
  `Pages/TrainingBar.luau` to `ctx.fire("TrainSet", false)`; rebind if stations get their own exit.
- Kept: `TrainingPanel.RankName`, `.GearName`, `.ProgressBar.Fill`, `.ProgressBar.ProgressText`, `.PowerIcon`,
  `.PowerPerRep`, `UpgradePrompt.UpgradeText`. Removed: `StopButton`.
- The whole page is shown while `state.training`; if a station has no timing game, hide `TimingRing`, `TapHint`,
  `StationTitle` from the controller that owns the mini-game.

## Client tasks left for the main thread (files I do not own)

1. **ThrowMeter zone label overlap (review point 9). Root cause found, fix is in `ThrowController:_refreshUi`.** Once
   a minimum-charge throw already reaches several zones, `Throw.chargeForZone` returns `MinCharge` for all of them,
   so every one of those bands gets height 0 and their `ZoneMarkName` labels ("Sakura Schoolyard", ..., "Realm of
   Legends") stack on top of each other at the foot of the meter. There is no duplicate instance in the tree. Change
   (keep only the furthest zone that sits at the foot):

   ```lua
   -- before the `for index, zone in Config.Zones do` band loop:
   local floorZone = 0
   for index in Config.Zones do
   	local need = Throw.chargeForZone(T, Config.Zones, state.power, food.PowerMult, index)
   	if need and need <= T.MinCharge then
   		floorZone = index
   	end
   end
   -- and in the loop, replace `if need and index > 1 then` with:
   if need and index > 1 and (need > T.MinCharge or index == floorZone) then
   ```
2. **ThrowMeter `ExitButton`**: bind it (contract above).
3. **TrainingBar mini-game**: drive `TimingRing.Shrink`, `PerfectLabel`, `RepPower`, `Combo`, `StationTitle` (contract above).
4. **Leaderboard look per board (optional, `WorldUiController:_paintBoard`)**: `Screens.tint(Screens.frame(gui,
   "BoardHeader"), colour)`, `Screens.setIcon(Screens.image(gui, "BoardIcon"), key)`, `Screens.label(gui,
   "BoardSub").Text = subtitle`. Suggested: yen `#FFB13D` `IconYenBig` "Yen earned"; caught `#38BDF8`
   `IconSquadBig` "Heroes caught"; rarest `#A855F7` `IconCrownBig` "Rarest hero caught". Ships gold, crown,
   "TOP 10 PLAYERS". Rows 1/2/3 ship gold / silver / bronze rank badges and keylines; rows alternate two navy tints.
5. Nothing else: every other binding is by name and unchanged, and the page binders under `src/client/Ui/**` were
   updated here (Squad, HeroIndex, Store, SummonOdds, TrainingBar).

## Icons

The other worker owns the icon images. Keys used by v4 and not new: every `...Big` window title icon (Shop, Squad,
Index, Store, Scroll, YenBig, Gift, Codes, Settings, Rebirth), `IconPowerBig` (ring centre), `IconCrownBig`
(leaderboard), `FxSunburst` (all flares, tinted by `ImageColor3`), `IconStar` (sparkles and the fuse star). Price
buttons use `IconRobux` (white glyph) at 22-38 px; `IconRobuxBig` is not used by any slot today.

## Phones

Uniform UIScale, so the fit is the same at 844x390 as at 1280x720: 0 overflow failures. The v3 touch rule
(`TouchScale` on each page's `Window`) is unchanged; `fit_gate`'s touch report lists 84 controls under 44 px
physical (v3: 82), same as before: they need the phone layout pass.

# UI v4.1: owner review 2 (2026-11-15)

System (`tools/ui/mp4.py`): WHITE border back on every panel / button / keylined frame (3 px buttons and cards,
4 px windows, 2 px chips and small tracks; gold NEXT food and leaderboard medals keep theirs); no offset shadow.
Buttons bigger (S 48 / M 56 / L 68, text 24 / 26 / 30) with a glossier face gradient. Captions are AutomaticSize X
(fixed TextSize, `CapWidth` UISizeConstraint, attribute `FitText` shrinks a too-long string at runtime) so icon +
caption are ONE centred group. Every centred display label carries a `Nudge` UIPadding (Luckiest Guy sits high
in its line box; tune `mp4.DISPLAY_NUDGE`). `fit_gate.py` classes and caption rule follow (S48/M56/L68, Z 96).

Runtime: `Ui/UiFx.luau` (one 30 Hz loop, connected only while a page is open or a HUD moment shows: flares turn /
breathe by rarity, sparkles twinkle, rarity card frames, shine sweeps), `Ui/HudMoments.luau` (toasts,
announcement, zone label, level up, cinematic fade), `Screens.wireMotion` (hover pops from the CENTRE: the
button's parts are re-anchored and scaled, never the laid-out button; shine bar `Shine` beside the face sweeps
on hover and every 3.5-6 s on HUD and primary buttons; `ui_hover` sound throttled), `Screens.setBlocked`.

| Where | What to look at |
|---|---|
| FoodShop `FoodCardTemplate` | compact card 220x380: `CravePill` rides the `ArtTile` bottom edge; `StatRow.PowerStat` / `.LuckStat` are tight auto-width pills (icon + text centred); `BuyButton` price centred with its yen icon |
| Squad `HeroRowTemplate` | BENCH / FUSE / SELL captions centred with icons; row frame by rarity; `Thumb` framed head + shoulders; fuse moment on success |
| HeroIndex `ZoneTab1..6` | 222x96 picture cards: `ZoneBg` (painted landscape, `ZoneBg_<zoneId>`), `NameWash`, `ZoneColumn.ZoneName` over `ZoneColumn.ZoneBar` (count centred), `LockIcon` top-right; selected = gold 4 px frame |
| HeroIndex `HeroTileTemplate` | 146x214; `PortraitWell.UnknownMark` (moved out of the viewport); `RarityTag.RarityText` chip on the portrait edge; unknown heroes = own black silhouette |
| SummonOdds `OddsRow1..6` | tier frames (Rare gradient, Epic+ turning, Legendary gold shine, Mythic colour cycle); the shipped `Rainbow` gradient is removed at init |
| HUD `Announcement` | 720x100 top-centre banner at y 118: `AnnounceIcon` on `Sunburst`, `TextColumn.PlayerName / HeroName / InfoRow.RarityChip.RarityText / InfoRow.OneInN`; recoloured per kind; waits while the Reveal screen is enabled |
| HUD `Toasts` | stack at x 112, y 252 (left, clear of centre and notice card); `ToastTemplate` 430x50 = gradient face + `IconWell.Icon` + `Text` |
| HudFx (new ScreenGui, DisplayOrder 15) | `ZoneCross` (x 400 centre, y 132..244: `Burst`, `ZonePlate.ZoneTitle`, `ZoneNumber.ZoneNumberText`) and `LevelUp` (centre, y 150: `Burst`, `LevelPlate.LevelTitle`, `LevelSubPlate.LevelSub`, `Sparkle1..4`) |
| TrainingBar `TrainingPanel` | 600x124: `HeadRow.RankName` / `HeadRow.GearName` on one row, `ProgressBar` (fill tweens, frame glows per rep), `RepRow` icon + `PowerPerRep` centred; `UpgradePrompt` at y -150 |

# UI v4.2: owner's review 3 (2026-11-16)

Screens: `tools/ui/screens_v42.py` (on top of `screens_v4.py`; `build_ui.py` now builds it). New screens `Confirm`
(DisplayOrder 14) and `PromptCard` (BillboardGui); `HudFx` rebuilt; `Store`, `Nameplate`, `TrainingBar`, toasts
rebuilt. Runtime: new `Ui/Moments.luau`, `Ui/Nameplate.luau`, `Controllers/PromptController.luau`; changed `UiFx`,
`Screens`, `HudMoments`, `Viewports`, `HudController`, `MenuController`, `Pages/Store`, `Pages/TrainingBar`,
`Pages/Types`, HeroController (nameplate code only). Gates: `build_ui.py` 0 project failures, `fit_gate.py` 0 at all
four sizes, `verify_labels.py` 314/314, `python tools/gate.py` all green. Nothing has been looked at in game yet.

## The review, item by item

| # | Change |
|---|---|
| 1 | ONE alert per gear upgrade: the gear moment is now the Reward popup (item 13). The LevelUp banner is a single glossy plate at the TOP centre (`HudFx.LevelUp`, y 52..172, under Roblox's top bar, clear of the character). The title sits small over the item name INSIDE the plate (`LevelPlate.LevelTitle` / `.LevelSub`), with an icon medallion `LevelMedal.LevelIcon` (picked from the title), a soft inner highlight (`Highlight` sheen), rays and a glow behind and 4 twinkles. It slams down from the top (`banner_slam`, then `level_up` on landing), gets two sheen sweeps and eases out upward. 500 x 86 (was 540 x 92 plus a separate pill). An empty `sub` puts the title on the big line. |
| 2 | `HudController:_announce` drops a "rebirth" announcement whose player is the LocalPlayer. It matches on payload `userId` / `player`, or on the text starting with the local DisplayName (the server sends only `text`). Other players still see it. |
| 3 | The "slanted toast" was the training bar's `UpgradePrompt` (NEW GEAR: Stone Pillar 600K) and every toast's shine. A UIGradient's Rotation is applied in the element's 0..1 box, so the fixed 18 degree shine on a 358 x 48 pill drew a white streak lying 22 degrees off HORIZONTAL across it, on a 3.5-6 s timer. The shine rotation is now computed from the element's pixel aspect (`UiFx.sweep`, leaning 20 degrees off upright on screen) and never runs on a timer. Toasts: 440 x 58 glossy plate, gloss layer, bigger icon well; `toastIn` resets Rotation on face and toast. The UpgradePrompt button is gone (item 13). |
| 4 | New API, see below. |
| 5 | `HudFx.ZoneCross` is back at the TOP centre (y 122..226): under the letterbox bar (79 px) and below the flight's luck line (86..117), never over the reveal's counter, which shows only after the flight. 420 x 64 plate. Suspense: the `ZONE n` tag drops in, a beat (longer for later zones), the name slams in from 2.2x and clear with an echo `ZoneGhost` blowing outward (a motion-blur feel), the plate bumps, `banner_slam`, rays and a glow in the zone colour (bigger zone by zone), a sheen; `zone_hype` from zone 4; hold 1.4-2 s by zone. |
| 6 | Buttons: the shine plays ONLY on hover and once on press (0.8 s, Sine InOut) as a wide soft bell (UIGradient transparency curve, min 0.66) with an aspect-corrected lean. Timer shines are removed (`AUTO_SHINE_GAP` and the idle loop are gone; the `AutoShine` attribute is ignored). Every button wears a permanent `Gloss` layer (a white highlight fading out by mid-height, a soft dark shade along the bottom) that moves with the press lip and the hover pop. Hover still pops from the centre with `ui_hover`. |
| 7 | Flares stopped because UiFx kept its records in WEAK-KEYED tables keyed by the ImageLabel. Roblox frees an Instance's Luau wrapper when no script holds it, even while the Instance is still in the PlayerGui, and the weak entry goes with it at the next GC cycle, so the image froze mid-turn. Records, rarity-frame gradients and card shines are strong tables now, dropped on `Destroying` / unparent. It is still one Heartbeat loop at 30 Hz, connected only while a page or a moment holds a key; each step touches only records whose whole ancestry is visible in an enabled gui (memoised per step). The same weak-table bug is fixed in `Screens.pressRest`. New: `FxTurn` / `FxPulse` attributes, `Twinkle*` sparkles, `Flame*` / `Petal*` / `Ember*` risers, `UiFx.setColour`, `UiFx.spinGradient`. |
| 8 | The Store is in sections, each with its own colour and a pill header with lines either side: the summon banner (left, violet); FEATURED (pink: `StarterPackBanner`, and `LimitedHeroBanner` with the limited hero's head in `LimitedHeroViewport`); GAMEPASSES (violet, starfield cards, `PassScroller`); LUCK & BOOSTS (green, petal cards, `ProductScroller`); YEN PACKS (gold, cloud cards, `YenScroller`). Cards: an illustrated backdrop `CardBg` blended in at about 22 %, rays and a glow in a frosted icon tile, a sheen, stickers ON the card's top edge (`Sticker` 126 x 28: BEST VALUE / GOOD VALUE / MOST VALUE / LIMITED / NEW!), and GREEN price buttons with the Robux mark (Store binds state "afford" + IconRobux). BEST VALUE now sits centred on the widened x10 button's top edge (152 px button, 140 px sticker, computed from the row). The summon hero is ANIMATED: `Viewports.heroStage` plays the hero's config idle (Fx/Motion) in a WorldModel with a slow camera breathe and sway. A UI aura sits behind it (`AuraGlow`, `Rays` turning, `Rays2` counter-turning, `Halo`, 7 rising `Flame` sprites) on the Mythic colour cycle, with twinkles and petals around the banner and `SummonHeroTag.SummonHeroName`. The clip, the loop and the viewport stop when the store closes. |
| 9 | Pages keep a stable size on big screens: `Screens.fit` caps a page's Window at 68 % of the viewport width and 82 % of its height, never below its authored 720p pixel size, so 1280x720 and phones are unchanged (touch enlargement unchanged). At 1920x1080 a 1104 px window is now 1305 px (68 %) instead of 1656 (86 %). |
| 10 | Border policy (`mp4.normalize`): a button's rim is a PALE TINT OF ITS OWN COLOUR (attribute `Rim` = 0.5; `Screens.tint` keeps it matching on every repaint). Plain navy cards inside windows get a soft periwinkle `#6F79D8`. A card that names its own accent rim keeps it (store sections, stat rows, prompt card). WHITE stays where it reads best: windows, chips, ribbons and stickers, toasts and banners over the world, rarity tiles (UiFx frames). |
| 11 | Nameplate (350 x 150, `Ui/Nameplate.luau`): `RarityText` in the rarity colour (Mythic / Secret: a turning rainbow UIGradient on an infinite engine tween, no Lua per frame; the black Secret colour would otherwise read as light grey); `HeroName` bold white with an outline; `TagRow` = size pill + mutation pill (in its colour) + stars as one centred group, hidden when empty; `BottomRow` = `IconYenBig` + `YenPerSecond` 36 px GREEN "+1.2K/s". A soft pop (Back) when a hero appears; the focused plate grows 12 %. Plates show within 45 studs (was 35). HeroController now calls `Nameplate.make/write/fit`; `plate.gui` / `plate.focused` semantics are unchanged. |
| 12 | `PromptController` (new Knit controller): every ProximityPrompt in Workspace, now and later, gets `Style = Custom`. On `PromptShown` the authored `PromptCard` hangs on the prompt's part (pixel-sized, scaled 0.62-1.15 by screen height, AlwaysOnTop): a glossy navy card, a white key cap (KeyboardKeyCode letter / gamepad button / `FxTap` ripple on touch), ActionText bold, ObjectText small (alone, the action centres), 16 hold pips ringing the key cap that fill over HoldDuration, a pop-in (`prompt_show`), a press bounce (`ui_click`). The `Accent` Color3 attribute tints the key cap, glow and pips and is watched while shown. On touch the whole card is a button calling `InputHoldBegin` / `InputHoldEnd`. |
| 13 | TrainingBar: no station or gear name in the bar (`HeadRow` = `RankName` centred; `GearName` removed). The `UpgradeReady` gold chip replaces the `UpgradePrompt` buy button: "UPGRADE READY!" + `UpgradeText` "Leave training, press F at the gear stand" (touch: "tap the gear stand"). It pulses (an engine tween) and chimes `upgrade_ready` once per gear tier. A gear upgrade calls `ctx.reward{ title = "NEW GEAR!", name, sub = "+N Power per rep", model = Assets.Gear.Equip_<lower_snake name>, image = "IconTrainBig", color = gold }`. A RANK UP stays the single top LevelUp banner. |
| 14 | `HudController:_purchases` runs on every snapshot (baseline at join). A newly owned food gives `Reward{ "NEW FOOD!", name, "Luck xN   Power xN", model = Assets.Foods.Food_<id>, image = "Food_<id>", flavour colour }`; slots going up by exactly one give `Reward{ "NEW SLOT!", "Slot n", image = "IconPlaceBig", green }`. This lives in HudController, not the FoodShop page, because a page only renders while it is open. |
| 15 | The Confirm dialog and the moments are authored as specs (fit-checked) instead of code-built frames; sibling gaps and centring are fixed on every new screen; the mockup renderer now tints and fades cropped sprites (`mp4._draw4`). |

## API (HudController; implemented in `Ui/Moments.luau`; every field optional, nothing errors)

```lua
HudController:Reward(info: { title: string?, name: string?, sub: string?, model: Instance?, image: string?,
    color: Color3?, rarity: string? })            -- queued; tap / click / A / Space / Return or 2.8 s dismisses
HudController:Confirm(info: { title: string?, name: string?, model: Instance?, image: string?, icon: string?,
    rows: { { label: string?, from: string?, to: string?, icon: string? } }?,   -- up to 3 rows; no `from` = value only
    cost: number?, costKind: ("yen" | "robux")?, canAfford: boolean?, confirmText: string?, color: Color3?,
    onConfirm: (() -> ())?, onCancel: (() -> ())? }): { Close: (self) -> () }
    -- Escape / ButtonB / X / CANCEL = cancel (onCancel); CONFIRM / Return / ButtonA = onConfirm, only when
    -- affordable (else the button reads NEED MORE YEN, greyed, and refuses with ui_error). A second Confirm
    -- replaces the first. handle:Close() closes without calling either callback.
HudController:StatTicks(info: { title: string?, color: Color3?, rows: { { label: string?, from: string?,
    to: string?, icon: string? } }?, step: number? (0.5), hold: number? (1.6) }): { Close: (self) -> () }
    -- up to 6 rows; numbers with the same prefix/suffix count up ("x1.50" -> "x2.00"), anything else flips;
    -- no `from` shows the value alone (e.g. "KEPT")
HudController:LevelUp(title: string, sub: string, color: Color3?)   -- the single top banner
HudController:ZoneCross(name: string, color: Color3, index: number)
```

Icons in `image` / `icon` / a row's `icon`: an Icons.luau key ("IconPower", "IconPlaceBig", "Food_ramen"; a missing
`...Big` falls back to the base key) or a raw content id ("rbxassetid://...", or a number). `IconSlot` does not exist;
use `IconPlaceBig`. Reward, StatTicks and the banners are on `HudFx` (DisplayOrder 15) and Confirm on `Confirm` (14),
so all of them show while `SetCinematic` has the HUD faded. `Viewports.model(frame, source, margin?)`,
`Viewports.pose` and `Viewports.heroStage(frame, id, idle)` are public for anyone else showing a model in the UI.

## Sound roles used (silent until the lead adds them to the bank)

New: `reward_whoosh`, `reward_pop`, `confirm_open`, `confirm_yes`, `stat_tick`, `prompt_show`, `upgrade_ready`,
`banner_slam`. Existing: `ui_hover`, `ui_click`, `ui_error`, `toast_good`, `toast_warn`, `toast_pop`, `level_up`,
`zone_cross`, `zone_hype`, `announce`.

## New images (uploaded as Image through Open Cloud; ids in `assets/ui/ids_fx_v4.json`, keys in Icons.luau)

Painted by `tools/ui/fx_v42.py` (white sprites tinted by ImageColor3; sheet `work/ui/fx_v42_sheet.png`):
FxGlow 75539576521240, FxRays 127562011670090, FxRing 139610311427274, FxTwinkle 86395251101799,
FxPetal 137141805526044, FxFlame 98281597397853, FxTap 90194008488748, FxShine 77769444335791,
BgClouds 90822575414969, BgSakura 73998558162080, BgStars 94571520394674, BgRays 125886885302155.
A fresh upload can render blank while it is in moderation review.

## Path changes (old -> new)

| Screen | Old | New |
|---|---|---|
| HudFx | `LevelUp.LevelSubPlate.LevelSub`, `Burst`, `Sparkle1..4` | `LevelUp.LevelPlate.LevelTitle` + `.LevelSub`, `LevelMedal.LevelIcon`, `Rays`, `Glow`, `Twinkle1..4` |
| HudFx | `ZoneCross.Burst` | `ZoneCross.Rays` / `.Glow`, `ZonePlate.ZoneGhost` (+ `ZoneTitle`, `ZoneNumber.ZoneNumberText`) |
| HudFx | - | `Scrim`; `Reward.(Rays, Rays2, Glow, Halo, RewardIcon, RewardStage, RewardTitlePlate.RewardTitle, RewardName, RewardSub, RewardHint, Twinkle1..6)`; `StatPanel.(StatHeader.StatTitle, StatRows.StatRow1..6.(StatIcon, StatLabel, StatFrom, StatArrow, StatTo))` |
| TrainingBar | `UpgradePrompt` (button) + `.UpgradeText`, `HeadRow.GearName` | `UpgradeReady` (chip: `ReadyIcon`, `ReadyTitle`, `UpgradeText`); GearName removed |
| Store | `PassesTitle`, `ItemsTitle`, gradient `IconTile`s | section headers `FeaturedHeader` / `PassesHeader` / `BoostsHeader` / `YenHeader`; `YenScroller`, `LimitedHeroBanner`, `CardBg`, `SummonHeroTag` |
| Nameplate | `BottomRow.Stars` | `TagRow.Stars`; new `RarityText` |

## For the lead (files I do not own) and what is not done

1. `TrainingService` still toasts "New rank: X!" on a rank up, which doubles the RANK UP banner (item 1's rule).
2. A slot confirm with `image = "IconSlot"` falls back to IconStar (no such key); use `IconPlaceBig`.
3. FxController's rebirth `hud:LevelUp("REBIRTH n", "You evolved!", purple)` and `hud:StatTicks{...}` work as sent: the banner at the top, the stats panel centre-right (x 1030), clear of the player.
4. Not verifiable from here: nothing was looked at in Studio (Roblox font metrics, the animated summon hero in its WorldModel, PromptCard input on touch, the `Accent` tint in play, the gradient-lean maths). The PromptCard covers Workspace prompts only. The touch-size report (88 controls under 44 px physical on a phone) is unchanged from v4.1: it still needs the phone layout pass.

# UI v4.3: owner's review 4 (2026-11-15)

Screens: `tools/ui/screens_v43.py` (on top of `screens_v42.py`; `build_ui.py` builds it). If
`tools/ui/screens_store_v5.py` exists, its `store` is passed through untouched. Gates: `build_ui.py` 0 project
failures, `fit_gate.py` 0 at all four sizes, `rojo build` OK, `tools/gate.py` code gates green. `verify_labels` is
red ONLY on Store labels from the store worker's in-progress Store (PerkText, PassDesc, ProductDesc,
Starter/LimitedStickerText). Nothing has been looked at in Studio yet.

| # | Change (root cause) |
|---|---|
| 1 | Welcome Back: the sunburst was placed at an offset computed from the SAMPLE amount width while `EarnedRow` is a centred auto-width row, so any other amount moved the coin off the burst. The burst and the coin now share one 64 px `EarnedRow.CoinHolder` (`Sunburst` + `Icon`), so they are centred on each other for any amount. The other burst-behind-icon spots (LevelUp medal, Reward, Confirm stage, Store tiles, Nameplate, fuse badge) were already children of, or centred on the same point as, their icon. |
| 2 | The translucent white box: `Screens.wireMotion` laid the v4.2 permanent `Gloss` layer (and the `Shine`) over EVERY button's face, including transparent self-faced buttons such as the HUD `FoodChip` (a TextButton with BackgroundTransparency 1 holding an icon and text): an opaque white gradient the size of its box. Gloss and shine now go only on a painted face (background < 0.95 or an image); attribute `Gloss = false` opts any button out. This fixes every transparent button at once. |
| 3 | Confirm (680 x 506): title bar; model panel 224 x 240 with a backdrop (`StageBg` BgRays, `Glow`, `StageFloor` shadow) clipping the turning model; right column `ConfirmName` + `ConfirmTagCell.ConfirmTag.ConfirmTagText` (new `tag` / `tagColor` fields, hidden when absent); 3 stat rows as aligned cards (`RowIconWell.RowIcon` / `RowLabel` / `RowFrom` / `RowArrow` / `RowTo`, fixed columns); `CostWell` full width (`CostBadge`, PRICE, amount right); `ConfirmNo` / `ConfirmYes` both 296 px. |
| 4 | Reward is a card: stage with rays above `RewardCard` (580 x 196), `RewardTitlePlate` ribbon on its top edge, `RewardName` 40 px, `RewardChips.RewardChip1..3Cell` (icon + text pills, new `chips` field; `sub` shows alone when no chips), hint. 4 s (tap still dismisses after 0.45 s), fades in and out over 0.35 / 0.4 s with a gentle scale (no pop). Callers send chips: NEW GEAR ("+N Power per rep", "Tier n of N"), NEW FOOD (Luck, Power, flavour), NEW SLOT ("Slot n of MaxSlots", "+1 hero on your plot"). |
| 5 | The Squad shine was the card-shine TIMER (Legendary 3.2 s, Mythic 2.6 s, Secret 2.2 s). Card shines now cross only on hover (1.5 s). New tier looks in `UiFx.styleCard`: Common white, Uncommon mint, Rare a soft drifting blue gradient, Epic a light chase (one bright run round a violet frame), Legendary turning gold + pulsing glow ring (`TierGlow`), Mythic / Secret multicolour + colour-cycling glow. Surfaces: `TierPattern` per tier (dots / starfield / gold rays / sakura / cycling stars) with a drifting shimmer band, on cards and on portrait tiles (`UiFx.stylePortrait`, Squad `PortraitTile`, Index `PortraitWell` once caught). Portraits: ClipsDescendants clips a rectangle, not rounded corners, so the viewport painted the hero over the corners and the white frame. `Viewports.hero` now insets every framed portrait 5 px, gives it its own UICorner and draws a `PortraitRim` (copy of the tile stroke) ABOVE it; camera margin 1.1 -> 1.24 so hair stays inside. Applies to Squad, Index, SummonOdds (store banner viewport has no tile, untouched). |
| 6 | Rebirth: 800 x 546 window (was 940 x 598). `Requirements` card with icon wells, captioned bars and `PowerDone` / `YenDone` ticks; `NextTierChip.NextTier`; gold `Rewards` panel on a `RewardRibbon`, `IncomeLine` / `LuckLine` icon + text, `ForeverChip`; `Keeps` / `Resets` cards with green / red header strips and a 2 x 2 list; `CurrentChip.CurrentRebirth`; REBIRTH 300 px with a glow. MAX shows "MAX REBIRTH". |
| 7 | ZoneCross: no text fade in. Everything is at full opacity on the first frame and slams in by scale (plate 1.18, name ~1.25 -> 1 Back 0.16 s), echo + sheen + `banner_slam` at once, hold 1.6-2.2 s, ease out. |
| 8 | Reveal final: one `HeroCard` (640 x 186, bottom centre, over the letterbox): `RarityRibbon.RarityText` on the top edge (tier colours turning in the word from Rare), `Stamp.StampLabel` sticker on the corner (NEW BEST! / NEW! / LUCKY!), `CardName` 40 px, `TagRow` (SizeTag, MutationTag in its colour, `CraveTag` "CRAVES X" / "CRAVING!" in the flavour colour with its icon, `Stars`), `StatsRow` = `IncomeRow` (IconYenBig + `IncomeLabel` 36 px green) / `Divider` / `CardOddsRow` (`CardOdds` "1 in N"), `SoldTag.SoldLabel` on the bottom edge. The card frame / glow / pattern use `styleCard`. It slides up 70 px and scales in (Back 0.45 s), then the ribbon pops and a shine crosses; it hides the spelled name and the top odds counter and stays until `enable(false)`. Removed from Reveal: `VariantLabel`, top-level `StampLabel`, `RarityRibbonCell`, `IncomeRow`, `SoldLabel` (all RevealUi signatures unchanged). |
| 9 | Also: chips / pills gap 8; `SkipHint` at y 696. |

## For the lead

1. `UpgradeController` (yours) can now pass `tag` to `HudController:Confirm`, e.g. gear `tag = "TIER " .. (state.gear + 1)`, slot `tag = "SLOT " .. (state.slots + 1) .. " / " .. Config.Plot.MaxSlots`; without it the chip is hidden. The slot row uses `icon = "IconSquad"` which has no icon (falls back to IconStar); `IconPlace` reads better.
2. `RevealUi.final` reads `result.stars` if present (fuse stars) and `character.Craves`; nothing else new.
3. Not verified in Studio: UICorner on the portrait ViewportFrames, the glow ring position on laid-out rows, the new card in the 4.5 s beat next to the hero holding the food (card top at y ~500 of 720).

# UI v5 store (owner's review 4)

Source: `tools/ui/screens_store_v5.py` (Store + `PassCardTemplate` + `ProductCardTemplate`; `screens_v43` takes
`store` and `TEMPLATES_OVERRIDE` from it). Runtime: `Ui/Pages/Store.luau` (rewritten), new `Ui/StoreFx.luau`, new
`Viewports.heroShowcase` (existing Viewports functions unchanged). Gates: `build_ui.py` 0 project failures,
`fit_gate.py` 0 at all four sizes, `verify_labels.py` 357/357, `tools/gate.py` all PASS. Nothing has been looked at in Studio yet.

| # | Change |
|---|---|
| 1 | Summon buttons stay INSIDE the card: three `ScrollTile1/3/10` tiles (124 x 150) in `BuyRow`, each with `ScrollCount` ("x1") ABOVE the button, `ScrollNote` ("79 EACH" / "SAVE 16%" / "SAVE 24%", worked out from the config prices), and `SummonBuy<n>` holding only the Robux icon and `Price`. BEST VALUE is a ribbon on the x10 tile's top edge (gold rim, light chase, pulsing). It is shown only when x10 really is the cheapest per scroll. The pool chip sits above the x1/x3 tiles only, so nothing is near the ribbon. Banner width 410 -> 436 (window 1152 at 720p). |
| 2 | Summon hero stage (`StageWell`): cosmic backdrop, a turning magic circle and a counter-turning rune ring (shrine sigil), radial speed lines, an energy core, an SSJ-style aura silhouette and two violet flame flipbooks, smoke at the feet, rising manga speed lines, embers, two lightning crackles (play once, pause 0.7-2.5 s), star glints. The hero plays its idle with a slow 14 s camera dolly and sway. Overlays: `SummonRarity` chip (tier from the pool order like SummonOdds, so MYTHIC; text gradient shimmer and a pulse), `SummonChance` ("1% CHANCE"), SEE ODDS, a name plate (`SummonHeroName`, `SummonHeroPerk` "EARNS 12x YOUR BEST"), `SummonPoolText` ("6 EXCLUSIVE HEROES"). The card border has a light chase. |
| 3 | The owner's textures are used as UI images (see the table below). Flipbooks are resolution independent: a clipping square holds a `Sheet` image grid x grid in size, and StoreFx moves it by whole cells. Their pixel sizes cannot be read from here, so ImageRectOffset was not used. |
| 4 | FEATURED: two 310 x 408 showcase cards in `FeaturedRow`. `StarterPackBanner`: Blood Fiend animated in `StarterViewport` over a sun burst, speed lines, a glow core, spinning gold coins, star glints and embers; ONE-TIME OFFER sticker (hidden once owned); `StarterPerk1..3.PerkText` with icons (hero, Lucky Throws, 2x Yen minutes, all from config `Rewards`); a wide green price button. `LimitedHeroBanner`: First Sun Swordsman animated in `LimitedHeroViewport` over a red sun burst, a turning sun crest, two flame flipbooks and a pulsing slash arc; LIMITED HERO sticker; perks "Earns 3x your best / Store exclusive / Not in any scroll". Both get light-chase borders and pulsing stickers. No countdown timer: the config has no end date, so none is invented. |
| 5 | Gamepasses: wide 310 x 186 cards (2 columns) with `PassDesc`, built from config and checked against the server code: 2x Yen "Every hero earns double yen, forever." (Income doubleYen); 2x Training "2x Power from every rep, perfect tap and boost." (TrainingService); VIP "+15% luck on every throw and +2 hero slots." (Luck.VipBonus, Plot.VipBonusSlots; no chat tag exists, so none is claimed); Auto Throw "Adds AUTO to your throw pad: it throws for you." (ThrowController); Lucky Aura "x1.5 luck on every throw, forever."; Big Bench "Your bench holds 60 heroes instead of 30.". Products (148 x 278) get `ProductDesc`: "x12 luck on N throws" (Throw.LuckyThrowLuck), "Server luck up for 15 min", "N min of training Power", "N hours of your income" (EconomyService:MinutesOfIncome). |
| 6 | Performance: `StoreFx` runs ONE RenderStepped loop, connected only between `Store.opened` and `Store.closed`. It steps only layers whose whole ancestry is visible and, inside `StoreScroll`, only those in view. At most 12 flipbooks step per frame (11 exist today). Sprites update at 30 Hz. The three 3D showcases have no loops of their own; StoreFx steps them only when on screen. On close the loop stops, the clips stop, the viewports are emptied and every layer goes back to its shipped pose. Tables are strong, and entries are dropped on Destroying (the v4.2 weak-table bug is avoided). |
| 7 | Page size rule unchanged (Screens.fit). Paddings are 12 px inside cards, gaps 14 px between tiles and cards, captions centred. 22 checker warnings remain (6 px gaps, grid aspect, and the stroke mix inherited from v4.2), with no failures. |

Owner textures used (ids in `assets/ui/ids_store_v5.json`, the single source: spec -> model attribute `VfxImage` -> StoreFx;
none re-uploaded; `assets/ui/store_v5/*.png` are 420 px thumbnails, used only for the mockup):

| Key | Id | Where |
|---|---|---|
| Galaxy | 10716751908 | summon card and stage backdrop |
| Sigil (magiccircle) | 12389948201 | summon: turning circle behind the hero |
| Runes (CircleOuter) | 2152222413 | summon: counter-turning rune ring |
| SpeedRays (Rays) | 1084975295 | radial speed lines: summon, starter, limited |
| AuraShape (OriginalAura2x2, 2x2) | 17612127081 | summon: aura silhouette |
| AuraFlame (Aura2, 4x4) | 16860267787 | summon: flames left and right |
| Smoke (4x4) | 15410021685 | summon: smoke at the feet |
| Zaps (4x4) | 11492870634 | summon: lightning crackle |
| Lightning (lightning #6, 4x4) | 14068947349 | summon: second crackle |
| StarFlip (Star4, 4x4) | 17062426399 | summon and starter: star glints |
| Streak (Lines D) | 241876428 | summon: rising speed lines |
| Flare (TopStar) | 448862775 | embers on all three stages |
| EnergyCloud (Energy Flare) | 10435576555 | summon: energy core |
| SunBurst (Burst) | 8210105223 | starter and limited: burst behind the hero |
| SunCrest (Dull Triangular Circle) | 16511726823 | limited: turning sun crest |
| FireRoar (FIRE, 4x4) | 11534281007 | limited: flames |
| FireLove (Fire1, 4x4) | 16841991986 | limited: second flames |
| Coin (COIN RAIN 3, 4x4) | 12010904379 | starter: spinning gold coins |
| Eclipse (Eclipse Aura) | 1280736246 | starter: glow core |
| Slashes | 12678933489 | limited: pulsing sword-slash arc |

Rejected: `glow` 9591714714, `Embers1`, `lightning` 8247403083, `Bolts`, `Rune` and `BrightStars2x2` have opaque black
backgrounds (they rely on LightEmission in particles) and would draw black squares. `Smoke2` 12026515010, `Hypnotism`
12867093437 and `HANMA 4` 14053069521 show a moderation placeholder.

## Path changes (old -> new)

| Old | New |
|---|---|
| `SummonBuy<n>.Count` + two-line buttons | `ScrollTile<n>.(ScrollCount, ScrollNote, SummonBuy<n>.Price)` |
| `BestValueSticker` on the window body | `ScrollTile10.BestValueStickerCell` |
| `NewSticker`, `SummonSub`, `SummonNote`, `AuraGlow/Rays/Rays2/Halo/Flame*/Sparkle*/Twinkle*/Petal*` | removed (the StoreFx `Vfx*` layers replace them; UiFx no longer animates anything on the summon banner) |
| `LimitedHeroDesc`, `LimitedHeroBannerStickerText`, `LimitedSticker` on the starter | `LimitedPerk1..3.PerkText`, `LimitedStickerText`; starter `StarterSticker(Text)`, `StarterPerk1..3.PerkText`, `StarterViewport` |
| - | `SummonRarity(Text)`, `SummonChance(Text)`, `SummonHeroPerk`, `SummonPoolText`, `PassDesc`, `ProductDesc` |

## Not done / for the lead

1. Not looked at in Studio: the flipbook cell stepping, the stage framing (`fill` 0.78 / 0.9 in `Store.opened`), the
   tint strength of each texture, and the light-chase speed all need one look in game. Effect strength is set per layer
   by `alphaImg` / tint in `screens_store_v5.py`.
2. A texture still in moderation, or one private to its creator, renders blank. That is harmless, but it is worth checking that each layer shows.
3. No new images were uploaded and no Icons keys were added (the textures go through model attributes). `build_ui.py` is
   unchanged: the mockup finds the thumbnails through a draw-time fallback in `screens_store_v5.py`.

# UI v4.4 (owner's review 5) (2026-11-15)

Screens: `tools/ui/screens_v44.py` (on top of `screens_v43.py`; `build_ui.py` builds it). Gates: `build_ui.py` 0 project
failures, `fit_gate.py` 0 at all four sizes, `verify_labels.py` 357/357, `rojo build` / lune 93 / selene PASS. `stylua --check`
is red only on the store worker's `Ui/StoreFx.luau` and `Ui/Pages/Store.luau` (not touched here). Nothing has been looked at in Studio yet.

| # | Change |
|---|---|
| 1 | Announcement: a slim dark bar (760 x 74) at the top centre at y 62, right under the objective pill (y 14..54, never overlapped; the hint now stays up). Rarity-coloured `AccentLeft` / `AccentRight` edges, `RarityWash` at both ends, rim and `PortraitWell` rim tinted by `HudMoments.dressAnnouncement`. Round portrait well: `AnnouncePortrait` (ViewportFrame) shows the caught hero via `Viewports.hero` (id found as the longest roster name the text ends with), `AnnounceIcon` when there is none. `PlayerName` 16 px "CAUGHT BY SWERTZ  ·  TITAN GOLDEN", `HeroName` 30 px (just the hero name), `MetaRow` = `RarityChip` + `OneInN` on one line at the right. Enters by sliding 26 px down + a fade (0.45 s Quint) and one shine; leaves by fading as it lifts. The luck bar and notice card step aside while it shows. |
| 2 | Toasts: top-centre stack (`Toasts`, list centred, gap 8). `ToastTemplate` is a wrapper (AutomaticSize X) holding `Face`, a 40 px navy pill: `IconWell` (28 px circle in the kind colour, 18 px icon) + one 18 px `Text` line. Kinds: info #3B82F6, good #2FBF71, bad #F0524D, reward #F5A524 (the well and the rim). In: slide 14 px down + fade 0.24 s; out: fade + lift 0.2 s. No bounce, no big icon, no shine. `HudController:_placeToasts` moves the stack to 10 px under the lowest visible top-centre piece (hint, announcement, luck bar, notice), so a toast never covers the banner. |
| 3 | Rebirth (820 x 432 body): row 1 two cards of EQUAL height 196 (`Requirements` 496, `Rewards` 310), both titles on the same line (y 14); requirement rows share columns (50 px well / caption over a 32 px bar, tick at the caption's right end), captions "TOTAL POWER" / "YEN COST". Reward: title, two centred lines (24 px), FOREVER chip on a 10 px rhythm, no ribbon poking into the title bar. Row 2: `Keeps` / `Resets` mirrored (373 x 140), titles centred by real metrics, 2 x 2 lists on shared 169 px columns, 18 px text. `Footer`: `CurrentChipCell` (icon pill, 18 px) and `ConfirmButton` on one centre line, flush with the cards' outer edges. |
| 4 | Every window heading (`mp4.header`, replaced in screens_v44, so the Store gets it too): `TitleRow` auto-sizes, the `Title` grows with its text (AutomaticSize X) so icon + title are centred as one group by Roblox's metrics; 36 px title, 44 px icon (sized to the caps), white -> pale-gold `TextGradient` over the 2 px ink stroke, a soft `HeaderShade` along the bar's lower edge. Bar geometry unchanged (68 px, close button on its centre line), so no body moved. |
| 5 | Windows 8% smaller: `Screens.luau` `PAGE_SCALE = 0.92` multiplies the desktop page factor (`factor = PAGE_SCALE * math.min(1, math.max(1 / scale, cap))`). Every page with a `Window` (Store included) is drawn at 92% at 720p and on big monitors; touch keeps its thumb-sized fill. Smallest page text (16 px) renders at ~14.7 px at 720p. |

# UI v5.1 store (owner's review 5)

Source: `tools/ui/screens_store_v5.py`; runtime `Ui/StoreFx.luau`, `Ui/Pages/Store.luau` (Viewports unchanged). Gates:
`build_ui.py --only Store` 0 project failures, `fit_gate.py` 0 at all four sizes, `verify_labels.py` 357/357,
`tools/gate.py` all PASS. Not yet looked at in Studio.

| # | Change |
|---|---|
| 1 | Pulsing chips (MYTHIC, BEST VALUE, ONE-TIME OFFER, LIMITED HERO). Cause: the v5 UIScale sat on the inner face (MYTHIC's pivot was its top-left, inside a list layout), and the text was TextScaled, which re-fits in whole font sizes, so letters stepped out of time with the plate. Now ONE UIScale (`FxPulseScale`) on the whole `...Cell`, AnchorPoint 0.5/0.5 at the chip's centre (in the model; `StoreFx.pulse` also re-centres any cell authored otherwise), the chip's text switched to a fixed TextSize (its SizeCap), a sine evaluated every frame, 4.5% at 2.6 rad/s for all four. MYTHIC is out of the list layout (absolute position). Other motion checked: sprites (turn / pulse / rise) now step every frame (were 30 Hz); the border chase no longer pulses UIStroke thickness (it snapped to whole pixels); flipbooks step at their own fps by design. The UiFx-driven glow in the old icon tiles is gone from store cards (the new icon slot's glow is static). |
| 2 | Summon name plate `SummonHeroTag` (376 x 80) on the stage floor, under the hero's feet: `SummonHeroName` 24 px display, upper case, white under a slow rarity gradient (`NAME_COLOURS`, violet for MYTHIC) with its dark outline; `SummonHeroPerk` in a gold chip `SummonPerkChip` with a yen icon. The viewport now ends above the plate (hero fill 0.9), so nothing covers the hero; every stage effect is placed from the hero's centre/feet. Pool count moved under the title ("6 EXCLUSIVE HEROES"). |
| 3 | Scroll tiles: three equal 124 x 140 tiles, 14 px gaps (the gate's card gap), row centred under the stage with the same 18 px side inset. Each tile: count (26 px) at 12, note at 50, Robux button S (108 x 48, price 20 px, centred with its icon) 8 px from the bottom and sides. BEST VALUE is centred ON the x10 tile's top edge. |
| 4 | Owner backgrounds uploaded as Images: `BgRedMoon` 110074599004151 (limited hero card), `BgBloodChains` 98516886373195 (starter pack card), in `assets/ui/ids_store_v5.json` (mockup thumbnails `assets/ui/store_v5/Vfx_<id>.png`). Each fills its whole card as `CardArt` (ScaleType Crop, own colours, restored by StoreFx.bind from `VfxImage`), a light top shade, and `TextScrim` (dark gradient, transparent -> 90%) behind the title, perks and price. The stage well is now transparent so the hero stands on the painting; the sun burst / crest / speed rays were dropped so the art shows; flames, slash, coins, glints and embers stay (lighter). Card content unchanged. |
| 5 | Pass card 310 x 186: coloured `HeaderBand` with `PassName` centred; framed `IconSlot` (94, dark well, white rim, glow) on the left; one column right of it with `PassDesc` (16 px, left, 3 lines) on top and `PassBuyButton` (S, 176 wide, identical on every card) at the bottom; 12 px paddings. Product card 148 x 272: `HeaderBand` (name, 2 lines), `IconSlot` 84, `ProductDesc` (16 px, centred, 2 lines), `ProductBuyButton` (S, 128) at the bottom: the same rows on every card, so a grid row lines up. Stickers centred on the top edge. |
| 6 | Section headers: one bar per section (dark tint of the section colour, section-colour rim): round badge with the section's icon (star / crown / clover / yen), the title left-aligned and outlined, and a rule fading out to the right. |
| 7 | Size: the store keeps its 720p layout (body 1112 x 540); the global page cap is the other worker's. All text is >= 15 px at 720p (descriptions 16), so at 90% it stays >= 13.5 px; fit_gate has no failures at any size. |

New mockup-only machinery in `screens_store_v5.py`: `scrim()` frames (a Frame + one UIGradient Transparency ramp; the
mockup draws the same ramp), installed by `_scrim_hooks()` next to `_preview_icons()`.

Not done / for the lead: look in game at the pulse smoothness, the cards' art crop (Crop centres the 729 x 1024
paintings on a 310 x 408 card), and the name gradient. Fresh uploads may show blank while in moderation review.

# UI v4.5 (owner's review 6) (2026-11-16)

| # | Owner's note | Fix |
|---|---|---|
| 1 | The announcement bar is slanted | No code rotates the bar: the model ships every part of it at Rotation 0 and nothing in HudMoments / HudController / UiFx / Moments / Screens writes a GUI Rotation outside the flares (checked every `Rotation` write in `src/client`). The tilt is the entrance SHINE: on a 760 x 74 bar the streak leans 20 deg off upright (UIGradient Rotation ~2 in the bar's 0..1 box), and a leaning light band crossing a long thin dark bar reads as the bar itself being tilted (the same illusion as the v4.4 "slanted toast"). The announcement's sweep is now UPRIGHT (`UiFx.sweep(shine, seconds, lean)`, `lean = 0`; `HudMoments.shineOver(..., lean)`), and every swept shine parks itself level (Offset -1, Rotation 0) when it ends. Guard against any future leftover: `UiFx.level(root)` puts a moment's root at exactly 0 and every descendant back at the Rotation it shipped with (attribute `ShipRotation`; flares/sparkles/risers excluded), called on entrance by the announcement, toasts (replaces the two `Rotation = 0` lines), zone banner, level-up banner, reward card, stat ticks and the confirm dialog. Designed angles (the 90 deg `RowArrow` / `StatArrow`) are kept. |
| 2 | Hero portraits cut off at the top (Squad, and every shared portrait) | `Viewports.hero` framing rewritten. The old box capped hair at 1/4 head above the head, ignored any hair/hat piece whose CENTRE was below the head's middle (long or swept-up hair meshes), measured parts without their rotation, and could pick a part named "Head" deep inside an accessory. Now: `Head` is the model's direct child when there is one; every visible piece in the head's column whose rotation-aware box reaches above the head's middle extends the box, up to 1.9 head heights above the head (a halo or raised weapon does not shrink the face); the bottom is just under the shoulders, the width the shoulders plus the hair. `frameBust` then pulls the camera back until all four TOP corners of that box project inside 84% of the frame's half height (headroom over the tallest hair) and every corner inside 94% of the half width, for the frame's real aspect (iterative, 12 steps max). Applies to Squad rows, Hero Index tiles (and silhouettes), Summon Odds rows and the announcement's round portrait. |

Files: `src/client/Ui/Viewports.luau`, `src/client/Ui/UiFx.luau`, `src/client/Ui/HudMoments.luau`, `src/client/Ui/Moments.luau`.
No model / spec change (no rebuild needed). Gates: `tools/gate.py`, `fit_gate.py`, `verify_labels.py` green.

Not done / for the lead: both fixes must be LOOKED AT IN THE GAME (I have no Studio): an announcement for a catch
(the bar level, the streak upright), and the Squad list with the tallest / spikiest-haired heroes (whole hair inside the
tile with headroom). If a hero still crops, its `Head` is probably not the visible head (an imported mesh head): print
`Char_<id>.Head.Transparency` and the accessory boxes for that hero.

# UI v5.2 store (owner's review 6) (2026-11-16)

Source: `tools/ui/screens_store_v5.py`; runtime `Ui/StoreFx.luau`, `Ui/Pages/Store.luau`, new store-only
`Viewports.heroSequence` (+ type `Viewports.Beat`; nothing shared changed); blood sprites `tools/ui/store_blood.py`.
Gates: `build_ui.py --only Store` 0 project failures, `fit_gate.py` 0 at all four sizes, `verify_labels.py` 357/357,
`tools/gate.py` all PASS. Not yet looked at in Studio.

| # | Change |
|---|---|
| 1 | Every store hero stands in a framed glass panel (`hero_frame`): `StarterFrame` / `LimitedFrame` (226 x 176 at y 22) and `SummonFrame` (168 x 184 in the stage). Rounded 18, themed rim with a light chase (`StoreFx.border`, crimson / fire / violet; thickness never changes), dark frosted glass (50% fill) over a faint themed pattern (`BgStars` crimson, `BgRays` gold, `BgStars` violet), inner glow at the top and bottom edges, a breathing core light, the hero's ViewportFrame (rounded 14 by Store.luau), a gloss sheen and a glint sweeping across every ~5 s. The owner's paintings stay as the card backgrounds. |
| 2 | Effects round each frame (behind its edges, corners and border; never over the text). Swordsman: heat glow, a turning sun ring and a counter-turning flame arc behind the frame, four layered flame flipbooks licking up its corners and edges (FireRoar, FireLove, FireColumn, FireWisp), flame tongues at his feet and a turning flame ring behind him inside the frame (FireBlast, FlameSwirl), 8 embers rising. Blood Fiend: crimson glow and a blood ring behind the frame, four blood spears (SPIKES) stabbing out of the corners and drawing back (`VfxThrust`), splash bursts at two corners, crimson wisps up one edge, a slash spray on the other, glossy splatters on two corners, four blood runs that creep down from the rim and drop a bead (`drip()`: position only), a ring turning inside the frame, red embers. The owner's packs hold no blood texture, so the splatter, run and drop are drawn (`tools/ui/store_blood.py`) and uploaded. |
| 3 | Card text: title in the theme's sliding gradient (white/crimson, cream/gold/orange) over a breathing glow; perks as themed glass chips (round icon well in the card colour, white rim, 16 px line); the price button on a breathing themed light; a darker text scrim. |
| 4 | Hero animation: `Viewports.heroSequence` cycles beats instead of one idle: base clips cross-fade 0.6 s and are held 4-5.5 s (+-15%), flourishes play over the base and fade out 0.4 s before they end; the camera orbits +-16 deg over ~28 s, lifts and pushes in during flourishes. Blood Fiend: IdlePower, HeroMenace, IdleCool, RebirthAwaken, IdlePower, RevealLand. Swordsman: IdleBlade, HeroMenace, IdleCool, RevealLand, IdleBlade, IdleNinja. Illusion Overlord: IdleCool, IdleFloat, HeroMenace, IdlePower, RebirthEvolve, IdleFloat. Missing clips are skipped. |
| 5 | Summon stage: the owner's throne painting (`BgThrone`) fills `StageWell` (Crop) with a shade at the bottom for the plate; the hero is in `SummonFrame`. Kept: magic circle, rune ring, speed rays, rising lines, violet flames either side of the frame, the aura silhouette and smoke (now inside the frame), the lightning crackles on the frame's edges, glints and embers. MYTHIC is the frame's crest (on its top edge). The drop chance is a badge left of the frame (`SummonChanceText` "1%" + "CHANCE"). |
| 6 | Section headers: the title centred, no icon, no box (a "bare" panel: nothing painted), a rule either side in the section colour fading out towards the edges, a small diamond at each inner end. |
| 7 | No size pulsing anywhere in the store: `StoreFx.pulse` is removed (any old `FxPulseScale` is destroyed), sprites `VfxPulse` became `VfxBreath` (transparency only), the border chase never touches thickness. MYTHIC, BEST VALUE, ONE-TIME OFFER, LIMITED HERO and the product stickers get `StoreFx.shine`: a glint band slides across (one UIGradient Offset set every frame, ~0.9 s every 3-3.6 s) and a halo behind breathes in transparency. Text never moves or resizes. |
| 8 | SEE ODDS: a compact mp3 S pill (34 px tall, 14 px text, no icon, at most 98 px wide) in the stage's top-right corner. |
| 9 | Performance: still ONE RenderStepped loop, only while the store is open; only visible / in-view layers step; flipbooks capped at 16 (summon 7, swordsman 6 with the feet fire, Blood Fiend 4; the spare frames hold); the 3D sequences step only from that loop while on screen. |

New ids (`assets/ui/ids_store_v5.json`; mockup thumbnails `assets/ui/store_v5/Vfx_<id>.png`):

| Key | Id | Source | Where |
|---|---|---|---|
| BgThrone | 104721066207509 | owner_bg/bg_throne_vortex.png, uploaded as Image | summon stage background |
| BloodSplat | 138180682365808 | drawn (store_blood.py), uploaded | splatters on the frame corners |
| BloodDrip | 74310528338938 | drawn, uploaded | blood runs from the rim |
| BloodDrop | 87019407382216 | drawn, uploaded | the falling drops |
| FireColumn (Fire55, 4x4) | 16860424478 | owner pack | flames up the frame's left edge |
| FireWisp (flame, 4x4) | 12656840930 | owner pack | flames up the right edge |
| FireBlast (Clean Flame Blast, 4x4) | 11843575561 | owner pack | flame tongues at the hero's feet |
| FlameSwirl (ring swirl) | 10365549270 | owner pack | sun-breathing ring inside the frame |
| FlameArc (spinning arc) | 4543893907 | owner pack | flame arc round the frame |
| FireRoar / FireLove (4x4), Runes, EnergyCloud | 11534281007 / 16841991986, 2152222413, 10435576555 | owner pack (already used) | corner flames, sun ring, heat glow |
| BloodBlobs (Fire2 blobs, 4x4) | 16843151641 | owner pack, tinted crimson | splash bursts |
| BloodWisp (smoksmok, 4x4) | 16867567145 | owner pack, tinted crimson | flowing wisps |
| BloodCrescent (Flame Burst, 4x4) | 11852978685 | owner pack, tinted crimson | slash spray |
| BloodSpear (SPIKES) | 7451697448 | owner pack, tinted crimson | blood spears |
| BloodRing (circle) | 10372847108 | owner pack, tinted crimson | rings behind and inside the frame |

Removed from the Blood Fiend card: the spinning coins and the star flipbook (to stay inside the flipbook budget and the theme).

Path changes: `StarterStage` / `LimitedStage` -> `StarterFrame` / `LimitedFrame` (viewports inside); `SummonViewport` now
under `StageWell.SummonFrame`; `SummonChance` is a badge (`SummonChanceText` holds only the percentage, plus a static
`SummonChanceCaption`); `<Section>HeaderBadge` / `BadgeIcon` / `<Section>HeaderRule` -> `<Section>HeaderRuleL/R`,
`<Section>HeaderGemL/R`; `PerkIcon` now sits in a `PerkWell`.

Not done / to check in game: the sequence clips on these rigs (RebirthAwaken / RebirthEvolve might move the hero
past the frame; tune `fill` 0.84 in `Store.opened` or swap the beat in `SEQUENCES`), the blood tints over the painting,
the thrust distance of the spears, the drip timing, and the new uploads (they may show blank while in moderation).
The mockup draws the drawn blood darker than the game does.

# UI v5.3 store (owner's review 7) (2026-11-16)

Source: `tools/ui/screens_store_v5.py`; runtime `Ui/Pages/Store.luau`. Gates: `build_ui.py --only Store` 0 project
failures, `fit_gate.py` 0 at all four sizes, `verify_labels.py` 357/357, `tools/gate.py` all PASS. Not yet looked at in Studio.

| # | Change |
|---|---|
| 1 | Featured cards: the Robux price button is 60% of the card (186 px, was 200 px on a narrower gap), centred, 14 px off the bottom. The cards are 12 px taller (420) so the button sits 20 px below the last perk on both cards (`BUY_GAP`, asserted >= 18 in the generator). `BuyGlow` follows the button's size. |
| 2 | Edge effects in FRONT of the glass: `hero_frame(..., rim=)` puts them inside the frame, above the glass fill, pattern and inner glows and below the hero's viewport, clipped by the frame, so they are no longer muted and the hero stays readable. Swordsman: `VfxFireA`-`D` (flames licking up both sides from the bottom corners, a column and a wisp up the edges). Blood Fiend: `VfxBurstL/R`, `VfxWisp`, `VfxSlashSpray`, the top-rim runs `VfxDrip3/4` (moved in from over the hero) and two new runs down the side rims `VfxDrip5/6`. Unchanged: the big glows, rings, sun ring and flame arc behind the frame, the spears (rotated, so they stay outside the clip), the splatters and the bottom drips over the rim, the embers. Flipbook count unchanged. |
| 3 | Summon Scroll: the glass frame round Illusion Overlord is gone (no rim, chase, glass, pattern or glint). `SummonViewport` now sits straight on `StageWell` (168 x 184, square: `showcase(..., rounded=false)`), with his core glow (`VfxCoreGlow`), aura and smoke behind / at his feet. Kept: the throne painting, magic circle, runes, rays, flames, lightning, MYTHIC chip, chance badge, SEE ODDS, name plate. |

Path changes: `StageWell.SummonFrame.SummonViewport` -> `StageWell.SummonViewport`; `VfxAura` / `VfxSmoke` move from
`SummonFrame` to `StageWell`; the blood / fire edge layers move from the card into `StarterFrame` / `LimitedFrame`.

To check in game: the flames' and blood's brightness over the glass (now unmuted; raise their alpha if loud), the
summon hero's viewport edges with no frame (a pose leaving the 168 x 184 box would show a straight crop).

# UI v4.6 (owner's review 7) (2026-11-16)

Screens: `tools/ui/screens_v46.py` (on top of `screens_v44.py`; `build_ui.py` now builds it; only HUD and Reveal
change, built with `--only HUD,Reveal` so the store worker's Store model was not rebuilt). Runtime: `Ui/RevealUi.luau`,
`Controllers/HudController.luau`, `Ui/DevPanel.luau` (rewritten), `Controllers/MenuController.luau` (passes the
DevPanel its tools). Gates: `build_ui.py` 0 project failures, `fit_gate.py` 0 at all four sizes, `verify_labels.py`
357/357, `rojo build` OK, `tools/gate.py` all PASS. Nothing has been looked at in Studio.

| # | Owner's note | Change |
|---|---|---|
| 1 | The reveal's hero info card is too big | `HeroCard.CardPanel` is 410 x 130 (was 640 x 186: 64% wide, 70% tall, 45% of the area; ~615 x 195 px at 1080p). Same content, tighter type: rarity ribbon 28 px / 16 px text on the top edge, name 26 px, one tag row (24 px pills, 14 px text, 18 px stars), income centred (32 px yen icon, 28 px figure), stamp 104 x 26 on the corner, sold line 24 px on the bottom edge. The odds row and divider are gone from the card (item 2). |
| 2 | Bring the "1 in N" back at the top for the final beat | New `FinalOdds` (Reveal, top centre at y 86, under the letterbox bar): `FinalOddsText` (58 px, uppercase "1 IN 2,500") over a wide `Glow` and a turning `Sunburst`, a `ChancePill` "CHANCE" chip under it, two twinkles. `RevealUi.finalOdds(oneInN, colour)` (called by `final`): the letters in the rarity colour with a dark rarity stroke, the glow/burst tinted to the rarity, the number SLAMS in (2.4x -> 1 with an overshoot, 0.32 s), a short shake on impact, the chip pops in, and a white shine band runs through the letters every 2.4 s (a UIGradient on the text, so no box) for as long as the beat holds. Hidden by `clear()`. Also shown for a gifted hero (`HudController:Reveal`) when `oneInN` is set. |
| 3 | The event bar at the top centre blocks the view | `ServerLuckBar` is now a compact 224 x 56 chip at x 1152 (right edge) / y 236, just left of the right button column (clear of the player list zone, the jump zone and every window's close button: fit_gate's hud_close): luck icon, `Multiplier` ("x2 LUCK" / "FESTIVAL") over `TimeLeft`, the Robux `BoostButton` (unchanged handler). The event is told once by the existing announcement bar; the chip waits while it shows, then pops in (UIScale 1.35 -> 1). It is no longer in the toast stack's top-centre list. |
| 4 | The TEST panel must be a proper playtest tool | `DevPanel` rewritten: a 720 x 500 window docked at the right (drag by the red title bar, DOCK puts it back, X closes; F2 / TEST button as before), tabs down the left, 40-44 px buttons with 18 px text, choice chips in rarity / mutation colours, steppers (- value + SEND), a hero picker with search, and a status line ("12:03:41  sent: nextrarity Mythic"). Tabs: Throw & Reveal (nextrarity, nextmut incl. none, nextsize incl. none, luckythrows, Fast reveal), Economy (yen +10K..+1Qa, allfoods, slots 8..24, away 10 min..24 h), Heroes (hero {id, mut, size} over Characters + PremiumCharacters, fuseset of the picked hero, rarityhero, clearcarry), Training & Rebirth (power, gear 1..8, rebirthready, REBIRTH NOW = ProgressAction "rebirth"), Events (festival minutes, luck, throws, say, announce, resetdaily), Store (every product key; pass toggles, green when `state.grantedPasses` has it), UI moments (toasts of each kind, Reward hero/item, LevelUp rank/rebirth, StatTicks, Confirm yen/robux, ZoneCross 1..6, the announcement bar for catch/festival/luck, and the reveal's final beat for any rarity: the new card + top odds, closed after 5 s), World (teleport to my throw pad / my plot / the hub by pivoting the local character onto the ground under the target; Fast reveal / Low detail through `SettingSet`), Danger (wipe after a `HudController:Confirm`). Access unchanged: shown only for `state.studio` / `state.admin`; an owner outside Studio gets only the owner commands (Events: festival, luck, throws, say) plus the client-only tabs; the server still refuses everything else. |

Path changes: `HeroCard...CardOddsRow`, `CardOdds`, `OddsIcon`, `Divider` removed; new `Reveal.FinalOdds.(Glow, Sunburst,
FinalOddsText, ChancePill.ChanceText)`; `ServerLuckBar` children are now `Icon`, `EventText.(Multiplier, TimeLeft)`,
`BoostButton`. `DevPanel.update(state, run, tools?)` takes `{ fire, hud }` (MenuController passes them).

Not done / for the lead: LOOK AT IT IN THE GAME (no Studio here): the slam + shine on the top odds next to the hero at
the final beat (and that nothing of the camera framing sits under y 86..198), the card size over the hero, the chip's
spot beside the right column on a phone, and the DevPanel's drag / tab scroll on touch. The teleports need the target
streamed in (they say "not found" otherwise). The panel's UI-moments previews call the private `HudController:_announce`
for the announcement bar (local only).
