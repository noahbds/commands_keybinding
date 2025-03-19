KeyBindManager = KeyBindManager or {}
KeyBindManager.Languages = {}
KeyBindManager.CurrentLanguage = "en"

function KeyBindManager.AddLanguage(langCode, langName, translations)
    KeyBindManager.Languages[langCode] = {
        name = langName,
        translations = translations
    }
end

function KeyBindManager.SetLanguage(langCode)
    if KeyBindManager.Languages[langCode] then
        KeyBindManager.CurrentLanguage = langCode
        return true
    end
    return false
end

function KeyBindManager.GetLanguages()
    local languages = {}
    for code, lang in pairs(KeyBindManager.Languages) do
        languages[code] = lang.name
    end
    return languages
end

function KeyBindManager.GetPhrase(key, ...)
    local currentLang = KeyBindManager.CurrentLanguage

    if not KeyBindManager.Languages[currentLang] then
        currentLang = "en"
    end

    local translation = KeyBindManager.Languages[currentLang].translations[key]

    if not translation then
        if currentLang ~= "en" and KeyBindManager.Languages["en"] then
            translation = KeyBindManager.Languages["en"].translations[key]
        end

        if not translation then
            return key
        end
    end

    if ... then
        return string.format(translation, ...)
    end

    return translation
end

function L(key, ...)
    return KeyBindManager.GetPhrase(key, ...)
end

local languageConVar = CreateClientConVar("keybind_language", "auto", true, false, "Language for Keybind Manager")

local function DetectLanguage()
    local langCode = languageConVar:GetString()

    if langCode == "auto" then
        local systemLang = system.GetCountry():lower()

        local countryMap = {
            ["fr"] = "fr",
            ["ca"] = "fr", -- Quebec
            ["ru"] = "ru",
            ["by"] = "ru", -- Belarus
            ["de"] = "de",
            ["at"] = "de", -- Austria
            ["ch"] = "de", -- Switzerland
            ["es"] = "es",
            ["mx"] = "es", -- Mexico
            ["ar"] = "es", -- Argentina
        }

        langCode = countryMap[systemLang] or "en"
    end

    if not KeyBindManager.SetLanguage(langCode) then
        KeyBindManager.SetLanguage("en")
    end
end

hook.Add("InitPostEntity", "KeyBindManager_LoadLanguages", function()
    local files, _ = file.Find("autorun/client/languages/*.lua", "LUA")

    for _, f in pairs(files) do
        AddCSLuaFile("autorun/client/languages/" .. f)
        include("autorun/client/languages/" .. f)
    end

    DetectLanguage()
    print("[Keybind Manager] Loaded " .. table.Count(KeyBindManager.Languages) .. " languages")
end)

concommand.Add("keybind_set_language", function(ply, cmd, args)
    local langCode = args[1]

    if KeyBindManager.SetLanguage(langCode) then
        print("[Keybind Manager] Language set to " .. KeyBindManager.Languages[langCode].name)
    else
        print("[Keybind Manager] Invalid language code. Available languages:")
        for code, lang in pairs(KeyBindManager.Languages) do
            print("  - " .. code .. ": " .. lang.name)
        end
    end
end, function(cmd, stringargs)
    stringargs = string.Trim(stringargs)
    local tbl = {}

    for code, lang in pairs(KeyBindManager.GetLanguages()) do
        table.insert(tbl, cmd .. " " .. code)
    end

    return tbl
end)
