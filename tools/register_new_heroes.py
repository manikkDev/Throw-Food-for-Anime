#!/usr/bin/env python3
"""Register the owner's 2026-11-22 batch of imported heroes (batch 4) in the design files.

    python tools/register_new_heroes.py            # writes roster.json + anime_zones.json
    python tools/register_new_heroes.py --check    # only prints the rarity table per zone

Each row: source (the real character, used on the lab pads and in design files only),
rig (the rig's name in Workspace.Characters_R15_New without " (R15)"), alias (the IN-GAME name:
recognisable but not the franchise's trademark, same style as "Straw Hat Rookie"), zone, rarity.
Also applies the rarity changes to heroes that were already planned (RETUNE).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROSTER = ROOT / "design" / "characters" / "roster.json"
ZONES = ROOT / "design" / "zones" / "anime_zones.json"

# source, rig name, alias, zone, rarity, note
NEW = [
    # Naruto
    ("Boruto", "Boruto", "Next-Gen Ninja", "Naruto", "Rare", "imported avatar Boruto"),
    ("Rock Lee", "Rock Lee", "Bowl Cut Brawler", "Naruto", "Common", "imported avatar rockleeoftheleaf8"),
    ("Hinata", "Hinata", "Pale-Eyed Princess", "Naruto", "Uncommon", "imported avatar hinata_001319"),
    ("Gaara", "Gaara", "Sand Guardian", "Naruto", "Rare", "imported avatar pvryou"),
    ("Jiraiya", "Jiraiya", "Toad Sage", "Naruto", "Epic", "imported avatar XxXfoxNathanXxX"),
    ("Pain", "Pain", "Rain God", "Naruto", "Legendary", "imported avatar noobtopro112276 + Akatsuki robe 74818563474159"),
    # Demon Slayer
    ("Inosuke", "Inosuke", "Boar Mask Brawler", "Demon Slayer", "Common", "built from catalog items"),
    ("Giyu Tomioka", "Giyu Tomioka", "Tide Swordsman", "Demon Slayer", "Rare", "imported avatar Mightcat9559 + haori + katana"),
    ("Shinobu Kocho", "Shinobu Kocho", "Butterfly Swordswoman", "Demon Slayer", "Epic", "built from catalog items"),
    ("Akaza", "Akaza", "Crimson Fist Demon", "Demon Slayer", "Legendary", "built from catalog items"),
    ("Douma", "Douma", "Crystal Cult Leader", "Demon Slayer", "Epic", "built from catalog items"),
    # One Piece
    ("Ace", "Ace", "Blazing Pirate", "One Piece", "Epic", "built from catalog items"),
    ("Usopp", "Usopp", "Long-Nose Sniper", "One Piece", "Uncommon", "built from catalog items"),
    ("Boa Hancock", "Boa Hancock", "Serpent Empress", "One Piece", "Rare", "built from catalog items"),
    ("Blackbeard", "Blackbeard", "Shadow Pirate Captain", "One Piece", "Epic", "built from catalog items"),
    # My Hero Academia
    ("Uraraka", "Uraraka", "Zero-Gravity Girl", "My Hero Academia", "Common", "imported avatar Tkmathias7654"),
    ("Bakugo", "Bakugo", "Blast Prodigy", "My Hero Academia", "Epic", "imported avatar bakugoexplosionkingw"),
    ("Todoroki", "Todoroki", "Frostflame Hero", "My Hero Academia", "Rare", "imported avatar Shoto Todorokii"),
    ("Toga", "Toga", "Blood-Stalker Girl", "My Hero Academia", "Uncommon", "built from catalog items"),
    ("Hawks", "Hawks", "Crimson-Wing Hero", "My Hero Academia", "Epic", "built from catalog items"),
    ("Dabi", "Dabi", "Blue Flame Villain", "My Hero Academia", "Rare", "built from catalog items"),
    ("Endeavor", "Endeavor", "Inferno Hero", "My Hero Academia", "Legendary", "built from catalog items"),
    ("All Might", "All Might", "Golden Age Hero", "My Hero Academia", "Mythic", "built from catalog items"),
    ("Shigaraki", "Shigaraki", "Decay Villain", "My Hero Academia", "Legendary", "built from catalog items"),
    # Blue Lock
    ("Isagi", "Isagi", "Egoist Striker", "Blue Lock", "Common", "imported avatar Yoichi Isagi"),
    ("Bachira", "Bachira", "Dribble Monster", "Blue Lock", "Uncommon", "imported avatar Meguru Bachira"),
    ("Chigiri", "Chigiri", "Lightning Winger", "Blue Lock", "Uncommon", "imported avatar Nagiri_bllk"),
    ("Reo", "Reo", "Chameleon Playmaker", "Blue Lock", "Common", "imported avatar Reo"),
    ("Nagi", "Nagi", "Lazy Genius Striker", "Blue Lock", "Rare", "imported avatar nagi"),
    ("Barou", "Barou", "King Striker", "Blue Lock", "Rare", "imported avatar Shoei Barou"),
    ("Rin Itoshi", "Rin Itoshi", "Cold Prodigy Winger", "Blue Lock", "Epic", "imported avatar rin itoshi"),
    ("Kaiser", "Kaiser", "Emperor Striker", "Blue Lock", "Legendary", "imported avatar kaiser"),
    ("Don Lorenzo", "Don Lorenzo", "Number One Striker", "Blue Lock", "Legendary", "imported avatar Don Lorenzo (owner to confirm which character)"),
    # Black Clover
    ("Noelle", "Noelle", "Water Princess", "Black Clover", "Uncommon", "imported avatar Noelle"),
    ("Yami Sukehiro", "Yami Sukehiro", "Dark Slash Captain", "Black Clover", "Legendary", "imported avatar yami_skhr"),
    ("Mereoleona", "Mereoleona", "Crimson Lioness", "Black Clover", "Epic", "imported avatar lady_mereoleona"),
    ("Liebe", "Liebe", "Devil Knight", "Black Clover", "Legendary", "imported avatar Liebe"),
    # Hunter x Hunter
    ("Gon", "Gon", "Rod Fisher Boy", "Hunter x Hunter", "Common", "imported avatar Gon + shirt 127036637888189"),
    ("Leorio", "Leorio", "Suit-and-Briefcase Doc", "Hunter x Hunter", "Common", "imported avatar Leoreo + face 131049169866571"),
    ("Kurapika", "Kurapika", "Chain Avenger", "Hunter x Hunter", "Rare", "imported avatar Kurapika + chains"),
    ("Illumi", "Illumi", "Needle Assassin", "Hunter x Hunter", "Epic", "built from catalog items + hair 135595723492190"),
    ("Chrollo", "Chrollo", "Spider Thief Boss", "Hunter x Hunter", "Legendary", "imported avatar Chrollo"),
    ("Netero", "Netero", "Prayer Master", "Hunter x Hunter", "Legendary", "imported avatar Netero"),
    ("Meruem", "Meruem", "Ant Monarch", "Hunter x Hunter", "Mythic", "imported avatar Meruem"),
    # Crossover: Other Worlds
    ("Anya Forger", "Anya", "Telepath Girl", "Crossover: Other Worlds", "Common", "built from catalog items"),
    ("Loid Forger", "Loid", "Master Spy Dad", "Crossover: Other Worlds", "Uncommon", "built from catalog items"),
    ("Kirito", "Kirito", "Dual-Blade Gamer", "Crossover: Other Worlds", "Rare", "imported avatar kirito100082"),
    # Attack on Titan
    ("Armin", "Armin", "Colossus Strategist", "Attack on Titan", "Common", "imported avatar Armin_Arlert1128"),
    ("Mikasa", "Mikasa", "Scarf Blade Soldier", "Attack on Titan", "Rare", "built from catalog items + Scout jacket"),
    ("Erwin", "Erwin", "Commander Tactician", "Attack on Titan", "Rare", "built from catalog items + Scout jacket"),
    ("Armored Titan", "Armored Titan", "Armored Giant", "Attack on Titan", "Legendary", "imported avatar Reiner_Braun211"),
    ("Zeke", "Zeke", "Beast Giant Prince", "Attack on Titan", "Epic", "built from catalog items"),
    # Chainsaw Man
    ("Kobeni", "Kobeni", "Panicking Rookie", "Chainsaw Man", "Common", "imported avatar pauly_2018"),
    ("Aki Hayakawa", "Aki Hayakawa", "Contract Hunter", "Chainsaw Man", "Rare", "imported avatar aki_hayakawa0805"),
    ("Reze", "Reze", "Bomb Girl", "Chainsaw Man", "Epic", "imported avatar Pranxww"),
    ("Kishibe", "Kishibe", "One-Eyed Instructor", "Chainsaw Man", "Legendary", "imported avatar Adominusraptor"),
    # JoJo
    ("Jonathan Joestar", "Jonathan Joestar", "Gentleman Hero", "JoJo's Bizarre Adventure", "Common", "built from catalog items"),
    ("Josuke", "Josuke", "Pompadour Guardian", "JoJo's Bizarre Adventure", "Uncommon", "imported avatar Josuke73632"),
    ("Giorno", "Giorno", "Gold Gang Boss", "JoJo's Bizarre Adventure", "Legendary", "imported avatar Giorno_Giovanna1777"),
    ("Kira", "Kira Yoshikage", "Quiet Bomber", "JoJo's Bizarre Adventure", "Epic", "built from catalog items"),
    ("Pucci", "Pucci", "Gravity Priest", "JoJo's Bizarre Adventure", "Rare", "imported avatar chestpixel1"),
    # Crossover: Masterminds
    ("Mob", "Mob", "Psychic Student", "Crossover: Masterminds", "Common", "imported avatar ShigeoKsageyama"),
    ("Thorfinn", "Thorfinn", "Viking Wanderer", "Crossover: Masterminds", "Uncommon", "imported avatar EXzinXc_FF"),
    ("Anos Voldigoad", "Anos Voldigoad", "Tyrant Demon Lord", "Crossover: Masterminds", "Mythic", "imported avatar antivenomfamous66 + jacket/arms"),
    # One Punch Man
    ("Mumen Rider", "Mumen Rider", "Bicycle Hero", "One Punch Man", "Common", "built from catalog items"),
    ("Genos", "Genos", "Cyborg Disciple", "One Punch Man", "Rare", "imported avatar Genosfan312"),
    ("Speed-o'-Sound Sonic", "Speed-o-Sound Sonic", "Ninja Speedster", "One Punch Man", "Uncommon", "built from catalog items"),
    ("King", "King", "Strongest Bluffer", "One Punch Man", "Uncommon", "built from catalog items"),
    ("Bang", "Bang", "Silver Fist Master", "One Punch Man", "Epic", "built from catalog items"),
    ("Tatsumaki", "Tatsumaki", "Tornado Psychic", "One Punch Man", "Legendary", "imported avatar TsarcraZy666"),
    ("Boros", "Boros", "Alien Conqueror", "One Punch Man", "Mythic", "imported avatar ABOBUSEK_228"),
    # Bleach
    ("Rukia", "Rukia", "Ice Blade Girl", "Bleach", "Common", "imported avatar DecayRoses"),
    ("Toshiro Hitsugaya", "Toshiro Hitsugaya", "Ice Dragon Captain", "Bleach", "Rare", "imported avatar Toshiro23121"),
    ("Byakuya", "Byakuya", "Petal Noble", "Bleach", "Epic", "imported avatar byakuya + katana 12779081947"),
    ("Urahara", "Urahara", "Bucket-Hat Shopkeeper", "Bleach", "Uncommon", "imported avatar king_derbi228"),
    ("Yoruichi", "Yoruichi", "Flash Cat Goddess", "Bleach", "Uncommon", "imported avatar Fgahdjajdfkaifhafjaf"),
    ("Kenpachi", "Kenpachi", "Battle Maniac Captain", "Bleach", "Legendary", "imported avatar thethreeblindmice3"),
    ("Gin Ichimaru", "DAVIDDDB2009", "Fox Smile Traitor", "Bleach", "Epic", "imported avatar DAVIDDDB2009 (owner to confirm which character)"),
    # Solo Leveling
    ("Cha Hae-In", "Cha Hae-In", "Hunter Swordswoman", "Solo Leveling", "Common", "built from catalog items"),
    ("Igris", "Igris", "Crimson Knight Shade", "Solo Leveling", "Rare", "imported avatar igris_shadow012 (aura piece removed)"),
    ("Beru", "Beru", "Ant King Shade", "Solo Leveling", "Epic", "imported avatar Beru"),
    ("Thomas Andre", "Thomas Andre", "Goliath Hunter", "Solo Leveling", "Uncommon", "built from catalog items"),
    ("Antares", "Antares", "Dragon Monarch", "Solo Leveling", "Legendary", "built from catalog items"),
    ("Ashborn", "Ashborn", "Shadow Sovereign", "Solo Leveling", "Mythic", "built from catalog items"),
    # Jujutsu Kaisen
    ("Nobara", "Nobara", "Hammer-and-Nails Girl", "Jujutsu Kaisen", "Uncommon", "imported avatar RRbestiep"),
    ("Todo", "Todo", "Clap Brother", "Jujutsu Kaisen", "Rare", "imported avatar TodoBoogieWoogieSwap"),
    ("Maki", "Maki", "Cursed Tool Fighter", "Jujutsu Kaisen", "Uncommon", "built from catalog items"),
    ("Yuta Okkotsu", "Yuta Okkotsu", "Special-Grade Rookie", "Jujutsu Kaisen", "Epic", "imported avatar yuta_senpai5"),
    ("Geto", "Geto", "Curse Manipulator", "Jujutsu Kaisen", "Legendary", "rebuilt from catalog items + original face/hair"),
    ("Kashimo", "Kashimo", "Lightning Duelist", "Jujutsu Kaisen", "Epic", "imported avatar Kashimo + staff 107739917538649"),
    # Dragon Ball
    ("Trunks", "Trunks", "Sword Time Prince", "Dragon Ball", "Common", "imported avatar ice_skull67"),
    ("Cell", "Cell", "Perfect Bio-Android", "Dragon Ball", "Legendary", "imported avatar CellBurst"),
    ("Majin Buu", "Majin Buu", "Pink Candy Monster", "Dragon Ball", "Epic", "imported avatar MajinxBuux"),
    ("Broly", "Broly", "Legendary Berserker", "Dragon Ball", "Legendary", "imported avatar BrolyCrak344"),
    ("Goku Black", "Goku Black", "Rose Dark Fighter", "Dragon Ball", "Mythic", "imported avatar Gokublack_alt123"),
    ("Jiren", "Jiren", "Gray Pride Warrior", "Dragon Ball", "Epic", "imported avatar deadrailsfan816_2"),
    ("Whis", "Whis", "Staff Angel Mentor", "Dragon Ball", "Secret", "imported avatar Oskarol55"),
]

# heroes that were already in the plan whose rarity is retuned for balance (design/zones/anime_zones.json)
RETUNE = {"Muzan": "Mythic", "Ulquiorra": "Legendary", "Saitama": "Secret", "Piccolo": "Uncommon", "Gohan": "Rare",
          "Yuji": "Common", "Ayanokoji": "Rare"}


def slug(text: str) -> str:
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", text.lower().replace("'", ""))).strip("_")


def main() -> int:
    roster = json.loads(ROSTER.read_text(encoding="utf-8"))
    plan = json.loads(ZONES.read_text(encoding="utf-8"))
    if "Secret" not in plan["rarities"]:
        plan["rarities"].append("Secret")
    have_ids = {r["Id"] for r in roster}
    have_src = {r["Source"] for r in roster}
    have_names = {r["Name"].lower() for r in roster}
    zones = {z["anime"]: z for z in plan["zones"]}

    for src, rig, alias, zone, rarity, note in NEW:
        assert zone in zones, zone
        assert rarity in plan["rarities"], rarity
        hid = slug(alias)
        if src in have_src:
            continue  # already registered on an earlier run
        assert hid not in have_ids, f"id clash {hid}"
        assert alias.lower() not in have_names, f"name clash {alias}"
        have_ids.add(hid)
        have_names.add(alias.lower())
        roster.append({"Id": hid, "Name": alias, "Source": src,
                       "Rig": f"ServerStorage.CharacterSources.R15_Final/{src} (R15)", "Planned": True,
                       "Notes": note, "WorkspaceRig": rig})
        zones[zone]["characters"].append({"source": src, "rarity": rarity})
        if src in zones[zone].get("suggest", []):
            zones[zone]["suggest"].remove(src)
    for z in plan["zones"]:
        for c in z["characters"]:
            if c["source"] in RETUNE:
                c["rarity"] = RETUNE[c["source"]]

    print(f"{'zone':26} " + " ".join(f"{r[:4]:>4}" for r in plan["rarities"]) + "  Prem total")
    for z in plan["zones"]:
        counts = {r: sum(1 for c in z["characters"] if c["rarity"] == r) for r in plan["rarities"] + ["Premium"]}
        total = sum(counts.values())
        print(f"{z['n']:>2} {z['anime'][:23]:23} " + " ".join(f"{counts[r]:>4}" for r in plan["rarities"]) + f"  {counts['Premium']:>4} {total:>4}")
    if "--check" in sys.argv:
        return 0
    ROSTER.write_text(json.dumps(roster, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    ZONES.write_text(json.dumps(plan, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"roster now {len(roster)} heroes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
