# Fabrikao!! — agent guide

World of Warcraft professions addon (name: "Fabrikao" ~ Spanish "fabricar", to craft). CurseForge summary: "Your professions companion: browse recipes, plan what to craft, and find out where to get every recipe and ingredient."
Features: information about professions and recipes (built: professions window, known and unknown recipes, search), help with
crafting and locating recipes and ingredients (planned; the maintainer adds ideas as they come). **Only for WoW Forever** (`## Interface: 16001`): no compatibility with other clients is needed, so code against Forever's API only.
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
- `Modules/Data/Inventory.lua` — what the OTHER characters carry and keep in their banks, from Embolsao's saved copies (account-wide):
  through Embolsao's public API (`EmbolsaoAPI`, since its branch `claude/public-api`: GetCharacters, GetOthersItemCount, GetItemHolders)
  when installed, else by reading its saved variable (`EmbolsaoDB.characterItems[key] = { name, class, time, bags = { [itemID] = n },
  bank = { [itemID] = n } }`), which older Embolsao versions need. Counts for "can make" go through `ns.Inventory_Count(itemID, alts)`;
  the `useAlts` preference turns it all off. **Embolsao (like Auctionator) is optional**: everything goes through this module, and without
  it the counts are the character's own, the "Other characters" checkbox is hidden and the preferences say it isn't installed (tests
  cover that path in `Alts.test.lua`); never reference `EmbolsaoAPI` / `EmbolsaoDB` anywhere else
- `Modules/Data/Prices.lua` — approximate prices for the table view: auction prices from Auctionator's public API when it is installed,
  else what vendors pay; `Modules/UI/RecipeList.lua` — the two views of the recipe list (table with sortable columns, detailed
  with a big icon); `Modules/UI/FilterBar.lua` — the two rows of filters and sorting shared by a profession's page and the search
  of every recipe (dropdowns of the game's menus, `WowStyle1DropdownTemplate` + `SetupMenu` with radios, falling back to cycling buttons when
  the templates are missing; each keeps its own filters: `ns.char.filters`, `ns.char.searchFilters`; the category of a recipe comes from
  its product item through `C_Item.GetItemInfoInstant`, `ns.RecipeDB_Category`); `Modules/UI/RecipeDetail.lua` — the panel of a recipe that opens next to the window
  on a click (`ns.RecipeDetail_Build` makes its content as data, `_Show`/`_Hide` the frame); `Modules/UI/Preferences.lua` — the gear's window (view, scale, resets)
- `Modules/Professions/` — `Professions.lua` (the character's professions, ordered: primary, First Aid, Cooking, Fishing) and `Recipes.lua`
  (a profession's recipes for the lists: from the data, with "known" from the spell book; the live answer of the game's window
  instead when that profession's tab is open; filtering, search and the "how many can I make" count from the bags)
- `Modules/UI/` — `MainWindow.lua` (professions page, recipes page), `SearchPage.lua` (search of every recipe in the data, with a detail
  panel) and `MinimapButton.lua`; `Bindings.xml` has the key binding (the game loads it itself: **never list it in the TOC**)
- `Data/Generated/Recipes.lua` (**generated, never edit by hand**) — every recipe of the crafting professions (skill levels where each
  turns orange / yellow / green / grey, ingredients, product, how it is learned), the items that teach them (vendors, drops, quests)
  and the trainers; `Data/Data.test.lua` checks its shape. `Modules/Data/RecipeDB.lua` queries it (by spell id, search by name /
  ingredient / NPC / zone, "where to learn it" lines)
- `Modules/Debug/Probe.lua` — `/fab probe` prints, per profession, how many of the data's recipes the client says are known (by each way
  of asking) and compares with the game's window when it is open; result also in `FabrikaoDB.probe` (SavedVariables file after `/reload`)
- `test/` (WoW API mock + local runner), `setupTests.lua`, `Icons/` (addon icon), `images/screencaps/` (CurseForge description images),
  `images/fabrikao_propuesta_iconos.jpg` (the four icon proposals; `Icons/Fabrikao.png` is the top-left one, cut round and transparent, 256x256, with the gold background hue-shifted to red so the four sibling addons are easy to tell apart: Completao green, Embolsao gold, Aggreao blue, Fabrikao red)

## Recipe data

`Data/Generated/Recipes.lua` comes from local tools in `tools/local/` (git-ignored, **never published, and the name of the web source is
never written in anything tracked**: README, CHANGELOG, CurseForge text, commit messages, code comments — credit it only as "public
databases", like Completao). Steps: `node tools/local/recipes_fetch.mjs` (a spell listing and a skill page per profession),
`node tools/local/recipes_items.mjs` (slow: one page per recipe item whose source isn't named yet; resumable; one request every 3 s,
the source answers 403 beyond that), then `node tools/local/recipes_write.mjs <worktree>/Data/Generated/Recipes.lua` (which also writes
`cache/npc_wanted.json`: the vendors, trainers and creatures of the data), `node tools/local/npc_coords.mjs` (where each stands: one page
each, for the map and TomTom buttons) and `recipes_write.mjs` again to put the positions in. Pages are cached in `tools/local/cache/`
(`CACHE_TTL_DAYS` and `REFRESH_BUDGET` make a run download the oldest ones again, a few at a time). Source codes in the data: 1 crafted, 2 drop, 3 PvP, 4 quest, 5 vendor, 6 trainer, 16 gathered, 21 salvaged.

## Forever's API (what the code relies on)

Forever runs on the retail engine: professions use `GetProfessions()` / `GetProfessionInfo(index)` for the list. **All professions live in one
window with tabs (K key)**, not one window each, and neither `C_TradeSkillUI.OpenTradeSkill` nor casting the profession spell from an
addon opened anything (no `TRADE_SKILL_*` event ever arrived), so the addon never opens it: the recipe lists come from the data and
"known" from `C_SpellBook.IsSpellKnown` / `IsPlayerSpell`; `C_TradeSkillUI` (`GetFilteredRecipeIDs`, `GetRecipeInfo`...) is only read when
the player has that profession's tab open. The game's own UI code for Forever (to check anything about the API) is the `forever` branch of
https://github.com/Gethe/wow-ui-source (`Interface/AddOns/Blizzard_Professions*`, `Blizzard_APIDocumentationGenerated`). Anything the docs
don't settle is verified in game with `/fab probe`.

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
- **Daily data refresh**, as in Completao: a cron job on the maintainer's VPS (`/etc/cron.d/fabrikao-data`, 03:20; `/opt/fabrikao-data/run.sh`,
  kept as `tools/local/vps/fabrikao-run.sh`) runs the tools above in a node container against a clone of this repo (the scripts and the page
  cache live in the clone's git-ignored `tools/local`; `tools/local/vps/deploy.ps1` copies them there, `-Cache` seeds the cache, `-Cron`
  installs the cron entry) and publishes `Recipes.lua` + `updated.txt` at `https://media.joanvilarino.online/fabrikao-data/` (a run
  that lost more than 5 % of the recipes publishes nothing). `.github/workflows/update-recipe-data.yml` (cron 05:50) fetches it, checks
  its shape and age, runs busted and opens the pull request `auto/recipe-data`, which the maintainer merges; nothing merges by itself.
  The server holds no credentials for this repo. Needs the repo setting "Allow GitHub Actions to create and approve pull requests".
  When the generator's output changes shape, update the scripts on the VPS with `deploy.ps1`. Log: `/var/log/fabrikao-data.log`.
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
