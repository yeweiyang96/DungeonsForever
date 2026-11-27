local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local B = {}

local DEFAULT_COLORS = {
    C_GOLD  = { 1, 0.82, 0 },
    C_GREEN = { 0.25, 0.85, 0.35 },
    C_GREY  = { 0.55, 0.55, 0.55 },
    C_DIM   = { 0.63, 0.63, 0.63 },
    C_WHITE = { 1, 1, 1 },
    C_TEXT  = { 0.88, 0.88, 0.88 },
}

local DEFAULT_CONSTS = {
    CONTENT_W     = 940,
    CONTENT_H     = 600,
    PAGE_INSET    = 12,
    ROW_CLASS     = "Button",
    FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark",
}

local MEDIA = {
    HelpIcon        = "Interface\\AddOns\\DungeonsForever\\Media\\Brand\\HelpIcon",
    HUIPillCap      = "Interface\\AddOns\\DungeonsForever\\Media\\Common\\HUIPillCap",
    WarnTri         = "Interface\\AddOns\\DungeonsForever\\Media\\Prof\\WarnTri",
    FactionAlliance = "Interface\\AddOns\\DungeonsForever\\Media\\icon\\FACTION\\FactionIcon_Alliance",
    FactionHorde    = "Interface\\AddOns\\DungeonsForever\\Media\\icon\\FACTION\\FactionIcon_Horde",
    Arrow           = "Interface\\AddOns\\DungeonsForever\\Media\\textures\\arrow.tga",
    ProfMute        = "Interface\\AddOns\\DungeonsForever\\Media\\Prof\\prof_mute.tga",
    VoiceNextItem   = "Interface\\AddOns\\DungeonsForever\\Media\\Voice\\prof_next_item.ogg",
    VoiceNotLearned = "Interface\\AddOns\\DungeonsForever\\Media\\Voice\\prof_not_learned.ogg",
    VoiceSkillCap   = "Interface\\AddOns\\DungeonsForever\\Media\\Voice\\prof_skill_cap.ogg",
    VoiceOn         = "Interface\\AddOns\\DungeonsForever\\Media\\Voice\\prof_voice_on.ogg",
}
B.MEDIA = MEDIA

local function mainNS()
    local g = _G.DF_NS
    if type(g) == "table" then return g end
    return type(gns) == "table" and gns or nil
end

local function mainFrom(key)
    local v = ns[key]
    if v ~= nil then return v end
    local g = mainNS()
    if g then return g[key] end
    return nil
end

function B.MainNS()
    return mainNS()
end

function B.Host()
    local h = mainFrom("ProfHost")
    return type(h) == "table" and h or nil
end

function B.DG()
    local h = B.Host()
    if h and type(h.DG) == "table" then return h.DG end
    local dg = mainFrom("DG")
    if type(dg) == "table" then return dg end
    local ddg = mainFrom("DungeonDG")
    return type(ddg) == "table" and ddg or nil
end

function B.U()
    local h = B.Host()
    return h and h.U or nil
end

function B.MainFrame()
    return _G.DungeonsForever_MainFrame
end

function B.IsForeverPagesEnabled()
    return mainFrom("LoadForeverPages") and true or false
end

function B.Locale()
    if type(_G.DF_Locale) == "function" then
        local ok, loc = pcall(_G.DF_Locale)
        if ok and type(loc) == "string" and loc ~= "" then return loc end
    end
    if type(_G.GetLocale) == "function" then
        local ok, loc = pcall(_G.GetLocale)
        if ok and type(loc) == "string" and loc ~= "" then return loc end
    end
    return "enUS"
end

function B.LocaleRaw()
    local lt = mainFrom("L")
    return type(lt) == "table" and lt or nil
end

function B.L(key)
    local lt = B.LocaleRaw()
    if lt and lt[key] ~= nil then return lt[key] end
    return tostring(key)
end

local localeProxy = setmetatable({}, {
    __index = function(_, k)
        return B.L(k)
    end,
})

function B.LocaleTable()
    return localeProxy
end

function B.OnInit(fn)
    if type(fn) ~= "function" then return end
    local initFn = mainFrom("Init")
    if type(initFn) == "function" then
        initFn(fn)
    else
        fn()
    end
end

function B.PageVisible(page)
    local pv = mainFrom("PageVisible")
    if type(pv) == "function" then
        local ok, v = pcall(pv, page)
        return ok and v == true
    end
    return (type(page) == "table" and type(page.IsVisible) == "function" and page:IsVisible()) and true or false
end

function B.PerfBegin(tag)
    local op = mainFrom("OpenPerf")
    if type(op) == "table" and type(op.Begin) == "function" then
        pcall(op.Begin, tag)
    end
end

function B.PerfMark(tag)
    local op = mainFrom("OpenPerf")
    if type(op) == "table" and type(op.Mark) == "function" then
        pcall(op.Mark, tag)
    end
end

function B.PlaySound(id)
    local ps = mainFrom("PlaySound")
    if type(ps) == "function" then
        pcall(ps, id)
    end
end

function B.SetDebugError(kind, err)
    if kind == "paint" then
        _G.DF_LAST_PAINT_ERR = tostring(err)
    elseif kind == "build" then
        _G.DF_LAST_BUILD_ERR = tostring(err)
    end
end

function B.Hui()
    local h = mainFrom("hui")
    return type(h) == "table" and h or nil
end

function B.HuiTheme()
    return mainFrom("huiTheme")
end

function B.Font()
    return mainFrom("FONT")
end

function B.SkinPopupFont(frame)
    local fn = mainFrom("SkinPopupFont")
    if type(fn) == "function" then
        return fn(frame)
    end
end

function B.Unpack(...)
    local h = B.Host()
    if h and type(h.Unpack) == "function" then
        return h.Unpack(...)
    end
    local fn = _G.unpack
    if type(fn) == "function" then
        return fn(...)
    end
end

function B.MakeFS(...)
    local h = B.Host()
    if h and type(h.MakeFS) == "function" then
        return h.MakeFS(...)
    end
    return {}
end

function B.NewButton(...)
    local h = B.Host()
    if h and type(h.NewButton) == "function" then
        return h.NewButton(...)
    end
    return {}
end

function B.MakeOutline(...)
    local h = B.Host()
    if h and type(h.MakeOutline) == "function" then
        return h.MakeOutline(...)
    end
end

function B.AddBtnIcon(...)
    local h = B.Host()
    if h and type(h.AddBtnIcon) == "function" then
        return h.AddBtnIcon(...)
    end
end

function B.CreateButton(...)
    local fn = mainFrom("CreateButton")
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

function B.CreateEditBox(...)
    local fn = mainFrom("CreateEditBox")
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

function B.SetOutline(...)
    local h = B.Host()
    if h and type(h.SetOutline) == "function" then
        return h.SetOutline(...)
    end
end

function B.SetTip(...)
    local h = B.Host()
    if h and type(h.SetTip) == "function" then
        return h.SetTip(...)
    end
end

function B.SetButtonSelected(...)
    local h = B.Host()
    if h and type(h.SetButtonSelected) == "function" then
        return h.SetButtonSelected(...)
    end
end

function B.MakeBadge(...)
    local dg = B.DG()
    if dg and type(dg.MakeBadge) == "function" then
        return dg.MakeBadge(...)
    end
    return nil
end

function B.BadgeTint(...)
    local dg = B.DG()
    if dg and type(dg.BadgeTint) == "function" then
        return dg.BadgeTint(...)
    end
end

function B.WheelScroll(...)
    local dg = B.DG()
    if dg and type(dg.WheelScroll) == "function" then
        return dg.WheelScroll(...)
    end
end

function B.Gate()
    local dg = B.DG()
    return dg and dg.Gate or nil
end

function B.GateBegin(n)
    local g = B.Gate()
    if g and type(g.Begin) == "function" then g.Begin(n) end
end

function B.GateAdvance(step)
    local g = B.Gate()
    if g and type(g.Advance) == "function" then g.Advance(step or 1) end
end

function B.GateFinish()
    local g = B.Gate()
    if g and type(g.Finish) == "function" then g.Finish() end
end

function B.GetGateMinSteps()
    local g = B.Gate()
    return g and g.minSteps or nil
end

function B.SetGateMinSteps(v)
    local g = B.Gate()
    if type(g) == "table" then g.minSteps = v end
end

function B.SetLootRowFrameCap(v)
    local dg = B.DG()
    if type(dg) == "table" then dg.LOOT_ROW_FRAME_CAP = v end
end

function B.PublishDGContract(key, val)
    local dg = B.DG()
    if type(dg) == "table" and type(key) == "string" then
        dg[key] = val
    end
end

function B.QColor(q)
    local dg = B.DG()
    if dg and type(dg.QColor) == "function" then
        return dg.QColor(q)
    end
    local hui = B.Hui()
    if hui and type(hui.QColor) == "function" then
        return hui.QColor(q)
    end
    return 1, 1, 1
end

function B.Color(name)
    local h = B.Host()
    if h and h[name] ~= nil then return h[name] end
    return DEFAULT_COLORS[name]
end

function B.Colors()
    return {
        C_GOLD  = B.Color("C_GOLD"),
        C_GREEN = B.Color("C_GREEN"),
        C_GREY  = B.Color("C_GREY"),
        C_DIM   = B.Color("C_DIM"),
        C_WHITE = B.Color("C_WHITE"),
        C_TEXT  = B.Color("C_TEXT"),
    }
end

function B.Const(name)
    local h = B.Host()
    if h and h[name] ~= nil then return h[name] end
    local dg = B.DG()
    if dg and dg[name] ~= nil then return dg[name] end
    local mv = mainFrom(name)
    if mv ~= nil then return mv end
    return DEFAULT_CONSTS[name]
end

function B.Media(key)
    return MEDIA[key]
end

function B.TipConfig()
    local tf = mainFrom("TipCfg")
    if type(tf) == "function" then
        local ok, cfg = pcall(tf)
        if ok and type(cfg) == "table" then return cfg end
    elseif type(tf) == "table" then
        return tf
    end
    return nil
end

function B.TipAppendLines(lines)
    if type(lines) ~= "table" or #lines == 0 then return end
    local dg = B.DG()
    if dg and type(dg.TipAppendLines) == "function" then
        return dg.TipAppendLines(lines)
    end
    local GT = _G.GameTooltip
    if not GT or type(GT.AddLine) ~= "function" then return end
    GT:AddLine(" ")
    for i = 1, #lines do
        local ln = lines[i]
        if type(ln) == "table" and type(ln[1]) == "string" then
            if ln[7] ~= nil and type(GT.AddDoubleLine) == "function" then
                GT:AddDoubleLine(ln[1], tostring(ln[7]), ln[2] or 1, ln[3] or 1, ln[4] or 1, ln[8] or 1, ln[9] or 1, ln[10] or 1)
            else
                GT:AddLine(ln[1], ln[2] or 1, ln[3] or 1, ln[4] or 1, true)
            end
        end
    end
end

function B.ShowItemTip(owner, it, extra, title)
    local dg = B.DG()
    if dg and type(dg.ShowItemTip) == "function" then
        return dg.ShowItemTip(owner, it, extra, title)
    end
    local GT = _G.GameTooltip
    if not (GT and owner and type(it) == "table") then return end
    local id = it[1]
    if type(GT.SetOwner) == "function" then GT:SetOwner(owner, "ANCHOR_RIGHT") end
    if type(GT.ClearLines) == "function" then GT:ClearLines() end
    if id and type(GT.SetHyperlink) == "function" then
        pcall(GT.SetHyperlink, GT, "item:" .. tostring(id))
    elseif title and type(GT.AddLine) == "function" then
        GT:AddLine(title, 1, 0.82, 0, true)
    end
    if type(extra) == "table" and #extra > 0 then
        B.TipAppendLines(extra)
    end
    if type(GT.Show) == "function" then GT:Show() end
end

function B.ItemInfo(id)
    local dg = B.DG()
    if dg and type(dg.ItemInfo) == "function" then
        local ok, info = pcall(dg.ItemInfo, id)
        if ok then return info end
    end
    return nil
end

function B.ItemName(id)
    local dg = B.DG()
    if dg and type(dg.ItemName) == "function" then
        return dg.ItemName(id)
    end
    return nil, false
end

function B.ItemIcon(id)
    local dg = B.DG()
    if dg and type(dg.ItemIcon) == "function" then
        local ok, tex = pcall(dg.ItemIcon, id)
        if ok then return tex end
    end
    return nil
end

function B.ItemQuality(id)
    local dg = B.DG()
    if dg and type(dg.QualOf) == "function" then
        return dg.QualOf(id)
    end
    return nil
end

function B.RequestItem(id)
    local dg = B.DG()
    if dg and type(dg.RequestItem) == "function" then
        pcall(dg.RequestItem, id)
    end
end

function B.ItemShiftClick(owner, button)
    local dg = B.DG()
    if dg and type(dg.ItemShiftClick) == "function" then
        return dg.ItemShiftClick(owner, button)
    end
end

function B.InsertItemLink(id)
    local dg = B.DG()
    if dg and type(dg.InsertItemLink) == "function" then
        return dg.InsertItemLink(id)
    end
end

function B.ZoneName(id)
    local dg = B.DG()
    if dg and type(dg.ZoneName) == "function" then
        return dg.ZoneName(id)
    end
    return nil
end

function B.QClassColor(...)
    local dg = B.DG()
    if dg and type(dg.QClassColor) == "function" then
        return dg.QClassColor(...)
    end
    return nil
end

function B.NowMs()
    local dg = B.DG()
    if dg and type(dg.__nowMs) == "function" then
        return dg.__nowMs()
    end
    if type(_G.debugprofilestop) == "function" then
        local ok, v = pcall(_G.debugprofilestop)
        if ok and type(v) == "number" then return v end
    end
    return 0
end

function B.Loader()
    local dg = B.DG()
    return dg and dg.Loader or nil
end

function B.Stepping()
    local dg = B.DG()
    return dg and dg.stepping or nil
end

function B.ZoneHint()
    local zh = mainFrom("ZoneHint")
    return type(zh) == "table" and zh or nil
end

function B.ProfessionTracking()
    local pt = mainFrom("ProfessionTracking")
    return type(pt) == "table" and pt or nil
end

function B.LegacySettingRaw(key, slug)
    local fn = mainFrom("ProfSettingRaw")
    if type(fn) == "function" then
        return fn(key, slug)
    end
    return nil
end

function B.ExternalAuctionBridge()
    local ab = mainFrom("AuctionBridge")
    return type(ab) == "table" and ab or nil
end

ns.ProfHostBridge = B
if type(gns) == "table" and gns ~= ns then
    gns.ProfHostBridge = B
end
