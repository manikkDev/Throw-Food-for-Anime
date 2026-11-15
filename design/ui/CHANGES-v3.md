# UI v3: what changed for the client

Built by `python tools/ui/build_ui.py` (screens: `tools/ui/screens_v3.py`, system: `tools/ui/mp3.py`).
Full path diff against v2: `work/ui/bindings_v3_diff.txt` (62 removed, 100 added). Every instance NAME the client
binds is unchanged, and `verify_labels.py` passes (214/214). Only these PARENTS moved:

## Path changes (old -> new)

| Screen | Old | New |
|---|---|---|
| Store | `Window.Body.StarterPackBanner` (+ all children) | `Window.Body.StoreScroll.StarterPackBanner` |
| Store | `Window.Body.PassScroller` | `Window.Body.StoreScroll.PassScroller` (now a Frame with UIGridLayout + AutomaticSize Y, not a ScrollingFrame) |
| Store | `Window.Body.ProductScroller` | `Window.Body.StoreScroll.ProductScroller` (same: Frame grid, AutomaticSize Y) |
| Store | `Window.Body.PassesTitle`, `ItemsTitle` | `Window.Body.StoreScroll.PassesTitle`, `.ItemsTitle` |
| Store | `SummonBuy10.BestValueSticker` | `SummonBanner.BestValueSticker` (sits on the x10 button's top border) |
| Store | `SummonBuyN.Count`, `SummonBuyN.PriceRow.Price` | unchanged names; all three are now L (56 px) two-line buttons |
| FoodShop | `FoodCard.Viewport` | `FoodCard.ArtTile.Viewport` (transparent ViewportFrame over a flavour tile + `Sunburst`) |
| FoodShop | `FoodCard.CraveHint` | `FoodCard.CravePill.CraveHint` (text now "+11 heroes") |
| FoodShop | `FoodScroller` | same name, now VERTICAL grid (4 columns, UIGridLayout), not a horizontal list |
| ThrowMeter | `LuckyThrowToggle.Text.LuckyCount`, `.Icon` | `LuckyThrowToggle.PriceRow.LuckyCount`, `.PriceRow.Icon` (`Title` stays) |
| ThrowMeter | `AutoToggle.Text.AutoState`, `.Icon` | `AutoToggle.PriceRow.AutoState`, `.PriceRow.Icon` |
| HUD | `BtnSettings` at top-left | same path; moved to the top-right corner (x 950), visible gear `GearFace` 44 px, hit 56 px |
| HUD | `TutorialHint.ObjectiveLine` | same path; the pill now has AutomaticSize X (TextSize 16, TextScaled off), capped at 768 px |

## Client tasks

1. **Button states are colours on the SAME instance** (the face carries a neutral gloss gradient, so any
   `BackgroundColor3` you write keeps the gloss). Write on the named instance (self-faced buttons) or on its
   `Face` child (cards/rows):
   - afford / free: confirm green `#48D687`; neutral (EQUIP, BENCH, tabs selected): info `#4CC4F9`;
     Robux: premium `#FF61AC`; destructive (SELL): danger `#F2574C`.
   - cannot afford (yen): slate `#5C6286` and the caption `TextColor3` soft red `#FF8A8A`.
   - a STATE (EQUIPPED, CLAIMED, OWNED): state grey `#5C628F`, set `Active = false`, set the `Icon` child's
     IconKey to `IconTick`. In the samples these ship as flat pills; the templates ship the button.
   - Every button has attribute `PressLip` (3/4/5 px): on press, move the face down by it and shrink the lip.
2. **FoodShop:** tint `ArtTile.BackgroundColor3` from the food's flavour (one tile, client-tinted):
   Savory `#F2A541`, Sweet `#FF8CC6`, Spicy `#FF6A3D`, Seafood `#2EC4B6`. The first food the player does not own:
   `NextTag.Visible = true` and the card's `Face.Stroke.Color` gold `#FFC93C`; foods after it: card `Face`
   colour `#D9CFBA` (dimmed).
3. **HeroIndex:** an unknown hero: tile `Face` colour `#23264F`, `Portrait.UnknownMark.Visible = true`,
   `UnknownMark.TextColor3` = rarity colour. Locked zone: `ZoneTabN.LockIcon.Visible = true`. Zone tabs live in a
   vertical ScrollingFrame (`ZoneTabs`): a seventh zone scrolls.
4. **Store:** `PassScroller` / `ProductScroller` are grids that grow (AutomaticSize Y) inside `StoreScroll`;
   clone the templates into them as before. `Sticker.StickerText` is bound: set "BEST VALUE" / "NEW" / "LIMITED"
   and `Sticker.Visible`.
5. **Touch (coordinator rule: 44 px physical at 844x390).** The desktop S/M/L classes cannot reach it by scale:
   at 844x390 the canvas scale is 0.5417, so 44 px physical = 81 px at the reference. On touch, apply a UIScale
   named `TouchScale` to each page's `Window` with factor
   `F = max(1, min(0.94 * vw / (W * s), 0.90 * vh / (H * s)))`, where `s = min(vw/1280, vh/720)` and W,H are the
   window's reference size (it fills up to 94% x 90% of the phone). That gives about 1.3 to 1.9 on 844x390 and still
   leaves 82 controls under 44 px (`fit_gate.py` touch_phone report lists them): the remainder needs the phone
   layout pass (fewer columns, taller rows), not done in v3.

## Icons to upload (then regenerate `Icons.luau`)

- **New keys, large glossy family** (`assets/ui/icons_big/`, 256 px, same post-process: ink outline 5% + white
  keyline): `IconShopBig IconSquadBig IconIndexBig IconStoreBig IconGiftBig IconRebirthBig IconSettingsBig
  IconYenBig IconCrownBig IconLuckBig IconLuckyThrowBig IconScrollBig IconBenchBig IconCodesBig IconFuseBig
  IconLockBig IconPlaceBig IconPowerBig IconTimerBig IconSellBig IconFlavorSweetBig IconFlavorSpicyBig
  IconFlavorSeafoodBig IconTrainBig` (= the dumbbell) and three that failed generation twice and are the flat
  glyph scaled up: `IconAutoBig IconFlavorSavoryBig IconThrowBig`.
- **New key:** `FxSunburst` (`assets/ui/icons/FxSunburst.png`, white, alpha baked at 30%).
- **Re-upload so the base keys are the FLAT glyphs again** (v2 had pointed them at the glossy files):
  every key in `assets/ui/icons/` that also has a file in `assets/ui/icons_v2/` (Shop, Squad, Index, Store, Gift,
  Settings, Yen, Power, Luck, LuckyThrow, Auto, Bench, Fuse, Lock, Timer, Crown, Scroll, FlavorSweet, FlavorSpicy,
  FlavorSeafood), and `IconPower`, which is now the dumbbell glyph (power and training share it everywhere).
- Rule: under 30 px use the base key (flat glyph); 40 px and up use the `...Big` key. The trees already do this.

## v3.1 fix round (play test s3-v3-01): client actions only

Path diff against v3: `work/ui/bindings_v31_diff.txt` (47 paths moved, no names changed).

| Screen | Old | New | Client must |
|---|---|---|---|
| HUD | `LeftColumn.BtnShop` (and Squad, Index, Store, Gifts, Rebirth) | `LeftColumn.BtnShopCell.BtnShop`, `RightColumn.BtnStoreCell.BtnStore`, ... | find buttons by name (recursive); each `<Btn>Cell` holds the button and its `Caption` row |
| HUD | `BtnGift.GiftTimerBadgeCell.GiftTimerBadge.GiftTimer` | `RightColumn.BtnGiftCell.GiftTimerBadgeCell.GiftTimerBadge.GiftTimer` | while a timer or READY shows: `GiftTimerBadgeCell.Visible = true` and `BtnGiftCell.Caption.Visible = false`; otherwise the reverse (same rectangle, ships with the caption showing) |
| HUD | `TutorialHintCell.TutorialHint.ObjectiveLine` | `TutorialHint.ObjectiveLine` (one Frame, AutomaticSize X, capped 768 px) | nothing: write the text, the pill sizes itself |
| HUD | `BtnSettings` at x 950 | same path, pinned to the top-right corner (`Position = (1,-20,0,12)`, AnchorPoint (1,0)) | nothing |
| HUD | `ServerLuckBar` top-right, `NoticeCard` at y 58 | `ServerLuckBar` top centre under the hint (y 58), `NoticeCard` at y 106 | nothing (the pill sat on five windows' close buttons) |
| Squad | `Row.PlaceButton`, `.FuseButton`, `.SellButton`, `.IncomeBlock` | `Row.Actions.PlaceButton` / `.FuseButton` / `.SellButton` / `.IncomeBlock` (right-aligned, SELL last) | find by name; hiding `FuseButton` no longer leaves a gap |
| OfflineEarnings | `DoubleButton.DoublePrice` = "2X  39" | `DoubleButton.Label` = "2X" (static), `DoubleButton.Icon`, `DoubleButton.DoublePrice` = the price only | write ONLY the Robux price ("39") to `DoublePrice` |

## v3.2 (owner: spacing, horizontal food row, legible HUD): client actions only

Path diff against v3.1: `work/ui/bindings_v32_diff.txt` (3 paths moved, no names changed).

| Screen | Old | New | Client must |
|---|---|---|---|
| FoodShop | `FoodScroller` vertical grid | `FoodScroller` ONE horizontal row (ScrollingDirection X, UIListLayout padding 14, 12 px canvas padding, 8 px bar in its own gutter). Cards 208 x 368, attribute `WheelScrollsX = true` on the scroller | make the mouse wheel scroll this row SIDEWAYS (Roblox scrolls Y by default): while the pointer is over `FoodScroller`, add the wheel delta to `CanvasPosition.X`. Clone cards into it as before (UIListLayout, not a grid) |
| FoodShop | `PowerText` "x1.15", `LuckText` "x1.1" | same paths; the chips are now full width and stacked | write `"POWER x" .. v` and `"LUCK x" .. v` |
| HUD | `RightColumn.BtnGiftCell.GiftTimerBadgeCell...` and `BtnGiftCell.Caption` | `RightColumn.BtnGiftCell.BtnGift.GiftTimerBadgeCell.GiftTimerBadge.GiftTimer` and `BtnGift.Caption` (the caption is now a band INSIDE each side button) | while a timer / READY shows: `GiftTimerBadgeCell.Visible = true`, `BtnGift.Caption.Visible = false`; otherwise the reverse |
| HUD | `PowerCounter.RankName` | `PowerCounter.RankChip.RankName` | nothing beyond finding it by name |
| HUD | stats as loose icon + text | `PowerCounter`, `YenCounter`, `LuckChip` are three equal pills (280 x 36) at x 28, y 452 / 496 / 540; `FoodChip` is one 200 x 44 pill at y 400 | nothing: texts are written to the same names |

## v3.3 (owner: buttons apart, simple stats, compact training): client actions only

Path diff against v3.2: `work/ui/bindings_v33_diff.txt` (2 paths moved, no names changed).

| Screen | Old | New | Client must |
|---|---|---|---|
| ALL | a button / panel painted its 4 px stroke and its lip OUTSIDE its box | the face is inset inside the box (stroke all round, lip below, comic offset right); `Face` / the self-faced button is `Size (1,-8,1,-8-lip)`, `Position (0,4,0,4)` | if code sets a face's Size or Position, keep that inset; recolouring is unchanged |
| HUD | `PowerCounter.RankChip.RankName` | `PowerCounter.RankName` (plain 14 px line under the value, no chip) | nothing beyond finding it by name |
| HUD | `FoodChip` = a 200 x 44 pill button with `FoodChip.Icon` | `FoodChip` = a transparent TextButton (230 x 48, `OpensPage = FoodShop`): `FoodChip.FoodRing.Icon` (round 48 px ring), `FoodChip.FoodName`, `FoodChip.FlavorRow` | set the food picture on `FoodChip.FoodRing.Icon`; bind `FoodChip.Activated` as before |
| HUD | stat pills | `PowerCounter` / `YenCounter` / `LuckChip` are plain rows (no background): 44 px icon box, value at x 54 (28 px), sub-line under it (14 px) | nothing: same names |
| TrainingBar | 660 x 172 panel + 500 px NEW GEAR bar | `TrainingPanel` 440 x 86 bottom centre (16 px up); `UpgradePrompt` an S button (max 300 wide) sitting on the panel's top edge | nothing: same names |
