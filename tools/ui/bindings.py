"""Generate design/ui/BINDINGS.md from the shipped trees (src/ui/*.model.json).

    python tools/ui/bindings.py

Names, paths, classes and IconKeys are read from the .model.json files, so the list
cannot drift from what ships. Samples come from the spec of the same screen. The
one hand-written part is DESC (what a label shows / what a button does), keyed by
name; a name missing from DESC is printed as "?" so the gap is visible.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "src" / "ui"
SPEC = ROOT / "design" / "ui"
SKIP = {"Face", "Content", "CanvasFrame"}

DESC = {
    # labels
    "YenAmount": "yen balance", "IncomePerSecond": "income per second", "PowerAmount": "power",
    "RankName": "rank name", "LuckAmount": "current luck multiplier", "FoodName": "equipped / card food name",
    "FoodFlavor": "equipped food flavour", "ObjectiveLine": "tutorial objective (hide panel when empty)",
    "Multiplier": "server luck or festival multiplier", "TimeLeft": "time left on server luck / festival",
    "PlayerName": "player name", "HeroName": "hero name (??? when undiscovered)",
    "RarityText": "rarity name", "OneInN": "Format.oneIn of the catch", "FlashText": "PERFECT! / LUCKY THROW! flash",
    "Text": "toast message", "GiftTimer": "time to next playtime gift or READY!",
    "ZonePreviewLabel": "'Lands in: <zone>' while charging, idle hint otherwise", "LuckyCount": "lucky throws owned",
    "AutoState": "ON / OFF", "SizeText": "size tag (TITAN/HUGE/BIG)", "MutationText": "mutation tag",
    "YenPerSecond": "hero income per second", "RevealAction": "joins plot / bench / sold for N",
    "TierText": "food tier", "PowerText": "food power multiplier", "LuckText": "food luck multiplier",
    "CraveHint": "undiscovered heroes that crave this flavour", "PriceText": "price / EQUIP / EQUIPPED",
    "SlotCount": "plot used/slots", "BenchCount": "bench used/slots", "IncomeText": "hero income per second",
    "LocationText": "ON PLOT n / ON BENCH", "PlaceText": "PLACE (bench hero) / BENCH (plot hero)",
    "ZoneProgress": "found/total in zone", "ZoneTitle": "selected zone name", "TotalText": "index total found",
    "LuckNote": "luck the chances are computed at", "ClaimText": "claim button state text",
    "ChanceText": "chance at current luck and food", "GiftTargetText": "gift recipient or GIFT A FRIEND",
    "StarterPrice": "starter pack Robux price / OWNED", "PassName": "pass display name",
    "PassPrice": "pass Robux price / OWNED", "ProductName": "product display name", "ProductPrice": "Robux price",
    "AwayTime": "time away", "EarnedAmount": "offline yen earned", "DoublePrice": "OfflineDouble Robux price",
    "NextTier": "next rebirth tier", "PowerReqText": "power / required", "YenReqText": "yen / cost",
    "RewardIncome": "income bonus of next tier", "RewardLuck": "luck bonus of next tier",
    "CurrentRebirth": "current rebirth count", "StreakLabel": "daily streak", "RewardText": "day reward",
    "NextIn": "time to next daily", "Timer": "session play time today", "GiftState": "CLAIM! / timer / CLAIMED",
    "ResultLabel": "code redeem result", "MusicValue": "music volume %", "SfxValue": "sfx volume %",
    "FastRevealState": "ON / OFF", "LowDetailState": "ON / OFF", "HideOtherPlotsState": "ON / OFF",
    "UpgradeText": "next affordable gear and price", "GearName": "current training gear",
    "ProgressText": "power / next rank power -> next rank", "PowerPerRep": "power gained per rep",
    "BoardTitle": "board title (MOST YEN / MOST CAUGHT / RAREST CATCH)", "RankText": "leaderboard rank",
    "Score": "leaderboard value", "FromTo": "slot n -> n+1", "Price": "next slot price",
    "BuyPrompt": "buy hint / not enough yen",
    # buttons
    "BtnShop": "open FoodShop (badge: affordable food)", "BtnSquad": "open Squad", "BtnIndex": "open HeroIndex (badge: zone claim)",
    "BtnSettings": "open Settings", "BtnStore": "open Store", "BtnGift": "open PlaytimeGifts (badge: reward ready)",
    "BtnRebirth": "open Rebirth (badge: can rebirth)", "FoodChip": "open FoodShop", "BoostButton": "buy ServerLuck product",
    "ThrowButton": "hold to charge, release to throw", "LuckyThrowToggle": "toggle lucky throw (recolour face)",
    "AutoToggle": "toggle Auto Throw pass", "CloseButton": "close page (ClosesPage attr)",
    "FilterAll": "flavour filter: all", "FilterSavory": "flavour filter", "FilterSweet": "flavour filter",
    "FilterSpicy": "flavour filter", "FilterSeafood": "flavour filter",
    "BuyButton": "ShopBuy food / FoodEquip (recolour face by state)", "TabPlot": "show plot heroes", "TabBench": "show bench heroes",
    "AutoSellCommon": "SettingSet autoSellCommon", "AutoSellUncommon": "SettingSet autoSellUncommon",
    "EquipBest": "SquadAction equipBest", "PlaceButton": "SquadAction place / bench", "FuseButton": "SquadAction fuse (hide unless fusable)",
    "SellButton": "SquadAction sell", "ZoneRewardClaim": "ProgressAction claimZone",
    "GiftTarget": "pick a gift recipient", "OddsButton": "open SummonOdds (no purchase)",
    "SummonBuy1": "prompt SummonScroll1", "SummonBuy3": "prompt SummonScroll3", "SummonBuy10": "prompt SummonScroll10",
    "StarterBuyButton": "prompt StarterPack", "PassBuyButton": "prompt the card's pass (PassKey attr)",
    "ProductBuyButton": "prompt the card's product (ProductKey attr)", "OddsBuy1": "prompt SummonScroll1",
    "OddsBuy3": "prompt SummonScroll3", "OddsBuy10": "prompt SummonScroll10", "ClaimButton": "RewardClaim (offline / daily)",
    "DoubleButton": "prompt OfflineDouble", "ConfirmButton": "ProgressAction rebirth", "GiftButton": "RewardClaim gift i",
    "RedeemButton": "RewardClaim code with CodeBox.Text", "MusicKnob": "drag music volume", "SfxKnob": "drag sfx volume",
    "FastReveal": "SettingSet fastReveal", "LowDetail": "SettingSet lowDetail", "HideOtherPlots": "SettingSet hideOthers",
    "BonusLabel": "bonus riding beside the marker (+12)", "IncomeLabel": "hero income per second (+24/s)",
    "LuckLabel": "luck multiplier during the flight", "NameLabel": "hero name spelling itself out from underscores",
    "NoticeBody": "notice detail line", "NoticeButton": "notice action (open shop / buy gear)",
    "NoticeButtonText": "notice action caption", "NoticeClose": "dismiss the notice", "NoticeTitle": "notice title",
    "OddsLabel": "1 in N counter (climbs, then lands)", "SoldLabel": "sold for N / sent to bench",
    "StampLabel": "LUCKY! / NEW! / NEW BEST!", "StickerText": "store sticker (BEST VALUE / NEW / LIMITED)",
    "ThrowButtonFace": "visible THROW button (same action as ThrowButton)",
    "ThrowButton": "transparent tap target over the lower two thirds: hold to charge, release to throw",
    "VariantLabel": "mutation and size, small caps", "ZoneBannerText": "zone the food is flying over",
    "CodesButton": "open Codes", "CodeBox": "TextBox: the code the player types (input)",
    **{f"ZoneTab{i}": f"select zone {i} in the index (recolour face when active; LockIcon when locked)" for i in range(1, 7)}, "StopButton": "stop training", "UpgradePrompt": "buy the next gear",
}
NAMED = {"MeterBar", "PerfectBand", "MeterMarker", "ZoneBands", "LetterboxTop", "LetterboxBottom", "FlashFrame",
         "NoticeCard", "ZoneBanner", "RarityRibbon", "OddsBurst", "RarityStripe", "TutorialHint", "ServerLuckBar",
         "Announcement", "GiftTimerBadge", "Badge", "Window", "Scrim",
         "ArtTile", "Sunburst", "NextTag", "CravePill", "StoreScroll", "UnknownMark", "GearFace",
         "BestValueSticker", "LimitedSticker", "NewSticker", "Sticker"}
TEMPLATE_OF = {"ZoneBands": "ZoneMarkTemplate (one tick per zone at its height; tag ZoneMarkName)", "FoodScroller": "FoodCardTemplate", "HeroList": "HeroRowTemplate", "HeroGrid": "HeroTileTemplate",
               "PassScroller": "PassCardTemplate", "ProductScroller": "ProductCardTemplate",
               "Toasts": "ToastTemplate", "ZoneMarks": "ZoneMarkTemplate", "DayStrip": "DailyCellTemplate (fixed DayCell1..7 shipped)",
               "GiftGrid": "GiftCellTemplate (fixed GiftCell1..6 shipped)", "OddsList": "OddsRowTemplate (fixed OddsRow1..6 shipped)",
               "Rows": "LeaderboardRowTemplate (fixed Row1..10 shipped)"}


def spec_samples(spec):
    out = {}

    def walk(n, chain):
        nm = n.get("name")
        ch = chain + [nm] if nm else chain
        if n.get("text") == "<unbound>":
            out.setdefault(tuple(ch[-2:]), n.get("samples", []))
            out.setdefault((nm,), n.get("samples", []))
        for c in n.get("children") or []:
            walk(c, ch)
    for c in spec["children"]:
        walk(c, [])
    return out


def clean(path):
    p = [x for x in path if x and x not in SKIP]
    return [x for i, x in enumerate(p) if not (x.endswith("Cell") and i + 1 < len(p) and p[i + 1] == x[:-4])]


def collect(model):
    labels, buttons, lists, icons, named = [], [], [], [], []

    def walk(n, path):
        nm = n.get("name", "")
        p = path + [nm]
        props, attrs, cls = n.get("properties", {}), n.get("attributes", {}), n.get("className")
        cp = clean(p)
        if props.get("Text") == "<unbound>":
            labels.append((cp, cls))
        if cls in ("TextButton", "ImageButton", "TextBox"):
            buttons.append((cp, attrs))
        if nm in TEMPLATE_OF and cls in ("Frame", "ScrollingFrame"):
            lists.append((cp, cls))
        if nm in NAMED:
            named.append((cp, cls))
        if "IconKey" in attrs:
            icons.append((cp, attrs["IconKey"]))
        for c in n.get("children", []):
            walk(c, p)
    for c in model.get("children", []):
        walk(c, [])
    return labels, buttons, lists, icons, named


def section(title, root_cls, model, spec, md):
    labels, buttons, lists, icons, named = collect(model)
    samples = spec_samples(spec) if spec else {}
    md.append(f"\n## {title}\n\nRoot: `{title}` ({root_cls}), file `src/ui/{'Templates/' if root_cls != 'ScreenGui' and spec is None else ''}{title}.model.json`\n")
    if labels:
        md.append("\n**Dynamic labels** (ship `<unbound>`)\n\n| Path | Shows | Samples |\n|---|---|---|")
        for cp, _ in labels:
            s = samples.get(tuple(cp[-2:])) or samples.get((cp[-1],)) or []
            md.append(f"| `{'.'.join(cp)}` | {DESC.get(cp[-1], '?')} | {' / '.join(s)} |")
    if buttons:
        md.append("\n**Buttons**\n\n| Path | Does | Attributes |\n|---|---|---|")
        for cp, attrs in buttons:
            a = ", ".join(f"{k}={v}" for k, v in attrs.items() if k in ("OpensPage", "ClosesPage"))
            md.append(f"| `{'.'.join(cp)}` | {DESC.get(cp[-1], '?')} | {a} |")
    if lists:
        md.append("\n**List containers**\n\n| Path | Class | Filled from |\n|---|---|---|")
        for cp, cls in lists:
            md.append(f"| `{'.'.join(cp)}` | {cls} | `ReplicatedStorage.Ui.Templates.{TEMPLATE_OF[cp[-1]]}` |")
    if named:
        md.append("\n**Other named instances** (shown, hidden, tweened or recoloured by code)\n\n| Path | Class |\n|---|---|")
        for cp, cls in named:
            md.append(f"| `{'.'.join(cp)}` | {cls} |")
    if icons:
        md.append("\n**IconKey slots** (ImageLabel, Image empty)\n\n| Path | IconKey |\n|---|---|")
        for cp, k in icons:
            md.append(f"| `{'.'.join(cp)}` | {k} |")


def main():
    md = ["# UI bindings (GENERATED by tools/ui/bindings.py from src/ui/*.model.json; do not edit)",
          "",
          "All screens mount at `ReplicatedStorage.Ui.<Screen>`; templates at `ReplicatedStorage.Ui.Templates`.",
          "Paths are relative to the screen root and skip the decorative `CanvasFrame`, `Face` and `Content`",
          "frames and the `<Name>Cell` wrapper of self-faced controls, so use `FindFirstChild(name, true)` on the",
          "screen (or on a row) rather than exact parent chains. `<X>SampleN` children of lists ship Visible=false",
          "with attribute `Sample=true`: destroy them, then clone the template. Paintable controls: write",
          "`BackgroundColor3` on the named instance (toggles, chips, ribbons) or on its `Face` child (cards,",
          "tiles, rows, toasts). Viewport slots are `ViewportFrame`s named Viewport / Thumb / Portrait / SummonViewport.",
          "Page ScreenGuis carry `OpenStyle/OpenFrom/OpenTime`; buttons carry `HoverScale/PressScale` and",
          "`OpensPage`/`ClosesPage` for the skill's UIController. Each ScreenGui's `CanvasFrame` is 1280x720",
          "offset with a `Scale` UIScale: set `Scale.Scale = min(vw/1280, vh/720)` on ViewportSize change."]
    for f in sorted(UI.glob("*.model.json")):
        name = f.name.removesuffix(".model.json")
        model = json.loads(f.read_text())
        sp = SPEC / f"{name}.json"
        section(name, model["className"], model, json.loads(sp.read_text()) if sp.exists() else None, md)
    md.append("\n# Templates")
    for f in sorted((UI / "Templates").glob("*.model.json")):
        name = f.name.removesuffix(".model.json")
        model = json.loads(f.read_text())
        sp = SPEC / "templates" / f"{name}.json"
        section(name, model["className"], {"children": model.get("children", [])},
                json.loads(sp.read_text()) if sp.exists() else None, md)
    out = SPEC / "BINDINGS.md"
    out.write_text("\n".join(md) + "\n", encoding="utf-8")
    missing = sorted({ln.split("`")[1].split(".")[-1] for ln in md if "| ? |" in ln})
    print(f"wrote {out}; names without a description: {missing}")


if __name__ == "__main__":
    main()
