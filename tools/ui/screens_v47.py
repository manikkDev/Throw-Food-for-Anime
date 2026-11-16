"""UI v4.7 (owner's review of section 5): the screens that changed, on top of screens_v46.

  Reveal   the final beat's "1 IN N" sits at the TOP edge (y 14, was 86): it was on the hero's head. How loud it
           is depends on the rarity (RevealUi.finalOdds): size, slam, shake, colours, flash.
  HUD      DAILY button back on screen, in the right column with the others (Store, Daily, Gifts, Rebirth),
           calendar icon (IconDailyBig), its own "!" badge while today's reward waits.
           The event chip beside the right column is gone. Active boosts live in a compact tray in the top-right
           corner under the settings gear (`BuffTray`): a small BOOSTS header with a count (tap to open or
           close), and under it one row per active boost: server luck, Festival
           Hour, timed 2x Yen, lucky throws; the open rows hang left of the right column, never over its
           buttons. Collapsed it is only the header; a new boost opens it for a few seconds, then it folds away.
           The right column starts at y 150 (was 224) so four buttons stay clear of the jump-button zone.
"""

from __future__ import annotations

import copy

import screens_v46 as v46
from mangapop import col, frame, ico, row
from mp4 import T, card
from screens_v3 import find

# =================================================================== Reveal: odds at the top edge

ODDS_Y = 14


def reveal():
    spec = v46.reveal()
    odds = find({"children": spec["children"]}, "FinalOdds")
    odds["pos"] = [0.5, 0, 0, ODDS_Y]
    return spec


# =================================================================== HUD: the DAILY button

PITCH, GAP = 72, 14


def _rename(node, old, new):
    if isinstance(node, dict):
        if isinstance(node.get("name"), str):
            node["name"] = node["name"].replace(old, new)
        for k in node.get("children") or []:
            _rename(k, old, new)


def daily_cell(store_cell):
    cell = copy.deepcopy(store_cell)
    _rename(cell, "BtnStore", "BtnDaily")
    btn = find(cell, "BtnDaily")
    btn.update({"colour": "info", "opens": "DailyRewards", "keyline": "#A9E4FF"})
    find(btn, "Icon")["icon"] = "IconDailyBig"
    find(btn, "Caption")["text"] = "DAILY"
    return cell


# =================================================================== HUD: the boosts tray

TRAY_W = 232       # the open rows
HEAD_W, HEAD_H = 180, 40
ROW_H = 50
TRAY_Y = 76        # under the settings gear (y 12..68)
COLUMN_Y = 140     # the right column, 4 buttons (y 140..470): clear of the jump-button zone (y > 490)
ROW_SHIFT = 84     # the open rows hang LEFT of the right column (76 wide + 8), never over its buttons


def tray_head():
    face = card("BuffHead", HEAD_W, HEAD_H, "panel", [
        ico("IconLuckBig", 26, name="Icon"),
        T("BuffTitle", "BOOSTS", 72, 16, font="display", align="left"),
        {**card("BuffCount", 28, 24, "danger", [
            T("BuffCountText", None, 24, 14, font="display", samples=["4", "1"]),
        ], keyline="#FFFFFF", corner=12), "name": "BuffCount"},
        ico("IconArrow", 16, name="Chevron"),
    ], layout=row(6, "center"))
    return frame("BuffToggle", HEAD_W, HEAD_H, [face], cls="TextButton", pos=[1, 0, 0, 0], anchor=[1, 0])


def buff_row(name, icon, title, value_samples, time_samples, extra=()):
    text = frame(f"{name}Text", 128, 40, [
        {**T(f"{name}Name", title, 128, 13, align="left"), "pos": [0, 0, 0, 0]},
        {**T(f"{name}Value", None, 128, 16, colour="luck", font="display", align="left",
             samples=value_samples), "pos": [0, 0, 1, 0], "anchor": [0, 1]},
    ])
    kids = [ico(icon, 30, name="Icon"), text,
            T(f"{name}Time", None, 52, 14, align="right", samples=time_samples), *extra]
    return card(name, TRAY_W, ROW_H, "panel", kids, layout=row(8, "center"), visible=False)


def buff_tray():
    rows = frame("BuffRows", TRAY_W, 4 * ROW_H + 3 * 6, [
        buff_row("BuffServerLuck", "IconLuckBig", "SERVER LUCK", ["x8 LUCK", "x2 LUCK"], ["14:59", "1:02:59"]),
        buff_row("BuffFestival", "IconGiftBig", "FESTIVAL HOUR", ["2x MUTATIONS"], ["59:59"]),
        buff_row("BuffDoubleYen", "IconYenBig", "2x YEN", ["x2 INCOME"], ["29:59", "1:59:59"]),
        buff_row("BuffLucky", "IconLuckyThrowBig", "LUCKY THROWS", ["25 LEFT", "1 LEFT"], [""]),
    ], layout=col(6, "start"), pos=[1, -ROW_SHIFT, 0, HEAD_H + 6], anchor=[1, 0], visible=False)
    return frame("BuffTray", TRAY_W + ROW_SHIFT, HEAD_H + 6 + 4 * ROW_H + 3 * 6, [tray_head(), rows],
                 pos=[1, -20, 0, TRAY_Y], anchor=[1, 0], visible=False, z=4)


def hud():
    spec = v46.hud()
    root = {"children": spec["children"]}
    column = find(root, "RightColumn")
    cells = column["children"]
    store = next(c for c in cells if c.get("name") == "BtnStoreCell")
    gift_at = next(i for i, c in enumerate(cells) if c.get("name") == "BtnGiftCell")
    cells.insert(gift_at, daily_cell(store))
    column["size"] = [0, 76, 0, len(cells) * PITCH + (len(cells) - 1) * GAP]
    column["pos"] = [1, -20, 0, COLUMN_Y]
    spec["children"] = [buff_tray() if k.get("name") == "ServerLuckBar" else k for k in spec["children"]]
    # the game turns Roblox's player list off (client init): the top-right corner (settings, boosts,
    # the right column) is the HUD's own
    spec["coreGui"] = {"playerList": False}
    return spec


_REPLACE = {"hud": hud, "reveal": reveal}
SCREENS = [_REPLACE.get(getattr(f, "__name__", ""), f) for f in v46.SCREENS]
TEMPLATES = v46.TEMPLATES
