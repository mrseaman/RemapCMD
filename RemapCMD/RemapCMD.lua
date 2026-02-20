local addonName, ns = ...

-- SavedVariables: RemapCMD_Config
-- Structure: { rules = { { from = "META", to = "ALT" }, ... } }

local VALID_MODS = { ALT = true, CTRL = true, SHIFT = true, META = true }
-- Canonical ordering WoW uses when assembling modifier+key strings
local MOD_ORDER = { "ALT", "CTRL", "SHIFT", "META" }

-- Owner frame for override bindings; scoped so ClearOverrideBindings only removes ours
local frame = CreateFrame("Frame", "RemapCMDFrame", UIParent)

-- Parse a binding key string like "ALT-CTRL-X" and substitute fromMod with toMod.
-- Returns the remapped key string, or nil if fromMod was not present in the key.
local function RemapKey(key, fromMod, toMod)
    local mods = {}
    local rest = key

    -- Strip all leading modifier prefixes
    local changed = true
    while changed do
        changed = false
        for _, mod in ipairs(MOD_ORDER) do
            local prefix = mod .. "-"
            if rest:sub(1, #prefix) == prefix then
                mods[mod] = true
                rest = rest:sub(#prefix + 1)
                changed = true
                break
            end
        end
    end

    if not mods[fromMod] then return nil end  -- source modifier not present

    mods[fromMod] = nil
    mods[toMod] = true

    -- Reassemble in canonical order
    local newKey = ""
    for _, mod in ipairs(MOD_ORDER) do
        if mods[mod] then
            newKey = newKey .. mod .. "-"
        end
    end
    return newKey .. rest
end

-- Expose for use by the options panel (RemapCMD_Options.lua)
ns.ClearBindings = function() ClearOverrideBindings(frame) end

local function ApplyRules(verbose)
    ClearOverrideBindings(frame)

    local rules = RemapCMD_Config and RemapCMD_Config.rules or {}
    if #rules == 0 then
        if verbose then
            print("|cff00ff00RemapCMD:|r No rules configured. Use /remapcmd add <FROM> <TO>.")
        end
        return 0
    end

    local count = 0
    for i = 1, GetNumBindings() do
        local action, category, key1, key2 = GetBinding(i)
        for _, key in ipairs({ key1, key2 }) do
            if key then
                for _, rule in ipairs(rules) do
                    -- rule.from = key the user physically presses (e.g. META/⌘)
                    -- rule.to   = binding modifier to trigger (e.g. ALT)
                    -- Find bindings using rule.to and create rule.from overrides.
                    local newKey = RemapKey(key, rule.to, rule.from)
                    if newKey and newKey ~= key then
                        SetOverrideBinding(frame, true, newKey, action)
                        count = count + 1
                    end
                end
            end
        end
    end

    if verbose then
        print(string.format("|cff00ff00RemapCMD:|r Applied %d binding remap(s).", count))
    end
    return count
end
ns.ApplyRules = ApplyRules

local function PrintList()
    local rules = RemapCMD_Config and RemapCMD_Config.rules or {}
    if #rules == 0 then
        print("|cff00ff00RemapCMD:|r No rules configured.")
        return
    end
    print("|cff00ff00RemapCMD:|r Active rules:")
    for i, rule in ipairs(rules) do
        print(string.format("  %d. %s \226\134\146 %s", i, rule.from, rule.to))
    end
end

local function PrintHelp()
    print("|cff00ff00RemapCMD:|r Modifier remapper. Valid modifiers: |cffffff00ALT  CTRL  SHIFT  META|r")
    print("  (META = Command on macOS)")
    print("  |cffffff00/remapcmd options|r             \226\128\148 open the graphical options panel")
    print("  |cffffff00/remapcmd list|r                \226\128\148 show active rules")
    print("  |cffffff00/remapcmd add <FROM> <TO>|r     \226\128\148 add or replace a remap rule")
    print("  |cffffff00/remapcmd remove <FROM>|r       \226\128\148 remove the rule for a source modifier")
    print("  |cffffff00/remapcmd clear|r                \226\128\148 remove all rules")
    print("  |cffffff00/remapcmd reset|r                \226\128\148 restore default rule (META \226\134\146 ALT)")
    print("  |cffffff00/remapcmd refresh|r              \226\128\148 reapply all rules now")
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")      -- character bindings fully loaded
frame:RegisterEvent("UPDATE_BINDINGS")   -- fires whenever bindings change

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not RemapCMD_Config then
            RemapCMD_Config = { rules = { { from = "META", to = "ALT" } } }
        end
        -- Bindings from WTF/ may not be loaded yet; PLAYER_LOGIN will re-apply.
        ApplyRules(false)
        print(string.format("|cff00ff00RemapCMD:|r Loaded. Type /remapcmd for help."))
    elseif event == "PLAYER_LOGIN" then
        -- Character-specific bindings are guaranteed loaded by now.
        local count = ApplyRules(false)
        print(string.format("|cff00ff00RemapCMD:|r %d remap(s) active.", count))
    elseif event == "UPDATE_BINDINGS" then
        ApplyRules(false)
    end
end)

SLASH_REMAPCMD1 = "/remapcmd"
SlashCmdList["REMAPCMD"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.*)")
    cmd = (cmd or ""):upper()
    local arg1, arg2 = (rest or ""):match("^(%S*)%s*(%S*)$")
    arg1 = (arg1 or ""):upper()
    arg2 = (arg2 or ""):upper()

    if cmd == "OPTIONS" or cmd == "CONFIG" then
        if ns.openSettings then
            ns.openSettings()
        else
            print("|cff00ff00RemapCMD:|r Options panel unavailable.")
        end

    elseif cmd == "REFRESH" then
        ApplyRules(true)

    elseif cmd == "LIST" then
        PrintList()

    elseif cmd == "ADD" then
        if not VALID_MODS[arg1] then
            print("|cff00ff00RemapCMD:|r Invalid source modifier '" .. arg1 .. "'. Valid: ALT, CTRL, SHIFT, META")
            return
        end
        if not VALID_MODS[arg2] then
            print("|cff00ff00RemapCMD:|r Invalid target modifier '" .. arg2 .. "'. Valid: ALT, CTRL, SHIFT, META")
            return
        end
        if arg1 == arg2 then
            print("|cff00ff00RemapCMD:|r Source and target must be different modifiers.")
            return
        end
        -- Reject rules that would form a chain or cycle.
        -- A chain exists when a modifier appears as both a 'to' in one rule and a 'from'
        -- in another (e.g. META→ALT + CTRL→META would make CTRL implicitly target ALT).
        -- We enforce that the 'from' and 'to' sets across all rules stay disjoint.
        local rules = RemapCMD_Config.rules
        for _, r in ipairs(rules) do
            if r.from ~= arg1 then  -- skip the rule being replaced
                if r.to == arg1 then
                    print(string.format(
                        "|cffff4444RemapCMD:|r Cannot add %s \226\134\146 %s: %s is already a target of %s \226\134\146 %s (would create a chain).",
                        arg1, arg2, arg1, r.from, r.to))
                    return
                end
                if r.from == arg2 then
                    print(string.format(
                        "|cffff4444RemapCMD:|r Cannot add %s \226\134\146 %s: %s is already a source in %s \226\134\146 %s (would create a chain).",
                        arg1, arg2, arg2, r.from, r.to))
                    return
                end
            end
        end
        -- Replace any existing rule for this source modifier
        for i = #rules, 1, -1 do
            if rules[i].from == arg1 then table.remove(rules, i) end
        end
        table.insert(rules, { from = arg1, to = arg2 })
        local count = ApplyRules(false)
        print(string.format("|cff00ff00RemapCMD:|r Added: %s \226\134\146 %s. %d remap(s) active.", arg1, arg2, count))

    elseif cmd == "REMOVE" then
        if not VALID_MODS[arg1] then
            print("|cff00ff00RemapCMD:|r Invalid modifier '" .. arg1 .. "'. Valid: ALT, CTRL, SHIFT, META")
            return
        end
        local rules = RemapCMD_Config.rules
        local before = #rules
        for i = before, 1, -1 do
            if rules[i].from == arg1 then table.remove(rules, i) end
        end
        if #rules < before then
            local count = ApplyRules(false)
            print(string.format("|cff00ff00RemapCMD:|r Removed rule for %s. %d remap(s) active.", arg1, count))
        else
            print("|cff00ff00RemapCMD:|r No rule found for source modifier: " .. arg1)
        end

    elseif cmd == "CLEAR" then
        RemapCMD_Config.rules = {}
        ClearOverrideBindings(frame)
        print("|cff00ff00RemapCMD:|r All rules cleared.")

    elseif cmd == "RESET" then
        RemapCMD_Config.rules = { { from = "META", to = "ALT" } }
        local count = ApplyRules(false)
        print(string.format("|cff00ff00RemapCMD:|r Reset to default (META \226\134\146 ALT). %d remap(s) active.", count))

    else
        PrintHelp()
    end
end
