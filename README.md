# Fabrikao!!

World of Warcraft professions addon. Your professions companion: browse recipes, plan what to craft, and find out where to get every recipe and ingredient.

**Work in progress**: for now this is the skeleton (TOC, `/fabrikao` and `/fab`, saved variables per
character or shared, Spanish/English locale, tests, CI and release); the features come next:

- Information about professions and recipes.
- Help with crafting.
- Where to find recipes and ingredients.

Only for WoW Forever (`Fabrikao.toc`: interface 16001).

## Install (development)

Copy or symlink this repo's root as `Fabrikao` into the client's AddOns folder:

```
World of Warcraft/_classic_beta_/Interface/AddOns/Fabrikao/
```

## Development

Layout, like [Completao!!](../Completao) and [Aggreao!!](../Aggreao): `Fabrikao.lua` (entry point),
`Localization/`, `Modules/`, a `*.test.lua` next to every module, `test/` (game API
mock and a local test runner) and `setupTests.lua`.

```
lua test/busted.lua                 # tests, no busted install needed (Lua 5.1+)
busted -p ".test.lua" .             # tests with busted (what CI runs, Lua 5.1)
luacheck Fabrikao.lua Localization Modules test setupTests.lua
```

CI (`.github/workflows/ci.yml`) runs luacheck and busted on every push and pull
request.

## Release

`Release to CurseForge` (`.github/workflows/release.yml`, run by hand from the
Actions tab) packages the repo with [BigWigsMods/packager](https://github.com/BigWigsMods/packager)
as the `Fabrikao` folder (`.pkgmeta`) and uploads it to CurseForge using the
`X-Curse-Project-ID` in the TOC. Needs the
`CF_API_KEY` repository secret.

### Description images

Screenshots in `images/screencaps/*.png` are resized, optimized and rsynced by
`.github/workflows/sync-media.yml` (on push to `master` touching that folder, or
by hand) to `https://media.joanvilarino.online/fabrikao/images/screencaps/`;
`CURSEFORGE_DESCRIPTION.md` references them by that URL. Needs the
`FABRIKAO_MEDIA_SSH_KEY` repository secret.

## License

GPL-3.0, see `LICENSE`.
