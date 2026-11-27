local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local PF = ns.ProfFollow or (type(gns) == "table" and gns.ProfFollow) or {}
ns.ProfFollow = PF
if type(gns) == "table" and gns ~= ns then
    gns.ProfFollow = PF
end

local format = string.format
local floor, ceil, max, min, huge = math.floor, math.ceil, math.max, math.min, math.huge

local function fromNS(key)
    local v = ns[key]
    if v ~= nil then return v end
    if type(gns) == "table" then return gns[key] end
    return nil
end

local function getBridge() return fromNS("ProfHostBridge") end
local function getEngine() return fromNS("ProfFollowEngine") end
local function getTT() return fromNS("ProfTooltips") end
local function getPD() return fromNS("ProfModule") end
local function getXP() return fromNS("ProfExecution") end
local function getRA() return fromNS("ProfRouteAuto") end
local function getEco() return fromNS("ProfEconomy") end
local function getAPI() return fromNS("ProfAPI") end
local function getAuctionBridge() return fromNS("AuctionBridge") or fromNS("ProfAuctionScanner") end
local function getShoppingExport() return fromNS("ProfShoppingExport") end

local function getHui()
    local b = getBridge()
    return b and b.Hui and b.Hui() or nil
end

local L = setmetatable({}, {
    __index = function(_, k)
        local b = getBridge()
        if b and type(b.L) == "function" then return b.L(k) end
        local lt = fromNS("L")
        if type(lt) == "table" and lt[k] ~= nil then return lt[k] end
        return tostring(k)
    end,
})

local function hostReady()
    local b = getBridge()
    return (b and b.IsForeverPagesEnabled and b.IsForeverPagesEnabled() and b.Host and b.Host()) and true or false
end

local function MakeFS(...)
    local b = getBridge()
    if b and b.MakeFS then return b.MakeFS(...) end
    return {}
end

local function NewButton(...)
    local b = getBridge()
    if b and b.NewButton then return b.NewButton(...) end
    return {}
end

local function SetButtonSelected(...)
    local b = getBridge()
    if b and b.SetButtonSelected then return b.SetButtonSelected(...) end
end

local function Unpack(...)
    local b = getBridge()
    if b and b.Unpack then return b.Unpack(...) end
    if type(_G.unpack) == "function" then return _G.unpack(...) end
end

local function Color(name, fallback)
    local b = getBridge()
    return (b and b.Color and b.Color(name)) or fallback
end

local function Const(name, fallback)
    local b = getBridge()
    local v = b and b.Const and b.Const(name)
    if v ~= nil then return v end
    return fallback
end

local function Media(key)
    local b = getBridge()
    return b and b.Media and b.Media(key) or nil
end

local function PlayClickSound(id)
    local b = getBridge()
    if b and b.PlaySound then b.PlaySound(id) end
end

local function ReportError(kind, err)
    local b = getBridge()
    if b and b.SetDebugError then b.SetDebugError(kind, err) end
    local handler = type(_G.geterrorhandler) == "function" and _G.geterrorhandler() or nil
    if type(handler) == "function" then
        pcall(handler, "[DungeonsForeverProf/ProfFollow:" .. tostring(kind) .. "] " .. tostring(err))
    end
end

local function FSW(fs, dflt)
    if not (fs and fs.GetStringWidth) then return dflt or 0 end
    local ok, w = pcall(fs.GetStringWidth, fs)
    if ok and type(w) == "number" then return w end
    local t = fs.GetText and fs:GetText()
    if type(t) == "string" and #t > 0 then return #t * 7 end
    return dflt or 0
end

local function ProfIconTex(name)
    if not name then return Const("FALLBACK_ICON", "Interface\\Icons\\INV_Misc_QuestionMark") end
    if type(name) == "string" and not name:find("\\", 1, true) then
        return "Interface\\Icons\\" .. name
    end
    return name
end

local function RoundFrame(fr, radius, col)
    local hui = getHui()
    if not (hui and hui.BuildRoundBorder) then return nil end
    local pieces = hui.BuildRoundBorder(fr, radius, col, fr, "OVERLAY", "both", 1) or {}
    for _, tex in ipairs(pieces) do tex:SetShown(true) end
    return pieces
end

local function RoundBG(fr, radius, col)
    local hui = getHui()
    if not (hui and hui.BuildRoundedBG) then
        fr:SetBackdropColor(col[1], col[2], col[3], col[4])
        return nil
    end
    fr:SetBackdropColor(0, 0, 0, 0)
    fr.__rbg = hui.BuildRoundedBG(fr, radius, col, "both", false)
    return fr.__rbg
end

local function Accent()
    local pd = getPD()
    if pd and pd.NavAccent then return { pd.NavAccent() } end
    local hui = getHui()
    if hui and hui.ACCENT then return { hui.ACCENT[1], hui.ACCENT[2], hui.ACCENT[3] } end
    return { 0x46 / 255, 0xbf / 255, 0x72 / 255 }
end

local C_OK   = { 0.27, 0.75, 0.45 }
local C_BAD  = { 0.85, 0.30, 0.30 }
local C_HEAD = { 0.95, 0.78, 0.35 }

local W, W_BASE = 375, 375
local PAD = 12
local SRC_COL_W = 68
local SRC_TEXT_W = 56
local NUM_CAP = 56
local TAG_CAP = 46
local BTN_W = { 92, 66, 66 }
local BTN_GAP = 4
local MAT_MAX = 6
local SHOP_MAX = 16
local SWEEP_MAX = 5
local IMPORT_TRIES = 5

-- Runtime cue state resets on file reload by design (muted preference persists in SavedVariables).
local cueState = {}

local function cueFile(kind)
    if kind == "cap" then return Media("VoiceSkillCap") end
    if kind == "item" then return Media("VoiceNextItem") end
    if kind == "on" then return Media("VoiceOn") end
    if kind == "nol" then return Media("VoiceNotLearned") end
    return nil
end

local function cueMuted()
    local eng = getEngine()
    local p = eng and eng.DbProf() or {}
    return (p and p.muteCue) and true or false
end

local function playCue(kind)
    if cueMuted() then return end
    if type(_G.PlaySoundFile) ~= "function" then return end
    local path = cueFile(kind)
    if path then pcall(_G.PlaySoundFile, path, "Master") end
end

local function chatNotify(msg)
    local cf = _G.DEFAULT_CHAT_FRAME
    if cf and cf.AddMessage then
        cf:AddMessage("|cff33ff99无限副本手册:|r " .. tostring(msg), 1, 1, 1)
    end
end

if type(_G.SlashCmdList) == "table" then
    _G.SLASH_DUNGEONSFOREVERVOICE1 = "/dfvoice"
    _G.SLASH_DUNGEONSFOREVERVOICE2 = "/df语音"
    _G.SlashCmdList["DUNGEONSFOREVERVOICE"] = function(msg)
        local k = type(msg) == "string" and msg:match("^%s*(.-)%s*$") or ""
        k = k:lower()
        if k == "cap" or k == "上限" or k == "1" then
            playCue("cap")
            chatNotify(L["播放：专业技能点上限了"])
        elseif k == "item" or k == "下一件" or k == "2" then
            playCue("item")
            chatNotify(L["播放：做下一件物品啦"])
        elseif k == "on" or k == "开启" or k == "3" then
            playCue("on")
            chatNotify(L["播放：语音开启"])
        elseif k == "nol" or k == "未学" or k == "4" then
            playCue("nol")
            chatNotify(L["播放：该配方还未学会，先找训练师学习"])
        else
            playCue("cap")
            chatNotify(L["播放：专业技能点上限了"])
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(1.8, function()
                    playCue("item")
                    chatNotify(L["播放：做下一件物品啦"])
                end)
            end
        end
    end
end

local function updateCues(slug, rankTasks)
    if cueState.slug ~= slug then cueState = { slug = slug } end
    local caps, newCap = {}, false
    for _, task in ipairs(rankTasks or {}) do
        local state = task.state or {}
        if task.due and state.known and state.maxSkill and state.maxSkill > 0
            and state.skill and state.skill >= state.maxSkill then
            local key = tostring(task.profession) .. ":" .. tostring(state.maxSkill)
            caps[key] = true
            if not (cueState.caps and cueState.caps[key]) then newCap = true end
        end
    end
    cueState.caps = caps
    local xp = getXP()
    local run = xp and xp.GetActive and xp.GetActive(slug)
    local index = run and run.currentIndex or 1
    local plan = run and xp.GetPlan and xp.GetPlan(slug)
    local steps = plan and plan.steps
    local seg = steps and steps[index]
    local step = seg and (seg.segmentID or seg)
    local advanced = run and cueState.run == run and cueState.step and step ~= cueState.step
        and index > (cueState.index or 0)
    cueState.run, cueState.step, cueState.index = run, step, index
    local craft = seg and not seg.navigationOnly and not seg.checkpoint and (tonumber(seg[3]) or 0) > 0
        and not (xp and xp.IsConversion and xp.IsConversion(seg))
        and not (xp and xp.IsSpecializationQuest and xp.IsSpecializationQuest(seg))
    if newCap then
        playCue("cap")
    elseif advanced and craft and not next(caps) then
        playCue("item")
    end
end

local function TipOn(bt, title, body)
    bt:SetScript("OnEnter", function(self)
        local tt = getTT()
        if tt and tt.ShowFollowButtonTip then
            tt.ShowFollowButtonTip(self, title, body)
        end
    end)
    bt:SetScript("OnLeave", function()
        local tt = getTT()
        if tt and tt.Hide then tt.Hide() end
    end)
end

local function fmtTime(sec)
    local m = floor(sec / 60)
    local s = floor(sec % 60)
    return format(L["用时 %d 分 %d 秒"], m, s)
end

-- =========================================================================
-- Engine Facade Re-Exports (100% backward-compatible ns.ProfFollow contract)
-- =========================================================================

local function syncEngineRefs()
    local eng = getEngine()
    if not eng then return end
    PF.pendingPlans = eng.pendingPlans
    PF.endedPlan = eng.endedPlan
    PF.bindErrors = eng.bindErrors
end
syncEngineRefs()

function PF.RankTasks(slug, target, steps, currentIndex)
    local eng = getEngine()
    return eng and eng.RankTasks(slug, target, steps, currentIndex) or {}
end

function PF.SpecializationQuestInfo(seg)
    local eng = getEngine()
    return eng and eng.SpecializationQuestInfo(seg) or nil
end

function PF.LearningWarning(slug, progress)
    local eng = getEngine()
    return eng and eng.LearningWarning(slug, progress) or nil
end

function PF.InvalidateRoute()
    local eng = getEngine()
    if eng then eng.InvalidateRoute() end
end

function PF.IsActive(slug)
    local eng = getEngine()
    local s = eng and eng.State()
    if not (s and s.slug == slug and not s.hidden) then return false end
    return (PF.f and PF.f:IsShown()) and true or false
end

function PF.Following(slug)
    local eng = getEngine()
    return eng and eng.Following(slug) or false
end

function PF.SuspendAutoTrack(slug, reason)
    local eng = getEngine()
    if eng then eng.SuspendAutoTrack(slug, reason) end
end

function PF.Sync()
    local eng = getEngine()
    if not eng then return false end
    local changed, resetView = eng.Sync()
    if resetView then PF.view = 0 end
    return changed
end

function PF.ShoppingForPlan(slug, plan)
    local eng = getEngine()
    return eng and eng.ShoppingForPlan(slug, plan) or {}
end

function PF.ShoppingList(slug, onlyStep)
    local eng = getEngine()
    return eng and eng.ShoppingList(slug, onlyStep) or {}
end

function PF.ShoppingSourceText(entry)
    local eng = getEngine()
    return eng and eng.ShoppingSourceText(entry) or nil
end

function PF.ShoppingSourceDetail(entry)
    local eng = getEngine()
    return eng and eng.ShoppingSourceDetail(entry) or nil
end

function PF.VendorPurchases(slug, plan)
    local eng = getEngine()
    return eng and eng.VendorPurchases(slug, plan) or {}
end

function PF.SupplementNeeds(slug)
    local eng = getEngine()
    return eng and eng.SupplementNeeds(slug) or nil
end

function PF.BidPending(id, have)
    local eng = getEngine()
    return eng and eng.BidPending(id, have) or 0
end

function PF.NoteBid(text, replay)
    local eng = getEngine()
    return eng and eng.NoteBid(text, replay, chatNotify) or false
end

function PF.ReplayBids(count)
    local eng = getEngine()
    return eng and eng.ReplayBids(count, chatNotify) or 0
end

function PF.ScanChatBids()
    local eng = getEngine()
    local hits = eng and eng.ScanChatBids(chatNotify) or 0
    if hits > 0 then
        local hud = PF.f or _G.DFProfFollowHUD
        if hud and hud:IsShown() then PF.Paint() end
        if PF.RefreshMainUI then PF.RefreshMainUI() end
    end
    return hits
end

function PF.RefreshRoute(slug)
    local eng = getEngine()
    local s = eng and eng.State()
    if not (s and s.slug) then return end
    if slug and slug ~= s.slug then return end
    PF.InvalidateRoute()
    PF.Sync()
    if PF.f and PF.f:IsShown() then pcall(PF.Paint) end
end

function PF.RefreshMainUI()
    local pd = getPD()
    if pd and pd.built and pd.page and pd.page.IsVisible and pd.page:IsVisible() then
        if pd.RequestRender then pd.RequestRender() end
    end
end

function PF.Prev()
    local eng = getEngine()
    local s = eng and eng.State()
    if not (s and s.slug) then return end
    local _, steps = eng.RouteFor(s.slug, s.skill)
    if not steps then return end
    PF.view = max(-((s.step or 1) - 1), (PF.view or 0) - 1)
    PF.Paint()
end

function PF.Skip()
    local eng = getEngine()
    local s = eng and eng.State()
    if not (s and s.slug) then return end
    local _, steps = eng.RouteFor(s.slug, s.skill)
    if not steps then return end
    PF.view = min(#steps - (s.step or 1) + 1, (PF.view or 0) + 1)
    PF.Paint()
end

function PF.VerifyCurrentOutput(total, ref)
    local eng = getEngine()
    local xp = getXP()
    local s = eng and eng.State()
    if not (s and s.slug and xp and xp.VerifyOutput and xp.Progress) then return false end
    local run = xp.GetRun(s.slug)
    local prog = run and xp.Progress(s.slug, nil, nil, run.planID)
    if not ref and prog then ref = { index = prog.index, item = prog.outputItem, planID = run.planID } end
    if not ref or not ref.item or ref.finished then return false end
    if ref.planID and (not run or ref.planID ~= run.planID) then return false end
    total = tonumber(total)
    if not total or total < 0 or total ~= floor(total) then return false end
    local ok
    if ref.manualConversion or (prog and prog.manualConversion) then
        ok = xp.ConfirmConversion and xp.ConfirmConversion(s.slug, ref.index, total, run and run.planID)
    else
        ok = xp.VerifyOutput(s.slug, ref.index, ref.item, total)
    end
    PF.InvalidateRoute()
    PF.Sync()
    PF.view = 0
    PF.Paint()
    return ok ~= false
end

local function verifyOutputDialog()
    local eng = getEngine()
    local xp = getXP()
    local s = eng and eng.State()
    if not (s and s.slug and xp and xp.GetRun and xp.Progress) then return end
    if not (_G.StaticPopupDialogs and _G.StaticPopup_Show) then return end
    local run = xp.GetRun(s.slug)
    local prog = run and xp.Progress(s.slug, nil, nil, run.planID)
    if not prog or not prog.outputItem or prog.finished then return end
    local data = {
        slug = s.slug,
        index = prog.index,
        item = prog.outputItem,
        total = prog.manualConversion and prog.remainingConversions or prog.actualOutputs or 0,
        manualConversion = prog.manualConversion,
        planID = run.planID,
    }
    _G.StaticPopupDialogs.DF_PROF_VERIFY_OUTPUT = {
        text = prog.manualConversion and L["填写本次已完成的精华转换次数。"]
            or L["填写本步骤累计实际产出件数（不是当前背包数量）。"],
        button1 = L["确认"],
        button2 = L["取消"],
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self)
            local edit = self.editBox or (self.GetEditBox and self:GetEditBox())
            if edit then
                edit:SetText(tostring((self.data and self.data.total) or 0))
                edit:SetFocus()
                edit:HighlightText()
            end
            local b = getBridge()
            if b and b.SkinPopupFont then b.SkinPopupFont(self) end
        end,
        OnAccept = function(self)
            local d = self.data
            local edit = self.editBox or (self.GetEditBox and self:GetEditBox())
            local n = edit and tonumber(edit:GetText())
            if not (d and n and n >= 0 and n == floor(n)) then return end
            PF.VerifyCurrentOutput(n, d)
        end,
    }
    _G.StaticPopup_Show("DF_PROF_VERIFY_OUTPUT", nil, nil, data)
end

-- =========================================================================
-- Crafting Panel Jump & Auction Shopping Export Actions
-- =========================================================================

local jumpPending
local jumpEvt
local jumpApply

local function jumpEvtInit()
    if jumpEvt or type(_G.CreateFrame) ~= "function" then return end
    jumpEvt = PF.__jumpEvt or _G.CreateFrame("Frame")
    PF.__jumpEvt = jumpEvt
    pcall(function() jumpEvt:RegisterEvent("TRADE_SKILL_LIST_UPDATE") end)
    jumpEvt:SetScript("OnEvent", function()
        local p = jumpPending
        if not p or p.eventQueued or p.applying or p.scheduled then return end
        if _G.C_Timer and _G.C_Timer.After then
            p.eventQueued = true
            _G.C_Timer.After(0, function()
                p.eventQueued = nil
                if jumpPending == p then jumpApply() end
            end)
        elseif not p.applying then
            jumpApply()
        end
    end)
end

local function panelShown()
    local pf = _G.ProfessionsFrame
    if pf and pf.IsShown and pf:IsShown() then return true end
    local tf = _G.TradeSkillFrame
    return (tf and tf.IsShown and tf:IsShown()) or false
end

local function CraftingEntrySpellID(index)
    if not _G.C_SpellBook or not _G.C_SpellBook.GetSpellBookItemInfo or not _G.Enum
        or not _G.Enum.SpellBookSpellBank or not _G.GetProfessionInfo then
        return nil
    end
    local _, _, _, _, count, offset = _G.GetProfessionInfo(index)
    if type(count) ~= "number" or type(offset) ~= "number" then return nil end
    local fallback
    for slot = offset + 1, offset + count do
        local info = _G.C_SpellBook.GetSpellBookItemInfo(slot, _G.Enum.SpellBookSpellBank.Player)
        local spellID = info and info.spellID
        if type(spellID) == "number"
            and (not _G.Enum.SpellBookItemType or info.itemType == _G.Enum.SpellBookItemType.Spell) then
            fallback = fallback or spellID
            if _G.C_TradeSkillUI and _G.C_TradeSkillUI.CanTradeSkillShowCraftingUI
                and _G.C_TradeSkillUI.CanTradeSkillShowCraftingUI(spellID) then
                return spellID
            end
        end
    end
    return fallback
end

local function openProfPanel(slug)
    local eng = getEngine()
    local profName = eng and eng.ProfName(slug) or slug
    local api = getAPI()
    local ids = (_G.GetProfessions and { _G.GetProfessions() }) or {}
    local targetLine
    if type(_G.GetProfessionInfo) == "function" then
        for _, idx in ipairs(ids) do
            if idx then
                local nm, _, _, _, _, _, skillLine = _G.GetProfessionInfo(idx)
                local matched = (skillLine and api and api.SkillLineToSlug and api.SkillLineToSlug(skillLine) == slug)
                    or (profName and nm == profName)
                if matched and skillLine then
                    targetLine = skillLine
                    if _G.C_TradeSkillUI and _G.C_TradeSkillUI.OpenTradeSkill
                        and pcall(_G.C_TradeSkillUI.OpenTradeSkill, skillLine) then
                        return true, skillLine
                    end
                end
            end
        end
    end
    for _, idx in ipairs(ids) do
        if idx and _G.GetProfessionInfo and _G.GetProfessionInfo(idx) == profName then
            local sid = CraftingEntrySpellID(idx)
            local nm = sid and eng and eng.SpellName(sid)
            if nm and _G.CastSpellByName and pcall(_G.CastSpellByName, nm) then return true, targetLine end
            if sid and _G.C_Spell and _G.C_Spell.CastSpell and pcall(_G.C_Spell.CastSpell, sid) then return true, targetLine end
        end
    end
    if profName and _G.CastSpellByName then
        if pcall(_G.CastSpellByName, profName) then return true, targetLine end
    end
    return false
end

local function modernJump(p)
    local frame = _G.ProfessionsFrame
    local cp = frame and frame.CraftingPage
    if not (frame and frame.IsShown and frame:IsShown() and cp) then return false end
    local CUI = _G.C_TradeSkillUI
    if p.skillLine and CUI and CUI.GetBaseProfessionInfo then
        local ok, info = pcall(CUI.GetBaseProfessionInfo)
        if not ok or type(info) ~= "table" or tonumber(info.professionID) ~= p.skillLine then return false end
    end
    if cp.IsShown and not cp:IsShown() then
        if _G.EventRegistry and _G.EventRegistry.TriggerEvent then
            pcall(_G.EventRegistry.TriggerEvent, _G.EventRegistry, "Professions.ShowSelectedCraftingPage")
        end
        if cp.IsShown and not cp:IsShown() then return false end
    end
    local form = cp.SchematicForm
    if not form then return false end
    local transaction = form.transaction
    local recipeInfo = form.currentRecipeInfo
    local selected = (transaction and tonumber(transaction.recipeID))
        or (recipeInfo and tonumber(recipeInfo.recipeID))
    if selected ~= p.spellID then
        local search = cp.RecipeList and cp.RecipeList.SearchBox
        if search and search.GetText and search.SetText and search:GetText() ~= "" then
            pcall(search.SetText, search, "")
        end
        if cp.SelectRecipe and CUI and CUI.GetRecipeInfo then
            local ok, info = pcall(CUI.GetRecipeInfo, p.spellID)
            if ok and type(info) == "table" then pcall(cp.SelectRecipe, cp, info) end
        end
        return false
    end
    local box = cp.CreateMultipleInputBox
    if not (box and box.SetValue and box.GetValue) then return false end
    local count = p.count
    if box.GetMaxValue then
        local maxCount = tonumber(box:GetMaxValue())
        if not maxCount or maxCount <= 0 then return false end
        count = min(count, maxCount)
    end
    local ok = pcall(box.SetValue, box, count)
    if ok and tonumber(box:GetValue()) == count then
        p.filledCount = count
        return true
    end
    return false
end

function jumpApply()
    local p = jumpPending
    if not p or p.applying then return end
    p.applying = true
    local selected, counted = false, modernJump(p)
    local frame = _G.ProfessionsFrame
    local modern = frame and frame.CraftingPage and frame.IsShown and frame:IsShown()
    local matches = true
    if p.skillLine and _G.C_TradeSkillUI and _G.C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(_G.C_TradeSkillUI.GetBaseProfessionInfo)
        matches = ok and type(info) == "table" and tonumber(info.professionID) == p.skillLine
    end
    if not counted and not modern and matches and _G.C_TradeSkillUI then
        local verified = false
        if _G.C_TradeSkillUI.SetSelectedRecipe then
            local ok, accepted = pcall(_G.C_TradeSkillUI.SetSelectedRecipe, p.spellID)
            selected = ok and accepted ~= false
            if selected and _G.C_TradeSkillUI.GetSelectedRecipeID then
                local ok2, rid = pcall(_G.C_TradeSkillUI.GetSelectedRecipeID)
                verified = ok2 and tonumber(rid) == p.spellID
            end
        end
        if verified and _G.C_TradeSkillUI.SetRecipeRepeatCount then
            local ok, accepted = pcall(_G.C_TradeSkillUI.SetRecipeRepeatCount, p.spellID, p.count)
            counted = ok and accepted ~= false
        end
    end
    if not counted and not modern and matches and type(_G.GetNumTradeSkills) == "function" then
        for i = 1, _G.GetNumTradeSkills() do
            local nm = _G.GetTradeSkillInfo(i)
            if nm == p.name then
                if _G.SelectTradeSkill then
                    local ok, accepted = pcall(_G.SelectTradeSkill, i)
                    selected = ok and accepted ~= false
                end
                if selected and _G.GetTradeSkillSelectionIndex then
                    local ok, index = pcall(_G.GetTradeSkillSelectionIndex)
                    selected = ok and index == i
                end
                if selected and _G.SetTradeSkillRepeatCount then
                    local ok, accepted = pcall(_G.SetTradeSkillRepeatCount, i, p.count)
                    counted = ok and accepted ~= false
                end
                break
            end
        end
    end
    p.applying = nil
    if jumpPending ~= p then return end
    if counted then
        jumpPending = nil
        chatNotify(format(L["已定位配方 %s，预填制造数量 %d —— 在专业面板点一次制造即可"], p.name, p.filledCount or p.count))
    elseif not p.scheduled then
        if (p.retries or 0) < 12 and _G.C_Timer and _G.C_Timer.After then
            p.scheduled = true
            _G.C_Timer.After(0.2, function()
                p.scheduled = nil
                if jumpPending ~= p then return end
                p.retries = (p.retries or 0) + 1
                jumpApply()
            end)
        else
            jumpPending = nil
            chatNotify(selected and format(L["已选中配方 %s，请在专业面板输入制造数量"], p.name)
                or panelShown() and L["面板已打开但未能自动定位配方，请在列表中手动选择"]
                or L["无法自动打开专业面板，请手动打开后重试"])
        end
    end
end

local function jumpCraft(stepIdx)
    jumpPending = nil
    local eng = getEngine()
    local s = eng and eng.State()
    if not (s and s.slug) then return end
    local _, steps, plan = eng.RouteFor(s.slug, s.skill)
    local index = stepIdx or (s.step or 1)
    local seg = steps and steps[index]
    if not seg then return end
    local xp = getXP()
    if seg.navigationOnly or seg.checkpoint or seg[3] == 0
        or (xp and ((xp.IsConversion and xp.IsConversion(seg)) or (xp.IsSpecializationQuest and xp.IsSpecializationQuest(seg)))) then
        return
    end
    local progress = xp and xp.Progress and xp.Progress(s.slug, seg.segmentID or index)
    local spellID = seg[3]
    local rec = eng.StepRecipe(seg, eng.RecMap(s.slug)[spellID])
    local learned = eng.IsLearned(spellID)
    local eco = getEco()
    if not learned and eco and eco.LearningSource and eco.LearningSource(rec) == "trainer" then playCue("nol") end
    local learningWarning = eng.LearningWarning(s.slug, progress)
    if learningWarning then chatNotify(learningWarning); return end
    if not learned then chatNotify(L["该配方还未学会，先找训练师学习"]); return end
    local mats = eng.RecMats(rec)
    if mats then
        for _, m in ipairs(mats) do
            if (eng.Have(m[1], not (plan and plan.useBagMaterials)) or 0) < (m[2] or 1) then
                local sup = eng.SupplementNeeds(s.slug)
                if sup then
                    chatNotify(format(L["本步材料不足：缺 %d 种共 %d 件，先按购物清单补齐"], sup.kinds, sup.qty))
                else
                    chatNotify(L["材料不足，先按购物清单备齐再制造"])
                end
                return
            end
        end
    end
    local count = max(1, ceil(eng.CraftsLeft(seg, s.skill, rec, s.slug, index ~= s.step)))
    if xp and xp.SafeCraftCount then
        count = xp.SafeCraftCount(s.slug, seg.segmentID or index, count)
        if count <= 0 then
            chatNotify(L["本步备用不足，或材料需留给后续步骤；请检查采购清单或续算。"])
            return
        end
    end
    local name = eng.SpellName(spellID)
    if not name then chatNotify(L["配方数据未就绪，稍后再试"]); return end
    jumpEvtInit()
    local opened, skillLine = openProfPanel(seg.profession or s.slug)
    if opened then
        jumpPending = { spellID = spellID, count = count, name = name, skillLine = skillLine }
        chatNotify(format(L["正在打开专业面板并定位 %s（预填数量 %d）…"], name, count))
        jumpApply()
    else
        chatNotify(L["无法自动打开专业面板，请手动打开后重试"])
    end
end

local importTries = 0
local function DoImport(slug, profName)
    local eng = getEngine()
    if not (eng and eng.HasRoute(slug)) then return end
    local s0 = eng.State()
    local tmp
    if s0 and s0.slug == slug then
        tmp = s0
    else
        local cur = eng.SkillOf(slug) or 0
        tmp = { slug = slug, skill = cur, step = eng.DerivedStep(slug, cur) or 1 }
    end
    local list = eng.ShopList(tmp)
    local items, missing, inventoryUnknown = {}, 0, false
    for _, e in ipairs(list) do
        local auction = slug == "poisons" or e.source == "ah" or e.source == "auction" or e.source == "mixed"
        if auction and e.haveKnown == false then
            inventoryUnknown = true
        elseif auction then
            local nm, got = eng.ItemName(e.id)
            if not got then
                missing = missing + 1
                eng.RequestItem(e.id)
            else
                local lack = e.planPurchases and not e.purchaseUnknown and (e.ahCount or 0) or max(0, e.need - e.have)
                if e.purchaseUnknown then lack = 0 end
                if not e.planPurchases and e.source == "mixed" then lack = min(lack, e.ahCount or 0) end
                if lack > 0 then
                    items[#items + 1] = { name = nm, need = lack, id = e.id }
                end
            end
        end
    end
    if missing > 0 and importTries < IMPORT_TRIES and _G.C_Timer and _G.C_Timer.After then
        importTries = importTries + 1
        _G.C_Timer.After(1, function() DoImport(slug, profName) end)
        return
    end
    importTries = 0
    if inventoryUnknown then chatNotify(L["请打开背包和银行，再查看需要购买的数量。"]) end
    local ab = getAuctionBridge()
    if ab and type(ab.DoImport) == "function" then
        ab.DoImport(profName, items)
        return
    end
    local se = getShoppingExport()
    if se and type(se.DoImport) == "function" then
        se.DoImport(profName, items)
    end
end
PF.ImportShoppingList = DoImport

-- =========================================================================
-- HUD Frame Construction & Hot-Reload-Safe Script Rebinding
-- =========================================================================

local function MakeLine(parent, fs, color)
    local t = MakeFS(parent, fs, color, "LEFT")
    t:SetWordWrap(false)
    t:Hide()
    return t
end

local function wireFrameScripts(f)
    local eng = getEngine()
    f:SetScript("OnHide", function() cueState = {} end)
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint(1)
        if eng then eng.DbProf().followPos = { pt, "UIParent", x, y } end
    end)
    f:SetScript("OnMouseWheel", function(_, delta)
        local e = getEngine()
        local s = e and e.State()
        if not (s and s.slug) then return end
        local _, steps = e.RouteFor(s.slug, s.skill)
        if not steps then return end
        PF.view = max(-(s.step - 1), min(#steps - s.step + 1, (PF.view or 0) - delta))
        PF.Paint()
    end)
    f:SetScript("OnEvent", function(_, event, message)
        if event == "CHAT_MSG_SYSTEM" then
            if PF.NoteBid(message) then
                PF.Paint()
                if PF.RefreshMainUI then PF.RefreshMainUI() end
            end
            return
        end
        local e = getEngine()
        if f:IsShown() and not (e and e.TrackingPaused()) then
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0, function()
                    local e2 = getEngine()
                    if e2 and e2.TrackingPaused() then return end
                    PF.Sync()
                    PF.Paint()
                end)
            else
                PF.Sync()
                PF.Paint()
            end
        end
    end)

    if f.rankHint then
        f.rankHint:SetScript("OnEnter", function(self)
            local tt = getTT()
            if tt and tt.ShowFollowRankHintTip then
                tt.ShowFollowRankHintTip(self, self.statusTitle, self.statusDetail, self.tasks)
            end
        end)
        f.rankHint:SetScript("OnLeave", function()
            local tt = getTT()
            if tt and tt.Hide then tt.Hide() end
        end)
    end

    for _, card in ipairs({ f.card, f.card2 }) do
        if card then
            card:SetScript("OnEnter", function(self)
                local tt = getTT()
                if tt and tt.ShowFollowCardTip then
                    tt.ShowFollowCardTip(self, self.__guide, self.__it, self.__mats, self.__spell ~= nil)
                end
            end)
            card:SetScript("OnLeave", function()
                local tt = getTT()
                if tt and tt.Hide then tt.Hide() end
            end)
            card:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    jumpPending = nil
                    if self.__spell then
                        jumpCraft(self.__step)
                        PlayClickSound(1)
                    end
                end
            end)
        end
    end

    if f.shop then
        f.shop:SetScript("OnMouseWheel", function(_, delta)
            PF.shopScroll = max(0, (PF.shopScroll or 0) - delta)
            PF.Paint()
        end)
        if f.shop.missTog then
            f.shop.missTog:SetScript("OnClick", function(self)
                local e = getEngine()
                if not e then return end
                e.DbProf().shopOnlyMiss = not e.OnlyMissView()
                self:SetChecked(e.OnlyMissView())
                PF.Paint()
                PlayClickSound(1)
            end)
            TipOn(f.shop.missTog, L["仅显示缺失"],
                L["开启：购物清单只列出还缺的材料，已备齐的自动隐藏。"])
        end
        for _, src0 in ipairs(f.__rowsShopSrcPill or {}) do
            src0:SetScript("OnEnter", function(self)
                local r = self.__row
                if not r or not r.srcText then return end
                local tt = getTT()
                local e = getEngine()
                if tt and tt.ShowFollowSourceTip then
                    tt.ShowFollowSourceTip(self, r, (e and e.VendorLoc(r.npcID) ~= nil) or false, PF.ShoppingSourceDetail(r.src))
                end
            end)
            src0:SetScript("OnLeave", function()
                local tt = getTT()
                if tt and tt.Hide then tt.Hide() end
            end)
            src0:SetScript("OnMouseUp", function(self, btn)
                if btn ~= "LeftButton" then return end
                local r = self.__row
                if not r or r.srcKind ~= 1 or not r.npcID then return end
                local pd = getPD()
                local e = getEngine()
                local loc = e and e.VendorLoc(r.npcID) or nil
                if pd and pd.MarkVendorLoc then pd.MarkVendorLoc(loc) end
                if not loc then
                    chatNotify(format(L["%s 的位置暂未收录"], r.srcFull or r.srcText or "?"))
                end
                PlayClickSound(1)
            end)
        end
    end

    if f.shopImp then
        f.shopImp:SetScript("OnClick", function()
            local e = getEngine()
            local s0 = e and e.State()
            if not (s0 and s0.slug) then return end
            DoImport(s0.slug, e.ProfName(s0.slug))
            PlayClickSound(1)
        end)
        TipOn(f.shopImp, L["一键导入到拍卖行"],
            L["将拍卖行采购的缺口导入拍卖行插件的购物清单；NPC 货物和自制材料不导入，同名清单将被覆盖。"])
    end

    if f.shopStep then
        f.shopStep:SetScript("OnClick", function()
            local e = getEngine()
            if not e then return end
            e.DbProf().shopStepView = not (e.DbProf().shopStepView and true or false)
            PF.shopScroll = 0
            PF.Paint()
            PlayClickSound(1)
        end)
        TipOn(f.shopStep, L["分步 / 汇总"],
            L["汇总：所有步骤的材料合并成一行。分步：按首次需要的步骤分组列出，便于分段采购。"])
    end

    if f.nowBtn then
        f.nowBtn:SetScript("OnClick", function() PF.view = 0; PF.Paint(); PlayClickSound(1) end)
    end
    if f.verifyBtn then
        f.verifyBtn:SetScript("OnClick", function() verifyOutputDialog(); PlayClickSound(1) end)
    end

    if f.btns then
        local onclick = {
            function() PF.showShop = not PF.showShop; PF.Paint() end,
            function() PF.Prev() end,
            function() PF.Skip() end,
        }
        for i = 1, 3 do
            if f.btns[i] then
                f.btns[i]:SetScript("OnClick", function() onclick[i](); PlayClickSound(1) end)
            end
        end
    end

    if f.xBtn then
        f.xBtn:SetScript("OnClick", function()
            local e = getEngine()
            local s = e and e.State()
            if s then s.hidden = true end
            f:Hide()
            if PF.RefreshMainUI then PF.RefreshMainUI() end
        end)
        TipOn(f.xBtn, L["隐藏 HUD"], L["关闭 HUD 只隐藏窗口，不会结束追踪。"] .. "\n"
            .. L["不再升级时，请在升级页点击追踪进度按钮结束追踪。"])
    end

    if f.muteBtn then
        f.muteBtn:SetScript("OnClick", function()
            local e = getEngine()
            if not e then return end
            local p = e.DbProf()
            p.muteCue = (not p.muteCue) and true or nil
            PF.PaintMute()
            chatNotify(p.muteCue and L["已静音：不再播放升级语音"] or L["已恢复语音提示"])
            if not p.muteCue then playCue("on") end
            PlayClickSound(1)
        end)
        f.muteBtn:SetScript("OnEnter", function(self)
            self.__hover = true
            PF.PaintMute(self)
            local tt = getTT()
            if tt and tt.ShowFollowMuteTip then tt.ShowFollowMuteTip(self, cueMuted()) end
        end)
        f.muteBtn:SetScript("OnLeave", function(self)
            self.__hover = false
            PF.PaintMute(self)
            local tt = getTT()
            if tt and tt.Hide then tt.Hide() end
        end)
        PF.PaintMute(f.muteBtn)
    end
end

local function ensureTickers()
    if not (_G.C_Timer and _G.C_Timer.NewTicker) then return end
    if not PF.bidTicker then
        local eng = getEngine()
        if eng then eng.bidScanCount = nil end
        PF.bidTicker = _G.C_Timer.NewTicker(2, function()
            if PF.ScanChatBids then PF.ScanChatBids() end
        end)
    end
    if not PF.syncTicker then
        PF.syncTicker = _G.C_Timer.NewTicker(1, function()
            if PF.f and PF.f:IsShown() and PF.Sync() then PF.Paint() end
        end)
    end
end

local buildSec = 0
local buildSecTotal = 8
local bgGate = 0
local buildingFrame

local function BuildStep(n)
    if n then
        buildSec = n
        if buildingFrame and buildingFrame.barBG and buildingFrame.zone then
            local frac = n / buildSecTotal
            if frac > 1 then frac = 1 end
            buildingFrame.zone:ClearAllPoints()
            buildingFrame.zone:SetPoint("TOPLEFT", buildingFrame.barBG, "TOPLEFT", 0, 0)
            buildingFrame.zone:SetWidth(max(1, floor((W - 20) * frac + 0.5)))
            local ac = Accent()
            buildingFrame.zone:SetVertexColor(ac[1], ac[2], ac[3], 0.9)
            buildingFrame.zone:Show()
        end
    end
    if not coroutine.running() then return end
    if not _G.debugprofilestop then return end
    local now = _G.debugprofilestop()
    if now - bgGate >= 3 then
        bgGate = now
        coroutine.yield()
    end
end

local function BuildBody()
    local existing = PF.f or _G.DFProfFollowHUD
    if existing and existing.__dfBuilt then
        PF.f = existing
        wireFrameScripts(existing)
        ensureTickers()
        return
    end
    buildSec = 0
    bgGate = 0

    local b = getBridge()
    local C_GOLD = Color("C_GOLD", { 1, 0.82, 0 })
    local C_GREY = Color("C_GREY", { 0.55, 0.55, 0.55 })
    local C_DIM = Color("C_DIM", { 0.63, 0.63, 0.63 })
    local C_TEXT = Color("C_TEXT", { 0.88, 0.88, 0.88 })
    local C_WHITE = Color("C_WHITE", { 1, 1, 1 })

    local f = _G.CreateFrame("Frame", "DFProfFollowHUD", _G.UIParent, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
    buildingFrame = f
    f:SetSize(W, 10)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("CHAT_MSG_SKILL")
    f:RegisterEvent("CHAT_MSG_SYSTEM")

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bgCol = { 0, 0, 0, 0.35 }
    local hui = getHui()
    if b and b.HuiTheme and b.HuiTheme() == "hui" and hui and hui.layer and hui.layer.L0 then
        local l0 = hui.layer.L0
        bgCol = { l0[1], l0[2], l0[3], 0.95 }
        f:SetBackdropBorderColor(1, 1, 1, 0.10)
    else
        f:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
    end
    RoundBG(f, 6, bgCol)
    if hui and hui.SkinShadow then
        f:SetHeight(200)
        hui.SkinShadow(f, 16, 0.55, 6)
        f:SetHeight(10)
    end
    f.__round = RoundFrame(f, 6, { 1, 1, 1, 0.25 })
    if f.__round then f:SetBackdropBorderColor(0, 0, 0, 0) end
    BuildStep(1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if hui and hui.RoundIcon then hui.RoundIcon(f.icon) end
    f.icon:SetSize(24, 24)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)

    f.title = MakeFS(f, 16, C_TEXT, "LEFT")
    f.title:SetWordWrap(false)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -14)

    f.capWarn = MakeFS(f, 12, { 0.95, 0.32, 0.32 }, "LEFT")
    f.capWarn:SetWordWrap(false)
    f.capWarn:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
    f.capWarn:Hide()

    f.skill = MakeFS(f, 16, C_TEXT, "LEFT")
    f.skill:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -42)

    f.noLearn = _G.CreateFrame("Frame", nil, f, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
    f.noLearn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    f.noLearn:SetHeight(22)
    f.noLearn:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    RoundBG(f.noLearn, 5, { 0.42, 0.09, 0.09, 0.92 })
    f.noLearn:SetBackdropBorderColor(0.93, 0.32, 0.32, 1)
    f.noLearn.__round = RoundFrame(f.noLearn, 5, { 0.93, 0.32, 0.32, 1 })
    if f.noLearn.__round then f.noLearn:SetBackdropBorderColor(0, 0, 0, 0) end
    f.noLearnTxt = MakeFS(f.noLearn, 12, { 1, 0.86, 0.86 }, "CENTER")
    f.noLearnTxt:SetWordWrap(false)
    f.noLearnTxt:SetPoint("CENTER", f.noLearn, "CENTER", 0, 0)
    f.noLearnTxt:SetText(L["未学习该专业"])
    do
        local cw = 72
        local pd = getPD()
        if pd and pd.TextW then
            local okw, wv = pcall(pd.TextW, L["未学习该专业"], 12)
            if okw and type(wv) == "number" then cw = ceil(wv) end
        end
        f.noLearn:SetWidth(cw + 20)
    end
    f.noLearn:Hide()

    f.rankHint = _G.CreateFrame("Frame", nil, f)
    f.rankHint:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -39)
    f.rankHint:SetSize(196, 24)
    f.rankHint:EnableMouse(true)
    f.rankHint:Hide()

    f.seg = MakeFS(f, 16, C_GREY, "RIGHT")
    f.seg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -42)

    f.barBG = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.barBG:SetColorTexture(1, 1, 1, 0.12)
    f.barBG:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -66)
    f.barBG:SetSize(W - 20, 5)

    f.zone = f:CreateTexture(nil, "OVERLAY")
    f.zone:SetColorTexture(1, 1, 1, 1)
    f.zone:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -66)
    f.zone:SetSize(1, 5)

    f.bar = f:CreateTexture(nil, "OVERLAY")
    f.bar:SetColorTexture(1, 1, 1, 1)
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -66)
    f.bar:SetSize(1, 5)
    f:SetHeight(90)
    f:Show()
    BuildStep(2)

    local function CreateCard()
        local card = _G.CreateFrame("Frame", nil, f, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        local cardCol = { 1, 1, 1, 0.06 }
        if b and b.HuiTheme and b.HuiTheme() == "hui" and hui and hui.layer and hui.layer.L1 then
            local l1 = hui.layer.L1
            cardCol = { l1[1], l1[2], l1[3], 0.95 }
        end
        RoundBG(card, 6, cardCol)
        card:SetBackdropBorderColor(0, 0, 0, 0)
        card.__round = RoundFrame(card, 6, { 0, 1, 0.4, 0.9 })
        card:EnableMouse(true)

        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if hui and hui.RoundIcon then hui.RoundIcon(card.icon) end
        card.icon:SetSize(26, 26)
        card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)

        card.name = MakeFS(card, 16, C_TEXT, "LEFT")
        card.name:SetWordWrap(false)
        card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 42, -9)

        card.range = MakeFS(card, 14, C_GREY, "LEFT")
        card.range:SetWordWrap(false)
        card.range:SetPoint("TOPLEFT", card, "TOPLEFT", 42, -12)

        card.crafts = MakeFS(card, 14, C_GREY, "LEFT")
        card.crafts:SetWordWrap(false)
        card.crafts:SetPoint("TOPLEFT", card, "TOPLEFT", 42, -33)

        local pd = getPD()
        card.chipLearn = b and b.MakeBadge and b.MakeBadge(card, Const("Q_BADGE_SHARE_BG"))
        card.chipSrc = b and b.MakeBadge and b.MakeBadge(card,
            (pd and pd.CARD_COL and pd.CARD_COL.trainer) or { 0.29, 0.33, 0.40 })
        for _, ch in ipairs({ card.chipLearn, card.chipSrc }) do
            if ch and ch.lab then
                ch.lab:SetFont(b and b.Font and b.Font() or "Fonts\\FRIZQT__.TTF", Const("Q_BADGE_FS", 11),
                    (hui and hui.FontFlags and hui.FontFlags("OUTLINE")) or "OUTLINE")
                ch:Hide()
            end
        end

        card.matHead = MakeFS(card, 14, C_GREY, "LEFT")
        card.matHead:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -56)
        BuildStep(3)

        card.__rowsMat, card.__rowsIcon, card.__rowsBadge = {}, {}, {}
        local rowsMat, rowsMatIcon, rowsMatBadge = card.__rowsMat, card.__rowsIcon, card.__rowsBadge
        for i = 1, MAT_MAX + 1 do
            BuildStep()
            rowsMat[i] = MakeLine(card, 14, C_TEXT)
            local ic = card:CreateTexture(nil, "ARTWORK")
            ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            if hui and hui.RoundIcon then hui.RoundIcon(ic) end
            ic:SetSize(22, 22)
            ic:Hide()
            rowsMatIcon[i] = ic
            local bd = MakeFS(card, 14, C_GOLD, "RIGHT")
            bd:SetFont((b and b.Font and b.Font()) or "Fonts\\FRIZQT__.TTF", 14, "THICKOUTLINE")
            bd:SetShadowColor(0, 0, 0, 1)
            bd:SetShadowOffset(1, -1)
            bd:SetWordWrap(false)
            bd:Hide()
            rowsMatBadge[i] = bd
        end
        card:Hide()
        return card
    end
    f.card = CreateCard()
    f.card2 = CreateCard()
    BuildStep(4)

    f.shop = _G.CreateFrame("Frame", nil, f, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
    f.shop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local shopCol = { 1, 1, 1, 0.04 }
    if b and b.HuiTheme and b.HuiTheme() == "hui" and hui and hui.layer and hui.layer.L1 then
        local l1s = hui.layer.L1
        shopCol = { l1s[1], l1s[2], l1s[3], 0.95 }
    end
    RoundBG(f.shop, 6, shopCol)
    f.shop:SetBackdropBorderColor(1, 1, 1, 0.14)
    f.shop.__round = RoundFrame(f.shop, 6, { 1, 1, 1, 0.14 })
    if f.shop.__round then f.shop:SetBackdropBorderColor(0, 0, 0, 0) end
    local labW = 70
    do
        local pd = getPD()
        if pd and pd.TextW then
            local okw, wv = pcall(pd.TextW, L["仅显示缺失"], 14)
            if okw and type(wv) == "number" then labW = ceil(wv) end
        end
    end
    f.shop.missTog = _G.CreateFrame("CheckButton", nil, f.shop)
    f.shop.missTog:SetSize(36, 20)
    f.shop.missTog:EnableMouse(true)
    if hui and hui.ReskinToggle then hui.ReskinToggle(f.shop.missTog) end
    f.shop.missTog:SetPoint("TOPRIGHT", f.shop, "TOPRIGHT", -6, -4)
    f.shop.missLab = MakeFS(f.shop, 14, C_TEXT, "RIGHT")
    f.shop.missLab:SetWordWrap(false)
    f.shop.missLab:SetPoint("RIGHT", f.shop.missTog, "LEFT", -4, 0)
    f.shop.missLab:SetText(L["仅显示缺失"])
    local eng = getEngine()
    f.shop.missTog:SetChecked(eng and eng.OnlyMissView() or false)
    f.shop.empty = MakeFS(f.shop, 14, C_GREY, "LEFT")
    f.shop.empty:SetPoint("TOPLEFT", f.shop, "TOPLEFT", 8, -30)
    f.shop.empty:Hide()
    f.shop:EnableMouse(true)
    f.shop:EnableMouseWheel(true)
    f.shop.sbarTrack = f.shop:CreateTexture(nil, "OVERLAY")
    f.shop.sbarTrack:SetColorTexture(1, 1, 1, 0.10)
    f.shop.sbarTrack:SetPoint("TOPRIGHT", f.shop, "TOPRIGHT", -4, -28)
    f.shop.sbarTrack:Hide()
    f.shop.sbarThumb = f.shop:CreateTexture(nil, "OVERLAY")
    f.shop.sbarThumb:SetColorTexture(1, 1, 1, 0.35)
    f.shop.sbarThumb:Hide()
    f.shop:Hide()
    BuildStep(5)

    f.__rowsShop, f.__rowsShopNum = {}, {}
    f.__rowsShopMissPill, f.__rowsShopSoldPill, f.__rowsShopTagPill, f.__rowsShopSrcPill = {}, {}, {}, {}
    for i = 1, SHOP_MAX + 1 do
        BuildStep()
        f.__rowsShop[i] = MakeLine(f.shop, 14, C_TEXT)
        f.__rowsShopNum[i] = MakeLine(f.shop, 14, C_GOLD)
        local function MakePill(color)
            local p = _G.CreateFrame("Frame", nil, f.shop, "BackdropTemplate")
            local solid = hui and hui.BuildSolidFill and true
            if solid then
                p:SetHeight((hui.ChipH and hui.ChipH(14)) or 13.7)
                p.__chipFill = hui.BuildSolidFill(p, hui.CHIP_S_R, hui.layer.L2)
                p.__border = hui.BuildRoundBorder(p, hui.CHIP_S_R, { 1, 1, 1, 1 }, nil, "BORDER", "both", 1)
                p.fs = MakeFS(p, hui.CHIP_S_FS, C_WHITE, "CENTER")
            else
                p:SetHeight(17)
                local cols
                if hui and hui.BuildCapsule then
                    cols = hui.BuildCapsule(p, 8, hui.layer.L2)
                else
                    local tx = p:CreateTexture(nil, "BACKGROUND")
                    tx:SetAllPoints()
                    tx:SetColorTexture(1, 1, 1, 1)
                    cols = { tx }
                end
                p.__cols = cols
                p.fs = MakeFS(p, 14, color, "CENTER")
            end
            if solid then
                p.fs:SetPoint("CENTER", p, "CENTER", 0, (hui.ChipLabelDY and hui.ChipLabelDY(hui.CHIP_S_FS)) or 0.5)
            else
                p.fs:SetAllPoints(p)
            end
            p.fs:SetWordWrap(false)
            p:Hide()
            return p
        end
        f.__rowsShopMissPill[i] = MakePill(C_TEXT)
        f.__rowsShopSoldPill[i] = MakePill(C_TEXT)
        f.__rowsShopTagPill[i] = MakePill(C_DIM)
        f.__rowsShopSrcPill[i] = MakePill(C_HEAD)
        local src0 = f.__rowsShopSrcPill[i]
        src0:EnableMouse(true)
        if src0.SetHitRectInsets then src0:SetHitRectInsets(-2, -3, -3, -2) end
    end
    BuildStep(6)

    f.shopImp = NewButton(f.shop, L["一键导入"], 66, 20, 13)
    f.shopImp:SetPoint("RIGHT", f.shop.missTog, "LEFT", -(labW + 10), 0)

    f.shopStep = NewButton(f.shop, L["分步"], 48, 20, 13)
    f.shopStep:SetPoint("RIGHT", f.shopImp, "LEFT", -10, 0)

    f.finish = MakeFS(f, 14, C_OK, "LEFT")
    f.finish:SetWordWrap(false)
    f.finish:Hide()
    f.scanStatus = MakeFS(f, 11, C_DIM, "LEFT")
    f.scanStatus:SetWordWrap(true)
    f.scanStatus:Hide()

    local nowW = 68
    do
        local pd = getPD()
        if pd and pd.TextW then
            local ok, wv = pcall(pd.TextW, L["回到当前"], 13)
            if ok and type(wv) == "number" then nowW = max(nowW, ceil(wv) + 14) end
            ok, wv = pcall(pd.TextW, L["校正产出"], 13)
            if ok and type(wv) == "number" then nowW = max(nowW, ceil(wv) + 14) end
        end
    end
    f.cardBtnW = nowW

    f.nowBtn = NewButton(f.card, L["回到当前"], nowW, 20, 13)
    f.nowBtn:SetFrameLevel((f.card:GetFrameLevel() or 0) + 6)
    f.nowBtn:Hide()

    f.verifyBtn = NewButton(f.card, L["校正产出"], nowW, 20, 13)
    f.verifyBtn:SetFrameLevel((f.card:GetFrameLevel() or 0) + 6)
    f.verifyBtn:Hide()

    local labels = { L["购物清单"], L["上一步"], L["下一步"] }
    f.btns = {}
    for i = 1, 3 do
        f.btns[i] = NewButton(f, labels[i], BTN_W[i], 22, 14)
    end

    f.xBtn = NewButton(f, "×", 24, 22, 14)
    f.xBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    f.muteBtn = NewButton(f, "", 24, 22, 14)
    f.muteBtn:SetPoint("TOPRIGHT", f.xBtn, "TOPLEFT", -4, 0)
    f.muteBtn.tex = f.muteBtn:CreateTexture(nil, "ARTWORK")
    f.muteBtn.tex:SetSize(12, 12)
    f.muteBtn.tex:SetPoint("CENTER", f.muteBtn, "CENTER", 0, 0)
    f.muteBtn.tex:SetTexture(Media("ProfMute"))
    BuildStep(7)

    local pos = eng and eng.DbProf().followPos
    f:ClearAllPoints()
    if pos and pos[1] then
        f:SetPoint(pos[1], pos[2] or _G.UIParent, pos[3], pos[4])
    else
        f:SetPoint("CENTER", _G.UIParent, "CENTER", 340, 60)
    end

    f.__dfBuilt = true
    wireFrameScripts(f)
    ensureTickers()
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(2, function() if PF.ReplayBids then PF.ReplayBids(5) end end)
    end

    BuildStep(8)
    buildingFrame = nil
    PF.f = f
end

function PF.Build()
    if not hostReady() then return end
    if PF.f then
        if PF.f.__dfBuilt then
            wireFrameScripts(PF.f)
            ensureTickers()
            if PF.onBuilt then
                local cb = PF.onBuilt
                PF.onBuilt = nil
                cb()
            end
            return
        end
        pcall(PF.f.UnregisterAllEvents, PF.f)
        pcall(PF.f.Hide, PF.f)
        PF.f = nil
    end
    if PF.building then return end
    PF.building = true
    local co = coroutine.create(BuildBody)
    local function pump()
        local ok, err = coroutine.resume(co)
        if not ok then
            PF.building = false
            PF.onBuilt = nil
            if buildingFrame then
                pcall(buildingFrame.Hide, buildingFrame)
                buildingFrame = nil
            end
            PF.f = nil
            ReportError("build", err)
            return
        end
        if coroutine.status(co) ~= "dead" then
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0, pump)
            else
                pump()
            end
        else
            PF.building = false
            if PF.onBuilt then
                local cb = PF.onBuilt
                PF.onBuilt = nil
                cb()
            end
        end
    end
    pump()
end

function PF.PaintMute(btn)
    local bt = btn or (PF.f and PF.f.muteBtn)
    if not (bt and bt.tex) then return end
    local muted = cueMuted()
    SetButtonSelected(bt, muted)
    if bt.__hover then
        bt.tex:SetVertexColor(1, 1, 1, 1)
    elseif muted then
        bt.tex:SetVertexColor(0.95, 0.32, 0.32, 0.98)
    else
        local r, g, b = 0.78, 0.78, 0.78
        local xb = PF.f and PF.f.xBtn
        if xb and xb.GetFontString then
            local fs = xb:GetFontString()
            if fs and fs.GetTextColor then
                local tr, tg, tb = fs:GetTextColor()
                if tr then r, g, b = tr, tg, tb end
            end
        end
        bt.tex:SetVertexColor(r, g, b, 0.95)
    end
end

function PF.Toggle(slug)
    local eng = getEngine()
    if not (eng and eng.HasRoute(slug)) then return end
    if not hostReady() then return end
    if PF.ConnectExecution then PF.ConnectExecution() end
    local p = eng.DbProf()
    p.follow = p.follow or {}
    local k = eng.CharKey()
    local s = p.follow[k]
    if s and s.slug ~= slug then s = nil end
    if s and not s.hidden and PF.building then
        s.hidden = true
        PF.onBuilt = nil
        PF.RefreshMainUI()
        return
    end
    if s and not s.hidden and PF.f and PF.f:IsShown() then
        s.hidden = true
        PF.f:Hide()
        PF.RefreshMainUI()
        return
    end
    if not s then
        eng.endedPlan[slug] = nil
        local cur = eng.SkillOf(slug) or 0
        s = { slug = slug, skill = cur, step = eng.DerivedStep(slug, cur) or 1, t0 = _G.time and _G.time() or 0 }
        local _mode, _steps = eng.RouteFor(slug, cur)
        s.rkey = eng.RouteKey(_mode, _steps)
        p.follow[k] = s
    end
    s.hidden = nil
    s.autoTrackSuspended = nil
    PF.InvalidateRoute()
    if PF.f then
        PF.Sync()
        if PF.ReplayBids then PF.ReplayBids(5) end
        PF.view = 0
        PF.f:Show()
        PF.Paint()
        PF.RefreshMainUI()
        return
    end
    if PF.building then return end
    PF.onBuilt = function()
        if not PF.f then return end
        PF.Sync()
        if PF.ReplayBids then PF.ReplayBids(5) end
        PF.view = 0
        PF.f:Show()
        PF.Paint()
        PF.RefreshMainUI()
    end
    PF.Build()
end

-- =========================================================================
-- HUD Painting Pipeline (Header / Cards / Shop / Footer)
-- =========================================================================

local sweep = 0
local function sweepPaint(pending)
    if pending and sweep < SWEEP_MAX and _G.C_Timer and _G.C_Timer.After then
        sweep = sweep + 1
        _G.C_Timer.After(2, function() if PF.f and PF.f:IsShown() then PF.Paint() end end)
    elseif not pending then
        sweep = 0
    end
end

local function paintMats(card, seg, rm, soldMemo, w, remaining, resR)
    local eng = getEngine()
    local b = getBridge()
    local C_DIM = Color("C_DIM", { 0.63, 0.63, 0.63 })
    local FALLBACK_ICON = Const("FALLBACK_ICON", "Interface\\Icons\\INV_Misc_QuestionMark")
    local rowsMat, rowsMatIcon, rowsMatBadge = card.__rowsMat, card.__rowsIcon, card.__rowsBadge
    local rec = eng.StepRecipe(seg, rm[seg[3]])
    local mats = eng.RecMats(rec)
    local n = 0
    local pending = false
    local canCraft
    local state = eng.State()
    local bagMode = false
    if state then
        local _, _, plan = eng.RouteFor(state.slug, state.skill)
        bagMode = (plan and plan.useBagMaterials) or false
    end
    local function isSold(itemID)
        local cached = soldMemo[itemID]
        if cached == nil then
            cached = eng.IsVendorSold(itemID) and true or false
            soldMemo[itemID] = cached
        end
        return cached
    end
    if mats and #mats > 0 then
        for _, m in ipairs(mats) do
            local per = (m[2] or 1)
            if per > 0 then
                local raw = eng.Have(m[1], not bagMode)
                local c = floor((raw + (bagMode and 0 or PF.BidPending(m[1], raw))) / per)
                canCraft = (canCraft == nil) and c or min(canCraft, c)
            end
        end
        card.matHead:Hide()
        for i, m in ipairs(mats) do
            if i > MAT_MAX then break end
            local raw = eng.Have(m[1], not bagMode)
            local pend = PF.BidPending(m[1], raw)
            local have = raw + (bagMode and 0 or pend)
            local per = (m[2] or 1)
            local need = per * max(0, remaining or 0)
            local ok = have >= need
            local nm, got = eng.ItemName(m[1])
            if not got then
                eng.RequestItem(m[1])
                pending = true
            end
            local line = rowsMat[i]
            line:SetTextColor(Unpack(ok and C_OK or C_BAD))
            local txt = format("%s %d/%d", nm, have, need)
            if pend > 0 then
                txt = txt .. " · " .. L["已竞拍"]
            elseif isSold(m[1]) then
                txt = txt .. " · " .. L[(state and state.slug == "poisons") and "商人直卖" or "NPC也有出售"]
            end
            line:SetText(txt)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", card, "TOPLEFT", 36, -(61 + (i - 1) * 26))
            line:SetWidth(max(60, w - 28 - (resR or 0)))
            line:Show()
            local ic = rowsMatIcon[i]
            local pd = getPD()
            ic:SetTexture((pd and pd.ItemIcon and pd.ItemIcon(m[1])) or (b and b.ItemIcon and b.ItemIcon(m[1])) or FALLBACK_ICON)
            local hui = getHui()
            if hui and hui.SetIconRing then
                local mq = b and b.ItemQuality and b.ItemQuality(m[1]) or nil
                hui.SetIconRing(ic, mq and { hui.QColor(mq) } or nil)
            end
            ic:ClearAllPoints()
            ic:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -(56 + (i - 1) * 26))
            ic:Show()
            local bd = rowsMatBadge[i]
            bd:ClearAllPoints()
            bd:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 2, 0)
            bd:SetText(per)
            bd:Show()
            n = i
        end
        if #mats > MAT_MAX then
            local more = rowsMat[MAT_MAX + 1]
            more:SetTextColor(Unpack(C_DIM))
            more:SetText(format(L["…共 %d 种材料，进购物清单看合计"], #mats))
            more:ClearAllPoints()
            more:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -(56 + n * 26))
            more:SetWidth(max(60, w - (resR or 0)))
            more:Show()
            rowsMatIcon[MAT_MAX + 1]:Hide()
            if getHui() and getHui().SetIconRing then getHui().SetIconRing(rowsMatIcon[MAT_MAX + 1], nil) end
            rowsMatBadge[MAT_MAX + 1]:Hide()
            n = n + 1
        else
            rowsMat[MAT_MAX + 1]:Hide()
            rowsMatIcon[MAT_MAX + 1]:Hide()
            if getHui() and getHui().SetIconRing then getHui().SetIconRing(rowsMatIcon[MAT_MAX + 1], nil) end
            rowsMatBadge[MAT_MAX + 1]:Hide()
        end
    elseif rec then
        card.matHead:SetText(L["无材料"])
        card.matHead:Show()
    else
        card.matHead:SetText(L["材料未收录"])
        card.matHead:Show()
    end
    for i = n + 1, MAT_MAX do
        rowsMat[i]:Hide()
        rowsMatIcon[i]:Hide()
        if getHui() and getHui().SetIconRing then getHui().SetIconRing(rowsMatIcon[i], nil) end
        rowsMatBadge[i]:Hide()
    end
    if n < MAT_MAX + 1 then
        rowsMatIcon[MAT_MAX + 1]:Hide()
        if getHui() and getHui().SetIconRing then getHui().SetIconRing(rowsMatIcon[MAT_MAX + 1], nil) end
        rowsMatBadge[MAT_MAX + 1]:Hide()
    end
    return n, pending, canCraft
end

local function paintTrackingStatus(f, title, detail)
    local C_TEXT = Color("C_TEXT", { 0.88, 0.88, 0.88 })
    f.skill:SetText(title)
    f.skill:SetWidth(W_BASE - 20)
    f.skill:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
    f.skill:SetWordWrap(false)
    f.skill:Show()
    f.noLearn:Hide()
    f.seg:Hide()
    f.capWarn:Hide()
    f.rankHint.tasks = nil
    f.rankHint.statusTitle, f.rankHint.statusDetail = title, detail
    f.rankHint:SetWidth(W_BASE - 16)
    f.rankHint:Show()
end

local function paintCards(f, s, slug, steps, cur, accent, viewing, vi, vRun, vProg, verShown, y)
    local eng = getEngine()
    local b = getBridge()
    local pd = getPD()
    local xp = getXP()
    local FALLBACK_ICON = Const("FALLBACK_ICON", "Interface\\Icons\\INV_Misc_QuestionMark")
    local rm = eng.RecMap(slug)
    local soldMemo = {}
    local cands = viewing and { vi } or eng.CurrentCands(steps, cur or s.skill or 0, s.step or 1, slug, rm, vRun)
    local cards = { f.card, f.card2 }
    local pending = false
    for painted, ci in ipairs(cands) do
        local seg = steps[ci]
        local rec = eng.StepRecipe(seg, rm[seg[3]])
        local desc = eng.DescribeStep(seg, rec, slug)
        local card, w = cards[painted], W - 2 * PAD - 16
        local isCur = (ci == s.step)
        card:Show()

        if card.__round then
            for _, tex in ipairs(card.__round) do
                tex:SetVertexColor(accent[1], accent[2], accent[3], isCur and 0.9 or 0.35)
            end
        else
            card:SetBackdropBorderColor(accent[1], accent[2], accent[3], isCur and 0.9 or 0.35)
        end

        local prodItem = eng.RecItem(rec)
        if prodItem then
            card.icon:SetTexture((pd and pd.ItemIcon and pd.ItemIcon(prodItem)) or (b and b.ItemIcon and b.ItemIcon(prodItem)) or FALLBACK_ICON)
        else
            card.icon:SetTexture(FALLBACK_ICON)
        end
        local hui = getHui()
        if hui and hui.SetIconRing then
            local pq = prodItem and b and b.ItemQuality and b.ItemQuality(prodItem) or nil
            hui.SetIconRing(card.icon, pq and { hui.QColor(pq) } or nil)
        end
        card.__it = prodItem and { prodItem } or nil
        card.__mats = eng.RecMats(rec)
        local nmText = desc.name
        card.__guide = desc.guide
        card.name:SetText(nmText)

        local crafts = seg[4] or 0
        local remaining = crafts
        if seg.segmentID or ci == s.step then
            remaining = ceil(eng.CraftsLeft(seg, s.skill, rec, slug, ci ~= s.step))
            crafts = remaining
        end
        local nMat, pend, canCraft = paintMats(card, seg, rm, soldMemo, w - 8, remaining,
            viewing and ((f.cardBtnW or 68) + 6) or 0)
        pending = pending or pend

        local src, detail, kind
        if not desc.manual and pd and pd.LevelSrc then
            src, detail, kind = pd.LevelSrc(eng.RecForLevelSrc(rec, seg[3]), seg.profession or slug, seg.recipe, true)
        end
        local learned = eng.IsLearned(seg[3])
        local learningWarning = isCur and eng.LearningWarning(slug, vProg)
        if learningWarning then card.__guide = { name = nmText, lines = { learningWarning } } end
        card.__step = ci
        card.__spell = not desc.manual and desc.spellID or nil

        local srcLabel, srcColor
        local CARD_COL = pd and pd.CARD_COL or {}
        if desc.manual then
            srcLabel = desc.srcLabel
            srcColor = CARD_COL.both
        elseif kind == "vendor" then srcLabel, srcColor = L["商人"], CARD_COL.vendor
        elseif kind == "drop" then srcLabel, srcColor = L["掉落"], CARD_COL.drop
        elseif kind == "currency" then srcLabel, srcColor = L["兑换"], CARD_COL.vendor
        elseif kind == "quest" then srcLabel, srcColor = L["任务"], CARD_COL.both
        elseif kind == "trainer" or src == L["向训练师学习"] then srcLabel, srcColor = L["训练师"], CARD_COL.trainer
        else srcLabel, srcColor = L["图纸"], CARD_COL.both end

        local chL, chS = card.chipLearn, card.chipSrc
        local badgeMinW = Const("Q_BADGE_MIN_W", 18)
        local badgePad = Const("Q_BADGE_PAD", 4)
        local badgeH = Const("Q_BADGE_H", 16)
        local badgeGap = Const("Q_BADGE_GAP", 4)
        local tagW = 0
        if chL and chS then
            chL.lab:SetText(learned and L["已学"] or L["未学"])
            if b and b.BadgeTint then
                b.BadgeTint(chL, learned and Const("Q_BADGE_SHARE_BG") or Const("Q_BADGE_RACE_BG"))
            end
            local w1 = max(badgeMinW, FSW(chL.lab, 18) + badgePad * 2)
            chL:SetSize(w1, badgeH)
            tagW = w1
            chL:ClearAllPoints()
            if srcLabel then
                chS.lab:SetText(srcLabel)
                chS:EnableMouse(true)
                if desc.manual then
                    local tipDetail = (desc.questInfo and desc.questInfo.summary) or seg.detail or seg.note
                    TipOn(chS, srcLabel, tipDetail)
                else
                    TipOn(chS, src or srcLabel, detail)
                end
                if b and b.BadgeTint then
                    b.BadgeTint(chS, srcColor or { 0.29, 0.33, 0.40 })
                end
                local w2 = max(badgeMinW, FSW(chS.lab, 18) + badgePad * 2)
                chS:SetSize(w2, badgeH)
                chS:ClearAllPoints()
                chS:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -9)
                chS:Show()
                chL:SetPoint("TOPRIGHT", chS, "TOPLEFT", -badgeGap, 0)
                tagW = tagW + badgeGap + w2
            else
                chS:Hide()
                chL:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -9)
            end
            chL:Show()
            if desc.manual then
                chL:Hide()
                tagW = srcLabel and (chS:GetWidth() or 0) or 0
            end
        end

        local rangeText = format(L["%d – %d"], seg[1], seg[2])
        card.range:SetText(rangeText)
        local numCol = format("|cff%02x%02x%02x", floor(accent[1] * 255 + 0.5),
            floor(accent[2] * 255 + 0.5), floor(accent[3] * 255 + 0.5))
        local exactQty = (tonumber(seg[4]) or 0) <= max(1, seg[2] - seg[1])
        if exactQty and _G.C_TradeSkillUI and _G.C_TradeSkillUI.GetRecipeInfo then
            local okInfo, ri = pcall(_G.C_TradeSkillUI.GetRecipeInfo, seg[3])
            if okInfo and type(ri) == "table" then
                local rd = ri.relativeDifficulty
                if rd == nil then rd = ri.difficulty end
                if rd ~= nil and rd >= 1 then exactQty = false end
            end
        end
        local needKey = exactQty and L["还需%s次"] or L["还需约%s次"]
        local craftText = format(needKey, numCol .. crafts .. "|r")
        if canCraft then
            craftText = craftText .. "/" .. format(L["可制造%s次"], numCol .. canCraft .. "|r")
        end
        if vRun and xp and xp.Progress then
            local pv = xp.Progress(slug, ci, nil, vRun.planID)
            if pv and pv.outputItem then
                craftText = craftText .. "/" .. format(L["已生产%s"], numCol .. (pv.actualOutputs or 0) .. "|r")
            end
        end
        if desc.subtitle then craftText = desc.subtitle end
        card.crafts:SetText(learningWarning or craftText)
        local craftW = w - 54
        if verShown and painted == 1 then craftW = craftW - (f.cardBtnW or 68) - 2 end
        card.crafts:SetWidth(max(60, craftW))

        local rangeW, nameW = 40, 90
        if pd and pd.TextW then
            local okW, tw = pcall(pd.TextW, rangeText, 14)
            if okW and type(tw) == "number" then rangeW = ceil(tw) end
            local okW2, tw2 = pcall(pd.TextW, nmText, 16)
            if okW2 and type(tw2) == "number" then nameW = ceil(tw2) end
        end
        local avail = max(60, w - 42 - tagW - 10 - rangeW - 10)
        local nameX = min(nameW, avail)
        card.name:SetWidth(avail)
        card.range:ClearAllPoints()
        card.range:SetPoint("TOPLEFT", card, "TOPLEFT", 42 + nameX + 10, -12)
        card.range:SetWidth(rangeW + 6)

        local cardH = max(nMat * 26 + 60, viewing and 86 or 60)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        card:SetSize(W - 2 * PAD, cardH)
        y = y - cardH - 8
    end
    return y, pending
end

local function paintShop(f, s, y)
    local eng = getEngine()
    local C_TEXT = Color("C_TEXT", { 0.88, 0.88, 0.88 })
    local list = eng.ShopList(s)
    local shown = {}
    local onlyMiss = eng.OnlyMissView()
    for _, e in ipairs(list) do
        e.missing = e.haveKnown and max(0, e.need - e.have) or nil
        if (not onlyMiss) or e.missing == nil or e.missing > 0 then shown[#shown + 1] = e end
    end
    f.shop.missTog:SetChecked(onlyMiss)
    local srcByID = {}
    for _, entry in ipairs(list) do srcByID[entry.id] = entry end

    local function tw(txt)
        local pd = getPD()
        if pd and pd.TextW then
            local ok, wv = pcall(pd.TextW, txt, 14)
            if ok and type(wv) == "number" then return wv end
        end
        return #txt * 5 + 16
    end
    local function clipText(txt, maxW)
        if type(txt) ~= "string" or txt == "" then return txt end
        local pd = getPD()
        local hui = getHui()
        local CS = hui and hui.CharStep
        if not (pd and pd.TextW and CS) then return txt end
        local ok, wv = pcall(pd.TextW, txt, 14)
        if not ok or type(wv) ~= "number" or wv <= maxW then return txt end
        local out, wvAcc = "", 0
        local i, n = 1, #txt
        while i <= n do
            local ch, step, k = CS(txt, i)
            local cw = (k or 1) * 14
            if wvAcc + cw > maxW - 14 then break end
            out = out .. ch
            wvAcc = wvAcc + cw
            i = i + (step or 1)
        end
        if out == "" then return txt end
        return out .. "…"
    end

    local rows = {}
    local pending = false
    local nameW, numW, missW, tagW = 0, 0, 0, 0
    local stepView = (eng.DbProf().shopStepView) and true or false
    f.shopStep:SetText(stepView and L["汇总"] or L["分步"])
    local function pushRow(e)
        local nm, got = eng.ItemName(e.id)
        if not got then
            eng.RequestItem(e.id)
            pending = true
        end
        local raw = tonumber(e.have) or 0
        local pend = PF.BidPending(e.id, raw)
        local row = {
            nm = e.formula and (L["图纸"] .. " · " .. nm) or nm,
            have = raw,
            availableHave = raw + (e.useBagMaterials and 0 or pend),
            pending = pend,
            need = e.need,
            missing = max(0, (tonumber(e.missing) or 0) - (e.useBagMaterials and 0 or pend)),
            inventoryUnknown = not e.haveKnown,
            at = e.at or 0,
            src = srcByID[e.id] or nil,
        }
        if row.at == huge then
            row.gate = true
            row.at = 0
        end
        local w1 = tw(row.nm)
        if w1 > nameW then nameW = w1 end
        local w2 = tw(row.inventoryUnknown and ("? / " .. row.need) or format("%d/%d", min(row.availableHave, row.need), row.need))
        if w2 > numW then numW = w2 end
        local w5 = tw(row.gate and L["全程"] or format("%d+", row.at)) + 10
        if w5 > tagW then tagW = w5 end
        if row.src then
            local entry = row.src
            local vendor = (entry.vendorCount or 0) > 0 or eng.PurchaseSource(entry) == "vendor"
            local auction = (entry.ahCount or 0) > 0 or eng.PurchaseSource(entry) == "ah"
            if vendor and auction then row.srcText, row.srcKind = L["商人"] .. "/" .. L["拍卖行"], 4
            elseif vendor then row.srcText, row.srcKind = L["商人"], 1
            elseif auction then row.srcText, row.srcKind = L["拍卖行"], 2
            elseif entry.selfCraft then row.srcText, row.srcKind = L["自制"], 3 end
            if row.srcKind == 1 then
                row.npcID = entry.npcID
                for _, purchase in ipairs(entry.purchases or {}) do
                    if purchase.npcID then row.npcID = purchase.npcID; break end
                end
                row.srcFull = eng.VendorName(row.npcID)
                row.srcText = row.srcFull or row.srcText
            end
            row.srcText = clipText(row.srcText, SRC_TEXT_W)
        end
        local missText = row.inventoryUnknown and L["请检查背包"]
            or row.missing > 0 and format(L["缺%d"], row.missing)
            or ((row.pending or 0) > 0 or row.srcKind == 2 or row.srcKind == 4) and L["已竞拍"]
            or L["已备齐"]
        local w3 = tw(missText) + 10
        if w3 > missW then missW = w3 end
        rows[#rows + 1] = row
    end

    if stepView then
        local lastAt = nil
        for _, e in ipairs(shown) do
            local at = e.at or 0
            if at == huge then at = 0 end
            if at ~= lastAt then
                local htext = at > 0 and format(L["第 %d 步起"], at) or L["路线起点"]
                local w0 = tw(htext) + 10
                if w0 > nameW then nameW = w0 end
                rows[#rows + 1] = { head = true, nm = htext }
                lastAt = at
            end
            pushRow(e)
        end
    else
        for _, e in ipairs(shown) do pushRow(e) end
    end

    if numW < 34 then numW = 34 end
    if numW > NUM_CAP then numW = NUM_CAP end
    if tagW > TAG_CAP then tagW = TAG_CAP end
    if tagW < 34 then tagW = 34 end
    local srcW = SRC_COL_W
    local innerW = W - 2 * PAD
    local xName = 8
    local xSrc = innerW - 14 - tagW - 8 - srcW
    local xMiss = xSrc - 8 - missW
    local xNum = xMiss - 10 - numW
    nameW = max(40, xNum - 10 - xName)
    local maxScroll = max(0, #rows - SHOP_MAX)
    PF.shopScroll = max(0, min(PF.shopScroll or 0, maxScroll))
    local scroll = PF.shopScroll

    local rowsShop = f.__rowsShop
    local rowsShopNum = f.__rowsShopNum
    local rowsShopMissPill = f.__rowsShopMissPill
    local rowsShopSoldPill = f.__rowsShopSoldPill
    local rowsShopSrcPill = f.__rowsShopSrcPill
    local rowsShopTagPill = f.__rowsShopTagPill
    local hui = getHui()

    local n = 0
    for ri = scroll + 1, min(#rows, scroll + SHOP_MAX) do
        local row = rows[ri]
        local ry = -(30 + n * 20)
        local nmFS = rowsShop[n + 1]
        local num = rowsShopNum[n + 1]
        local mp = rowsShopMissPill[n + 1]
        local sp = rowsShopSoldPill[n + 1]
        local srcp = rowsShopSrcPill[n + 1]
        local tp = rowsShopTagPill[n + 1]
        local function paintPill(p, txt, x0, wpx, cr, cg, cb, ca)
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", f.shop, "TOPLEFT", x0, ry + ((hui and hui.ChipDY and hui.ChipDY(14)) or -0.8))
            p:SetWidth(max(wpx, 34))
            if p.__chipFill and hui and hui.PaintSolidFill then
                hui.PaintSolidFill(p.__chipFill, hui.ChipSolidBase({ cr, cg, cb }))
                if p.__border then
                    for _, t in ipairs(p.__border) do t:SetVertexColor(cr, cg, cb, 1) end
                end
                p.fs:SetTextColor(1, 1, 1)
            else
                local a2 = ca or 0.99
                for _, t in ipairs(p.__cols) do t:SetVertexColor(cr, cg, cb, a2) end
            end
            p.fs:SetText(txt)
            p:Show()
        end
        if row.head then
            nmFS:SetText(row.nm)
            nmFS:SetWidth(innerW - 2 * xName)
            nmFS:SetTextColor(Unpack(C_HEAD))
            nmFS:ClearAllPoints()
            nmFS:SetPoint("TOPLEFT", f.shop, "TOPLEFT", xName, ry)
            nmFS:Show()
            num:Hide()
            mp:Hide()
            sp:Hide()
            srcp:Hide()
            tp:Hide()
            n = n + 1
        else
            nmFS:SetTextColor(Unpack(C_TEXT))
            nmFS:SetText((tw(row.nm) > nameW) and clipText(row.nm, nameW) or row.nm)
            nmFS:SetWidth(nameW)
            num:SetWidth(numW)
            num:SetText(row.inventoryUnknown and ("? / " .. row.need) or format("%d/%d", min(row.availableHave, row.need), row.need))
            nmFS:ClearAllPoints()
            nmFS:SetPoint("TOPLEFT", f.shop, "TOPLEFT", xName, ry)
            nmFS:Show()
            num:ClearAllPoints()
            num:SetPoint("TOPLEFT", f.shop, "TOPLEFT", xNum, ry)
            num:Show()
            if row.inventoryUnknown then
                paintPill(mp, L["请检查背包"], xMiss, missW, Unpack(C_BAD))
            elseif row.missing > 0 then
                paintPill(mp, format(L["缺%d"], row.missing), xMiss, missW, Unpack(C_BAD))
            else
                local okr, okg, okb = Unpack(C_OK)
                local done = ((row.pending or 0) > 0 or row.srcKind == 2 or row.srcKind == 4) and L["已竞拍"] or L["已备齐"]
                paintPill(mp, done, xMiss, missW, okr, okg, okb, 0.5)
            end
            sp:Hide()
            if row.src and row.srcText then
                if row.srcKind == 1 then
                    local kr, kg, kb = Unpack(C_HEAD)
                    paintPill(srcp, row.srcText, xSrc, srcW, kr, kg, kb)
                elseif row.srcKind == 3 then
                    local okr, okg, okb = Unpack(C_OK)
                    paintPill(srcp, row.srcText, xSrc, srcW, okr, okg, okb, 0.5)
                else
                    paintPill(srcp, row.srcText, xSrc, srcW, 0.58, 0.58, 0.58, 0.45)
                end
                srcp.__row = row
                srcp.fs:SetWidth(srcW - 10)
                srcp.fs:SetWordWrap(false)
                srcp:EnableMouse(true)
            else
                srcp.__row = nil
                srcp:Hide()
            end
            tp:ClearAllPoints()
            tp:SetPoint("TOPRIGHT", f.shop, "TOPRIGHT", -14, ry + ((hui and hui.ChipDY and hui.ChipDY(14)) or -0.8))
            tp:SetWidth(max(tagW, 34))
            if tp.__chipFill and hui and hui.PaintSolidFill then
                hui.PaintSolidFill(tp.__chipFill, hui.ChipSolidBase({ 0.55, 0.55, 0.55 }))
                if tp.__border then
                    for _, t in ipairs(tp.__border) do t:SetVertexColor(0.55, 0.55, 0.55, 1) end
                end
                tp.fs:SetTextColor(1, 1, 1)
            else
                for _, t in ipairs(tp.__cols) do t:SetVertexColor(0.55, 0.55, 0.55, 0.22) end
            end
            tp.fs:SetText(row.gate and L["全程"] or format("%d+", row.at))
            tp:Show()
            n = n + 1
        end
    end

    local total = #rows
    if total > SHOP_MAX then
        local visH = SHOP_MAX * 20
        f.shop.sbarTrack:SetSize(3, visH)
        f.shop.sbarTrack:Show()
        local thumbH = max(14, floor(visH * SHOP_MAX / total + 0.5))
        local thumbOff = floor((visH - thumbH) * scroll / (total - SHOP_MAX) + 0.5)
        local sb = f.shop.sbarThumb
        sb:SetHeight(thumbH)
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT", f.shop, "TOPRIGHT", -3, -(28 + thumbOff))
        sb:Show()
    else
        f.shop.sbarTrack:Hide()
        f.shop.sbarThumb:Hide()
    end
    for i = n + 1, #rowsShop do
        rowsShop[i]:Hide()
        rowsShopNum[i]:Hide()
        rowsShopMissPill[i]:Hide()
        rowsShopSoldPill[i]:Hide()
        rowsShopSrcPill[i]:Hide()
    end
    for i = n + 1, #rowsShopTagPill do
        rowsShopTagPill[i]:Hide()
    end
    local shopH
    if n > 0 then
        shopH = 30 + n * 20 + 10
        f.shop.empty:Hide()
    else
        f.shop.empty:SetText(#list > 0 and L["所有物品已备齐"] or L["无材料"])
        f.shop.empty:Show()
        shopH = 30 + 20 + 10
    end
    f.shop:ClearAllPoints()
    f.shop:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    f.shop:SetSize(W - 2 * PAD, shopH)
    f.shop:Show()
    return y - shopH - 8, pending
end

local function paintImpl()
    local f = PF.f
    if not (f and f:IsShown()) then return end
    local eng = getEngine()
    if not eng then return end
    local b = getBridge()
    local C_TEXT = Color("C_TEXT", { 0.88, 0.88, 0.88 })

    f.scanStatus:Hide()
    if eng.TrackingPaused() then
        eng.combatPaused = true
        paintTrackingStatus(f, L["战斗中暂停追踪"], L["战斗中暂停追踪，脱战后自动恢复。"])
        return
    end
    local state = eng.State()
    if state and state.autoTrackSuspended == "inactive" then
        paintTrackingStatus(f, L["追踪已自动结束"], L["48 小时无制作，追踪已自动结束。"])
        return
    end
    W = W_BASE
    f:SetWidth(W)
    f.barBG:SetWidth(W - 20)
    if not (state and state.slug) then f:Hide(); return end
    local slug = state.slug
    local mode, steps = eng.RouteFor(slug, state.skill)
    if not steps then f:Hide(); return end
    local p = eng.ProfInfo(slug)
    local accent = Accent()
    local name = (p and p.name) or eng.ProfName(slug)

    f.icon:SetTexture(ProfIconTex(p and p.icon))
    f.title:SetText(format(L["%s升级HUD"], name))

    local cur, mx = eng.SkillOf(slug)
    local rankTasks = PF.RankTasks(slug, eng.RouteTarget(slug), steps, state.step)
    updateCues(slug, rankTasks)
    f.rankHint.tasks = rankTasks
    f.rankHint.statusTitle, f.rankHint.statusDetail = nil, nil
    f.rankHint:SetShown(#rankTasks > 0)
    local atCap = false
    for _, task in ipairs(rankTasks) do
        local ts = task.state or {}
        if task.due and ts.known and ts.maxSkill and ts.maxSkill > 0
            and ts.skill and ts.skill >= ts.maxSkill then
            atCap = true
            break
        end
    end
    if cur then
        local seg = steps[state.step or 1]
        local toPts = seg and tonumber(seg[2]) or nil
        if toPts and toPts > cur then
            f.skill:SetText(format(L["技能 %d（%d）/ %d"], cur, toPts, mx or 300))
        else
            f.skill:SetText(format(L["技能 %d / %d"], cur, mx or 300))
        end
        f.skill:Show()
        if f.noLearn then f.noLearn:Hide() end
    else
        f.skill:SetText("")
        f.skill:Hide()
        if f.noLearn then f.noLearn:Show() end
    end
    if atCap then
        f.skill:SetTextColor(0.95, 0.32, 0.32)
    else
        f.skill:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
    end
    if f.capWarn then
        if atCap then
            f.capWarn:SetText(L["找训练师提高技能上限"])
            f.capWarn:Show()
        else
            f.capWarn:Hide()
        end
    end
    if f.__round then
        local br, bgc, bb, ba = 1, 1, 1, 0.25
        if atCap then br, bgc, bb, ba = 0.93, 0.32, 0.32, 0.95 end
        for _, tex in ipairs(f.__round) do tex:SetVertexColor(br, bgc, bb, ba) end
    elseif atCap then
        f:SetBackdropBorderColor(0.93, 0.32, 0.32, 0.95)
    elseif b and b.HuiTheme and b.HuiTheme() == "hui" then
        f:SetBackdropBorderColor(1, 1, 1, 0.10)
    else
        f:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
    end
    local ratio = cur and min(1, cur / 300) or 0
    f.bar:SetWidth(max(2, floor((W - 20) * ratio + 0.5)))
    f.bar:SetVertexColor(accent[1], accent[2], accent[3], 0.95)

    local finished = (state.step or 1) > #steps
    local vi = #steps > 0 and max(1, min(#steps, (state.step or 1) + (PF.view or 0))) or 0
    f.seg:SetText(((mode == "auto") and L["自动计算"] or mode == "gather" and L["采集路线"] or L["固定路线"]) .. " · "
        .. format(L["段落 %d / %d"], vi, #steps))
    f.seg:Show()
    local segmentWidth = FSW(f.seg, 140)
    local skillWidth = max(90, W - 28 - segmentWidth)
    f.skill:SetWidth(skillWidth)
    f.skill:SetWordWrap(false)
    f.rankHint:SetWidth(skillWidth + 4)

    local segCur = (not finished) and steps[min((state.step or 1), #steps)] or nil
    if segCur then
        local x0 = floor((W - 20) * min(1, segCur[1] / 300) + 0.5)
        local x1 = floor((W - 20) * min(1, segCur[2] / 300) + 0.5)
        f.zone:ClearAllPoints()
        f.zone:SetPoint("TOPLEFT", f.barBG, "TOPLEFT", x0, 0)
        f.zone:SetWidth(max(1, x1 - x0))
        f.zone:SetVertexColor(C_HEAD[1], C_HEAD[2], C_HEAD[3], 0.9)
        f.zone:Show()
    else
        f.zone:Hide()
    end

    f.finish:SetShown(finished)
    f.card:SetShown(not finished)
    f.card2:Hide()
    local viewing = (PF.view or 0) ~= 0 and not finished
    f.nowBtn:SetShown(viewing)
    local xp = getXP()
    local vRun = (slug ~= "poisons" and xp and xp.GetActive) and xp.GetActive(slug) or nil
    local vProg = (type(vRun) == "table" and xp.Progress) and xp.Progress(slug, nil, nil, vRun.planID) or nil
    f.verifyBtn:SetText(type(vProg) == "table" and vProg.manualConversion and L["确认转换"] or L["校正产出"])
    local verShown = not finished and type(vProg) == "table" and vProg.outputItem ~= nil and not vProg.finished
    f.verifyBtn:SetShown(verShown)

    local y = -82
    local pending = false

    if not finished then
        local pendCard
        y, pendCard = paintCards(f, state, slug, steps, cur, accent, viewing, vi, vRun, vProg, verShown, y)
        pending = pending or pendCard
    end

    if PF.showShop and not finished then
        local pendShop
        y, pendShop = paintShop(f, state, y)
        pending = pending or pendShop
    else
        f.shop:Hide()
        PF.shopScroll = nil
    end

    local pd = getPD()
    if finished then
        local waiting = eng.pendingPlans[slug]
        f.finish:SetText(waiting and (pd and pd.PlanStatusText and pd.PlanStatusText(waiting) or L["正在计算升级路线…"])
            or format(L["%s跟随完成 · %s"], name, fmtTime((_G.time and _G.time() or 0) - (state.t0 or (_G.time and _G.time() or 0)))))
        f.finish:ClearAllPoints()
        f.finish:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
        f.finish:Show()
        y = y - 34
    end

    local scanText = pd and pd.ScanSnapshotText and pd.ScanSnapshotText()
    local scanWarning, scanBlocked
    if pd and pd.ReplicateScanWarning then scanWarning, scanBlocked = pd.ReplicateScanWarning() end
    local bindErr = eng.BindError(slug)
    local bindText
    if bindErr and not vRun then
        bindText = (pd and pd.ReplicateScanMessage and pd.ReplicateScanMessage(bindErr))
            or (getEco() and getEco().DiagnosticText and getEco().DiagnosticText(bindErr))
            or scanWarning
        if bindText then scanBlocked = true end
    end
    scanText = bindText or scanText or scanWarning
    if scanText and not (finished and f.finish:GetText() == scanText) then
        f.scanStatus:SetText(scanText)
        f.scanStatus:SetTextColor(scanBlocked and 0.98 or 0.55, scanBlocked and 0.55 or 0.85, scanBlocked and 0.4 or 0.6)
        f.scanStatus:SetWidth(W - 20)
        f.scanStatus:ClearAllPoints()
        f.scanStatus:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
        f.scanStatus:Show()
        y = y - max(16, f.scanStatus:GetStringHeight() or 16) - 8
    end

    if viewing then
        f.nowBtn:ClearAllPoints()
        f.nowBtn:SetPoint("TOPRIGHT", f.card, "TOPRIGHT", -8, -59)
    end
    local by = y - 4
    f.btns[1]:ClearAllPoints()
    f.btns[1]:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, by)
    f.btns[3]:ClearAllPoints()
    f.btns[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, by)
    f.btns[2]:ClearAllPoints()
    f.btns[2]:SetPoint("TOPRIGHT", f.btns[3], "TOPLEFT", -BTN_GAP, 0)
    f.verifyBtn:SetShown(verShown)
    if verShown then
        f.verifyBtn:ClearAllPoints()
        f.verifyBtn:SetPoint("TOPRIGHT", f.card, "TOPRIGHT", -8, -30)
    end

    f:SetHeight(-by + 30)
    sweepPaint(pending)
end

function PF.Paint()
    if not (PF.f and PF.f:IsShown()) then return end
    local ok, err = pcall(paintImpl)
    if not ok then
        ReportError("paint", err)
    end
end

function PF.PaintButton(bt, slug)
    if not bt then return end
    local eng = getEngine()
    local ok = hostReady() and slug and slug ~= "__index" and eng and eng.HasRoute(slug)
    if not ok then
        bt:SetShown(false)
        return
    end
    local text = L["升级HUD"]
    bt:SetText(text)
    local pd = getPD()
    if pd and pd.ToolSize then
        local w = select(1, pd.ToolSize(text))
        if w then bt:SetWidth(w) end
    elseif pd and pd.TextW then
        bt:SetWidth(math.max(pd.TOOL_MIN_W or 56, ceil(pd.TextW(text, 14)) + (pd.TOOL_PADX or 18)))
    end
    bt:SetScript("OnClick", function() PF.Toggle(slug) end)
    TipOn(bt, text, L["打开 HUD 后，路线就绪时会自动开始执行并追踪制作进度。"] .. "\n"
        .. L["连续 48 小时无制作（含离线）自动结束；战斗中暂停，脱战后恢复。"] .. "\n"
        .. L["关闭 HUD 只隐藏窗口，不会结束追踪。"] .. "\n"
        .. L["不再升级时，请在升级页点击追踪进度按钮结束追踪。"])
    local active = PF.IsActive(slug)
    SetButtonSelected(bt, active)
    local fs = bt.GetFontString and bt:GetFontString()
    if fs then
        local C_WHITE = Color("C_WHITE", { 1, 1, 1 })
        local C_GREY = Color("C_GREY", { 0.55, 0.55, 0.55 })
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", 0, -1)
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(Unpack(active and C_WHITE or C_GREY))
    end
    bt:SetShown(true)
end

function PF.PaintImportBtn(bt, slug)
    if not bt then return end
    local eng = getEngine()
    local ok = hostReady() and slug and slug ~= "__index" and eng and eng.HasRoute(slug)
    if not ok then
        bt:SetShown(false)
        return
    end
    local text = L["一键导入购物清单"]
    bt:SetText(text)
    local pd = getPD()
    if pd and pd.TextW then bt:SetWidth(ceil(pd.TextW(text, 13)) + 22) end
    bt:SetScript("OnClick", function()
        DoImport(slug, eng.ProfName(slug))
        PlayClickSound(1)
    end)
    TipOn(bt, text, L["将拍卖行采购的缺口导入拍卖行插件的购物清单；NPC 货物和自制材料不导入，同名清单将被覆盖。"])
    local ifs = bt.GetFontString and bt:GetFontString()
    if ifs then
        local C_GREY = Color("C_GREY", { 0.55, 0.55, 0.55 })
        ifs:ClearAllPoints()
        ifs:SetPoint("CENTER", 0, -1)
        ifs:SetJustifyH("CENTER")
        ifs:SetTextColor(Unpack(C_GREY))
    end
    bt:SetShown(true)
end

-- =========================================================================
-- Idempotent Cross-Module Hook Wiring (Safe Across Hot-Reloads)
-- =========================================================================

PF.__onAuctionChanged = function(_, reason)
    if reason == "supply" or reason == "scan-status" then
        PF.InvalidateRoute()
        if PF.f and PF.f:IsShown() then
            PF.Sync()
            PF.Paint()
        end
    end
end

PF.__onExecObsChanged = function()
    if PF.f and PF.f:IsShown() then
        PF.Sync()
        PF.Paint()
    end
end

PF.__onExecChanged = function(slug, run, reason)
    if slug == "poisons" then return end
    local eng = getEngine()
    local state = eng and eng.State()
    if not state or state.slug ~= slug then return end
    if reason == "ended" and run and run.archiveReason == "completed" then
        eng.endedPlan[slug] = run.plan
    end
    PF.InvalidateRoute()
    PF.Sync()
    if PF.f and PF.f:IsShown() then PF.Paint() end
end

PF.__onPlanChanged = function(slug)
    local eng = getEngine()
    local state = eng and eng.State()
    if not state or state.slug ~= slug then return end
    PF.InvalidateRoute()
    PF.Sync()
    if PF.f and not state.hidden then
        PF.f:Show()
        PF.Paint()
    end
end

local function connectExecution()
    syncEngineRefs()
    local bridge = getAuctionBridge()
    if bridge and bridge.OnChanged and PF.__hookedBridge ~= bridge then
        PF.__hookedBridge = bridge
        bridge.OnChanged(function(...)
            if PF.__onAuctionChanged then PF.__onAuctionChanged(...) end
        end)
    end
    local xp = getXP()
    if xp and xp.OnObservationChanged and PF.__hookedXPObs ~= xp then
        PF.__hookedXPObs = xp
        xp.OnObservationChanged(function(...)
            if PF.__onExecObsChanged then PF.__onExecObsChanged(...) end
        end)
    end
    if xp and xp.OnChanged and PF.__hookedXP ~= xp then
        PF.__hookedXP = xp
        xp.OnChanged(function(...)
            if PF.__onExecChanged then PF.__onExecChanged(...) end
        end)
    end
    local ra = getRA()
    local planState = ra and ra._planState or ra
    if ra and ra.OnPlanChanged and PF.__hookedPlanState ~= planState then
        PF.__hookedPlanState = planState
        ra.OnPlanChanged(function(...)
            if PF.__onPlanChanged then PF.__onPlanChanged(...) end
        end)
    end
    if PF.f and PF.f.__dfBuilt then
        wireFrameScripts(PF.f)
        ensureTickers()
        if PF.f:IsShown() then PF.Paint() end
    end
end

PF.ConnectExecution = connectExecution

-- Hot-reload: immediately rebind existing HUD frame (or retire pre-refactor frame) and idempotently wire hooks
if _G.DFProfFollowHUD and _G.DFProfFollowHUD.__dfBuilt then
    PF.f = _G.DFProfFollowHUD
    wireFrameScripts(PF.f)
    ensureTickers()
elseif PF.f and not PF.f.__dfBuilt then
    pcall(PF.f.UnregisterAllEvents, PF.f)
    pcall(PF.f.Hide, PF.f)
    PF.f = nil
end
connectExecution()
local hb = getBridge()
if hb and type(hb.OnInit) == "function" then
    hb.OnInit(connectExecution)
end
