# Changelog

## Unreleased

- New: window (`/fab`, the minimap button or a key binding) that lists the character's professions with the game's icons:
  the primary ones first, then First Aid, Cooking and Fishing, each with its skill bar.
- New: a profession's page lists the recipes the character knows (colored by difficulty, with how many can be made from the
  bags in brackets) and then the ones it doesn't know, with a search box (names and where to learn them) and a filter by source.
- New: the recipes you don't know show the skill they need and where they are learned (trainer, vendor, drop, quest), with the skill
  levels where they turn orange, yellow, green and grey in the tooltip. The search also looks at who sells or drops them.
- New: data for every recipe of every crafting profession (also the ones of professions you don't have), from public databases.
- New: search of every recipe in the game (the box above your professions, or `/fab find <text>`): by name, ingredient, vendor, drop,
  quest or zone, also for professions you don't have, with a detail panel (skill levels, what it makes, ingredients with how many you
  have, where to learn it) and a filter by profession.
- New: filters on a profession's recipes (where they are learned, color for your skill, learnable now / needs more skill, only what you can
  make now with your bags, hide grey), sorting (name, level, cost, auction value, how many you can make) and a "Clear" button.
  The "Known recipes" and "Not known" titles fold and unfold with a click.
- New: the search of every recipe has the same filters and sorting (source, color for your skill in each profession, learnable
  now / needs more skill, can make now, hide grey); with no text it lists everything that passes them. It knows which recipes you
  know and colors the others for your skill in their profession.
- New: integration with Embolsao: with the "Other characters" checkbox (next to "Can make now") the counts of what you can make
  include the bags and banks of your other characters, as Embolsao saved them (through Embolsao's new public API when it has it; without
  Embolsao nothing of this shows and everything works with the character's own items); the ingredient icons' tooltips say who has each
  item, and the details of the search show how many the others have. A preference turns it off.
- New: the detailed view shows the ingredients as icons too, with their tooltips (red when you lack them), like the table.
- New: two views of the recipe lists, chosen in the preferences or with the "View" button: table (icon, name, components,
  approximate cost, approximate auction value, level; click a title to sort) and detailed (big icon, three lines). In the table
  the components are the ingredients' icons with their count (red when you lack it on a recipe you know); hover one for the
  item's tooltip.
- New: preferences window (the gear next to the X): view, window scale, minimap button, chat messages, reset window position and
  size, reset filters, restore defaults. The window can be resized and remembers its size.
- The recipe lists no longer need the game's profession window: they come from the data.
- Now only for WoW Forever.
- `/fab probe`: diagnostic that saves what the client's profession API answers.

## 0.1.0

- Initial skeleton: TOC for Retail, TBC Anniversary, Classic Era and Forever, `/fabrikao` (`/fab`),
  saved variables (per character or shared), Spanish/English locale, tests and CI.
- Addon icon (anvil and hammer), transparent round PNG 256x256.
