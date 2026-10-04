# +1 Coin for Hay

A source-first Roblox co-op haystack search for **1–6 players**, inspired by [Needle In A Haystack by NoGlyph](https://store.steampowered.com/app/5085740/Needle_In_A_Haystack/). This repository contains original Luau, primitive geometry, UI and needle designs; no Steam code, art, music or models.

**Public shared repository:** https://github.com/the-sloppery/plus-one-coin-for-hay. GitHub admin access verified for `markus41` and `Goy2Joy`. Hourly verified source/build delivery is configured in the originating Codex chat.

## Play in Studio

Download the `.rbxlx` from GitHub Releases, open it in Studio, and press Play. Walk into one of four colored squares. First entrant becomes host; open **Expedition** to set maximum party size (1–6), start now, or leave. A 20-second countdown also starts the group. Studio uses isolated local fields and temporary profiles, without cloud access.

Clear hay through proximity prompts or **F / right trigger / touch action**. Every hay unit removed earns one coin. Uncover and collect three needles to win a pile; rewards and collection entries go to the whole expedition. **Journal** shows contracts and your collection; **Equipment** sells upgrades; **Expedition** starts the next pile or returns to the village. **J / gamepad Y** opens the journal; **gamepad B** closes it. Toss hay bales and hunt for buried keepsakes or the lost boot.

## Develop

Use pinned tools in `rokit.toml`. No Wally packages or external UI framework are required.

```sh
mkdir -p build
rojo serve default.project.json
rojo build default.project.json -o build/plus-one-coin-for-hay.rbxlx
stylua --check src tests tools
selene src
lune run tests/run.luau
lune run tests/integration.luau
lune run tests/ui.luau
```

In the GoYisms workspace, run the combined verifier:

```sh
python3 tools/verify.py --luaudit-hook ../../agent/plugins/luaudit/scripts/luaudit_hook.py
```

Standalone clones can install luaudit and use `python3 tools/verify.py`. CI checks format, lint, all three suites, Roblox type analysis and Rojo build. Generated files belong in ignored `build/`, `outputs/` and `previews/`. The build creates its world and UI on Play.

## Published setup

Publish the same place as the experience start place and set **Max Players 24** for four six-player queues. Public lobbies reserve another server of their own `game.PlaceId`; reserved servers omit the lobby, verify a server-written party roster, and enforce six-player field membership. No second place ID is needed. Choose **Secure within universe only** access; leave third-party teleports disabled.

Published profiles use `HayProfiles_v1` with session leases and autosaves. Studio uses memory only. Do not enable Studio production-save access for testing. Reserved-server teleports require a published Roblox-client test. These deployment steps have not been performed by this repository.

See [GAME_SPEC](docs/GAME_SPEC.md), [HANDOVER](docs/HANDOVER.md) and [VERIFICATION](docs/VERIFICATION.md).
