# +1 Coin for Hay development

Read README.md, docs/GAME_SPEC.md, docs/HANDOVER.md and docs/VERIFICATION.md first. In GoYisms also read ../../AGENTS.md and ../../agent/README.md; standalone clones do not require those external files.

Rojo source files are authoritative. Server owns membership, saves, rewards and prices; clients send bounded intent and display state. Use strict Luau and native Roblox UI. No external assets or package dependencies are required.

After edits run pinned StyLua, Selene, the three Lune suites, Roblox type analysis/luaudit and Rojo build. Expected test counts matter, not just exit codes. Export actual World/View modules with tools/export.luau and render with RHR after UI/3D edits. Use Studio for native proof. Keep fixture, rendering, Studio and published-client evidence separate.

Preserve collaborator commits. Fetch before delivery, never force-push or rewrite published tags/assets. After the initial baseline prefer feature branches and PRs for integration. Build release files from the exact committed source. Never commit secrets or personal logs. Studio diagnostics under tools/ must be excluded from production builds and run only in Studio.
