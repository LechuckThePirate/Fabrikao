# Changelog

## 0.1.3

- Fix: the "Craft" button is off when your bags hold nothing to craft the recipe with.
- New: a small public API for other addons, `FabrikaoAPI` (`ShowRecipesUsing(itemID)` opens the search page with the recipes that use that item). Embolsao!! uses it
  for the "Recipes" entry of its item menu.
- New: the search of every recipe lists its results like a profession's page (table or detailed view, with the same filters and sorting) and a click
  on one opens its panel next to the window, with the Craft button for the recipes you know.

## 0.1.2

- New: a welcome window, once per version (and with `/fab changelog` or the preferences' "What's new" button): what's new, where to report bugs, and
  links to the other addons of the same author (Embolsao!!, Completao!!, Aggreao!!), to copy and paste in a browser.
- New: the "Map" and "TomTom" buttons of the trainers, vendors and creatures are in the panel of the recipes you know too, not only of the ones you don't.
- New: the panel of a recipe you know has a "Craft" button, with how many your bags allow, that opens the game's profession window on that
  recipe, ready to craft there (the game does not let addons craft).

## 0.1.1

- Data: fresh recipe data (training costs and where some recipes are learned, as the public databases have them now).

## 0.1.0

First version, only for WoW Forever.

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
- Fix: the vendors and trainers shown for a recipe are the ones of your faction: the ones the data has no side for are left out when
  they stand in the other faction's capitals or starting zones. Up to five vendors are listed, each with its zone, and how many more there are.
- New: a click on a recipe of the list (table or detailed view) opens its panel next to the window with everything known about it:
  whether you know it, the skill it needs and how its colors look for you, what it makes, how many you can make, the ingredients
  with how many you have (bags, bank and other characters) and their prices, what the ingredients cost, what it sells for and
  the profit, the training cost, the item that teaches it and the full list of where it is learned (trainers, vendors, quests, drops).
  Shift-click still puts the recipe's link in the chat.
- New: in the recipe's panel the trainers, vendors and creatures that drop it are listed nearest first, with how far they are, when the
  game tells where you are (the ones on your map next, then the ones elsewhere).
- New: the trainers, vendors and creatures that drop the recipe you don't know have a "Map" button in the recipe's panel that opens the world map on them
  with a pin, and, with TomTom installed, a "TomTom" button that sets a waypoint (the ones in the zone you are in are listed first).
- New: the filters are dropdowns like the ones of the game's options, and there is a new one by category: the slot of armor (hands,
  wrist, chest...), the kind of weapon, bags, potions, elixirs, food, gems, trade goods, the slot an enchantment goes on... in both
  the profession's page and the search of every recipe. "Clear" moved next to the view button, and the sort dropdown has a
  "Descending" checkbox.
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
