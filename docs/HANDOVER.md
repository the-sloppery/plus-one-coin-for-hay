# Collaboration handover

Public repository: **the-sloppery/plus-one-coin-for-hay**, transferred from Goy2Joy on October 4, 2026. GitHub verified `markus41` and `Goy2Joy` have admin access. Local checkout: `/Users/reece/goyisms/games/plus-one-coin-for-hay`.

| Source | Owns |
|---|---|
| shared/Catalog | Economy, contract definitions, equipment, needles and tiers |
| shared/GameState | Pure profile/round operations and save validation |
| shared/Queue, shared/Admission | Queue state and reserved roster validation |
| server/Main.server | Authoritative integration, remotes, sessions and loops |
| server/World | Original lobby, fields, prompts and visuals |
| server/Profiles, server/Travel | Session leases, persistence, reservations, retries and return |
| client/Main.client, client/View | Input, network wiring, HUD, menus and loading |
| tests/ | Domain, service, server integration and actual UI fixtures |
| tools/verify.py, tools/export.luau | Source-bound check receipts and production render exports |

Paths above live under src/ unless otherwise specified. Clone, install pinned tools, then use Rojo or a release `.rbxlx`. Change source, never generated builds. Fetch before delivery. Use feature branches/PRs and avoid simultaneous edits of Main.server. Update GAME_SPEC and tests when changing economy rules.

Hourly automation **Hourly haystack GitHub updates**, ID `hourly-haystack-github-updates`, runs on the originating Codex chat. It uploads completed, verified source and exact-commit builds, preserves collaborator commits, and stays quiet without new work. It skips unfinished/failing candidates, never force-pushes or publishes to Roblox, and depends on the desktop automation environment being available.

Before acceptance: native 2–6-client checks for all four queues, host/disconnect behavior, collection races and input; owner-approved private Roblox experience tests for reservation/arrival/retry/return; real save reload, lock conflicts, outages/recovery; physical touch/gamepad and six-player performance. VERIFICATION.md records what actually ran.
