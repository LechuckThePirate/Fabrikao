local _, ns = ...

-- Keys are the English text; on esES/esMX clients they are replaced by the Spanish one.
local es = {
    ["initializing..."] = "inicializando...",
    ["initialization complete"] = "inicialización completa",
    ["Usage: /fabrikao | find <recipe> | minimap | version"] = "Uso: /fabrikao | find <receta> | minimap | version",
    ["Open / close the window"] = "Abrir / cerrar la ventana",

    -- minimap button
    ["Left-click: open"] = "Clic izquierdo: abrir",
    ["Drag: move"] = "Arrastrar: mover",
    ["Minimap button hidden."] = "Botón del minimapa oculto.",
    ["Minimap button shown."] = "Botón del minimapa mostrado.",

    -- professions
    ["Professions"] = "Profesiones",
    ["Secondary professions"] = "Profesiones secundarias",
    ["Skill: %d / %d"] = "Habilidad: %d / %d",
    ["Click to see its recipes"] = "Clic para ver sus recetas",
    ["This profession has no recipes"] = "Esta profesión no tiene recetas",
    ["No professions learned yet."] = "Todavía no has aprendido ninguna profesión.",
    ["< Professions"] = "< Profesiones",

    -- recipes
    ["Known"] = "Conocida",
    ["Not known"] = "No conocidas",
    ["Known recipes"] = "Recetas conocidas",
    ["%d shown, %d known, %d not known"] = "%d mostradas, %d conocidas, %d no conocidas",

    -- filters, sorting and views of the lists
    ["Can make now"] = "Puedo fabricar ya",
    ["Hide grey"] = "Ocultar grises",
    ["Clear"] = "Limpiar",
    ["Color: %s"] = "Color: %s",
    ["Skill: %s"] = "Habilidad: %s",
    ["Sort: %s"] = "Orden: %s",
    ["View: %s"] = "Vista: %s",
    ["Learnable now"] = "Aprendibles ya",
    ["Needs more skill"] = "Piden más habilidad",
    ["Default"] = "Por defecto",
    ["Name"] = "Nombre",
    ["Components"] = "Componentes",
    ["Cost"] = "Coste",
    ["AH value"] = "Valor SC",
    ["Level"] = "Nivel",
    ["Can make"] = "Puedo fabricar",
    ["List"] = "Lista",
    ["Table"] = "Tabla",
    ["Detailed"] = "Detallada",
    ["Ingredients cost: %s"] = "Coste de los ingredientes: %s",
    ["Needs %d, you have %d"] = "Hacen falta %d, tienes %d",
    ["Sells for about: %s"] = "Se vende por unos: %s",
    ["Cost %s   AH %s"] = "Coste %s   SC %s",

    -- preferences
    ["Preferences"] = "Preferencias",
    ["Fabrikao!! Preferences"] = "Preferencias de Fabrikao!!",
    ["Settings are saved for this character only."] = "Los ajustes se guardan solo para este personaje.",
    ["Settings are shared by all your characters."] = "Los ajustes son comunes a todos tus personajes.",
    ["Character specific preferences"] = "Preferencias por personaje",
    ["View of the recipes"] = "Vista de las recetas",
    ["List (one line per recipe)"] = "Lista (una línea por receta)",
    ["Table (columns: components, cost, value, level)"] = "Tabla (columnas: componentes, coste, valor, nivel)",
    ["Detailed (big icon, three lines)"] = "Detallada (icono grande, tres líneas)",
    ["Window scale: %d%%"] = "Escala de la ventana: %d%%",
    ["Show the minimap button"] = "Mostrar el botón del minimapa",
    ["Show chat messages at startup"] = "Mostrar mensajes en el chat al iniciar",
    ["Prices: Auctionator found (auction prices are used)."] = "Precios: Auctionator encontrado (se usan los precios de la casa de subastas).",
    ["Prices: Auctionator not found (costs use what vendors pay, there is no auction value)."] =
        "Precios: no se encuentra Auctionator (los costes usan lo que pagan los vendedores y no hay valor de subasta).",
    ["Reset window position and size"] = "Restablecer posición y tamaño de la ventana",
    ["Reset filters"] = "Restablecer filtros",
    ["Restore default preferences"] = "Restaurar preferencias por defecto",
    ["Search recipes (name or where to learn them)..."] = "Buscar recetas (nombre o dónde aprenderlas)...",
    ["Source: %s"] = "Origen: %s",
    ["All"] = "Todos",
    ["Other"] = "Otro",
    ["Where to learn it"] = "Dónde aprenderla",
    ["Turns grey at skill %d"] = "Se vuelve gris con habilidad %d",
    ["Reading recipes..."] = "Leyendo recetas...",
    ["Could not read this profession's recipes."] = "No se pudieron leer las recetas de esta profesión.",
    ["No recipes match"] = "Ninguna receta coincide",

    -- search of every recipe
    ["Search any recipe in the game..."] = "Buscar cualquier receta del juego...",
    ["Search any recipe: name, ingredient, vendor, drop, zone..."] = "Buscar cualquier receta: nombre, ingrediente, vendedor, botín, zona...",
    ["Search by recipe, ingredient, NPC or zone."] = "Busca por receta, ingrediente, PNJ o zona.",
    ["Type to search every recipe."] = "Escribe para buscar entre todas las recetas.",
    ["No recipes found"] = "No se encontraron recetas",
    ["%d recipes"] = "%d recetas",
    ["%d recipes (showing the first %d)"] = "%d recetas (se muestran las %d primeras)",
    ["Profession: %s"] = "Profesión: %s",
    ["Profession:"] = "Profesión:",
    ["You know this recipe"] = "Conoces esta receta",
    ["You don't know this recipe yet"] = "Aún no conoces esta receta",
    ["You don't have this profession"] = "No tienes esta profesión",
    ["Skill needed:"] = "Habilidad necesaria:",
    ["you have %d"] = "tienes %d",
    ["Difficulty:"] = "Dificultad:",
    ["For your skill:"] = "Para tu habilidad:",
    ["orange"] = "naranja",
    ["yellow"] = "amarilla",
    ["green"] = "verde",
    ["grey"] = "gris",
    ["Makes:"] = "Crea:",
    ["Ingredients:"] = "Ingredientes:",
    ["item %d"] = "objeto %d",

    -- recipe details
    ["Skill %d"] = "Hab. %d",
    ["Skill needed: %d"] = "Habilidad necesaria: %d",

    -- where a recipe is learned
    ["Crafted"] = "Fabricada",
    ["Drop"] = "Botín",
    ["PvP"] = "JcJ",
    ["Quest"] = "Misión",
    ["Vendor"] = "Vendedor",
    ["Trainer"] = "Instructor",
    ["Gathered"] = "Recolectada",
    ["Salvaged"] = "Recuperada",
    ["Found in"] = "Se encuentra en",
    ["Unknown"] = "Desconocido",
    ["No source known for this recipe"] = "No se conoce el origen de esta receta",
    ["and %d more"] = "y %d más",
    ["costs %s"] = "cuesta %s",
    ["level %d"] = "nivel %d",
    ["level %d-%d"] = "nivel %d-%d",
    ["World drop: any creature of about level %d"] = "Botín del mundo: cualquier criatura de nivel %d aproximadamente",

    -- diagnostic
    ["Probe finished. Type /reload to save it."] = "Diagnóstico terminado. Escribe /reload para guardarlo.",
}

ns.L = setmetatable({}, { __index = function(_, k) return k end })

local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
    for k, v in pairs(es) do ns.L[k] = v end
end
