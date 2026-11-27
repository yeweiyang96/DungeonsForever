local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local SE = ns.ProfShoppingExport or (type(gns) == "table" and gns.ProfShoppingExport) or {}
ns.ProfShoppingExport = SE
if type(gns) == "table" and gns ~= ns then
    gns.ProfShoppingExport = SE
end

local CALLER = "DungeonsForever"
local format = string.format
local floor, huge = math.floor, math.huge

local function getBridge()
    return ns.ProfHostBridge or (type(gns) == "table" and gns.ProfHostBridge) or nil
end

local function getL()
    local b = getBridge()
    return b and type(b.LocaleRaw) == "function" and b.LocaleRaw() or nil
end

local function getSkinPopupFont()
    local b = getBridge()
    return b and type(b.SkinPopupFont) == "function" and b.SkinPopupFont or nil
end

local function tr(key)
    local L = getL()
    if type(L) == "table" then
        local ok, v = pcall(function() return L[key] end)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    return key
end

local function Say(msg)
    local frame = _G.DEFAULT_CHAT_FRAME
    if type(frame) == "table" and type(frame.AddMessage) == "function" then
        frame:AddMessage("|cffffd100" .. tostring(msg) .. "|r")
    end
end

local function Int(v, minimum)
    v = tonumber(v)
    if not v or v ~= v or v == huge or v == -huge then return nil end
    if v < minimum or v ~= floor(v) then return nil end
    return v
end

function SE.ListName(profName)
    return format(tr("[DF] %s购物清单"), profName or "?")
end

function SE.SearchString(name, need)
    local quoted = "\"" .. (name or "") .. "\""
    local hasNeed = (type(need) == "number" and need > 0) and true or false
    local a = _G.Auctionator
    if type(a) == "table" and type(a.API) == "table" and type(a.API.v1) == "table"
        and type(a.API.v1.ConvertToSearchString) == "function" then
        local term = { searchString = name, isExact = true }
        if hasNeed then term.quantity = need end
        local ok, s = pcall(a.API.v1.ConvertToSearchString, CALLER, term)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    if hasNeed then
        return table.concat({ quoted, "", "", "", "", "", "", "", "", "", "", "#", "", tostring(need) }, ";")
    end
    return quoted
end

function SE.ExportString(listName, items)
    local parts = { listName }
    for _, e in ipairs(items or {}) do
        if type(e) == "table" and type(e.name) == "string" and e.name ~= "" then
            parts[#parts + 1] = SE.SearchString(e.name, e.need)
        end
    end
    return table.concat(parts, "^")
end

function SE.PlainText(listName, items)
    local lines = { listName }
    for _, e in ipairs(items or {}) do
        if type(e) == "table" and type(e.name) == "string" and e.name ~= "" then
            local qty = tonumber(e.need)
            if qty and qty > 0 then
                lines[#lines + 1] = format("%s x%d", e.name, qty)
            else
                lines[#lines + 1] = e.name
            end
        end
    end
    return table.concat(lines, "\n")
end

local POPUP = "DungeonsForever_AuctionImport"
local pendingImportText = ""
local pendingImportHint = nil

function SE.ShowCopy(text, hint)
    pendingImportText = text or ""
    pendingImportHint = hint
    local dialogs = _G.StaticPopupDialogs
    local showFn = _G.StaticPopup_Show
    if type(dialogs) ~= "table" or type(showFn) ~= "function" then
        return false
    end
    if not dialogs[POPUP] then
        dialogs[POPUP] = {
            text = tr("已生成购物清单文本，按 Ctrl+C 复制"),
            button1 = tr("关闭"),
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            hasEditBox = true,
            editBoxWidth = 320,
            OnShow = function(self)
                local label = self.text or (self.GetName and _G[(self:GetName() or "") .. "Text"])
                if label and pendingImportHint and label.SetText then label:SetText(pendingImportHint) end
                local edit = self.EditBox or self.editBox
                if edit then
                    edit:SetText(pendingImportText)
                    edit:HighlightText()
                    edit:SetFocus()
                end
                local skin = getSkinPopupFont()
                if type(skin) == "function" then skin(self) end
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                if parent and parent.Hide then parent:Hide() end
            end,
            EditBoxOnEscapePressed = function(self)
                local parent = self:GetParent()
                if parent and parent.Hide then parent:Hide() end
            end,
        }
    end
    showFn(POPUP)
    return true
end

local function tryWriteAuctionator(listName, items)
    local a = _G.Auctionator
    if not (type(a) == "table" and a.EasyAuctionCompat == nil
        and type(a.API) == "table" and type(a.API.v1) == "table"
        and type(a.API.v1.CreateShoppingList) == "function") then
        return false
    end
    local strings = {}
    for _, e in ipairs(items) do
        if type(e) == "table" and type(e.name) == "string" and e.name ~= "" then
            strings[#strings + 1] = SE.SearchString(e.name, e.need)
        end
    end
    if #strings == 0 then return false end
    local ok = pcall(a.API.v1.CreateShoppingList, CALLER, listName, strings)
    if ok then
        Say(format(tr("已导入购物清单：%s（共 %d 种）"), listName, #items))
        return true
    end
    return false
end

local function tryWriteEasyAuction(listName, items)
    local root = _G.EasyAuction12
    local store = type(root) == "table" and root.Store or nil
    if not (type(store) == "table" and type(store.GetLists) == "function"
        and type(store.CreateList) == "function" and type(store.DeleteList) == "function"
        and type(store.SetListItem) == "function") then
        return false
    end
    local okLists, lists = pcall(store.GetLists)
    if okLists and type(lists) == "table" then
        for i = 1, #lists do
            local list = lists[i]
            if type(list) == "table" and list.name == listName then
                pcall(store.DeleteList, list.id)
                break
            end
        end
    end
    local made, list = pcall(store.CreateList, listName)
    if not made or type(list) ~= "table" then return false end
    local written = 0
    for i = 1, #items do
        local entry = items[i]
        if type(entry) == "table" then
            local id = Int(entry.id, 1)
            local need = Int(entry.need, 1)
            if id and need then
                local key = { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
                if pcall(store.SetListItem, list.id, key, entry.name, need) then
                    written = written + 1
                end
            end
        end
    end
    if written == 0 then
        pcall(store.DeleteList, list.id)
        return false
    end
    local ui = type(root) == "table" and root.UI or nil
    if type(ui) == "table" and type(ui.Refresh) == "function" then
        pcall(ui.Refresh)
    end
    Say(format(tr("已导入购物清单：%s（共 %d 种）"), listName, written))
    return true
end

function SE.DoImport(profName, items)
    if not (type(items) == "table" and #items > 0) then
        Say(tr("购物清单为空，没有可导出的物品"))
        return
    end
    local listName = SE.ListName(profName)
    if tryWriteAuctionator(listName, items) then return end
    if tryWriteEasyAuction(listName, items) then return end
    SE.ShowCopy(SE.ExportString(listName, items), tr("已生成购物清单文本，按 Ctrl+C 复制"))
end

local function attachCompat(target)
    if type(target) ~= "table" then return end
    target.ListName = SE.ListName
    target.SearchString = SE.SearchString
    target.ExportString = SE.ExportString
    target.PlainText = SE.PlainText
    target.ShowCopy = SE.ShowCopy
    target.DoImport = SE.DoImport
end

attachCompat(ns.AuctionBridge)
if type(gns) == "table" and gns ~= ns then
    attachCompat(gns.AuctionBridge)
end
