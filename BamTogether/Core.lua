local ADDON_NAME, Bam = ...
local L = Bam.L

Bam.version = "1.0.0"

local SOUND_DIR = "Interface\\AddOns\\BamTogether\\sounds\\"

-- Ids travel in party messages, so keep them stable and free of ":".
-- "finisher" only decides the shuffle pool; any sound can be picked for either slot.
Bam.sounds = {
    { id = "bam", name = "BAM!", file = "bam.ogg" },
    { id = "baaam", name = "BAAAM!", file = "baaam.ogg", finisher = true },
}

local soundsById = {}
for _, sound in ipairs(Bam.sounds) do soundsById[sound.id] = sound end

local defaults = {
    enabled = true,
    meleeCrits = true,
    spellCrits = true,
    finisherBaaam = true,
    muteInDungeon = false,
    muteInGroup = false,
    throttle = 0.25,
    debug = false,
    critChat = false,
    partyBam = true,
    critSound = "bam",
    finisherSound = "baaam",
}

-- A successful API call can still return a secret value. Check before
-- branching, comparing, formatting or building table keys from that value.
local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function readAPI(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or not readable(value) then return nil end
    return value
end

local function publicNumber(value)
    if not readable(value) then return nil end
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function copyDefaults(target)
    for k,v in pairs(defaults) do
        if target[k] == nil then target[k] = v end
    end
end

function Bam:Print(msg)
    print("|cff9bdbf5Bam Together:|r " .. tostring(msg))
end

function Bam:InitDB()
    if type(BamTogetherSettings) ~= "table" then BamTogetherSettings = {} end
    copyDefaults(BamTogetherSettings)
    for _, key in ipairs({ "critSound", "finisherSound" }) do
        local choice = BamTogetherSettings[key]
        if choice ~= "shuffle" and not soundsById[choice] then BamTogetherSettings[key] = defaults[key] end
    end
    BamTogetherSettings.throttle = math.min(2, math.max(0, publicNumber(BamTogetherSettings.throttle) or defaults.throttle))
    Bam.db = BamTogetherSettings
end

local lastSoundAt = -100
local lastSpellAt = -100
local lastSpellTargetGUID
local lastSpellID
local recentCritEvents = {}
local SPELL_TARGET_WINDOW = 30

local function now()
    if GetTimePreciseSec then return GetTimePreciseSec() end
    return GetTime and GetTime() or 0
end

local function isDuplicateCrit(unit, action, amount)
    local guid = unit and readAPI(UnitGUID, unit) or nil
    local key = tostring(guid or unit or "?") .. ":" .. tostring(action or "?") .. ":" .. tostring(amount or "?")
    local t = now()
    local previous = recentCritEvents[key]
    recentCritEvents[key] = t

    for k, stamp in pairs(recentCritEvents) do
        if (t - stamp) > 1.0 then recentCritEvents[k] = nil end
    end

    return previous ~= nil and (t - previous) <= 0.12
end

local function formatNumber(value)
    local valueNumber = publicNumber(value)
    if not valueNumber then return "?" end
    local n = math.floor(valueNumber + 0.5)
    if BreakUpLargeNumbers then
        local ok, result = pcall(BreakUpLargeNumbers, n)
        if ok and result then return tostring(result) end
    end
    local s = tostring(n)
    local sign, digits = s:match("^([%-]?)(%d+)$")
    if not digits then return s end
    local out = digits
    while true do
        local changed
        out, changed = out:gsub("^(%d+)(%d%d%d)", "%1.%2", 1)
        if changed == 0 then break end
    end
    return (sign or "") .. out
end

function Bam:CanPlay()
    if not self.db or not self.db.enabled then return false end
    if self:IsContextMuted() then return false end
    return (now() - lastSoundAt) >= (self.db.throttle or 0)
end

function Bam:IsContextMuted()
    if not self.db then return false end

    if self.db.muteInDungeon and type(IsInInstance) == "function" then
        local ok, inInstance, instanceType = pcall(IsInInstance)
        if ok
            and readable(inInstance)
            and readable(instanceType)
            and inInstance == true
            and instanceType == "party"
        then
            return true
        end
    end

    if self.db.muteInGroup and readAPI(IsInGroup) == true then
        return true
    end

    return false
end

function Bam:ResolveSound(choice, finisher)
    if choice ~= "shuffle" then return soundsById[choice] and choice or (finisher and "baaam" or "bam") end
    local pool = {}
    for _, sound in ipairs(self.sounds) do
        if (sound.finisher or false) == finisher then pool[#pool + 1] = sound.id end
    end
    return pool[math.random(#pool)]
end

function Bam:SoundName(choice)
    if choice == "shuffle" then return L.SHUFFLE end
    return soundsById[choice] and soundsById[choice].name or tostring(choice)
end

function Bam:Play(soundId, preview)
    if not preview and not self:CanPlay() then return false end
    local sound = soundsById[soundId] or soundsById.bam
    local ok = PlaySoundFile(SOUND_DIR .. sound.file, "Master")
    if ok == false then
        self:Print(L.SOUND_ERROR)
        return false
    end
    if not preview then lastSoundAt = now() end
    return true
end

local function isHostileUnit(unit)
    if not unit or not readAPI(UnitExists, unit) then return false end
    if UnitCanAttack and not readAPI(UnitCanAttack, "player", unit) then return false end
    return true
end

local function sameAsCurrentTarget(unit)
    if not readAPI(UnitExists, "target") or not readAPI(UnitExists, unit) then return false end
    if UnitIsUnit then return readAPI(UnitIsUnit, unit, "target") end
    local a,b = readAPI(UnitGUID, unit), readAPI(UnitGUID, "target")
    return a and b and a == b
end

local function playerIsAttackingUnit(unit)
    if not unit or not readAPI(UnitExists, unit) then return false end

    -- Preferred Classic/Forever API: directly asks whether THIS player
    -- is melee-attacking the specified unit.
    if IsPlayerAttacking then
        local ok, active = pcall(IsPlayerAttacking, unit)
        if ok and readable(active) and active == true then return true end
    end

    -- Fallback for clients where IsPlayerAttacking is unavailable.
    if not sameAsCurrentTarget(unit) then return false end

    if C_Spell and C_Spell.IsCurrentSpell then
        local ok, active = pcall(C_Spell.IsCurrentSpell, 6603)
        if ok and readable(active) and active == true then return true end
    end

    if IsCurrentSpell then
        local ok, active = pcall(IsCurrentSpell, 6603)
        if ok and readable(active) and active == true then return true end
    end

    return false
end

local function rememberSpellTarget(spellID)
    lastSpellAt = now()
    lastSpellID = publicNumber(spellID)

    if readAPI(UnitExists, "target") and isHostileUnit("target") then
        lastSpellTargetGUID = readAPI(UnitGUID, "target")
    else
        lastSpellTargetGUID = nil
    end
end

local function classifyCrit(unit)
    if not unit or not readAPI(UnitExists, unit) then return nil end

    local unitGUID = readAPI(UnitGUID, unit)
    if not unitGUID then return nil end

    -- Spell crits are only accepted if *this player* just successfully cast
    -- something and the damaged unit is the same target we recorded.
    -- Periodic effects can crit long after the original cast succeeded.
    -- Keep the hostile spell target long enough to cover those later ticks.
    local recentSpell = (now() - lastSpellAt) <= SPELL_TARGET_WINDOW
    if recentSpell
        and lastSpellTargetGUID
        and unitGUID == lastSpellTargetGUID
    then
        return "spell"
    end

    -- Melee crits are only accepted if the client reports that THIS player
    -- is actively melee-attacking this exact unit.
    if playerIsAttackingUnit(unit) then
        return "melee"
    end

    return nil
end

function Bam:PrintCrit(amount, unit, killed, combatLogTargetName, senderName)
    if not self.db or not self.db.critChat then return end
    if self:IsContextMuted() then return end
    local value = formatNumber(amount)
    local targetName = readable(combatLogTargetName) and combatLogTargetName or nil
    if not targetName then
        targetName = unit and readAPI(UnitExists, unit) and readAPI(UnitName, unit) or nil
    end
    local prefix = killed and "|cffff5a36BAAAM!|r" or "|cffffd04aBAM!|r"
    local label = killed and L.FINISHER_LABEL or L.CRIT_LABEL
    local suffix = targetName and ("  |cff707782→|r  |cffd8dbe2" .. targetName .. "|r") or ""
    if senderName then prefix = "|cff9bdbf5" .. senderName .. "|r  " .. prefix end
    print(prefix .. "  |cffffffff" .. value .. "|r |cffc6cbd3" .. label .. "|r" .. suffix)
end

local COMM_PREFIX = "BamTogether"
local PARTY_SEND_INTERVAL = 0.2
local lastPartySendAt = -100
local CLAIM_WINDOW = 0.5
local recentClaims = {}

-- Crit attribution is a guess, so several clients in the party can claim
-- the same crit. The first claim of a target/amount pair wins; later ones
-- are dropped so one crit plays and prints once.
local function isAlreadyClaimed(targetName, amount)
    if not amount then return false end
    local key = tostring(targetName or "?") .. ":" .. tostring(math.floor(amount + 0.5))
    local t = now()
    for k, stamp in pairs(recentClaims) do
        if (t - stamp) > CLAIM_WINDOW then recentClaims[k] = nil end
    end
    if recentClaims[key] then return true end
    recentClaims[key] = t
    return false
end

-- Message format: "<A|B>:<sound id>:<amount>:<target name>", A = finisher.
-- The receiver plays the sender's sound, so everyone hears the same one.
function Bam:SendPartyCrit(isFinisher, soundId, amount, targetName)
    if not self.db.partyBam or readAPI(IsInGroup) ~= true then return end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local t = now()
    if (t - lastPartySendAt) < PARTY_SEND_INTERVAL then return end
    lastPartySendAt = t
    local amountText = amount and tostring(math.floor(amount + 0.5)) or ""
    local msg = (isFinisher and "A" or "B") .. ":" .. soundId .. ":" .. amountText .. ":" .. (targetName or "")
    pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, msg:sub(1, 255), "PARTY")
end

function Bam:ReceivePartyCrit(text, sender)
    if not self.db.partyBam then return end
    local kindChar, soundId, amountText, targetName = text:match("^([AB]):([%w_]*):(%d*):(.*)$")
    if not kindChar then return end
    local senderName = Ambiguate and Ambiguate(sender, "short") or sender
    local amount = tonumber(amountText)
    if targetName == "" then targetName = nil end
    if isAlreadyClaimed(targetName, amount) then
        if self.db.debug then
            self:Print(L.CLAIM_DUPLICATE .. ": sender=" .. senderName .. " msg=" .. text)
        end
        return
    end
    local isFinisher = kindChar == "A"
    if not soundsById[soundId] then soundId = isFinisher and "baaam" or "bam" end

    self:PrintCrit(amount, nil, isFinisher, targetName, senderName)
    self:Play(soundId, false)
    if self.db.debug then
        self:Print(L.PARTY_RECEIVED .. ": sender=" .. senderName .. " msg=" .. text)
    end
end

local function isOwnMessage(sender)
    local name = Ambiguate and Ambiguate(sender, "none") or sender
    return name == readAPI(UnitName, "player")
end

local function handleCritical(unit, amount)
    if not Bam.db or not Bam.db.enabled or not isHostileUnit(unit) then return end
    amount = publicNumber(amount)

    local kind = classifyCrit(unit)
    if kind == "spell" and not Bam.db.spellCrits then return end
    if kind == "melee" and not Bam.db.meleeCrits then return end
    if not kind then return end
    if isDuplicateCrit(unit, "WOUND", amount) then
        if Bam.db.debug then
            Bam:Print(L.DUPLICATE .. ": amount=" .. tostring(amount or "?")
                .. " unit=" .. tostring(unit or "?"))
        end
        return
    end

    local guid = readAPI(UnitGUID, unit)
    local function finish()
        if not Bam.db or not Bam.db.enabled then return end
        local sameUnit = readAPI(UnitExists, unit) == true
        if sameUnit and guid then
            sameUnit = readAPI(UnitGUID, unit) == guid
        end
        local dead = sameUnit and UnitIsDeadOrGhost and readAPI(UnitIsDeadOrGhost, unit)
        local isFinisher = Bam.db.finisherBaaam and dead
        local targetName = sameUnit and readAPI(UnitName, unit) or nil
        local soundId = isFinisher and Bam:ResolveSound(Bam.db.finisherSound, true)
            or Bam:ResolveSound(Bam.db.critSound, false)

        Bam:SendPartyCrit(isFinisher, soundId, amount, targetName)
        if isAlreadyClaimed(targetName, amount) then
            if Bam.db.debug then
                Bam:Print(L.CLAIM_DUPLICATE .. ": amount=" .. tostring(amount) .. " unit=" .. tostring(unit))
            end
            return
        end
        Bam:PrintCrit(amount, sameUnit and unit or nil, isFinisher)
        Bam:Play(soundId, false)
        if Bam.db.debug then
            local prefix = kind == "spell" and L.SPELL_CRIT or L.MELEE_CRIT
            Bam:Print(prefix .. ": amount=" .. tostring(amount or "?")
                .. " unit=" .. tostring(unit or "?")
                .. " dead=" .. tostring(dead and true or false)
                .. " spellID=" .. tostring(lastSpellID or "-")
                .. " attacking=" .. tostring(playerIsAttackingUnit(unit)))
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.03, finish)
    else
        finish()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_COMBAT")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end
        Bam:InitDB()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
        end
        Bam:RegisterSlashCommands()
        Bam:Print(string.format(L.LOADED, Bam.version))
        return
    end

    if not Bam.db or not Bam.db.enabled then return end

    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if not readable(prefix) or prefix ~= COMM_PREFIX then return end
        if not readable(text) or not readable(sender) then return end
        if type(text) ~= "string" or type(sender) ~= "string" or isOwnMessage(sender) then return end
        Bam:ReceivePartyCrit(text, sender)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if readable(unit) and unit == "player" then
            rememberSpellTarget(spellID)
        end
        return
    end

    if event == "UNIT_COMBAT" then
        local unit, action, flagText, amount = ...
        if not readable(unit) or not readable(action) or not readable(flagText) then return end
        if type(unit) ~= "string" or action ~= "WOUND" then return end

        if flagText == "CRITICAL" then
            amount = publicNumber(amount)
            handleCritical(unit, amount)
        end
    end
end)

function Bam:RegisterSlashCommands()
    SLASH_BAM1 = "/bam"
    SlashCmdList.BAM = function(msg)
        msg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if msg == "test" then
            Bam:Play(Bam:ResolveSound(Bam.db.critSound, false), true)
        elseif msg == "testbig" or msg == "baaam" then
            Bam:Play(Bam:ResolveSound(Bam.db.finisherSound, true), true)
        elseif msg == "on" then
            Bam.db.enabled = true
            Bam:Print(L.ENABLED_MSG)
            if Bam.RefreshSettings then Bam:RefreshSettings() end
        elseif msg == "off" then
            Bam.db.enabled = false
            Bam:Print(L.DISABLED_MSG)
            if Bam.RefreshSettings then Bam:RefreshSettings() end
        elseif msg == "reset" then
            wipe(BamTogetherSettings)
            copyDefaults(BamTogetherSettings)
            Bam.db = BamTogetherSettings
            Bam:Print(L.RESET_MSG)
            if Bam.RefreshSettings then Bam:RefreshSettings() end
        else
            if Bam.OpenSettings then Bam:OpenSettings() end
        end
    end
end
