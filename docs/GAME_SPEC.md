# Game specification

Reference inspected October 4, 2026: [official Steam description](https://store.steampowered.com/app/5085740/Needle_In_A_Haystack/). It confirms six-player co-op, searching hay, earning money, equipment, collectible needles, movable/throwable objects and discoveries. It does not describe contracts, prices, drop rates or secret-event rules. The economy and contracts below are original Roblox adaptation rules, not exact Steam parity claims.

## Essential loop

1. Enter a square, form a group of 1–6, and start an expedition.
2. Clear patches cooperatively. Each removed hay unit gives its digger one coin.
3. Fully clearing a needle's patch reveals a collectible object. Collection adds its type and catalog coin reward to every current expedition member once.
4. Claim accepted contracts; buy stronger search equipment.
5. Collect three needles to win. Host starts a denser pile or players return to the village; collection, equipment and contracts persist in published games.

Hay uses **81 patches with virtual counts and primitive straw geometry**, not millions of physics objects. Piles taper toward the edges, shrink while clearing, and cap physical height at eight studs. Density increases through pile 20. Locations remain server-side until revealed. Three different types appear per pile, rotating across six original types; pile one has sewing, copper and garden needles. Seeds and rewards are server-owned.

Secondary features: three buried keepsakes per pile (+50 to discoverer), a lost boot (+50 once per expedition), four throwable hay bales with server-owned physics and out-of-bounds recovery, magnet, auto rake, album, cross-platform input and scrolling menus. Steam achievements/cloud/leaderboards, exact secrets, its full item physics sandbox and undocumented equipment are not verified parity. “100 Days” refers to the requested queue/group/departure flow; no survival day counter is added.

## Contracts and progression

Three accepted, unfinished contracts maximum per player. Events before acceptance do not count. Duplicate accepts, locked accepts, early claims and repeated claims fail server validation. Completed contracts are permanent and free their active slot. Contracts and progress persist. First handful is auto-accepted for a new profile's first expedition; the others are opt-in. No paid rerolls or timers.

| Contract | Tier | Requirement after acceptance | Coins | XP |
|---|---:|---|---:|---:|
| First handful | 1 | Personally clear 30 hay | 40 | 25 |
| Clear the field | 1 | Personally clear 180 hay | 120 | 60 |
| Sharp eyes | 1 | Expedition collects 1 needle | 90 | 40 |
| Lost and found | 2 | Personally discover 1 keepsake or boot | 100 | 50 |
| Helping hands | 2 | Other members clear 300 hay while you are present | 180 | 80 |
| Copper commission | 3 | Expedition collects 1 copper needle | 220 | 100 |
| Big harvest | 3 | Personally clear 600 hay | 350 | 150 |
| Needle curator | 4 | Expedition collects 5 needles | 500 | 200 |

Tier XP thresholds: **0 / 100 / 175 / 325**. Starter-tier contracts total 125 XP; Lost and found reaches 175; Big harvest reaches 325. Solo players can reach all equipment tiers without Helping hands. Contracts are a finite onboarding track; collection and procedural piles continue afterward.

## Economy and equipment

Start with zero coins/XP. No monetization, premium currency or wagers. Client never specifies a reward or price. Needle team rewards: sewing 30, copper 45, garden 60, frost 80, royal 100, sunburst 150. Disconnected players do not receive subsequent events. Collection keeps the needle in the album; there is no separate sale/delivery step.

| Equipment | Tier | Prices | Behavior |
|---|---:|---|---|
| Rake | 1 | 60 / 180 / 450 | Manual clear increases from 1 to 4 / 7 / 11 units |
| Needle magnet | 1 | 150 | Every 2 seconds, collects exposed needles within 14 studs |
| Leaf blower | 2 | 250 | Successful manual clear also removes up to 2 units from adjacent grid cells |
| Auto rake | 3 | 400 | Every 2 seconds, clears up to 2 units from the closest patch within 14 studs |

Rewards are clamped to actual remaining hay. Own clearing, including automation, counts toward personal contracts; others' clearing feeds Helping hands.

## Lobby, sessions and travel

Four colored squares. First entrant hosts; capacity defaults to six and host may set any integer 1–6 not below occupancy. At most one queue/session per player. Host starts immediately or a 20-second countdown starts with first entry. Membership persists until leave, switching squares, death or disconnect. Host departure hands control to next entrant. Empty queues reset timer/capacity. Launch frees the square for the next group; seventh entrant is rejected.

Studio: separated fields, character PivotTo, temporary profiles, no production MemoryStore construction. Published: one reserved server per group, 180-second MemoryStore party roster, group TeleportAsync. Only a routing identifier crosses TeleportData. Inventory/currency remain in server DataStore. Failed/late travel retries at most three times into the same reservation; a 30-second watchdog restores stranded lobby controls. Successful members may arrive before a failed member's retry. Host absence after 30 seconds transfers control. Return saves first; failed return restores field controls.

## Authority and saves

Validate membership, live character, distance, bounded catalog/cell IDs and request rate. Prompt and remote digging share a 0.2-second cooldown; general remote route accepts at most one request per 0.08 seconds. Empty hay, hidden needles and repeated collections cannot pay. Bales stay server-owned and reset when too far away.

Published profiles: UpdateAsync, 120-second token lease, 30-second autosave, deep snapshots before yielding and ownership checks before writes. Corrupt/future saves and unavailable loads fail closed. Save outages are surfaced; expired ownership freezes gameplay and forces safe reconnect. Departure/shutdown saves use bounded retries. Crashes can lose changes since the last successful save; live outage/recovery tests remain required. Studio never writes production saves.
