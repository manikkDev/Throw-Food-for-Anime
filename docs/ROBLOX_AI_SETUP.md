# ROBLOX AI GAME SETUP: agent runbook

> **For the human:** copy this file into a new, empty game folder (e.g.
> `D:\Roblox Studio Games\<My New Game>\`) together with whatever you have of:
> the skills download (`roblox-ai-skills-main`), your rigs (`Rigs/`), and the
> `SyphoDev VFX Texture Pack`. Open Roblox Studio on the game's place (published, Team Create
> is fine), open Claude Code (desktop app, Code tab) in the game folder, and say:
>
> **"Follow ROBLOX_AI_SETUP.md and set everything up. The GitHub repo is <url>."**
>
> The agent asks you only for things it cannot do itself (pasting secret keys into a hidden
> prompt, one click in Studio, quitting Blender, approving a push).

> **For the agent:** you are setting up a Windows machine so a Roblox game can be built almost
> entirely by AI, using the SyphoDev Roblox skills, Roblox Studio's built-in MCP, Rojo, and
> Blender. Work through the phases IN ORDER. Every phase ends with a CHECK; do not move on while
> a check is red. Most of this was proven on 2026-11-13; versions may have moved since, so
> **look up current versions on the web before installing** (see "Version policy"), and
> **detect before you install**: on a machine set up before, most phases are verify-only.
> Keep a task list; report pass/fail honestly at the end with the evidence.

---

## 0. Ground rules (read first, they prevent the failures we already hit)

1. **Secrets never pass through chat, files, logs, command lines or commits.** API keys live
   in Windows *user* environment variables. The user sets them with `set-secret.ps1` (below),
   typing into a hidden prompt in their own terminal. You only ever check presence:
   `python -c "import os;print(bool(os.environ.get('ROBLOX_API_KEY')))"`. If the user pastes a
   key into chat anyway, tell them to rotate it on the Creator Hub.
2. **Ask before:** installing anything not listed here, pushing to GitHub, publishing a place,
   deleting anything (move to `_RobloxAI\backups\` instead), touching Studio settings.
3. **Exactly one** Studio MCP server, **one** Rojo plugin, **one** Studio window with the place.
   Two Rojo plugins = duplicated modules; two Studio MCPs = deadlock; a stray Studio start page
   used to break every direct MCP call (patched, see P5).
4. **Never call computer-use `open_application("Roblox Studio")` while Studio is running.** It
   launches a *second* Studio instead of focusing the first (measured). Prefer the MCP for
   everything; ask the user for the one-click things (Rojo Connect).
5. **Blender 5.x breaks the skills' scripts** (5.0 removed `Action.fcurves`;
   `calibrate_rig.py` crashes). Skill scripts run on a portable **Blender 4.5 LTS**; any
   Blender 5.x the user has stays for interactive work + the Blender MCP.
6. **Kaggle is banned** for these skills (its terms; the author's account was banned). Never set it up.
7. Do not modify `LOCAL.md` files that already exist without showing the diff and getting a yes.

### Version policy (look these up fresh, 2 minutes of web search)

| Component | Proven 2026-11-13 | Rule |
|---|---|---|
| Rojo CLI | 7.7.1 | **Must equal the Rojo plugin version installed in Studio.** Read the plugin version (Phase D) and install that exact CLI. 7.6.x plugin cannot talk to 7.7.x server (protocol 4 vs 5) |
| Wally / Selene / StyLua / Lune | 0.3.2 / 0.32.0 / 2.6.0 / 0.11.1 | Latest *stable* (no alpha/rc). If Lune's major require rules change again, re-run the gate test |
| Blender (skills) | 4.5.16 LTS portable | Latest 4.5.x LTS from download.blender.org, SHA-256 verified |
| mcp-for-blender | 2.2.7 | Pin a release that is at least ~1 week old (it ships almost daily). Addon must match server |
| Kiln | v0.8.0 | Keep v0.8.0 (the version the 3D skill validated) unless the skill says otherwise |
| Python | 3.13 | 3.11+ |
| Node | 22.x | 22.2+ (Kiln) |

---

## 1. Ask the user up front (one message, then work)

- Game title and GitHub repo URL (empty repo is ideal).
- Is the game's place open in Studio? (Needed for MCP + Rojo checks. If it is a new game, the user
  publishes an empty baseplate once from Studio: File > Publish to Roblox. Never do that yourself.)
- Uploads under the user's account or a group? (Default: user. Group needs `ROBLOX_GROUP_ID`.)
- Which optional AI services they want: Hugging Face token (organic 3D meshes), Cloudflare
  Workers AI (concept images + UI icons). Both free. Roblox Open Cloud key: strongly recommended.

---

## Phase A: Inventory (detect, don't assume)

```bash
for t in python git node npm uv uvx rokit rojo wally selene stylua lune ffmpeg claude; do printf "%-7s " $t; (command -v $t || echo MISSING) | head -1; done
python --version; rojo --version; claude --version
ls "D:/Roblox Studio Games/_RobloxAI" 2>/dev/null && echo "TOOLKIT EXISTS: mostly verify-only"
```
Also: Blender installs under `C:\Program Files\Blender Foundation\`, Studio under
`%LOCALAPPDATA%\Roblox\Versions\`, `%LOCALAPPDATA%\Roblox\mcp.bat` exists, the Roblox user id
folder `%LOCALAPPDATA%\Roblox\<digits>\InstalledPlugins\`.

Notes: under Rokit, `rojo --version` *outside a project* fails with "Failed to find tool" unless
the tool is installed globally. The Claude desktop app bundles Claude Code but does **not** put a
`claude` CLI on PATH.

---

## Phase B: Shared toolkit folder

`<GAMES_HOME>` = the parent of the game folder (e.g. `D:\Roblox Studio Games`).
`<TOOLKIT>` = `<GAMES_HOME>\_RobloxAI`. It is shared by every game and is NOT a game.

```
_RobloxAI\
  bootstrap\     ROBLOX_AI_SETUP.md, patch_skills.py, set-secret.ps1
  inputs\        roblox-ai-skills\ (the download), syphodev-vfx-texture-pack\
  rigs\          MrXen0_R15RIG_v1.2.blend, roblox-r6-rigged\ ...
  tools\         blender-4.5.x-windows-x64\ (portable), kiln\ (npm)
  vfx-library\   (ROBLOX_VFX_LIB)   vfx-research\   sfx\   model-work\
  texture-scratch\   ui-icons\   map-work\   backups\
```

1. Create the folders that are missing.
2. **Move** (never copy-then-delete, never delete) the pasted inputs out of the game folder into
   `inputs\` and `rigs\`. If the same thing already exists in the toolkit, compare (size/hash);
   if identical, move the pasted copy to `backups\` and tell the user; if different, ask.
   The game folder must end up containing only this file before scaffolding.
3. Write `bootstrap\patch_skills.py` and `bootstrap\set-secret.ps1` from the appendices below
   (byte for byte), and copy this file to `bootstrap\ROBLOX_AI_SETUP.md`.

CHECK: the game folder holds only `ROBLOX_AI_SETUP.md`; the toolkit tree exists.

---

## Phase C: Tools

Install only what Phase A found missing. Prefer official sources: winget, the vendor's installer,
or the vendor's release page with checksum verification.

| Tool | How |
|---|---|
| Python 3.11+ | `winget install -e --id Python.Python.3.13` |
| Python packages | `python -m pip install --upgrade numpy scipy pillow requests opencv-python-headless gradio_client huggingface_hub` (torch/diffusers/kaggle are NOT needed) |
| Git | `winget install -e --id Git.Git`; set `user.name`/`user.email` if unset (ask) |
| Node 22 | `winget install -e --id OpenJS.NodeJS.LTS` |
| uv | `winget install -e --id astral-sh.uv` (never `pip install uv`) |
| ffmpeg | `winget install -e --id Gyan.FFmpeg` (lands on PATH via `%LOCALAPPDATA%\Microsoft\WinGet\Links`) |
| Rokit | `Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 \| Invoke-Expression` |
| Claude Code CLI | `irm https://claude.ai/install.ps1 \| iex` -> `%USERPROFILE%\.local\bin\claude.exe` (needed for `claude mcp add/list`) |

Global Rokit tools (run from `~`, with the versions chosen under Version policy):
```bash
cd ~ && rokit add --global --force rojo-rbx/rojo@<PLUGIN_VERSION>
rokit add --global --force UpliftGames/wally@0.3.2
rokit add --global --force Kampfkarren/selene@<v>
rokit add --global --force JohnnyMorganz/StyLua@<v>
rokit add --global --force lune-org/lune@<v>
```

**Blender 4.5 LTS portable** (skills only):
```bash
T="<TOOLKIT>/tools"; cd "$T"
V=$(curl -s https://download.blender.org/release/Blender4.5/ | grep -oE 'blender-4\.5\.[0-9]+-windows-x64\.zip' | sort -uV | tail -1); V=${V%-windows-x64.zip}
curl -sSLO https://download.blender.org/release/Blender4.5/$V.sha256
curl -sSLO https://download.blender.org/release/Blender4.5/$V-windows-x64.zip
grep windows-x64.zip $V.sha256 | sha256sum -c - && unzip -q $V-windows-x64.zip && rm $V-windows-x64.zip
mkdir -p $V-windows-x64/portable    # keeps its prefs/addons separate from the user's Blender
"$V-windows-x64/blender.exe" --version
```

**Kiln** (hard-surface 3D route, local, no GPU, no keys):
```bash
mkdir -p "<TOOLKIT>/tools/kiln" && cd "<TOOLKIT>/tools/kiln" && npm init -y
npm install "https://github.com/matthew-kissinger/kiln/archive/refs/tags/v0.8.0.tar.gz" --omit=dev --include=optional
```

CHECK: every row of Phase A is present; `rojo --version` == plugin version; Blender 4.5 prints
its version; `ls <TOOLKIT>/tools/kiln/node_modules/@gltf-transform` shows core/functions.

---

## Phase D: Roblox Studio side

1. **Rojo plugin version.** The Creator Store Rojo plugin (asset id `13916111004`) lives in
   `%LOCALAPPDATA%\Roblox\<userid>\InstalledPlugins\13916111004\*\Plugin.rbxm`; a CLI-installed
   one is `%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm` (or `Rojo.rbxm`). Read versions:
   ```powershell
   $s=[Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes("<path>")); [regex]::Matches($s,'7\.\d+\.\d+') | % Value | sort -Unique
   ```
   (the highest number is the plugin's own version). **If both exist, move the local
   `RojoManagedPlugin.rbxm` to `<TOOLKIT>\backups\`** (we found a stale 7.6.1 one next to the
   7.7.1 Store plugin), and tell the user to restart Studio at a convenient moment.
   If only a local one exists, either install the matching CLI version, or upgrade both with
   `rojo plugin install` from the new CLI.
2. **Studio MCP toggle** (user, once): Studio > Assistant panel > `...` > Manage MCP Servers >
   **Enable Studio as MCP server**. It can switch itself OFF after Studio updates: check it after
   every update.
3. Rojo plugin settings worth keeping: Two-Way Sync **off** (disk is the source of truth).

CHECK: one Rojo plugin, version == CLI; MCP toggle on (verified in Phase E).

---

## Phase E: MCP servers (user scope, so every game gets them)

```powershell
$c="$env:USERPROFILE\.local\bin\claude.exe"
& $c mcp add --transport stdio --scope user Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
& $c mcp add --transport stdio --scope user blender -e DISABLE_TELEMETRY=true -- cmd /c uvx mcp-for-blender@<pinned>
& $c mcp list
```
Trap: in `claude mcp add`, `-e` is variadic. Put the server **name before** `-e`, or `-e` swallows it.
Skip any server that `claude mcp list` already shows (re-adding errors). Do NOT add a third-party
Roblox MCP alongside the built-in one.

**Blender addon** (must match the server version). With Blender 5.x CLOSED (ask the user to quit
it; Blender rewrites its prefs on quit):
```bash
B5="$APPDATA/Blender Foundation/Blender/<5.x>/scripts/addons"
# move an old copy (often addon.py, v1.x) out of the way first:
cp "$APPDATA/Blender Foundation/Blender/<5.x>/config/userpref.blend" "<TOOLKIT>/backups/"
[ -f "$B5/addon.py" ] && mv "$B5/addon.py" "<TOOLKIT>/backups/blender_addon_old.py" && rm -rf "$B5/__pycache__"
# PYTHONIOENCODING: without it the installer writes the file, then crashes printing a unicode arrow
PYTHONIOENCODING=utf-8 DISABLE_TELEMETRY=true cmd //c uvx mcp-for-blender@<pinned> install-addon --addons-dir "$(cygpath -w "$B5")"
"C:/Program Files/Blender Foundation/Blender <5.x>/blender.exe" -b --python-expr "
import addon_utils, bpy
try: addon_utils.disable('addon', default_set=True)
except Exception as e: print('old addon:', e)
addon_utils.enable('blender_mcp', default_set=True, persistent=True)
bpy.ops.wm.save_userpref(); print('PREFS SAVED')"
```
(Proven 2026-11-13: package 2.2.7 ships addon `bl_info` version 1.8, file `blender_mcp.py`.)
Then the user reopens Blender; the addon starts its server on port 9876 (N panel > MCP for Blender).

CHECKS (real calls, not just handshakes):
- `claude mcp list` -> both `Connected`.
- Studio: `python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py list` lists ~38 tools
  and one studio with the right `placeId`; then
  `studio_mcp.py luau --code 'return game.PlaceId'` three times in a row: all succeed.
- Blender: an MCP `tools/call get_addon_status` reports `up_to_date: true`, and `get_scene_info`
  returns the open scene. (When scripting your own stdio client, send the server's stderr to a
  FILE: an unread stderr pipe fills up and hangs the server.)
- The Claude app must be fully restarted (tray > Quit) before `mcp__Roblox_Studio__*` and
  `mcp__blender__*` tools appear inside a chat session.

---

## Phase F: Install the skills and agents, then patch

**If the user has a private toolkit repo** (recommended; see "Toolkit repo" below), clone it to
`<TOOLKIT>` first and run `python <TOOLKIT>\bootstrap\sync_skills.py restore` instead of
`install.ps1`: that restores the skills AS IMPROVED on the old machine. Then patch/check as below.

```powershell
powershell -ExecutionPolicy Bypass -File "<TOOLKIT>\inputs\roblox-ai-skills\install.ps1"
python "<TOOLKIT>\bootstrap\patch_skills.py"
python "<TOOLKIT>\bootstrap\patch_skills.py" --check
```
`install.ps1` copies `skills\*` to `~/.claude/skills` and `agents\*` to `~/.claude/agents`, backing
up older copies and preserving `LOCAL.md`. Before installing a NEW download, skim its scripts for
network calls (`grep -rhoE "https?://[a-zA-Z0-9._-]+"`): the API key must only go to
`apis.roblox.com`.

`patch_skills.py` re-applies local fixes (see its docstring): rokit.toml with current pins (P1),
Lune require paths (P2), rokit hints (P3), Studio MCP polling (P4) and start-page filtering (P5).
If it reports CONFLICT, the skill changed upstream: read the new code and re-derive the fix, then
update `patch_skills.py` and this file.

CHECK: `python ~/.claude/skills/roblox-skills-setup/scripts/check_setup.py` shows all 10 skills
installed and tools ok; `patch_skills.py --check` says all applied.

---

## Phase G: Environment variables

Non-secret (you set them; values are paths/ids):
```powershell
$v=@{ 'ROBLOX_GAMES_HOME'='<GAMES_HOME>'; 'ROBLOX_AI_HOME'='<TOOLKIT>';
      'BLENDER'='<TOOLKIT>\tools\blender-4.5.x-windows-x64\blender.exe';
      'ROBLOX_VFX_LIB'='<TOOLKIT>\vfx-library'; 'ROBLOX_USER_ID'='<user id>';
      'KILN_HOME'='<TOOLKIT>\tools\kiln' }
foreach($k in $v.Keys){ [Environment]::SetEnvironmentVariable($k,$v[$k],'User') }
```
Get the user id from Studio, not from guessing:
`studio_mcp.py luau --code 'return game:GetService("StudioService"):GetUserId()'`.

Secrets (the USER runs this in their own PowerShell window; it hides input, verifies the
Roblox key against Open Cloud, never echoes):
```powershell
powershell -ExecutionPolicy Bypass -File "<TOOLKIT>\bootstrap\set-secret.ps1"                 # ROBLOX_API_KEY
powershell -ExecutionPolicy Bypass -File "<TOOLKIT>\bootstrap\set-secret.ps1" -Name HF_TOKEN   # optional
powershell -ExecutionPolicy Bypass -File "<TOOLKIT>\bootstrap\set-secret.ps1" -Name CF_ACCOUNT_ID
powershell -ExecutionPolicy Bypass -File "<TOOLKIT>\bootstrap\set-secret.ps1" -Name CF_API_TOKEN
```
How the user makes the Roblox key: create.roblox.com > Creator Hub > All tools > Open Cloud >
API Keys > Create API Key. Access permissions: **Assets: Read + Write** (one permission covers
images, meshes/models, audio, animations, and place publishing via the Assets API). Optionally
restrict to the experience and to their public IP. Keys idle for 60 days expire (toggle Enable
off/on to revive). Rate limit about 60 requests/min; audio uploads capped at 100/month (ID
verified) or 10/month.
Hugging Face: huggingface.co > Settings > Access Tokens (read). Cloudflare: dashboard > Workers AI
> account id + API token with *Workers AI: Read*.

After setting, the Claude app must be fully restarted to see them. A key entered while the app
is running is in the registry but invisible to the session until then (observed 2026-11-14).

**Least privilege.** Ask the user to create the Roblox key with ONLY Assets Read+Write (add
place publishing later if wanted). Observed: a key created with every box ticked had 46 scopes
(datastore delete, user bans, group admin, marketplace publish). `set-secret.ps1` now warns.

CHECK (no value is ever printed): read each key from `HKCU\Environment` in a child process and
test it against its own service:
- Roblox: GET `https://apis.roblox.com/assets/v1/operations/00000000-0000-0000-0000-000000000000`
  with `x-api-key` -> **404** means it authenticates; POST `/api-keys/v1/introspect`
  `{"apiKey": ...}` lists scopes: must include `asset` read+write.
- Hugging Face: GET `https://huggingface.co/api/whoami-v2` (Bearer) -> 200. Tokens start `hf_`
  and are ~37 chars (we caught a 101-char non-token pasted by mistake).
- Cloudflare: GET `/client/v4/accounts/<CF_ACCOUNT_ID>/tokens/verify` -> `active` (account-owned
  tokens fail on `/user/tokens/verify`), and `/accounts/<id>/ai/models/search` -> 200.

---

## Phase H: LOCAL.md for every skill

For each skill folder in `~/.claude/skills/<skill>/`, read `LOCAL.template.md`, keep its headings,
fill the values, write `LOCAL.md`. Values for this layout:

| Skill | Values |
|---|---|
| create-roblox-game | games folder `<GAMES_HOME>`; toolkit `<TOOLKIT>`; Blender = 4.5 path (env BLENDER), never 5.x; tools via Rokit global + per-game `rokit.toml`; MCP `Roblox_Studio` (only one); key names `ROBLOX_API_KEY`, `ROBLOX_USER_ID`; Kaggle NOT USED; place ids live in each game's `design/game.json`; preferences (quality over speed, no stand-ins) |
| roblox-3d-model | BLENDER 4.5; `KILN_HOME=<TOOLKIT>\tools\kiln`; work folder `<TOOLKIT>\model-work`; MCP `Roblox_Studio`; which credential env vars are set (yes/no only) |
| roblox-animation | R15 rig `<TOOLKIT>\rigs\<rig>.blend` (+ calibration notes from Phase I); R6: build from Studio when first needed; Blender 4.5; ffmpeg on PATH yes; MCP `Roblox_Studio` |
| roblox-build-orchestrator | ledger `<game>\build-runs`; agents `~/.claude/agents` |
| roblox-code | Rokit (not Aftman); pins; plugin == CLI version |
| roblox-map | python; MCP; map work `<game>\work\map`; port 8787 |
| roblox-sfx | MCP; `<TOOLKIT>\sfx`; audio quota note |
| roblox-texture-gen | MCP; `<TOOLKIT>\texture-scratch`; POLLINATIONS_TOKEN no |
| roblox-ui | icons `<TOOLKIT>\ui-icons`; CF var names; MCP |
| roblox-vfx | `ROBLOX_VFX_LIB=<TOOLKIT>\vfx-library`; bridge `Roblox_Studio`; port 48752; Blender 4.5; Lune global; research `<TOOLKIT>\vfx-research`; key name; texture-library status; SyphoDev pack path |

Never write a secret value. Record only variable NAMES and set/unset.

---

## Phase I: Asset pipelines (first run + smoke tests)

Run these and look at the outputs. Use the 4.5 Blender (`$BLENDER`) for every headless call.

1. **Rig calibration** (once per rig):
   `"$BLENDER" --background <rig>.blend --enable-autoexec --python ~/.claude/skills/roblox-animation/scripts/calibrate_rig.py`
   Expect for the MrXen0 R15 rig: armature `Roblox_R15`, 141 bones, rest-pose Action trap present,
   `ARM_IK_FK`/`LEG_IK_FK` = 1.0 (IK). Specs must set those to 0.0 (FK). Record in LOCAL.md.
2. **Animation**: render `references/example-fk-punch.json` with `scripts/anim_render.py` into
   `<TOOLKIT>\model-work\anim-smoke`. Expect "RIG INTACT" and LOOK at a mid frame: it must show
   a punch, not the rest pose. (~30 s.)
3. **3D hard-surface**: in `<TOOLKIT>\model-work\kiln-smoke`, copy
   `references/example-rifle.kiln.js`, then `npx --prefix <kiln> kiln render ... --json` (expect
   344 tris) and `node .../kiln_to_roblox.mjs rifle.glb rifle_roblox.glb` (front -Z, under 20k cap).
4. **Map**: `cd ~/.claude/skills/roblox-map && python scripts/prove.py minimal` -> `RESULT: WARN`
   with ONLY `P11 Empty space`. `plan.py minimal --prove -o <TOOLKIT>/map-work/smoke/plan.png`.
5. **UI**: `python scripts/ui_build.py examples/coin_hud.json --out <TOOLKIT>/ui-icons/smoke`, then
   `verify_ui.py examples/coin_hud.json` -> 0 failures.
6. **VFX first run** (once per machine). In `~/.claude/skills/roblox-vfx/sim/tex` run
   `make_textures.py`, `make_magic_tex.py`, `make_painted.py` (~10-20 min, from FILES not stdin).
   **Texture library: if the user has the SyphoDev VFX Texture Pack, do NOT run
   `build_library.py`** (45+ min of all cores, cannot resume after a reboot). The pack is that
   generator's own output minus `catalog.json`. Install and index it in under a minute:
   `python <TOOLKIT>\bootstrap\index_texture_pack.py "<TOOLKIT>\inputs\syphodev-vfx-texture-pack"`
   (Appendix C; it refuses nothing, reports unknown files, moves any old library aside). Proven
   2026-11-14: 2,431/2,431 files known to the generator, all structural catalog fields identical
   to native renders. Without the pack, run `tex/lib/build_library.py` in the background.
   Then `tex/lib/check_library.py` (0 defects expected) and `find_tex.py slash glow`.
   Meshes (seconds each) with **`$BLENDER` (4.5)** in `sim/mesh`: `-b -P make_meshes.py`,
   `make_props.py`, `make_dragon.py`; then `tex/make_prop_tex.py` (expect 50 meshes, 16 skins).
   Then `python sim/serve.py` -> http://127.0.0.1:8765/ : the three examples (Crimson Detonation,
   Eclipse Rend, Riptide Lance) must play with no console errors.
7. **VFX harvest library** starts EMPTY by design. Later, the user takes free Creator Store VFX
   packs into their own inventory and you harvest them with `roblox-vfx`. Check each pack's terms.

CHECK: all six smoke tests pass; outputs exist on disk.

---

## Phase J: The game repo

From the game folder (which now holds only this file):
1. Move this file to `<TOOLKIT>\bootstrap\` if not already there (the copy in the repo goes to
   `docs\ROBLOX_AI_SETUP.md` at step 6).
2. `python ~/.claude/skills/create-roblox-game/scripts/new_game.py "<Title>" --dir "<game folder>"`
   (add `--force` only if the folder is non-empty for a good reason).
3. `rokit install && wally install && python ~/.claude/skills/roblox-code/scripts/check.py`
   -> **all four gates green**.
4. Record the place in `design/game.json` -> `publish.place_id` / `publish.universe_id` (read
   them from `studio_mcp.py list`). Confirm the Studio window title matches the game.
   `place_state.py --place-id <id>` must say PUBLISHED (or SAVED).
5. Append to `.gitignore`: `*.rbxl`, `*.rbxlx`, `build/`, `work/`, `*.blend1`, `__pycache__/`,
   `node_modules/`, `.env`, `.env.*`, `*.pem`, `.claude/settings.local.json`, OS junk. (Do NOT add
   broad globs like `*secret*`: they silently hide game modules.)
6. Write the game's `CLAUDE.md` (toolchain table, ids, hard rules: disk is truth, gates before
   Studio, one MCP/Rojo/Studio, secrets, no Ctrl+S, no slop, git cadence, known traps). Copy
   this runbook to `docs\ROBLOX_AI_SETUP.md`.
7. **Auto-gate hook:** write `.claude/hooks/luau_gate.py` (Appendix D) and
   `.claude/settings.json`:
   ```json
   {"hooks": {"PostToolUse": [{"matcher": "Edit|Write|MultiEdit", "hooks": [
     {"type": "command", "command": "python \"$CLAUDE_PROJECT_DIR/.claude/hooks/luau_gate.py\"", "timeout": 300}]}]}}
   ```
   Test it by piping a JSON payload BUILT WITH PYTHON (`json.dumps`; hand-escaped Windows paths
   produce invalid JSON and the hook silently ignores it): a broken `.luau` -> exit 2 with the
   gate error; fixed file / a `.md` -> exit 0. It takes effect in new sessions.
8. `git init -b main`, `git remote add origin <url>`, first commit (end the message with the
   attribution lines your harness requires). **Ask before `git push -u origin main`.**
9. **Baseline snapshot:** `git tag setup-baseline`, then `mcp__Roblox_Studio__save_place` with
   notes `"Setup complete - baseline (git setup-baseline)"`. save_place on a Roblox/Team Create
   place saves a new place VERSION and never publishes. Record the version number in CLAUDE.md,
   with the rule: every approved section = gates green, commit, `git tag section-<N>`,
   save_place `"Section <N> approved (git section-<N>)"`.

CHECK: gates green; `git status` clean; remote set; (after the yes) `git ls-remote origin` shows main.

---

## Phase K: Prove Rojo sync end to end

1. Inventory the place first (`studio_mcp.py luau` listing each service's children) so you know
   nothing of the user's will be overwritten. Rojo only owns the `$path` subtrees.
2. `rojo serve default.project.json` in the background (note the port, default 34872).
3. Ask the user: Studio > Plugins > Rojo > **Connect** (localhost:34872) and accept the prompt.
4. Verify via MCP: `ReplicatedStorage.Shared`, `ServerScriptService.Server`,
   `StarterPlayer.StarterPlayerScripts.Client`, `ReplicatedStorage.Packages.Knit` exist.
5. Live edit test: change a marker string in `src/shared/Config/GameConfig.luau` (or any module),
   wait ~2 s, read that ModuleScript's `.Source` via `execute_luau` (read `.Source`, never
   `require`: requires are cached) and confirm the change arrived. Revert the edit, confirm again.
6. Stop the server when done (or leave it for the user).

CHECK: structure present and the live edit round-tripped.

---

## Toolkit repo (once per user, then reused)

`<TOOLKIT>` is itself a PRIVATE git repo (the SyphoDev licence allows modification for own use,
not resale; keep it private). It versions only small hand-made files: `bootstrap/`, `README.md`,
and `skills/` + `agents/` snapshots made by `sync_skills.py export` (generated VFX
textures/meshes excluded). Its `.gitignore` excludes `inputs/ tools/ backups/ rigs/` and all work
folders. **In .gitignore a `#` comment must be on its own line**: a trailing comment silently
breaks the pattern (we staged 1.2 GB of Blender that way). Verify with
`git ls-files | cut -d/ -f1 | sort | uniq -c` before the first commit (expect ~300 files, ~3 MB).
The remote is a private repo the USER creates on github.com (empty, no README); ask before pushing.
After any skill improvement: `sync_skills.py export`, commit, push (with the user's OK).

---

## Phase L: Final report to the user

A table with every component: PASS/FAIL, version, evidence (command + key output line). Then the
list of things only the user can do, if any remain (secrets, Rojo click, Blender restart, app
restart, push approval). Then how to start:

```
/create-roblox-game complete the research and plan stage: <the game idea>
```
(one section per session; after approving a section, clear the chat and say
"continue with the development of the <game> game").

---

## Quality playbook: where AI is weak, and what we do about it

- **3D models.** Route by shape class (the 3D skill's fork): hard-surface props (food trays,
  crates, weapons, furniture, buildings) -> **Kiln** (code-as-model, exact, local); organic
  (creatures, characters, food with soft shapes) -> concept image (Cloudflare Flux) -> **Hi3DGen
  on a Hugging Face Space** -> Blender 4.5 decimate/UV/bake -> painted texture -> Open Cloud
  upload. Studio's `generate_mesh` (Cube 3D, ~10k tris) is the fallback, not the default.
  Check licences (`roblox-3d-model/references/licences.md`): Hunyuan3D excludes EU/UK/KR;
  Meshy/Tripo free tiers are not for commercial use. Judge every mesh in Studio, in context.
- **Animation.** Author as FK pose data on the calibrated rig, 30 fps, combat moves 0.3-0.7 s,
  five poses, exaggerate, render plain grey and LOOK at frames; animate only arms/torso for idles
  that must coexist with walking. Fallbacks: Studio MCP `generate_animation` (R15 from prompt),
  Animation Editor's Animation Capture (video to R15, <15 s clips) for natural locomotion. Upload
  with `upload_animation.py` before publishing (test animations don't play in live games).
- **VFX.** Build in the browser sim with the skill's generated textures (or the SyphoDev pack),
  follow the pro timing rules (flash 1-4 frames then gone, slash full-size on frame 1, long charge
  / tiny hit, white-hot core with colour at edges, dark under-stroke), pass `critic_gate.py` and
  the blind review, then build in Studio. Real meshes (Blender) instead of sprite stand-ins.
- **Every asset**: ask "is this the real thing or a stand-in?", verify in the engine, and wire it in.
- When the user corrects an output, write the fix into the skill (or memory) so it never recurs.

---

## Troubleshooting log (all observed for real)

| Symptom | Cause | Fix |
|---|---|---|
| `calibrate_rig.py`: `'Action' object has no attribute 'fcurves'` | Blender 5.x API | Use the 4.5 LTS portable (`$BLENDER`) |
| Rojo plugin refuses to connect / version error | CLI and plugin differ (protocol 4 vs 5) | Same version both sides |
| Every new module appears twice, Knit throws duplicate name | Two Rojo plugins or two connections | Keep one plugin; one `rojo serve`; one Connect |
| `lune run test`: "require path must start with a valid prefix" | Lune >= 0.9 require rules | patch P2 (`../tests/...`) |
| `studio_mcp.py`: "need exactly one Studio, found 0" on every 2nd call | fresh server sees Studio only after ~1-2 s | patch P4 (poll 15 s) |
| `studio_mcp.py`: "found 2/3" with only one place open | Studio start-page windows register as instances | patch P5 (ignore `mode: Unavailable`) |
| Computer-use `open_application` opened a new Studio | it launches instead of focusing | never call it while Studio runs; ask the user for clicks |
| Computer-use: "desktop shell is frontmost" on every click | the Claude window/shell holds focus | don't fight it; ask the user for the click |
| Studio MCP tools vanish mid-session | known disconnect every 5-15 min; toggle can turn off after updates | re-enable in Assistant > Manage MCP Servers, retry |
| `execute_luau` returns nothing | the script yielded | no yields; or `task.delay` and read later |
| `claude mcp add ... -e X=Y name` -> "Invalid environment variable format" | `-e` is variadic | name first, then `-e` |
| Blender MCP tool call hangs in a hand-written client | stderr pipe not drained | stderr to a file |
| Blender MCP `up_to_date: false`, few tools | addon older than server | reinstall addon with the same pinned version (Phase E) |
| `preflight.py`: "place saved to disk FAIL" on a cloud place | it needs the place id | `place_state.py --place-id <id>` / record ids in game.json |
| Two Blender MCP addons, port 9876 busy | old `addon.py` + new `blender_mcp.py` | move the old file to backups with Blender closed |
| VFX `build_library.py` respawns forever | run from stdin on Windows | run it as a file from its folder |
| Keys "MISSING" in the session right after the user set them | env is read when the app starts | fully restart the Claude app; verify from the registry meanwhile |
| HF token 401 | something other than the token was pasted | re-run `set-secret.ps1 -Name HF_TOKEN` (it now validates) |
| Studio MCP lists one instance, `mode: Unavailable` | Studio is on the start page (e.g. after a reboot) | user opens the game's place; never open it via computer-use |

---

## Appendix A: `patch_skills.py` (write to `<TOOLKIT>\bootstrap\patch_skills.py`)

```python
#!/usr/bin/env python3
"""Re-apply the local fixes to the SyphoDev Roblox skills after (re)installing them.

    python patch_skills.py            # apply (idempotent: safe to run any time)
    python patch_skills.py --check    # report only, exit 1 if anything is unpatched

Why each patch exists (all measured on this machine, 2026-11-13):

  P1  new_project.py pins a 2024 toolchain (rojo 7.4.1 ...) in aftman.toml. Rojo
      7.7.x speaks protocol 5; a 7.4/7.6 CLI cannot talk to the 7.7.1 Studio plugin.
      -> emit rokit.toml with the versions in PINS below.
  P2  The scaffold's lune/test.luau requires "tests/X.spec". Lune >= 0.9 resolves
      require() relative to the requiring FILE and demands a ./ ../ or @ prefix.
      -> "../tests/X.spec". (Specs already use ../src/..., which is correct.)
  P3  "aftman install" hints -> "rokit install".
  P4  studio_mcp.py asks list_roblox_studios once, immediately. A fresh StudioMCP.exe
      sees no Studio for ~0.6-1.6 s while the plugin re-registers, so every second
      call failed with "found 0". -> poll for up to 15 s.
  P5  (same function) an empty Studio start page registers as an instance with mode
      "Unavailable"; with one open, every call refused with "need exactly one Studio".
      -> ignore instances that have no place open.
  P6  preflight's "place saved" gate only accepted a place id from --place-id or the global
      ROBLOX_PLACE_ID env var, so a PUBLISHED game failed preflight. -> fall back to
      publish.place_id in ./design/game.json (per game, where new_game.py puts it).

Update PINS when you deliberately upgrade the toolchain (and re-run the gate test).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

PINS = {
    "rojo": "rojo-rbx/rojo@7.7.1",          # MUST match the Rojo plugin in Studio
    "wally": "UpliftGames/wally@0.3.2",
    "selene": "Kampfkarren/selene@0.32.0",
    "stylua": "JohnnyMorganz/StyLua@2.6.0",
    "lune": "lune-org/lune@0.11.1",
}

SKILLS = Path(os.environ.get("ROBLOX_SKILLS_DIR") or Path.home() / ".claude" / "skills")

ROKIT_BODY = "".join(f'{k} = "{v}"\n' for k, v in PINS.items())


def patches() -> list[tuple[str, str, str, str]]:
    """(label, relative file, old text, new text). Old text must be unique."""
    new_project = "roblox-code/scripts/new_project.py"
    return [
        ("P1 rokit template", new_project,
         'AFTMAN = """# {title} - pinned toolchain (run `aftman install`)\n[tools]\n'
         'rojo = "rojo-rbx/rojo@7.4.1"\nwally = "UpliftGames/wally@0.3.2"\n'
         'selene = "Kampfkarren/selene@0.28.0"\nstylua = "JohnnyMorganz/StyLua@0.20.0"\n'
         'lune = "lune-org/lune@0.8.9"\n"""',
         'AFTMAN = """# {title} - pinned toolchain (run `rokit install`)\n'
         '# LOCAL PATCH P1: rojo must match the Rojo plugin version in Studio.\n[tools]\n'
         + ROKIT_BODY + '"""'),
        ("P1 rokit filename", new_project,
         'write(root / "aftman.toml", AFTMAN.format(**fmt))',
         'write(root / "rokit.toml", AFTMAN.format(**fmt))'),
        ("P2 lune require", new_project,
         'local requirePath = `{{TESTS_DIR}}/{{fileName:gsub("%.luau$", "")}}`',
         'local requirePath = `../{{TESTS_DIR}}/{{fileName:gsub("%.luau$", "")}}`'),
        ("P3 readme hint", new_project,
         "aftman install                 # pinned tools",
         "rokit install                  # pinned tools"),
        ("P3 print hint", new_project,
         'print("  aftman install")',
         'print("  rokit install")'),
        ("P3 new_game hint", "create-roblox-game/scripts/new_game.py",
         'print(f"  cd {root} && aftman install && wally install")',
         'print(f"  cd {root} && rokit install && wally install")'),
        ("P4 studio poll", "create-roblox-game/scripts/studio_mcp.py",
         'def studio_id(c: Client, want: str | None) -> str:\n'
         '    ok, text = c.tool("list_roblox_studios", {})\n'
         '    studios = json.loads(text).get("studios", []) if ok else []',
         'def studio_id(c: Client, want: str | None) -> str:\n'
         '    # LOCAL PATCH P4: a fresh StudioMCP.exe needs ~1-2 s before Studio re-registers.\n'
         '    import time\n'
         '    studios: list = []\n'
         '    deadline = time.time() + 15\n'
         '    while True:\n'
         '        ok, text = c.tool("list_roblox_studios", {})\n'
         '        studios = json.loads(text).get("studios", []) if ok else []\n'
         '        # LOCAL PATCH P5: a Studio start page registers as mode "Unavailable" /\n'
         '        # "Place is not open". It can never be the target; ignore it.\n'
         '        studios = [s for s in studios if s.get("mode") != "Unavailable"]\n'
         '        if studios or time.time() > deadline:\n'
         '            break\n'
         '        time.sleep(0.5)'),
        ("P6 place id from game.json", "create-roblox-game/scripts/place_state.py",
         '    raw = cli_value if cli_value is not None else os.environ.get("ROBLOX_PLACE_ID", "")\n'
         '    try:\n'
         '        return int(str(raw).strip() or 0)\n'
         '    except ValueError:\n'
         '        return 0',
         '    raw = cli_value if cli_value is not None else os.environ.get("ROBLOX_PLACE_ID", "")\n'
         '    try:\n'
         '        pid = int(str(raw).strip() or 0)\n'
         '    except ValueError:\n'
         '        pid = 0\n'
         '    if not pid:\n'
         '        # LOCAL PATCH P6: each game records its own ids in design/game.json (publish.place_id);\n'
         '        # a global env var would be wrong for every other game. Read the game in the cwd.\n'
         '        try:\n'
         '            import json as _json\n'
         '            with open(os.path.join("design", "game.json"), encoding="utf-8") as fh:\n'
         '                pid = int((_json.load(fh).get("publish") or {}).get("place_id") or 0)\n'
         '        except (OSError, ValueError, TypeError, AttributeError):\n'
         '            pid = 0\n'
         '    return pid'),
    ]


def main() -> int:
    check_only = "--check" in sys.argv
    if not SKILLS.is_dir():
        print(f"skills folder not found: {SKILLS}")
        return 1
    bad = 0
    for label, rel, old, new in patches():
        path = SKILLS / rel
        if not path.exists():
            print(f"  MISSING  {label}: {rel} not installed")
            bad += 1
            continue
        text = path.read_text(encoding="utf-8")
        # "already patched" = the new text is present, OR an equivalent hand patch
        # (P4 was first applied by hand with a longer comment).
        marker = new.splitlines()[-1].strip() if label.startswith("P4") else new
        if marker in text and old not in text:
            print(f"  ok       {label}")
            continue
        if text.count(old) != 1:
            print(f"  CONFLICT {label}: expected text not found exactly once in {rel} "
                  "(the skill changed upstream - re-derive this patch by hand)")
            bad += 1
            continue
        if check_only:
            print(f"  TODO     {label}")
            bad += 1
            continue
        path.write_text(text.replace(old, new), encoding="utf-8", newline="")
        print(f"  patched  {label}")
    print("all patches applied" if not bad else f"{bad} patch(es) need attention")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
```

## Appendix B: `set-secret.ps1` (write to `<TOOLKIT>\bootstrap\set-secret.ps1`)

```powershell
<#
  Store an API key / token as a USER environment variable, without it ever appearing
  on screen, in PowerShell history, in a file, or in a Claude chat.

  Run it YOURSELF in a normal PowerShell window (not by pasting the key to Claude):

      powershell -ExecutionPolicy Bypass -File "D:\Roblox Studio Games\_RobloxAI\bootstrap\set-secret.ps1"
      powershell -ExecutionPolicy Bypass -File "...\set-secret.ps1" -Name HF_TOKEN

  Then FULLY quit and reopen the Claude app (system tray > Quit) so it picks up the
  new variable. Re-run any time to replace a key. -Remove deletes it.

  Where it lives: HKCU\Environment (your Windows user only). Every program you run as
  yourself can read it - that is how the skills use it - so never run untrusted tools
  with these set, and rotate the key on the Roblox Creator Hub if it ever leaks.
#>
param(
    [ValidateSet('ROBLOX_API_KEY', 'HF_TOKEN', 'CF_ACCOUNT_ID', 'CF_API_TOKEN', 'POLLINATIONS_TOKEN', 'ROBLOX_GROUP_ID')]
    [string]$Name = 'ROBLOX_API_KEY',
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'

if ($Remove) {
    [Environment]::SetEnvironmentVariable($Name, $null, 'User')
    Write-Host "$Name removed from your user environment." -ForegroundColor Yellow
    exit 0
}

Write-Host "Paste the value for $Name and press Enter (input is hidden):" -ForegroundColor Cyan
$secure = Read-Host -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim()
    if ([string]::IsNullOrWhiteSpace($plain)) { throw "Nothing was entered; $Name left unchanged." }
    [Environment]::SetEnvironmentVariable($Name, $plain, 'User')
    Write-Host "$Name saved to your user environment ($($plain.Length) characters)." -ForegroundColor Green

    if ($Name -eq 'ROBLOX_API_KEY') {
        # Same harmless probe the skills' preflight uses: GET an operation id that cannot
        # exist. 404 = the key authenticated; 401/403 = rejected. Creates nothing.
        $uri = 'https://apis.roblox.com/assets/v1/operations/00000000-0000-0000-0000-000000000000'
        try {
            Invoke-WebRequest -Uri $uri -Headers @{ 'x-api-key' = $plain } -UseBasicParsing -TimeoutSec 25 | Out-Null
            Write-Host "Open Cloud check: key authenticates." -ForegroundColor Green
        } catch {
            $code = $_.Exception.Response.StatusCode.value__
            if ($code -eq 404) { Write-Host "Open Cloud check: key authenticates (404 on a dummy id, as expected)." -ForegroundColor Green }
            elseif ($code -in 401, 403) { Write-Host "Open Cloud check: key REJECTED ($code). Check it has Assets Read+Write and is enabled." -ForegroundColor Red }
            else { Write-Host "Open Cloud check: inconclusive (HTTP $code / $($_.Exception.Message))." -ForegroundColor Yellow }
        }
        # Least privilege: the skills need only asset read+write (plus optional place publishing).
        try {
            $info = Invoke-RestMethod -Method Post -Uri 'https://apis.roblox.com/api-keys/v1/introspect' -ContentType 'application/json' -Body (@{ apiKey = $plain } | ConvertTo-Json) -TimeoutSec 25
            $names = @($info.scopes | ForEach-Object { $_.name })
            if ($names -notcontains 'asset') { Write-Host "Scopes: MISSING 'asset' (Assets Read+Write). Uploads will fail." -ForegroundColor Red }
            $extra = @($names | Where-Object { $_ -notin 'asset', 'asset-permissions', 'universe-places', 'universe.place' })
            if ($extra.Count -gt 0) {
                Write-Host "Scopes: this key also has $($extra.Count) permissions the skills never use (e.g. $(($extra | Select-Object -First 4) -join ', '))." -ForegroundColor Yellow
                Write-Host "        If it ever leaks they expose your whole account. Consider a key with only Assets Read+Write." -ForegroundColor Yellow
            } else { Write-Host "Scopes: minimal (good)." -ForegroundColor Green }
        } catch { Write-Host "Scopes: could not introspect ($($_.Exception.Message))." -ForegroundColor Yellow }
    }
    elseif ($Name -eq 'HF_TOKEN') {
        if (-not $plain.StartsWith('hf_')) { Write-Host "Warning: Hugging Face tokens start with 'hf_'. This value does not." -ForegroundColor Yellow }
        try {
            $me = Invoke-RestMethod -Uri 'https://huggingface.co/api/whoami-v2' -Headers @{ Authorization = "Bearer $plain" } -TimeoutSec 25
            Write-Host "Hugging Face check: token VALID (account type: $($me.type))." -ForegroundColor Green
        } catch { Write-Host "Hugging Face check: token REJECTED ($($_.Exception.Response.StatusCode.value__)). Copy it again from huggingface.co > Settings > Access Tokens." -ForegroundColor Red }
    }
    elseif ($Name -eq 'CF_API_TOKEN') {
        $acct = [Environment]::GetEnvironmentVariable('CF_ACCOUNT_ID', 'User')
        $uri = if ($acct) { "https://api.cloudflare.com/client/v4/accounts/$acct/tokens/verify" } else { 'https://api.cloudflare.com/client/v4/user/tokens/verify' }
        try {
            $r = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $plain" } -TimeoutSec 25
            Write-Host "Cloudflare check: token $($r.result.status)." -ForegroundColor Green
        } catch { Write-Host "Cloudflare check: token REJECTED ($($_.Exception.Response.StatusCode.value__)). Set CF_ACCOUNT_ID first for account-owned tokens." -ForegroundColor Red }
    }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Variable plain -ErrorAction SilentlyContinue
}
Write-Host "Now fully quit and reopen the Claude app so it sees the new value." -ForegroundColor Cyan
```

## Appendix C: `index_texture_pack.py` (write to `<TOOLKIT>\bootstrap\index_texture_pack.py`)

```python
#!/usr/bin/env python3
"""Install a pre-built VFX texture pack as the roblox-vfx texture library, and build its
catalog.json WITHOUT re-rendering (minutes instead of ~45+ minutes of CPU).

    python index_texture_pack.py "<pack folder>"          # install + index
    python index_texture_pack.py "<pack folder>" --dry-run

The SyphoDev VFX Texture Pack is the output of roblox-vfx's own generator
(sim/tex/lib/build_library.py): same folders, same file names, but no catalog.json, so
find_tex.py cannot search it. Every catalog field is recoverable from the PNGs:
  file/kind/category/family/style/index/grid  <- the path and file name
  size, coverage, thumb, last, moving         <- the alpha channel (same formulas as the builder)
  loop (flipbooks), tile (beams)              <- one tiny call of the family's own definition
Tags and ids use the builder's own TAGS table, so the result matches a native build.

Safety: the pack is COPIED (the original is untouched). Any existing library is moved to
lib.replaced-<time> next to it, never deleted. Pack files the installed generator does not
know are reported and skipped (a version mismatch you should look at).
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

SKILL_LIB_SRC = Path.home() / ".claude" / "skills" / "roblox-vfx" / "sim" / "tex" / "lib"
sys.path.insert(0, str(SKILL_LIB_SRC))
import build_library as BL  # noqa: E402  (the skill's own builder: jobs(), TAGS)
import texcore as C  # noqa: E402  (C.LIB = sim/textures/lib)

SPRITE = re.compile(r"^sprites/(?P<cat>[^/]+)/(?P<fam>.+)_(?P<st>[a-z]+)_(?P<i>\d\d)\.png$")
FLIP = re.compile(r"^flipbooks/(?P<cat>[^/]+)/(?P<fam>.+)_(?P<st>[a-z]+)_(?P<i>\d\d)_(?P<g>\d)x\d\.png$")
BEAM = re.compile(r"^beams/(?P<fam>.+)_(?P<st>[a-z]+)_(?P<i>\d\d)\.png$")


def alpha(path: Path) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    return np.asarray(im, dtype=np.float32)[..., 3] / 255.0


def known_files() -> set[str]:
    out = set()
    for kind, cat, fam, st, i, g in BL.jobs():
        if kind == "sprite":
            out.add(f"sprites/{cat}/{fam}_{st}_{i:02d}.png")
        elif kind == "flip":
            out.add(f"flipbooks/{cat}/{fam}_{st}_{i:02d}_{g}x{g}.png")
        else:
            out.add(f"beams/{fam}_{st}_{i:02d}.png")
    return out


_loop_cache: dict[tuple[str, int], bool] = {}
_tile_cache: dict[tuple[str, int], bool] = {}


def flip_loops(fam: str, i: int) -> bool:
    import flips as F
    key = (fam, i)
    if key not in _loop_cache:
        rng = np.random.default_rng(BL.seed_of("flip", "x", fam, i))
        m = 32
        x, y = C.grid(m)
        try:
            frame = getattr(F, fam)(rng)
            _loop_cache[key] = any(bool(frame(t, x, y, m).get("loop", False)) for t in (0.0, 0.5))
        except Exception:  # noqa: BLE001
            _loop_cache[key] = False
    return _loop_cache[key]


def beam_tiles(fam: str, i: int) -> bool:
    import beams as B
    key = (fam, i)
    if key not in _tile_cache:
        rng = np.random.default_rng(BL.seed_of("beam", "beams", fam, i))
        try:
            x, y = B.strip_grid(64, 16)
            _tile_cache[key] = bool(getattr(B, fam)(rng, x, y).get("tile", True))
        except Exception:  # noqa: BLE001
            _tile_cache[key] = True
    return _tile_cache[key]


def thumb(mask: np.ndarray) -> str:
    return "".join("1" if v else "0" for v in mask.ravel())


def entry(rel: str, path: Path) -> dict | None:
    a = alpha(path)
    if m := SPRITE.match(rel):
        n = a.shape[0]
        return {"file": rel, "kind": "sprite", "category": m["cat"], "family": m["fam"], "style": m["st"],
                "size": [n, n], "coverage": round(float((a > 0.5).mean()), 4),
                "thumb": thumb(a[:: max(1, n // 16), :: max(1, n // 16)] > 0.3)}
    if m := FLIP.match(rel):
        g = int(m["g"])
        size = a.shape[0]
        n = size // g
        per = [float((a[(k // g) * n:(k // g + 1) * n, (k % g) * n:(k % g + 1) * n] > 0.5).mean()) for k in range(g * g)]
        loop = flip_loops(m["fam"], int(m["i"]))
        return {"file": rel, "kind": "flip", "category": m["cat"], "family": m["fam"], "style": m["st"],
                "grid": g, "frames": g * g, "loop": loop, "size": [size, size], "coverage": round(max(per), 4),
                "last": round(per[-1], 4), "moving": bool(float(np.std(per)) > 1e-4 or loop),
                "thumb": thumb(a[::64, ::64] > 0.3)}
    if m := BEAM.match(rel):
        h, w = a.shape
        return {"file": rel, "kind": "beam", "category": "beams", "family": m["fam"], "style": m["st"],
                "size": [w, h], "tile": beam_tiles(m["fam"], int(m["i"])),
                "coverage": round(float((a > 0.5).mean()), 4), "thumb": thumb(a[::32, ::64] > 0.3)}
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pack")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    pack = Path(a.pack)
    files = sorted(p.relative_to(pack).as_posix() for p in pack.rglob("*.png") if not p.relative_to(pack).as_posix().startswith("_sheets/"))
    known = known_files()
    unknown = [f for f in files if f not in known]
    usable = [f for f in files if f in known]
    print(f"pack: {len(files)} textures | known to this skill version: {len(usable)} | unknown: {len(unknown)}")
    for f in unknown[:10]:
        print("  unknown (skipped):", f)
    print(f"generator families not in the pack: {len(known - set(files))} (pruned duplicates are expected)")
    if a.dry_run:
        return 0

    lib = Path(C.LIB)
    t0 = time.time()
    if lib.exists():
        aside = lib.with_name(f"lib.replaced-{time.strftime('%Y%m%d-%H%M%S')}")
        lib.rename(aside)
        print(f"existing library moved aside to {aside}")
    lib.mkdir(parents=True)
    for rel in usable:
        dst = lib / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(pack / rel, dst)
    if (pack / "_sheets").is_dir():
        shutil.copytree(pack / "_sheets", lib / "_sheets")

    out = []
    for k, rel in enumerate(usable, 1):
        e = entry(rel, lib / rel)
        if e is None:
            continue
        e["tags"] = (BL.TAGS.get(e["category"], "") + " " + e["family"].replace("_", " ") + " " + e["style"]).split()
        e["id"] = "sim:lib/" + e["file"][:-4]
        out.append(e)
        if k % 500 == 0:
            print(f"  indexed {k}/{len(usable)}", flush=True)
    cat = {"note": "Generated VFX texture library (installed from a pre-built pack, indexed by "
                   "index_texture_pack.py). id = the Texture value to use in the sim (Studio: upload the png).",
           "textures": sorted(out, key=lambda e: e["file"])}
    (lib / "catalog.json").write_text(json.dumps(cat, indent=0))
    print(f"done: {len(out)} textures installed and indexed in {time.time() - t0:.0f}s -> {lib / 'catalog.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

## Appendix D: `luau_gate.py` (write to `<game>\.claude\hooks\luau_gate.py`)

```python
#!/usr/bin/env python3
"""PostToolUse hook: after Claude edits a Luau file, run the four roblox-code gates.

Reads the hook payload (JSON) on stdin. Only reacts to Edit/Write/MultiEdit on *.luau/*.lua
files inside this project. Exit 0 = gates green (silent). Exit 2 = a gate failed: the failure
text goes to stderr, which Claude Code feeds back to the model so it fixes the code before
anything reaches Studio. Never blocks on its own errors (exits 0 if the checker is missing).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECK = Path.home() / ".claude" / "skills" / "roblox-code" / "scripts" / "check.py"


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:  # noqa: BLE001
        return 0
    path = (payload.get("tool_input") or {}).get("file_path") or ""
    if not path.lower().endswith((".luau", ".lua")):
        return 0
    try:
        Path(path).resolve().relative_to(ROOT)
    except ValueError:
        return 0  # a Luau file outside this game (e.g. a skill's script): not ours to gate
    if not CHECK.exists():
        return 0
    env = dict(os.environ, NO_COLOR="1", PYTHONIOENCODING="utf-8")
    r = subprocess.run([sys.executable, str(CHECK)], cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=300, env=env)
    if r.returncode == 0:
        return 0
    import re
    out = re.sub(r"\x1b\[[0-9;]*m", "", r.stdout + r.stderr).strip()
    sys.stderr.write(
        "roblox-code gates FAILED after editing " + os.path.basename(path)
        + ". Fix this before continuing (do not hand broken code to Rojo/Studio):\n"
        + out[-3500:] + "\n")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
```

## Appendix E: `sync_skills.py` (write to `<TOOLKIT>\bootstrap\sync_skills.py`)

```python
#!/usr/bin/env python3
"""Keep a versioned copy of YOUR improved Roblox skills + agents in this toolkit repo.

    python sync_skills.py export     # ~/.claude -> <toolkit>/skills, <toolkit>/agents  (then git commit)
    python sync_skills.py restore    # <toolkit> -> ~/.claude (new PC / broken install)
    python sync_skills.py status     # what differs, without copying

The skills improve every time a correction is written back into them; without this they only
live in ~/.claude on one PC. Generated, re-creatable data is NOT copied (VFX textures/meshes:
rebuild with index_texture_pack.py + the mesh scripts, see ROBLOX_AI_SETUP.md).
restore moves any existing skill folder to <toolkit>/backups/skills-<time>/ first; never deletes.
LOCAL.md files are included (paths only, never secrets) so a restore on the same layout just works.
"""
from __future__ import annotations

import filecmp
import shutil
import sys
import time
from pathlib import Path

TOOLKIT = Path(__file__).resolve().parents[1]
CLAUDE = Path.home() / ".claude"
SKILLS = ["create-roblox-game", "roblox-3d-model", "roblox-animation", "roblox-build-orchestrator",
          "roblox-code", "roblox-map", "roblox-sfx", "roblox-skills-setup", "roblox-texture-gen",
          "roblox-ui", "roblox-vfx"]
# generated or cache data, relative to a skill folder (re-creatable, large)
EXCLUDE_DIRS = {"roblox-vfx": ["sim/textures", "sim/meshes"]}
EXCLUDE_NAMES = {"__pycache__", ".cache", "node_modules"}
EXCLUDE_SUFFIX = {".pyc"}


def wanted(skill: str, rel: Path) -> bool:
    if any(p in EXCLUDE_NAMES for p in rel.parts) or rel.suffix in EXCLUDE_SUFFIX:
        return False
    return not any(rel.as_posix() == d or rel.as_posix().startswith(d + "/") for d in EXCLUDE_DIRS.get(skill, []))


def files(root: Path, skill: str) -> dict[str, Path]:
    if not root.is_dir():
        return {}
    return {p.relative_to(root).as_posix(): p for p in root.rglob("*")
            if p.is_file() and wanted(skill, p.relative_to(root))}


def pairs():
    for s in SKILLS:
        yield s, CLAUDE / "skills" / s, TOOLKIT / "skills" / s
    yield "agents", CLAUDE / "agents", TOOLKIT / "agents"


def diff(src: Path, dst: Path, name: str):
    a = files(src, name)
    b = files(dst, name)
    if name == "agents":
        a = {k: v for k, v in a.items() if k.startswith("roblox-")}
        b = {k: v for k, v in b.items() if k.startswith("roblox-")}
    changed = [k for k in a if k in b and not filecmp.cmp(a[k], b[k], shallow=False)]
    return a, b, sorted(set(a) - set(b)), changed, sorted(set(b) - set(a))


def copy(src: Path, dst: Path, name: str, prune: bool) -> int:
    a, b, new, changed, gone = diff(src, dst, name)
    for k in new + changed:
        (dst / k).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(a[k], dst / k)
    if prune:
        for k in gone:
            (dst / k).unlink()
    return len(new) + len(changed) + (len(gone) if prune else 0)


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        for name, live, repo in pairs():
            _, _, new, changed, gone = diff(live, repo, name)
            if new or changed or gone:
                print(f"{name}: {len(changed)} changed, {len(new)} only in ~/.claude, {len(gone)} only in repo")
                for k in (changed + new)[:8]:
                    print("    ", k)
        print("status done")
    elif cmd == "export":
        n = sum(copy(live, repo, name, prune=True) for name, live, repo in pairs())
        print(f"exported {n} file changes into {TOOLKIT}  (now: git add -A && git commit)")
    elif cmd == "restore":
        stamp = time.strftime("%Y%m%d-%H%M%S")
        for name, live, repo in pairs():
            if name != "agents" and live.exists():
                bk = TOOLKIT / "backups" / f"skills-{stamp}" / name
                bk.parent.mkdir(parents=True, exist_ok=True)
                shutil.copytree(live, bk)
            n = copy(repo, live, name, prune=False)
            print(f"restored {name}: {n} files")
        print("Now re-run patch_skills.py --check, and rebuild VFX textures/meshes if this is a new PC.")
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```
