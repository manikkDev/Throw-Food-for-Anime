# Throw Food for Anime: pre-handover matrix (section 5)

Build `s5-04`, place 106586376894468, Studio playtest 2026-11-16 on the owner's account
(RealSwertz). Every row is MEASURED (what was done and what was read back) or UNTESTED.
"Structural" means checked in the place by a probe, not played; it is listed as UNTESTED in play.

## How it was played

One Studio client, driven through the real UI: mouse clicks on the game's own buttons
(`user_mouse_input` on the instance), keys E / F / Space / Backspace, typed text in the code box,
and Roblox's own purchase dialog clicked on screen. Results were read back from the HUD labels,
player attributes, the world (Workspace.Heroes) and the server's replies. Dev commands
(`AdminCommand`, Studio only) were used only to SET UP a state (yen for a slot, rebirth
requirements, fuse copies, zone 1 heroes); every action that followed went through the UI.

## The loop

| step | result |
|---|---|
| fresh profile (wipe) | HUD yen 0, power 10, ROOKIE, Onigiri; objective "Step onto the glowing THROW PAD"; badges hidden except the gift timer |
| walk onto the pad | locked (anchored, meter shown), Hint billboard hidden |
| THROW (button, held 0.9 s) | catch came to the hands (`Carrying` set), player set down off the pad, income +3/s |
| reveal | camera Scriptable for the reveal, back to Custom; HUD back (measured 3 throws: emerald_hero, cursed_vessel Huge, cursed_vessel) |
| walk while carrying | legs move: RightHip swing -4..62 deg over 2.5 s of walking (CarryHold does not mask the walk) |
| place with E at a pedestal | `Carrying` cleared, `Workspace.Heroes.Char_emerald_hero` stands at Plot1.Pedestal1 |
| train (E at Strike Dummy) | player anchored, WalkSpeed 0, TrainingBar on; power rose 23 -> 36 with Space taps |
| exit training (Backspace) | unanchored, WalkSpeed 16, bar off |
| locked station (E at Dumbbell Curls, gear 1) | refused with toast "Dumbbell Curls unlocks with the Sandbag" |
| gear upgrade (F, dialog) | dialog: Sandbag, +1 -> +3, unlocks Dumbbell Curls, TIER 2, 600; at 596 yen shows NEED MORE YEN; bought at 744 -> 214 yen; station unlocked |
| slot (E at the sign, dialog) | Slot 9 for 1.5K; bought (5.27K -> 3.8K), sign now "SLOT 9 -> 10, 5.4K" |
| food shop | Dango bought for 250 and equipped (food chip shows Dango) |
| rebirth x3 (button, page, REBIRTH!) | requirements read 500B/500B and 120M/120M; reset to yen 0 / power 10 / Onigiri / slots 8; cinematic (camera Scriptable 8 s); luck x1.10 after 1, x2.14 after 2 (with passes); Index kept |
| daily reward (gift button routes there first) | CLAIM DAY 1 -> +1.5K yen, "1 DAY STREAK! +1% LUCK", next in 16 h |
| playtime gifts | Gift 1 CLAIM! -> CLAIMED; timers count down for gifts 2-6 |
| Hero Index | zone tabs with live progress (2/9 kept through rebirth); zone 1 filled to 9/9 -> CLAIM! -> CLAIMED, luck x1.12 -> x1.14 |
| Squad: bench | Sorcerer Hunter BENCH: plot 8/8 -> 7/8, bench 0 -> 1, income 461 -> 281/s (120 x 1.5 rebirth) |
| Squad: sell | now asks first (fixed this section), then sold: plot 7/8, row gone |
| Squad: fuse | 3 Cursed Vessels: FUSE -> bench 2 -> 0, star badge on, income +1 -> +2/s |
| Settings | Hide other plots ON (other plots fade) / OFF; music 60%, sfx 80% shown |
| codes | WELCOME -> "Code redeemed!"; again -> "That code is not valid or was already used" |
| Store | opens with live hero showcases; summon odds page lists 6 heroes, TOTAL 100% |
| Robux purchase (test mode) | 1 Lucky Throw: Roblox dialog "This is a test purchase", Buy -> receipt granted, lucky throws x4 -> x5 (PromptProductPurchaseFinished true) |
| data survives rejoin / shutdown | 5 Stop/Play cycles (Stop shuts the server): yen, power, heroes, gear, slots, daily streak, gifts, index all came back |

## Rows

| what | result |
|---|---|
| heroes in play | MEASURED for emerald_hero, cursed_vessel (also Huge and fused), midfield_genius, first_emperor (caught / revealed / carried / placed), and zone 1's other 7 (granted, shown, listed in Squad and Index with portraits). Structural for all 59 (51 lane + 8 premium): template, R15 rig, height and aura resolve. The other 42 lane heroes and the 8 premium heroes are UNTESTED in play this section (the premium ones are seen in the Store showcases: lucky_cat_mascot, sakura_shogun, void_empress) |
| foods | Onigiri thrown; Dango bought and equipped. The other 10 (sushi, spicy_bun, gyoza, ice_cream, takoyaki, ramen, curry, tempura, festival_cake, dragon_feast) structural only: template loads. UNTESTED thrown |
| animations (24 clips) | all 24 load (Length > 0). Seen playing in play: Throw, HeroStalk, HeroPickUp, RevealLand, Eat, CarryHold, PlaceHero, TrainStrike, RebirthAwaken, the store idles. The other training clips (TrainLift, TrainPush, TrainMeditate) UNTESTED this section |
| locomotion | owner's avatar: stand, walk (legs measured), carry-walk (legs measured). Jump and land UNTESTED this section |
| hero auras (20 worn templates) | rebuilt; 7 emitters on moderated textures removed (UltraInstinct 6, FieryRitual 1); all 20 worn templates present. Each aura looked at in play: UNTESTED this section (owner reviewed them in section 4) |
| VFX (27 effects) | the throw / reveal sequence and the rebirth cinematic ran start to end (read from camera and HUD state, not judged frame by frame). Each effect looked at in play: UNTESTED this section (the owner reviewed them in section 4) |
| UI screens open in play with live values | HUD, ThrowMeter, TrainingBar, Confirm (gear, slot, sell), FoodShop, Rebirth, DailyRewards, PlaytimeGifts, HeroIndex, Squad, Settings, Codes, Store, SummonOdds, Leaderboard (avatar headshot loads), SlotSign, PromptLayer cards, Reveal. OfflineEarnings UNTESTED (needs time away) |
| UI pages (verify_ui, fit_gate) | 0 failures on every page; warnings only (sibling gaps of 2-7 px in gift cells, odds rows, pass/product buttons; two wrapper boxes); fit_gate clean at 1280x720, 1345x611, 844x390, 1920x1080 |
| sound roles (78) | all load with TimeLength > 0. HEARD: UNTESTED (nothing in the toolchain can hear) |
| passes (6) and products (17) | created on the universe this section, ids in config. Product receipt MEASURED (Lucky Throw x2). Pass purchase prompt UNTESTED: the owner's account owns every pass it creates, so the pass effects show for the owner (luck x1.96, income doubled) and the prompt cannot be shown to this account |
| two players | UNTESTED. Studio MCP runs one client; the plot ownership, leaderboards with two rows, gifting a pass and the server-luck stack need a second player |
| phones | UNTESTED. verify_ui reports 87 touch targets under 44 px at 844x390 (not gating; needs a phone layout pass) |

## Owner's review of section 5 (rework 1, build `s5-04`), measured in play

| asked | result |
|---|---|
| alerts drawn behind the pages (sell, purchases) | toasts live in their own top layer (`ToastLayer`, DisplayOrder 40, above pages 10-14, Confirm 14, HudFx 15); its canvas copies the HUD canvas's size, position and scale. Measured: "Sold for 30 yen" over the Squad page; with a page open the stack drops to the bottom centre under the window (FoodShop open: anchor 0.5,1 at y 720-10, the page title stays clear); back at the top when the page closes. The same words already on screen are not shown twice (two FUSE refusals -> one toast) |
| the 1-in-N on the hero's head | odds at the top edge (y 14, was 86) and the final shot frames the hero at 46% of the frame (was 50%). Measured on a Legendary: "1 IN 316" at the top, clear gap above the head, card under the feet |
| flashier by rarity | `RevealUi.finalOdds(oneInN, color, rarity)`: size 0.80 (Common) .. 1.26 (Secret), slam from 1.7x .. 3.2x, shake 3 .. 13 px, outline 3 .. 6, a breathing pulse from Rare, sparkles from Rare, a flash in the rarity colour from Epic, letters: white shine through the rarity colour up to Epic, flowing gold (Legendary, Premium), the Mythic palette, a full rainbow with a glitch (Secret); glow and sunburst at the rarity's own UiFx pace. Seen in play: Legendary. Common, Rare, Epic, Mythic and Secret UNTESTED on screen this rework |
| active buffs too big, want a corner, minimisable | `BuffTray` under the settings gear: a BOOSTS header with a count; tap to open or fold; rows hang left of the right column (server luck x2 14:56, Festival Hour 4:57, lucky throws 10 left measured). A new boost opens it for 5 s, then it folds by itself (measured). Timed 2x Yen row UNTESTED (no timed 2x Yen was active) |
| Daily Rewards UI gone | DAILY button (new calendar icon `IconDailyBig`) in the right column: Store, Daily, Gifts, Rebirth; "!" while today's reward waits; key 6. Measured: opens Daily Rewards (TOMORROW, streak 1, next in 12 h). The Gifts button no longer routes to it |
| could throw while carrying | refused on both ends: the client does not lock onto the pad or arm the meter, the server refuses the pad and a throw request (`ThrowService`), one toast "Place your hero on a pedestal first!". Measured: walked onto the pad carrying -> not anchored, no meter; a direct ThrowRequest -> refused, carry unchanged. Training is refused the same way (measured: E at Strike Dummy while carrying -> no training, the toast) |
| what if the plot is full | a catch that does not beat the weakest hero is saved on the bench and still comes to the hands; when the reveal ends: "Plot full! Swap it onto a pedestal with E, or it waits on your bench"; every pedestal offers "Swap here (replaces X)". Measured on a 10/10 plot: Common catch -> bench -> toast; Swap at Pedestal 4 -> the catch stands there, the displaced Freedom Seeker is off the plot (plot still 10/10, bench read 4/60 after the swap). A catch stronger than the weakest swaps by itself (Squad.placement); bench full too -> the weakest is sold and the card says "sold for ..." (spec-tested, not played) |
| console errors | 12026515010 / 12867093437 (moderated): gone from play (aura builder drops them) and from Studio load (the 76 emitters in the owner's `ServerStorage.ImportedVfx` archive keep their id in a `ModeratedTexture` attribute, texture blank; nothing deleted). 82901655376528 (planks) and 81858128734855 (aurora band VFX): both load (`PreloadAsync` Success); the "No asset content representation" line is Studio asking for an extra version that does not exist. 203785492 and "Unable to load plugin icon": not in the game (every content property of every instance scanned): a Studio plugin or Roblox's own UI |

Also found and fixed in this rework: Roblox's own player list is turned off (the game has world leaderboards and no leaderstats; its corner is the HUD's: settings, boosts, the right column, which now starts at y 140 to stay clear of the jump button); `verify_ui` learned a per-screen opt-out for it (toolkit commit 9d135d0).

Test-tool notes (not game defects): Studio MCP's `execute_luau` resets a Scriptable camera to Custom if a call yields during the reveal (it cut reveals short until the waits moved to the input tool); a teleported character is only seen by the server once it is unanchored and moves, and a prompt only arms when the character walks into its range.

## Defects found and fixed this section

1. The gear and slot dialogs stayed on NEED MORE YEN after income passed the price. The dialog now
   re-checks while open (`Moments.confirm` `affordCheck`); measured: 5K yen arrived and the button
   turned to BUY SLOT.
2. SELL removed a hero in one click (a misclick could cost a Legendary). It now opens a red
   confirmation with the hero, what it sells for and the income lost (`Pages/Squad.luau`).
3. Rebirth left a wiped hero in the player's hands until the 150 s timeout. The carry is now
   dropped when the rebirth took the hero (`ProgressService:Rebirth`); measured after rebirth 3.
4. Seven aura emitters used two textures Roblox has moderated, logging "Asset is not approved"
   on every server and client. `build_auras.luau` now drops the moderated ids (also on emitters
   copied straight off a body part) and the templates were rebuilt; the console is clean of them.
5. Store purchases had no product ids (all 0). The passes and products were created on the
   universe with `tools/mint_monetization.py` and the ids written into config.

## Known and not fixed

- `rbxassetid://203785492` "Asset type does not match requested type" three times per client.
  It is not anywhere in the game's tree (Workspace, ReplicatedStorage, ServerStorage, StarterGui,
  StarterPlayer, Players, PlayerGui, Lighting, SoundService, Chat) nor in the tester's avatar
  description. No visible effect.
- The owner's account owns every pass, so the owner always plays with all six pass effects.
  Test pass-free play on another account (or in the two-player test).
