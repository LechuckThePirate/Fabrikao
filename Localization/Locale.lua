local _, ns = ...

-- Keys are the English text; on esES/esMX clients they are replaced by the Spanish one.
local es = {
    ["initializing..."] = "inicializando...",
    ["initialization complete"] = "inicialización completa",
    ["Usage: /fabrikao | minimap | version"] = "Uso: /fabrikao | minimap | version",
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
    ["Known"] = "Conocidas",
    ["Not known"] = "No conocidas",
    ["Known recipes"] = "Recetas conocidas",
    ["%d known, %d not known"] = "%d conocidas, %d no conocidas",
    ["Search recipes (name or where to learn them)..."] = "Buscar recetas (nombre o dónde aprenderlas)...",
    ["Source: %s"] = "Origen: %s",
    ["All"] = "Todos",
    ["Other"] = "Otro",
    ["Where to learn it"] = "Dónde aprenderla",
    ["Turns grey at skill %d"] = "Se vuelve gris con habilidad %d",
    ["Reading recipes..."] = "Leyendo recetas...",
    ["Could not read this profession's recipes."] = "No se pudieron leer las recetas de esta profesión.",
    ["No recipes match"] = "Ninguna receta coincide",

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
