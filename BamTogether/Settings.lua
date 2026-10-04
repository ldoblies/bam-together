local _, Bam = ...
local L = Bam.L

local function label(parent, text, x, y, width, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width or 430)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function button(parent, text, x, y, w, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 160, 26)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end

local function check(parent, text, x, y, callback)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(26,26)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    c.text = label(parent, text, x+31, y-6, 470)
    c:SetScript("OnClick", function(self) callback(self:GetChecked() and true or false) end)
    return c
end

local function makeSlider(parent, x, y, minv, maxv, step, callback)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetSize(300, 18)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:SetScript("OnValueChanged", function(_, v)
        if not Bam.refreshing then callback(v) end
    end)
    return s
end

local function cycleSound(key, step)
    local options = {}
    for _, sound in ipairs(Bam.sounds) do options[#options + 1] = sound.id end
    options[#options + 1] = "shuffle"
    local index = 1
    for i, id in ipairs(options) do
        if id == Bam.db[key] then index = i end
    end
    Bam.db[key] = options[(index - 1 + step) % #options + 1]
    Bam:RefreshSettings()
end

local function soundPicker(parent, key, finisher, y)
    button(parent, "<", 22, y, 26, function() cycleSound(key, -1) end)
    button(parent, ">", 50, y, 26, function() cycleSound(key, 1) end)
    button(parent, L.TEST, 420, y, 120, function()
        Bam:Play(Bam:ResolveSound(Bam.db[key], finisher), true)
    end)
    return label(parent, "", 86, y - 6, 320)
end

function Bam:OpenSettings()
    if not self.settings then
        local tpl = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "BamTogetherSettingsFrame", UIParent, tpl)
        self.settings = f
        f:SetSize(580, 763)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        if f.SetBackdrop then
            f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14, insets={left=3,right=3,top=3,bottom=3}})
            f:SetBackdropColor(.025,.03,.04,.97)
            f:SetBackdropBorderColor(.20,.62,.82,1)
        end

        f.title = label(f, L.SETTINGS_TITLE, 22, -20, 490, "GameFontNormalLarge")
        f.subtitle = label(f, L.SETTINGS_SUBTITLE, 22, -48, 490, "GameFontHighlightSmall")
        button(f, "X", 530, -12, 30, function() f:Hide() end)

        f.enabled = check(f, L.ENABLED, 22, -82, function(v) Bam.db.enabled=v end)
        f.melee = check(f, L.MELEE_CRITS, 22, -119, function(v) Bam.db.meleeCrits=v end)
        f.spell = check(f, L.SPELL_CRITS, 22, -156, function(v) Bam.db.spellCrits=v end)
        f.finisher = check(f, L.FINISHER, 22, -193, function(v) Bam.db.finisherBaaam=v end)
        f.muteInDungeon = check(f, L.MUTE_IN_DUNGEON, 22, -230, function(v) Bam.db.muteInDungeon=v end)
        f.muteInGroup = check(f, L.MUTE_IN_GROUP, 22, -267, function(v) Bam.db.muteInGroup=v end)
        f.partyBam = check(f, L.PARTY_BAM, 22, -304, function(v) Bam.db.partyBam=v end)
        f.critChat = check(f, L.CRIT_CHAT, 22, -341, function(v) Bam.db.critChat=v end)
        f.chatExample = label(f, L.CHAT_EXAMPLE, 53, -370, 500, "GameFontDisableSmall")

        f.throttleText = label(f, "", 22, -410, 490)
        f.throttle = makeSlider(f, 25, -443, 0, 2, .05, function(v)
            Bam.db.throttle = math.floor(v*20+.5)/20
            Bam:RefreshSettings()
        end)
        f.throttleHelp = label(f, L.THROTTLE_HELP, 22, -472, 520, "GameFontDisableSmall")

        f.critSound = soundPicker(f, "critSound", false, -512)
        f.finisherSound = soundPicker(f, "finisherSound", true, -548)
        f.debug = check(f, L.DEBUG, 22, -592, function(v) Bam.db.debug=v end)
        f.debugHelp = label(f, L.DEBUG_HELP, 53, -621, 500, "GameFontDisableSmall")

        f.detectionTitle = label(f, L.DETECTION, 22, -655, 500, "GameFontNormal")
        f.detectionHelp = label(f, L.DETECTION_HELP, 22, -680, 525, "GameFontDisableSmall")
        f.footer = label(f, "Bam Together v" .. tostring(Bam.version) .. " by Snardge", 22, -710, 525, "GameFontDisableSmall")

        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1] = "BamTogetherSettingsFrame" end
        f:SetScript("OnShow", function() Bam:RefreshSettings() end)
        f:Hide()
    end

    self:RefreshSettings()
    self.settings:Show()
end

function Bam:RefreshSettings()
    local f = self.settings
    if not f or not self.db then return end
    self.refreshing = true
    f.enabled:SetChecked(self.db.enabled)
    f.melee:SetChecked(self.db.meleeCrits)
    f.spell:SetChecked(self.db.spellCrits)
    f.finisher:SetChecked(self.db.finisherBaaam)
    f.muteInDungeon:SetChecked(self.db.muteInDungeon)
    f.muteInGroup:SetChecked(self.db.muteInGroup)
    f.partyBam:SetChecked(self.db.partyBam)
    f.critChat:SetChecked(self.db.critChat)
    f.debug:SetChecked(self.db.debug)
    f.critSound:SetText(string.format(L.CRIT_SOUND, self:SoundName(self.db.critSound)))
    f.finisherSound:SetText(string.format(L.FINISHER_SOUND, self:SoundName(self.db.finisherSound)))
    f.throttle:SetValue(self.db.throttle or .25)
    f.throttleText:SetText(string.format(L.THROTTLE, self.db.throttle or .25))
    self.refreshing = false
end
