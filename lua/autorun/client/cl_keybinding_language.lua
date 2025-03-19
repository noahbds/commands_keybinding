KeyBindManager = KeyBindManager or {}
KeyBindManager.Languages = {}
KeyBindManager.CurrentLanguage = "en" -- English as default

-- Function to add a new language
function KeyBindManager.AddLanguage(langCode, langName, translations)
    KeyBindManager.Languages[langCode] = {
        name = langName,
        translations = translations
    }
end

-- Function to set the current language
function KeyBindManager.SetLanguage(langCode)
    if KeyBindManager.Languages[langCode] then
        KeyBindManager.CurrentLanguage = langCode
        return true
    end
    return false
end

-- Function to get the list of available languages
function KeyBindManager.GetLanguages()
    local languages = {}
    for code, lang in pairs(KeyBindManager.Languages) do
        languages[code] = lang.name
    end
    return languages
end

-- Function to translate a string
function KeyBindManager.GetPhrase(key, ...)
    local currentLang = KeyBindManager.CurrentLanguage

    if not KeyBindManager.Languages[currentLang] then
        currentLang = "en" -- Fallback to English
    end

    local translation = KeyBindManager.Languages[currentLang].translations[key]

    if not translation then
        -- Fallback to English if translation is missing
        if currentLang ~= "en" and KeyBindManager.Languages["en"] then
            translation = KeyBindManager.Languages["en"].translations[key]
        end

        -- If still no translation, return the key
        if not translation then
            return key
        end
    end

    -- Handle string formatting
    if ... then
        return string.format(translation, ...)
    end

    return translation
end

-- Shorthand function for translation
function L(key, ...)
    return KeyBindManager.GetPhrase(key, ...)
end

-- Create ConVar for language selection
local languageConVar = CreateClientConVar("keybind_language", "auto", true, false, "Language for Keybind Manager")

-- Detect system language and set appropriate language
local function DetectLanguage()
    local langCode = languageConVar:GetString()

    if langCode == "auto" then
        local systemLang = system.GetCountry():lower()

        -- Map countries to languages
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

    -- Set language if it exists, otherwise default to English
    if not KeyBindManager.SetLanguage(langCode) then
        KeyBindManager.SetLanguage("en")
    end
end

-- Load language files
hook.Add("InitPostEntity", "KeyBindManager_LoadLanguages", function()
    local files, _ = file.Find("autorun/client/languages/*.lua", "LUA")

    for _, f in pairs(files) do
        AddCSLuaFile("autorun/client/languages/" .. f)
        include("autorun/client/languages/" .. f)
    end

    DetectLanguage()
    print("[Keybind Manager] Loaded " .. table.Count(KeyBindManager.Languages) .. " languages")
end)

-- Create console command to change language
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
