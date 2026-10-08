-- luacheck: Lua 5.1, the game's version. Runs in CI; locally:
--   luacheck Fabrikao.lua Localization Modules test setupTests.lua
std = "lua51"
max_line_length = 160
codes = true

exclude_files = {
    "tools/",
    ".github/",
    "images/",
}

-- what the addon defines as globals
globals = {
    "FabrikaoDB", "FabrikaoCharDB",
    "SlashCmdList", "SLASH_FABRIKAO1", "SLASH_FABRIKAO2",
}

-- the game's API and frames it uses (add here as the addon grows)
read_globals = {
    "C_AddOns", "C_Timer", "CreateFrame", "GetAddOnMetadata", "GetLocale",
    "strtrim",
}

-- tests (busted): they define and change the simulated game's globals on purpose
files["**/*.test.lua"] = { std = "+busted", globals = { "_G" }, allow_defined_top = true, ignore = { "111", "112", "113", "121", "122" } }
files["setupTests.lua"] = { std = "+busted", allow_defined_top = true, ignore = { "111", "112", "113", "121", "122" } }
files["test/"] = { std = "+busted", allow_defined_top = true, ignore = { "111", "112", "113", "121", "122", "131", "212" } }
