"""Create the game's passes and developer products on Roblox (Open Cloud) and write
their ids into design/game.json config.Monetization (then run gen_config.py).

Idempotent: anything that already exists on the universe under the same name is
reused, never created twice. The key is read from ROBLOX_API_KEY and never printed.
Needs the key scopes game-pass:write and developer-product:write (plan/08 input 3).

    python tools/mint_monetization.py            # list what would be made
    python tools/mint_monetization.py --create   # make the missing ones
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "design" / "game.json"
ICONS = ROOT / "assets" / "ui" / "icons_v4"
API = "https://apis.roblox.com"

PASS_NAME = {
    "DoubleYen": "2x Yen",
    "DoubleTraining": "2x Training",
    "Vip": "VIP",
    "AutoThrow": "Auto Throw",
    "LuckyAura": "Lucky Aura",
    "BigBench": "Big Bench",
}
PASS_ICON = {
    "DoubleYen": "IconYenBig",
    "DoubleTraining": "IconTrainBig",
    "Vip": "IconCrownBig",
    "AutoThrow": "IconAutoBig",
    "LuckyAura": "IconLuckBig",
    "BigBench": "IconBenchBig",
}
KIND_ICON = {
    "lucky": "IconLuckyThrowBig",
    "serverluck": "IconLuckBig",
    "yen": "IconYenBig",
    "train": "IconTrainBig",
    "offline2x": "IconTimerBig",
    "summon": "IconScrollBig",
    "starter": "IconStoreBig",
    "character": "IconStoreBig",
    "gift": "IconGiftBig",
}


def fmt(n: float) -> str:
    return f"{n:.2f}".rstrip("0").rstrip(".")


def pass_text(p: dict, c: dict) -> tuple[str, str]:
    k = p["Key"]
    desc = {
        "DoubleYen": "Every hero earns double yen, forever.",
        "DoubleTraining": "2x Power from every rep, perfect tap and boost.",
        "Vip": f"+{round(c['Luck']['VipBonus'] * 100)}% luck on every throw and "
        f"+{c['Plot']['VipBonusSlots']} hero slots.",
        "AutoThrow": "Adds AUTO to your throw pad: it throws for you.",
        "LuckyAura": f"x{fmt(p.get('Luck', 1))} luck on every throw, forever.",
        "BigBench": f"Your bench holds {p.get('BenchSlots')} heroes instead of {c['Plot']['BenchSlots']}.",
    }
    return PASS_NAME[k], desc[k]


def product_text(p: dict, c: dict, premium: dict, passes: dict) -> tuple[str, str]:
    kind = p["Kind"]
    if kind == "lucky":
        n = p["Amount"]
        throws = "one throw" if n == 1 else f"{n} throws"
        return f"{n} Lucky Throw{'' if n == 1 else 's'}", f"x{fmt(c['Throw']['LuckyThrowLuck'])} luck on {throws}."
    if kind == "serverluck":
        return "Server Luck", f"Luck up for everyone in the server for {c['Luck']['ServerStepMinutes']} min (stacks)."
    if kind == "yen":
        m = p["Minutes"]
        if m >= 60:
            h = m // 60
            return f"{h} Hour Yen", f"{h} hour{'' if h == 1 else 's'} of your income, paid now."
        return f"{m} Min Yen", f"{m} min of your income, paid now."
    if kind == "train":
        return f"{p['Minutes']} Min Training", f"{p['Minutes']} min of training Power, paid now."
    if kind == "offline2x":
        return "2x Offline Claim", "Double the yen your heroes earned while you were away."
    if kind == "summon":
        n = p["Amount"]
        return f"Summon Scroll x{n}", f"{n} summon{'' if n == 1 else 's'} from the scroll pool. Odds are shown in game."
    if kind == "starter":
        hero = premium.get(p.get("Hero"), {}).get("Name", "a premium hero")
        return "Starter Pack", f"{hero}, lucky throws and 2x yen time. Once per player."
    if kind == "character":
        hero = premium.get(p.get("Hero"), {}).get("Name", p["Key"])
        return hero, f"The limited hero {hero}. Store exclusive."
    if kind == "gift":
        name = PASS_NAME[passes[p["Pass"]]["Key"]]
        return f"Gift {name}", f"Gives the {name} pass to another player in your server."
    return p["Key"], ""


def request(method: str, url: str, key: str, body: bytes | None = None, ctype: str | None = None):
    headers = {"x-api-key": key}
    if ctype:
        headers["Content-Type"] = ctype
    for attempt in range(5):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                text = r.read().decode()
                return r.status, (json.loads(text) if text.strip() else {})
        except urllib.error.HTTPError as e:
            text = e.read().decode()
            if e.code == 429 and attempt < 4:
                time.sleep(3 * (attempt + 1))
                continue
            return e.code, text[:400]
    return 0, "retries exhausted"


def multipart(fields: dict, image: Path | None) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    out = bytearray()
    for k, v in fields.items():
        out += f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    if image and image.exists():
        out += (
            f'--{boundary}\r\nContent-Disposition: form-data; name="imageFile"; '
            f'filename="{image.name}"\r\nContent-Type: image/png\r\n\r\n'
        ).encode()
        out += image.read_bytes() + b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={boundary}"


def list_all(key: str, url: str, field: str) -> list[dict]:
    items: list[dict] = []
    token = ""
    while True:
        status, data = request("GET", f"{url}?pageSize=100" + (f"&pageToken={token}" if token else ""), key)
        if status != 200:
            raise SystemExit(f"list failed {status}: {data}")
        items += data.get(field) or []
        token = data.get("nextPageToken") or ""
        if not token:
            return items


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--create", action="store_true")
    ap.add_argument("--only", help="one Key, to try the write scope first")
    a = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        raise SystemExit("ROBLOX_API_KEY is not set")
    game = json.loads(GAME.read_text(encoding="utf-8"))
    c = game["config"]
    universe = game["publish"]["universe_id"]
    mon = c["Monetization"]
    premium = {h["Id"]: h for h in c.get("PremiumCharacters", [])}
    passes = {p["Key"]: p for p in mon["Passes"]}

    pass_url = f"{API}/game-passes/v1/universes/{universe}/game-passes"
    prod_url = f"{API}/developer-products/v2/universes/{universe}/developer-products"
    have_pass = {g.get("name"): g for g in list_all(key, pass_url + "/creator", "gamePasses")}
    have_prod = {d.get("name"): d for d in list_all(key, prod_url + "/creator", "developerProducts")}

    changed = False
    rows = [("pass", p) for p in mon["Passes"]] + [("product", p) for p in mon["Products"]]
    for kind, row in rows:
        if a.only and row["Key"] != a.only:
            continue
        if kind == "pass":
            name, desc = pass_text(row, c)
            icon = ICONS / f"{PASS_ICON.get(row['Key'], 'IconStoreBig')}.png"
            existing = have_pass.get(name)
            got = existing and (existing.get("gamePassId") or existing.get("id"))
        else:
            name, desc = product_text(row, c, premium, passes)
            icon = ICONS / f"{KIND_ICON.get(row['Kind'], 'IconStoreBig')}.png"
            existing = have_prod.get(name)
            got = existing and (existing.get("productId") or existing.get("id"))
        if got:
            if row["ProductId"] != int(got):
                row["ProductId"] = int(got)
                changed = True
            print(f"have   {kind:7} {row['Key']:20} {name!r} -> {got}")
            continue
        verb = "create" if a.create else "would "
        print(f"{verb} {kind:7} {row['Key']:20} {name!r} R${row['Robux']} [{icon.name}] {desc}")
        if not a.create:
            continue
        fields = {
            "name": name,
            "description": desc,
            "price": row["Robux"],
            "isForSale": "true",
            "isRegionalPricingEnabled": "false",
        }
        body, ctype = multipart(fields, icon)
        status, data = request("POST", pass_url if kind == "pass" else prod_url, key, body, ctype)
        if status not in (200, 201) or not isinstance(data, dict):
            print(f"   FAILED {status}: {data}")
            break
        new_id = data.get("gamePassId") or data.get("productId") or data.get("id")
        if not new_id:
            print(f"   no id in reply: {sorted(data)}")
            break
        row["ProductId"] = int(new_id)
        changed = True
        print(f"   -> {new_id}")
        time.sleep(1.0)
    if changed:
        GAME.write_text(json.dumps(game, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("design/game.json updated: run gen_config.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
