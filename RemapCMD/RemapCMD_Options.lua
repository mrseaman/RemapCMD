local addonName, ns = ...

-- ============================================================
-- RemapCMD Options Panel
-- Uses the modern Settings canvas layout API (TWW 11.x+)
-- ============================================================

local MODS = { "ALT", "CTRL", "SHIFT", "META" }
local MOD_LABEL = {
    ALT   = "Alt",
    CTRL  = "Ctrl",
    SHIFT = "Shift",
    META  = "Meta",
}

-- ── Helpers ──────────────────────────────────────────────────

local function Separator(parent, yOff)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  4, yOff)
    t:SetPoint("TOPRIGHT", -4, yOff)
    t:SetColorTexture(0.4, 0.4, 0.4, 0.6)
end

-- UIDropDownMenuTemplate-based modifier selector.
-- UIDropDownMenu_SetWidth(dd, w) sets frame width to w+25; total visual ~w+25px.
-- 'name' must be a unique global string (required by UIDropDownMenuTemplate).
local function CreateModDropdown(parent, name, x, yOff, initial)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x, yOff)
    UIDropDownMenu_SetWidth(dd, 100)

    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, mod in ipairs(MODS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text  = MOD_LABEL[mod]
            info.value = mod
            info.func  = function(btn)
                UIDropDownMenu_SetSelectedValue(dd, btn.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Set initial selection (SetSelectedValue alone doesn't update the displayed text
    -- until the menu has been opened, so also set the text explicitly)
    UIDropDownMenu_SetSelectedValue(dd, initial)
    UIDropDownMenu_SetText(dd, MOD_LABEL[initial] or initial)

    dd.GetValue = function() return UIDropDownMenu_GetSelectedValue(dd) end
    dd.SetValue = function(val)
        UIDropDownMenu_SetSelectedValue(dd, val)
        UIDropDownMenu_SetText(dd, MOD_LABEL[val] or val)
    end

    return dd
end

-- ── Canvas frame ─────────────────────────────────────────────
local optFrame = CreateFrame("Frame")

-- ── Rules list ───────────────────────────────────────────────
-- Anchored at y=-90; max 4 rules × 28px = 112px, fits in 116px height
local rulesContainer = CreateFrame("Frame", nil, optFrame)
rulesContainer:SetPoint("TOPLEFT", 20, -90)
rulesContainer:SetSize(560, 116)

rulesContainer.emptyLabel = rulesContainer:CreateFontString(nil, "ARTWORK", "GameFontDisable")
rulesContainer.emptyLabel:SetPoint("TOPLEFT", 4, -4)
rulesContainer.emptyLabel:SetText("No rules configured.")

local ruleRows = {}

local function GetRow(i)
    if ruleRows[i] then return ruleRows[i] end

    local row = CreateFrame("Frame", nil, rulesContainer)
    row:SetSize(560, 26)

    row.lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.lbl:SetPoint("LEFT", 4, 0)
    row.lbl:SetWidth(300)
    row.lbl:SetJustifyH("LEFT")

    row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.del:SetSize(80, 22)
    row.del:SetPoint("LEFT", 320, 0)
    row.del:SetText("Remove")

    ruleRows[i] = row
    return row
end

local function RefreshList()
    local rules = (RemapCMD_Config and RemapCMD_Config.rules) or {}
    for _, r in ipairs(ruleRows) do r:Hide() end

    if #rules == 0 then
        rulesContainer.emptyLabel:Show()
        return
    end
    rulesContainer.emptyLabel:Hide()

    for i, rule in ipairs(rules) do
        local row = GetRow(i)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 28)
        row.lbl:SetText(string.format(
            "|cffffff00%s|r   ->   |cffffff00%s|r",
            MOD_LABEL[rule.from] or rule.from,
            MOD_LABEL[rule.to]   or rule.to))
        local capturedFrom = rule.from  -- capture for closure
        row.del:SetScript("OnClick", function()
            local r = RemapCMD_Config.rules
            for j = #r, 1, -1 do
                if r[j].from == capturedFrom then table.remove(r, j) end
            end
            ns.ApplyRules(false)
            RefreshList()
        end)
        row:Show()
    end
end

optFrame:SetScript("OnShow", RefreshList)

-- ── Layout ───────────────────────────────────────────────────
local L = 16  -- left margin

-- Title
local titleFs = optFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
titleFs:SetPoint("TOPLEFT", L, -16)
titleFs:SetText("RemapCMD")

-- Description
local descFs = optFrame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
descFs:SetPoint("TOPLEFT", L, -38)
descFs:SetText("Remap Alt / Ctrl / Shift / Meta to each other for cross-platform keybinding compatibility.")

Separator(optFrame, -58)

-- "Active Rules" header
local rulesHdr = optFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
rulesHdr:SetPoint("TOPLEFT", L, -70)
rulesHdr:SetText("Active Rules")

-- rulesContainer at y=-90, height=116, bottom edge at y=-206

Separator(optFrame, -218)

-- "Add Rule" header
local addHdr = optFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
addHdr:SetPoint("TOPLEFT", L, -230)
addHdr:SetText("Add Rule")

-- "Add Rule" input row at y=-252.
-- UIDropDownMenu_SetWidth(100) → frame width=125; with arrow button total visual ≈ 128px.
-- fromDD left=66, right≈194.  toDD left=214, right≈342.  button left≈352.
local fromDD = CreateModDropdown(optFrame, "RemapCMD_FromDropdown", L + 50, -252, "META")

-- "From:" label anchored to the left of fromDD, vertically centred to it
local fromLabel = optFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
fromLabel:SetPoint("RIGHT", fromDD, "LEFT", -4, 2)
fromLabel:SetText("From:")

-- "→" arrow anchored to the right of fromDD
local arrowFs = optFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
arrowFs:SetPoint("LEFT", fromDD, "RIGHT", 6, 2)
arrowFs:SetText("->")

-- toDD: fixed x so it clears the arrow glyph (~10px wide + small gap)
local toDD = CreateModDropdown(optFrame, "RemapCMD_ToDropdown", L + 198, -252, "ALT")

-- "Add Rule" button anchored to the right of toDD
local addRuleBtn = CreateFrame("Button", nil, optFrame, "UIPanelButtonTemplate")
addRuleBtn:SetSize(90, 22)
addRuleBtn:SetPoint("LEFT", toDD, "RIGHT", 10, -2)
addRuleBtn:SetText("Add Rule")

addRuleBtn:SetScript("OnClick", function()
    local from = fromDD.GetValue()
    local to   = toDD.GetValue()
    if from == to then
        print("|cff00ff00RemapCMD:|r Source and target must be different modifiers.")
        return
    end
    local rules = RemapCMD_Config.rules
    for _, r in ipairs(rules) do
        if r.from ~= from then  -- skip the rule being replaced
            if r.to == from then
                print(string.format(
                    "|cffff4444RemapCMD:|r Cannot add %s -> %s: %s is already a target of %s -> %s (would create a chain).",
                    MOD_LABEL[from], MOD_LABEL[to], MOD_LABEL[from], MOD_LABEL[r.from], MOD_LABEL[r.to]))
                return
            end
            if r.from == to then
                print(string.format(
                    "|cffff4444RemapCMD:|r Cannot add %s -> %s: %s is already a source in %s -> %s (would create a chain).",
                    MOD_LABEL[from], MOD_LABEL[to], MOD_LABEL[to], MOD_LABEL[r.from], MOD_LABEL[r.to]))
                return
            end
        end
    end
    for i = #rules, 1, -1 do
        if rules[i].from == from then table.remove(rules, i) end
    end
    table.insert(rules, { from = from, to = to })
    ns.ApplyRules(false)
    RefreshList()
    print(string.format("|cff00ff00RemapCMD:|r Added rule: %s -> %s",
        MOD_LABEL[from] or from, MOD_LABEL[to] or to))
end)

-- Separator below the row: UIDropDownMenu frame is 44px tall, so bottom at y=-252-44=-296
Separator(optFrame, -308)

-- Utility buttons
local resetBtn = CreateFrame("Button", nil, optFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(150, 22)
resetBtn:SetPoint("TOPLEFT", L, -320)
resetBtn:SetText("Reset to Default")
resetBtn:SetScript("OnClick", function()
    RemapCMD_Config.rules = { { from = "META", to = "ALT" } }
    ns.ApplyRules(false)
    RefreshList()
    print("|cff00ff00RemapCMD:|r Reset to default (Meta -> Alt).")
end)

local clearBtn = CreateFrame("Button", nil, optFrame, "UIPanelButtonTemplate")
clearBtn:SetSize(130, 22)
clearBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
clearBtn:SetText("Clear All Rules")
clearBtn:SetScript("OnClick", function()
    RemapCMD_Config.rules = {}
    ns.ClearBindings()
    RefreshList()
    print("|cff00ff00RemapCMD:|r All rules cleared.")
end)

-- ── Register with Settings API ───────────────────────────────
local category = Settings.RegisterCanvasLayoutCategory(optFrame, "RemapCMD")
Settings.RegisterAddOnCategory(category)

ns.openSettings = function()
    Settings.OpenToCategory(category:GetID())
end
