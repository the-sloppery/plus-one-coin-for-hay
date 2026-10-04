# Verification record

Initial candidate checked October 4, 2026. Release receipts identify the exact source commit and build SHA-256. A GitHub Actions run is required for each pushed candidate; its result is visible in the repository Actions tab.

## Checks actually run

| Layer | Command / observation | Result |
|---|---|---|
| Formatting | `stylua --check src tests tools` | Pass |
| Domain and service fixtures | `lune run tests/run.luau` | 45 passed, 0 failed |
| Production server integration, mocked services/physics | `lune run tests/integration.luau` | 15 scenarios passed |
| Production View with UI/service fixtures | `lune run tests/ui.luau` | 8 scenarios passed |
| Sourcemap and build | `rojo sourcemap`, `rojo build` | Pass |
| Luaudit | workspace `luaudit_hook.py check src --warnings` | Pass, no errors/warnings |
| Production headless exports | `lune run tools/export.luau` per mode, RHR check with all devices | Five modes, no error findings; warning details below |
| 3D rendering | RHR scene of exported production lobby and field | Both rendered, zero reported missing assets/fallbacks |
| Native Studio 0.741.19.7411056 | Open generated place, Play; position test character on square 3 through server command bar; client Expedition then Start now | Lobby/UI and 1/6 queue observed; one-player session and field/pile UI observed |

The first native launch exposed a MemoryStore construction error in an unpublished Studio place. Travel now avoids cloud map construction in Studio; its regression test passed and a rebuilt place started successfully. The native observation used the same production source as the release candidate; subsequent changes were export/verification tooling and documentation. The server command bar assisted character positioning only; session start used the actual client button and server route. Native checks stopped when the Mac locked. No further native flow or six-client session is claimed.

## Rendering findings

RHR renders actual World and View modules with explicit no-physics/service fixtures. Lune does not mirror Position/CFrame or Font/FontFace automatically; the exporter normalizes those stored properties. Phone and desktop images plus JSON findings are generated under ignored outputs/render/. Scene renders depict original primitives, without Roblox physics, lighting parity or avatar/input simulation.

The all-device scan reports a Journal HUD button warning against its broad landscape-phone thumbstick rectangle. Modal screens report touch-control warnings and notch warnings on scroll children: Close.Modal hides Roblox touch controls while the journal is open, and ScrollingFrame clips off-screen entries. The current scanner does not account for those behaviors. These warnings remain recorded, not silently suppressed. Native phone/touch validation is still needed, especially the HUD thumbstick region. Visible menu buttons are 44 pixels high; UI fixtures cover focus, modal state and stable updates.

## Acceptance work still required

- Native 2–6-client playtests of all four squares, capacity, timer, disconnects and collection races.
- Published Roblox-client reserved-server departure, roster admission, retries and return. Studio cannot validate TeleportService travel.
- Published DataStore reloads, lock conflicts, failure/recovery and shutdown saves. Service fixtures establish bounded behavior, not live storage proof.
- Physical touch/gamepad, performance with six participants and final gameplay/art balancing.

The build is a playable prototype for collaboration. It is not a completed published Roblox release. Steam's undocumented contracts, equipment prices and secret rules were not available from the inspected store description; GAME_SPEC distinguishes this adaptation's original rules from confirmed reference features.
