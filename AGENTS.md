# Fabrikao!! — agent guide

World of Warcraft professions addon (name: "Fabrikao" ~ Spanish "fabricar", to craft). CurseForge summary: "Your professions companion: browse recipes, plan what to craft, and find out where to get every recipe and ingredient."
Planned features: information about professions and recipes, help with crafting, locating recipes and ingredients. **Not built yet**:
this repo is the skeleton cloned from the sibling addons' infra (TOC, entry point, localization, per-character/shared settings,
tests, CI, release). Targets Retail, TBC Anniversary, Classic Era and the Classic "Forever" beta (`## Interface: 120100, 20506, 11509, 16001`);
development targets Forever first.
Public repo `LechuckThePirate/Fabrikao` (branch `master`), GPLv3, CurseForge project id 1733457. Siblings with the
same conventions: `Completao` (the original template), `Embolsao` and `Aggreao`, under `D:\Source\WowAddons\`.

## How to work with the maintainer

- **Chat in Spanish from Spain** ("tú", never Argentine voseo: not "tenés", "contame", "dale"). **Everything committed is in English**:
  code comments, test names, docs, workflow comments, commit messages. Spanish only in the esES/esMX table of `Localization/Locale.lua` (the `esMX` TOC notes
  are Spanish too).
- Windows machine. Prefer the PowerShell tool over Bash. Multi-line commit messages: write a file and use `git commit -F <file>`.
- Work happens in git worktrees (`.claude/worktrees/<name>`, branch `claude/<name>`). **After every change (tests green) commit and
  push** (`git push origin HEAD`). **Merging to `master` and releasing only happen when the maintainer asks.**
- Keep the maintainer informed in one or two short lines during long tasks.

## Layout

Addon files at the repo root, packaged as the folder `Fabrikao` (`.pkgmeta`):

- `Fabrikao.toc` (load order), `Fabrikao.lua` (entry point: events and `/fabrikao`, `/fab`; loaded last)
- `Localization/Locale.lua` — English text is the key, with the Spanish (esES/esMX) table; more locales can be added as files
- `Modules/Settings/` — settings per character or shared by the account; new modules go in their own `Modules/<Area>/` folder and are
  added to the TOC. Every `X.lua` has `X.test.lua` next to it
- `test/` (WoW API mock + local runner), `setupTests.lua`, `Icons/` (addon icon), `images/screencaps/` (CurseForge description images),
  `images/fabrikao_propuesta_iconos.jpg` (the four icon proposals; `Icons/Fabrikao.png` is the top-left one, cut round and transparent, 256x256, with the gold background hue-shifted to red so the four sibling addons are easy to tell apart: Completao green, Embolsao gold, Aggreao blue, Fabrikao red)

## Commands (PowerShell, repo root)

```powershell
lua test/busted.lua                       # all tests, no busted install needed (Lua 5.1+)
busted -p ".test.lua" .                   # real busted (what CI runs, Lua 5.1)
luacheck Fabrikao.lua Localization Modules Fabrikao.test.lua test setupTests.lua   # if installed
```

No deploy script: copy or symlink the repo root as `Fabrikao` into
`D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\` (without `test/`, `images/`, `*.test.lua`, `setupTests.lua`), then
`/reload`.

## Code conventions

- Lua 5.1. Shared namespace: `local ADDON, ns = ...` in every file; no new globals (see `.luacheckrc`, add the game API a file uses to `read_globals`).
- English text is the localization key: `ns.L["Some text"]`; translations go in `Localization/`.
- Every module gets a `*.test.lua` next to it, starting with `dofile("setupTests.lua")`. CI runs luacheck and busted on Lua 5.1.
- Comments explain *why*, are short, and match the surrounding density. Match surrounding naming and idiom.
- Commit style: `feat(scope):`, `fix(scope):`, `perf(scope):`, `release: X.Y.Z -- short summary`.
- User-visible changes go in `CHANGELOG.md` (newest first, `New:` / `Fix:` bullets, plain sentences).

## Infra and release

- **CI:** `.github/workflows/ci.yml` (luacheck + busted on every push and PR).
- **Release** (only when asked): one commit `release: X.Y.Z -- short summary` that bumps `## Version` in `Fabrikao.toc` and adds the
  section to `CHANGELOG.md` (once a welcome/changelog window exists, as in Aggreao, also its `LATEST_CHANGELOG_TEXT`); then
  `git tag vX.Y.Z`, push `master` and the tag, and
  `gh workflow run release.yml --repo LechuckThePirate/Fabrikao --ref vX.Y.Z` (workflow_dispatch only; BigWigsMods/packager uploads to
  CurseForge with repo secret `CF_API_KEY` and creates the GitHub release). Watch with `gh run watch`.
- **Screenshots:** `images/screencaps/*.png` are shrunk and rsynced by `.github/workflows/sync-media.yml` (push to master touching that
  path, or `gh workflow run sync-media.yml`; skipped while there is no PNG) to
  `https://media.joanvilarino.online/fabrikao/images/screencaps/`, which `CURSEFORGE_DESCRIPTION.md` references.
  Secret `FABRIKAO_MEDIA_SSH_KEY` (private key `~/.ssh/id_ed25519_fabrikao_media`): restricted rsync-only VPS user `fabrikao-deploy`
  (`authorized_keys` forced to `rrsync -wo /srv/embolsao-media/fabrikao`, like `aggreao-deploy`; the same Caddy container serves it, so no
  Caddy change); the media host itself is configured in the Embolsao repo.
- `.pkgmeta` keeps images, tests and `CURSEFORGE_DESCRIPTION.md` out of the package.
