# 05 UI and UX

Inventory of screens and elements: `design/ui.json`. Built with `roblox-ui` (one resolved tree ->
mockup PNG + `.model.json` + Luau), checked with `verify_ui.py`. Our own look; nothing is copied
from the reference game's screens.

## 1. Style: "Manga Pop"

- **Panels:** deep indigo `#1B1F4B`, 4 px white keyline, 6 px offset comic shadow in ink
  `#0D0F2B`, 18 px corner radius.
- **Headers:** tilted ribbon (-2 degrees), coral `#FF5A5F` to yellow `#FFC93C` gradient,
  halftone-dot overlay, title in Luckiest Guy, white with a 3 px ink stroke.
- **Buttons:** chunky, 2-tone with a darker bottom lip; green confirm, yellow buy-with-yen,
  pink premium (Robux), blue info, red close/sell. Press = scale 0.94 + lip collapse, 80 ms.
- **Numbers:** Fredoka One with ink stroke; yen green-gold, power electric blue, luck clover green.
- **Rarity** colours from `config.Rarities[].Color` on every tile border, banner and pedestal.
- **Motion:** panels open with scale 0.85 -> 1 + fade, 180 ms, back-out easing; counters roll;
  new items pop with a star burst; the HUD yen counter bumps on each tick over 1% of balance.
- **Sound:** every button has ui_click; open/close have their own.

## 2. HUD (always on)

Bottom-left: Yen and income/s, Power with rank name. Top-centre: TutorialHint line (retires
after onboarding), ServerLuckBar when active, Announcement banner slot. Left column: Shop
(food), Squad, Index. Right column: Store (Robux), Gift (playtime/daily, with a timer badge),
Rebirth (appears once tier 1 is within 25%), Settings (small). Bottom-centre on the throw pad:
ThrowMeter. Bottom-right: FoodChip (equipped food, tap to open FoodShop). All inside the
device safe area; nothing under the jump button or the chat on mobile.

## 3. Screens

| Screen | Purpose | Key behaviour |
|---|---|---|
| ThrowMeter | charge and release | bar fills over ChargeSeconds; marks for each unlocked zone with its key colour; perfect window glows; label "lands in: <zone>"; lucky-throw toggle with count |
| Reveal | the catch | not a blocking modal: a card over the world while the camera is at the landing spot; OneInN, NEW, NEW BEST stamps; tap anywhere skips |
| FoodShop | buy/equip | 12 cards in a horizontal scroller; 3D food spins in a viewport; flavour icon; shows which undiscovered heroes crave it ("3 new heroes love this") |
| Squad | manage heroes | plot list and bench list; row actions; Equip Best; fuse appears when three match; auto-sell toggles |
| HeroIndex | collection | zone tabs with progress; undiscovered = silhouette; tile shows craving and the chance at current luck; zone reward claim |
| Store | Robux | passes, products, starter pack once, summon banner with an ODDS button that opens SummonOdds before any purchase |
| OfflineEarnings | return | time away, amount, Claim / 2x |
| Rebirth | prestige | requirements with progress bars, what you keep and lose, reward |
| DailyRewards, PlaytimeGifts, Codes, Settings | meta | simple grids |
| TrainingBar | training | rank progress, power per rep, Stop; "new gear" prompt when affordable |
| Nameplate | over each hero | name, tags (TITAN, GOLDEN), yen/s, stars; hidden beyond 60 studs |
| Leaderboards | hub boards | three SurfaceGuis, top 10, refresh each minute |
| Toasts, Announcement | notices | toasts stack bottom-centre; announcement slides from the top for Legendary and better |

## 4. Rules the build is checked against

1. Siblings never touch (8 px minimum at 1280 x 720). Deliberate overlaps are marked `overhang`.
2. Centred means measured: anchor 0.5 with position 0.5.
3. No opaque frame that only wraps one child.
4. Touch targets at least 56 px. Text never below 14 px at 720p.
5. Every dynamic label ships as `<unbound>` with `samples` (longest strings: "999.99Qi",
   "Crimson Oni General", "1 in 48,400,000"), and a gate fails if any label still shows a
   placeholder in play.
6. Every screen is opened in play at phone and desktop sizes before section 3 closes.
7. Nothing opens by itself over the throw: nudges ("you can afford Dango") are badges on HUD
   buttons, not popups.

## 5. Icons

`ui.json` icons: 18 system icons + 12 food icons. Food icons are renders of the food meshes.
System icons: Kenney Game Icons (CC0) restyled with the keyline and shadow, or generated with the
UI skill's icon tool when no CC0 icon fits; all uploaded as Images and referenced by id.

## 6. Input

| Action | Touch | Mouse/keyboard | Gamepad |
|---|---|---|---|
| Throw | hold and release the big THROW button | hold and release LMB or Space | hold and release R2 |
| Train / Stop | button | E / button | X |
| Open screens | HUD buttons | 1 to 5, Tab closes | D-pad |
| Skip reveal | tap | click | A |
