---@class LamarDialogue
---@field director IntroDirector
---@field index integer
---@field startedAt integer? game timer of the last StartScriptConversation call
---@field attempts integer failed start attempts for the current line
---@field subtitleShown boolean a manual subtitle is on screen for the playing line
---@field activeArrivalSub table? currently displayed arrival subtitle entry
LamarDialogue = {}
LamarDialogue.__index = LamarDialogue

local START_GRACE_MS = 1000 -- engine may need a few frames before ONGOING flips true
local MAX_ATTEMPTS = 3
local AUDIO_TEXT_SLOT = 9 -- FMINT already occupies Constants.dialogueTextSlot
local SUBTITLE_HOLD_MS = 10000 -- upper bound; cleared early when the line ends

-- '0'-'9' -> 0-9, 'A'-'Z' -> 10-35, anything else -> -1
---@param c string
---@return integer
local function participantFromChar(c)
    local b = c:byte() or 0
    if b >= 48 and b <= 57 then return b - 48 end
    if b >= 65 and b <= 90 then return b - 55 end
    return -1
end

---@param c string
---@return integer
local function audibilityFromChar(c)
    if c == "0" or c == "1" then return 1 end
    if c == "2" then return 2 end
    if c == "3" then return 3 end
    return 0
end

---@param c string
---@return boolean
local function boolFromChar(c)
    return c ~= "0"
end

---@param director IntroDirector
---@return LamarDialogue
function LamarDialogue.new(director)
    local self = setmetatable({}, LamarDialogue)
    self.director = director
    self.index = 1
    self.startedAt = nil
    self.attempts = 0
    self.subtitleShown = false
    return self
end

-- Dialogue subtitle labels are prefixed with the "~z~" token, which the HUD only
-- renders when the profile Subtitles setting is on. Strip it and print the text
-- ourselves so subtitles never depend on that setting.
---@param label string GXT key; anything with the right joaat hash works
---@param holdMs integer
---@return boolean shown
local function printSubtitle(label, holdMs)
    local text = GetLabelText(label)
    if text == "NULL" then
        return false
    end
    if text:sub(1, 3) == "~z~" then
        text = text:sub(4)
    end
    BeginTextCommandPrint("CELL_EMAIL_BCON")
    for i = 1, #text, 99 do
        AddTextComponentSubstringPlayerName(text:sub(i, i + 98))
    end
    EndTextCommandPrint(holdMs, true)
    return true
end

---@param label string
function LamarDialogue:showSubtitle(label)
    if printSubtitle(label, SUBTITLE_HOLD_MS) then
        self.subtitleShown = true
    end
end

-- FiveM does not render the arrival cutfile's own subtitle events, so we re-fire
-- them from cutscene time.
---@param cutTime integer GetCutsceneTime() in ms
function LamarDialogue:arrivalTick(cutTime)
    if cutTime <= 0 then
        return
    end

    local subs = self.director.isMale and Constants.arrivalSubtitles.male or Constants.arrivalSubtitles.female

    local active
    for _, sub in ipairs(subs) do
        if cutTime >= sub.time and cutTime < sub.time + sub.duration then
            active = sub
            break
        end
    end

    if active ~= self.activeArrivalSub then
        if active then
            printSubtitle(active.key, active.duration)
        else
            ClearPrints()
        end
        self.activeArrivalSub = active
    end
end

function LamarDialogue:init()
    -- fm_intro is a GTA:Online script; MP speech data must be mounted.
    SetAudioFlag("LoadMPData", true)

    -- FM_1AU is the GXT text block the game's dialogue_handler loads before
    -- building each conversation: per line it holds the subtitle label
    -- (FM_LAM1_1), the audio filename (FM_LAM1_1A) and the config labels
    -- (FM_LAM1SL / FM_LAM1LF / FM_LAM1IF).
    RequestAdditionalText(Constants.dialogueBlock, AUDIO_TEXT_SLOT)
    WaitUntil(function()
        return HasAdditionalTextLoaded(AUDIO_TEXT_SLOT)
    end, "FM_1AU dialogue text", 5000)

    RequestAdditionalText(Constants.dialogueTextBlock, Constants.dialogueTextSlot)
    WaitUntil(function()
        return HasAdditionalTextLoaded(Constants.dialogueTextSlot)
    end, "FMINT dialogue text", 5000)
end

-- Port of dialogue_handler.c sub_40e3: every ADD_LINE_TO_CONVERSATION argument
-- is read out of the FM_1AU GXT block.
---@param root string subtitle root, e.g. "FM_LAM1"
---@param label string line label, e.g. "FM_LAM1_5"
function LamarDialogue:playLine(root, label)
    -- the on-screen Lamar ped, so lip-sync shows on the one the player sees
    local ped = self.director.lamar.visiblePed or self.director.lamar.pedIGLamar

    -- 0-based position of this line within its conversation
    local lineNum = tonumber(label:match("_(%d+)$")) or 1
    local i = lineNum - 1

    -- the audio filename is the TEXT of "<label>A"
    local filename = GetLabelText(label .. "A")

    -- "<root>SL": 3 chars per line -> speaker slot, listener slot, volume type
    local sl = GetLabelText(root .. "SL")
    local speaker = participantFromChar(sl:sub(i * 3 + 1, i * 3 + 1))
    local listener = participantFromChar(sl:sub(i * 3 + 2, i * 3 + 2))
    local volume = participantFromChar(sl:sub(i * 3 + 3, i * 3 + 3))

    -- "<root>LF": 7 chars per line -> five bools around an audibility digit
    local lf = GetLabelText(root .. "LF")
    local function lfChar(offset)
        return lf:sub(i * 7 + offset + 1, i * 7 + offset + 1)
    end

    -- "<root>IF": conversation-level flags; char 0 feeds StartScriptConversation
    local ifText = GetLabelText(root .. "IF")

    CreateNewScriptedConversation()
    AddPedToConversation(1, ped, Constants.lamarSpeaker)

    -- the sync scene disables viseme anims, so re-enable or the mouth stays shut
    SetPedCanPlayVisemeAnims(ped, true, false)

    AddLineToConversation(
        speaker,
        filename,
        label,
        listener,
        volume,
        false,
        boolFromChar(lfChar(0)),
        boolFromChar(lfChar(1)),
        boolFromChar(lfChar(2)),
        audibilityFromChar(lfChar(3)),
        boolFromChar(lfChar(4)),
        boolFromChar(lfChar(5)),
        boolFromChar(lfChar(6))
    )

    StartScriptConversation(true, true, false, boolFromChar(ifText:sub(1, 1)))
end

---@param driveTime integer
function LamarDialogue:tick(driveTime)
    local ongoing = IsScriptedConversationOngoing()

    if self.subtitleShown and not ongoing then
        ClearPrints()
        self.subtitleShown = false
    end

    local lines = self.director.isMale and Constants.lamarLines.male or Constants.lamarLines.female

    if self.index > #lines then
        return
    end

    local line = lines[self.index]

    if driveTime < line.time then
        return
    end

    if ongoing then
        if self.startedAt then
            self:showSubtitle(line.label)
            self.startedAt = nil
            self.attempts = 0
            self.index = self.index + 1
        end
        -- previous line is still playing: wait, never stomp it
        return
    end

    local now = GetGameTimer()

    if self.startedAt then
        -- conversation is still spinning up; recreating it every frame would
        -- reset the pending conversation and guarantee silence
        if now - self.startedAt < START_GRACE_MS then
            return
        end
        self.attempts = self.attempts + 1
        if self.attempts >= MAX_ATTEMPTS then
            self.startedAt = nil
            self.attempts = 0
            self.index = self.index + 1
            return
        end
    end

    self:playLine(line.root, line.label)
    self.startedAt = now
end
