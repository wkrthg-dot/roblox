-- zelax.tha v1 | Bee Swarm farm (ASCII only)
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local runId = tick()
_G.BSS_RUN_ID = runId
local function alive() return _G.BSS_RUN_ID == runId end

local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
local old = guiParent:FindFirstChild("BSS_ControlMenu")
if old then old:Destroy() end

---------------------------------------------------------------
-- State + config
---------------------------------------------------------------
local S = { farm = false, sell = true, speed = true, cam = true, sprinkler = false, fps = false }
local converting = false
local hitCount, hitMethod, pollenRate = 0, "-", 0
local bestToken = nil
local field = nil
local cur = nil
local bad = setmetatable({}, { __mode = "k" })
local sessionTime, honey0 = 0, nil
local fps = 60
local lastSprinkler = 0

local FIELDS = {
    "Sunflower Field", "Dandelion Field", "Mushroom Field", "Blue Flower Field",
    "Clover Field", "Spider Field", "Bamboo Field", "Strawberry Field",
    "Pineapple Patch", "Stump Field", "Cactus Field", "Pumpkin Patch",
    "Pine Tree Forest", "Rose Field", "Mountain Top Field", "Coconut Field",
    "Pepper Patch",
}

local CFG_FILE = "zelax_tha_v1.json"
local saved = {}
pcall(function()
    if isfile and readfile and isfile(CFG_FILE) then
        saved = HttpService:JSONDecode(readfile(CFG_FILE))
    end
end)
if type(saved) ~= "table" then saved = {} end
for _, k in ipairs({ "sell", "speed", "cam", "sprinkler", "fps" }) do
    if type(saved[k]) == "boolean" then S[k] = saved[k] end
end
local selectedName = "Pepper Patch"
for _, n in ipairs(FIELDS) do
    if saved.field == n then selectedName = n end
end

local function saveCfg()
    if not writefile then return end
    pcall(function()
        writefile(CFG_FILE, HttpService:JSONEncode({
            field = selectedName, speed = S.speed, sell = S.sell,
            cam = S.cam, sprinkler = S.sprinkler, fps = S.fps,
        }))
    end)
end

local function speeds()
    if S.speed then return 320, 140 end
    return 60, 30
end

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------
local function fmt(n)
    n = n or 0
    local a = math.abs(n)
    local sign = n < 0 and "-" or ""
    if a >= 1e12 then return sign .. string.format("%.1fT", a / 1e12)
    elseif a >= 1e9 then return sign .. string.format("%.1fB", a / 1e9)
    elseif a >= 1e6 then return sign .. string.format("%.1fM", a / 1e6)
    elseif a >= 1e3 then return sign .. string.format("%.1fK", a / 1e3)
    end
    return sign .. tostring(math.floor(a))
end

local function fmtTime(s)
    s = math.floor(s)
    return string.format("%02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

local function getChar()
    local c = LocalPlayer.Character
    return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function tpTo(root, pos)
    root.CFrame = CFrame.new(pos)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function inField(pos, margin)
    local rel = field.CFrame:PointToObjectSpace(pos)
    return math.abs(rel.X) <= field.Size.X / 2 + margin
       and math.abs(rel.Z) <= field.Size.Z / 2 + margin
end

local function fieldPoint()
    local s = field.Size
    local hx = math.max(1, math.floor(s.X / 2 - 4))
    local hz = math.max(1, math.floor(s.Z / 2 - 4))
    local off = Vector3.new(math.random(-hx, hx), s.Y / 2 + 3, math.random(-hz, hz))
    return field.CFrame:PointToWorldSpace(off)
end

local function pollen()
    local cs = LocalPlayer:FindFirstChild("CoreStats")
    local p = cs and cs:FindFirstChild("Pollen")
    local c = cs and cs:FindFirstChild("Capacity")
    if p and c then return p.Value, c.Value end
    return 0, 1
end

local function honeyValue()
    local cs = LocalPlayer:FindFirstChild("CoreStats")
    local h = cs and cs:FindFirstChild("Honey")
    return h and h.Value or 0
end

local function getRemote(name)
    local ev = RS:FindFirstChild("Events")
    return ev and ev:FindFirstChild(name)
end

local function setJump(enabled)
    local _, _, hum = getChar()
    if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled) end) end
end

---------------------------------------------------------------
-- Learn the game's real hit remote
---------------------------------------------------------------
if hookmetamethod and getnamecallmethod and not _G.BSS_HOOKED then
    local ok = pcall(function()
        local oldNC
        oldNC = hookmetamethod(game, "__namecall", (newcclosure or function(f) return f end)(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and typeof(self) == "Instance" and self:IsA("RemoteEvent")
                and not (checkcaller and checkcaller()) then
                local n = self.Name:lower()
                if n:find("collect") or n:find("click") or n:find("tool") then
                    _G.BSS_CAP = { remote = self, args = table.pack(...) }
                end
            end
            return oldNC(self, ...)
        end))
    end)
    if ok then _G.BSS_HOOKED = true end
end

---------------------------------------------------------------
-- UI
---------------------------------------------------------------
local RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 190)),
    ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 215, 120)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 190)),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 195, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 130, 255)),
})
local grads = {}
local function addGrad(parent)
    local g = Instance.new("UIGradient")
    g.Color = RAINBOW
    g.Parent = parent
    table.insert(grads, g)
    return g
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = parent
    return c
end

local function newLabel(parent, text, x, y, w, h, size, font, color, align)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h)
    l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = font
    l.TextSize = size
    l.TextColor3 = color
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = parent
    return l
end

local WHITE = Color3.fromRGB(255, 255, 255)
local W, FULL_H, MINI_H = 232, 224, 34

local Gui = Instance.new("ScreenGui")
Gui.Name = "BSS_ControlMenu"
Gui.ResetOnSpawn = false
Gui.Parent = guiParent

local Root = Instance.new("Frame")
Root.Size = UDim2.new(0, W, 0, FULL_H)
Root.Position = UDim2.new(0.5, -W / 2, 0.03, 0)
Root.BackgroundTransparency = 1
Root.Parent = Gui

local Shadow2 = Instance.new("Frame")
Shadow2.Size = UDim2.new(1, 10, 1, 10)
Shadow2.Position = UDim2.new(0, -5, 0, 0)
Shadow2.BackgroundColor3 = Color3.new(0, 0, 0)
Shadow2.BackgroundTransparency = 0.82
Shadow2.BorderSizePixel = 0
Shadow2.ZIndex = 1
Shadow2.Parent = Root
corner(Shadow2, 22)

local Shadow1 = Instance.new("Frame")
Shadow1.Size = UDim2.new(1, 0, 1, 0)
Shadow1.Position = UDim2.new(0, 0, 0, 5)
Shadow1.BackgroundColor3 = Color3.new(0, 0, 0)
Shadow1.BackgroundTransparency = 0.6
Shadow1.BorderSizePixel = 0
Shadow1.ZIndex = 2
Shadow1.Parent = Root
corner(Shadow1, 17)

local Card = Instance.new("Frame")
Card.Size = UDim2.new(1, 0, 1, 0)
Card.BackgroundColor3 = WHITE
Card.BackgroundTransparency = 0.1
Card.BorderSizePixel = 0
Card.Active = true
Card.ZIndex = 3
Card.Parent = Root
corner(Card, 16)
local cgrad = Instance.new("UIGradient", Card)
cgrad.Rotation = 90
cgrad.Color = ColorSequence.new(Color3.fromRGB(42, 46, 78), Color3.fromRGB(14, 16, 30))
local cstroke = Instance.new("UIStroke", Card)
cstroke.Color = WHITE
cstroke.Thickness = 1.5
cstroke.Transparency = 0.2
addGrad(cstroke)

-- header
newLabel(Card, "zelax.tha v1", 12, 5, 86, 20, 14, Enum.Font.GothamBold, WHITE)

local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(0, 208, 0, 2)
Bar.Position = UDim2.new(0, 12, 0, 28)
Bar.BackgroundColor3 = WHITE
Bar.BorderSizePixel = 0
Bar.Parent = Card
corner(Bar, 1)
local barGrad = Instance.new("UIGradient", Bar)
barGrad.Color = RAINBOW

local FieldBtn = Instance.new("TextButton")
FieldBtn.Size = UDim2.new(0, 96, 0, 20)
FieldBtn.Position = UDim2.new(0, 100, 0, 5)
FieldBtn.BackgroundColor3 = WHITE
FieldBtn.BackgroundTransparency = 0.88
FieldBtn.Text = selectedName .. " v"
FieldBtn.Font = Enum.Font.GothamBold
FieldBtn.TextSize = 10
FieldBtn.TextColor3 = WHITE
FieldBtn.TextTruncate = Enum.TextTruncate.AtEnd
FieldBtn.AutoButtonColor = false
FieldBtn.Parent = Card
corner(FieldBtn, 8)
local fstroke = Instance.new("UIStroke", FieldBtn)
fstroke.Color = WHITE
fstroke.Transparency = 0.5
addGrad(fstroke)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 22, 0, 20)
MinBtn.Position = UDim2.new(0, 200, 0, 5)
MinBtn.BackgroundColor3 = WHITE
MinBtn.BackgroundTransparency = 0.88
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.TextColor3 = WHITE
MinBtn.AutoButtonColor = false
MinBtn.Parent = Card
corner(MinBtn, 8)

-- body
local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, 0, 1, -34)
Body.Position = UDim2.new(0, 0, 0, 34)
Body.BackgroundTransparency = 1
Body.Parent = Card

local function makeStat(x, title)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 50, 0, 30)
    f.Position = UDim2.new(0, x, 0, 0)
    f.BackgroundColor3 = Color3.new(0, 0, 0)
    f.BackgroundTransparency = 0.45
    f.BorderSizePixel = 0
    f.Parent = Body
    corner(f, 8)
    local st = Instance.new("UIStroke", f)
    st.Color = WHITE
    st.Transparency = 0.86
    newLabel(f, title, 0, 3, 50, 10, 8, Enum.Font.GothamMedium, Color3.fromRGB(140, 150, 195), Enum.TextXAlignment.Center)
    return newLabel(f, "0", 0, 14, 50, 14, 11, Enum.Font.GothamBold, WHITE, Enum.TextXAlignment.Center)
end

local StatTime = makeStat(12, "TIME")
local StatHoney = makeStat(66, "HONEY")
local StatRate = makeStat(120, "POLLEN/s")
local StatFps = makeStat(174, "FPS")
StatTime.Text = "00:00:00"

local Status = newLabel(Body, "Status: Idle", 12, 34, 208, 14, 12, Enum.Font.GothamBold, Color3.fromRGB(255, 170, 170))
local Dbg = newLabel(Body, "Hit: -  |  Hook: -", 12, 48, 208, 11, 9, Enum.Font.Gotham, Color3.fromRGB(140, 150, 195))

local function setStatus(text, good)
    Status.Text = "Status: " .. text
    Status.TextColor3 = good and Color3.fromRGB(150, 255, 190) or Color3.fromRGB(255, 170, 170)
end

-- 3D keys
local GREEN = { top = Color3.fromRGB(96, 236, 160), bot = Color3.fromRGB(34, 176, 112), base = Color3.fromRGB(16, 104, 68) }
local RED = { top = Color3.fromRGB(255, 118, 118), bot = Color3.fromRGB(206, 52, 64), base = Color3.fromRGB(122, 26, 38) }
local BLUE = { top = Color3.fromRGB(120, 176, 255), bot = Color3.fromRGB(64, 104, 226), base = Color3.fromRGB(30, 52, 130) }
local OFFC = { top = Color3.fromRGB(70, 76, 102), bot = Color3.fromRGB(46, 50, 70), base = Color3.fromRGB(24, 26, 40) }
local PURP = { top = Color3.fromRGB(190, 140, 255), bot = Color3.fromRGB(120, 80, 220), base = Color3.fromRGB(62, 36, 130) }

local function setKeyColors(key, pal)
    key.grad.Color = ColorSequence.new(pal.top, pal.bot)
    key.base.BackgroundColor3 = pal.base
end

local function makeKey(x, y, w, h, text, tsize, depth)
    local base = Instance.new("Frame")
    base.Size = UDim2.new(0, w, 0, h)
    base.Position = UDim2.new(0, x, 0, y + depth)
    base.BorderSizePixel = 0
    base.ZIndex = 1
    base.Parent = Body
    corner(base, 9)

    local face = Instance.new("Frame")
    face.Size = UDim2.new(0, w, 0, h)
    face.Position = UDim2.new(0, x, 0, y)
    face.BackgroundColor3 = WHITE
    face.BorderSizePixel = 0
    face.ZIndex = 2
    face.Parent = Body
    corner(face, 9)
    local grad = Instance.new("UIGradient", face)
    grad.Rotation = 90
    local rim = Instance.new("UIStroke", face)
    rim.Color = WHITE
    rim.Thickness = 1
    rim.Transparency = 0.45
    local rimGrad = Instance.new("UIGradient", rim)
    rimGrad.Rotation = 90
    rimGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.85),
    })

    local gloss = Instance.new("Frame")
    gloss.Size = UDim2.new(1, -8, 0, math.floor(h / 2) - 2)
    gloss.Position = UDim2.new(0, 4, 0, 2)
    gloss.BackgroundColor3 = WHITE
    gloss.BackgroundTransparency = 0.86
    gloss.BorderSizePixel = 0
    gloss.Parent = face
    corner(gloss, 7)

    local lbl = Instance.new("TextButton")
    lbl.Size = UDim2.new(0, w, 0, h)
    lbl.Position = UDim2.new(0, x, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = tsize
    lbl.TextColor3 = WHITE
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.TextStrokeTransparency = 0.8
    lbl.AutoButtonColor = false
    lbl.ZIndex = 4
    lbl.Parent = Body

    local function press(p)
        local pos = UDim2.new(0, x, 0, y + (p and (depth - 1) or 0))
        face.Position = pos
        lbl.Position = pos
    end
    lbl.MouseButton1Down:Connect(function() press(true) end)
    lbl.MouseButton1Up:Connect(function() press(false) end)
    lbl.MouseLeave:Connect(function() press(false) end)

    return { base = base, face = face, grad = grad, lbl = lbl }
end

local BtnFarm = makeKey(12, 66, 208, 32, "START", 15, 3)
setKeyColors(BtnFarm, GREEN)

local function makeChip(x, y, text, getState)
    local key = makeKey(x, y, 104, 22, text, 11, 2)
    local pad = Instance.new("UIPadding", key.lbl)
    pad.PaddingLeft = UDim.new(0, 12)
    local led = Instance.new("Frame")
    led.Size = UDim2.new(0, 6, 0, 6)
    led.Position = UDim2.new(0, x + 9, 0, y + 8)
    led.BorderSizePixel = 0
    led.ZIndex = 5
    led.Parent = Body
    corner(led, 3)
    local function refresh()
        local on = getState()
        setKeyColors(key, on and BLUE or OFFC)
        led.BackgroundColor3 = on and Color3.fromRGB(120, 255, 170) or Color3.fromRGB(110, 114, 140)
        key.lbl.TextTransparency = on and 0 or 0.3
    end
    refresh()
    return key, refresh
end

local ChipSpeed, refSpeed = makeChip(12, 108, "Speed Boost", function() return S.speed end)
local ChipSell, refSell = makeChip(120, 108, "Auto Sell", function() return S.sell end)
local ChipCam, refCam = makeChip(12, 134, "Calm Cam", function() return S.cam end)
local ChipSpr, refSpr = makeChip(120, 134, "Sprinkler", function() return S.sprinkler end)
local ChipFps, refFps = makeChip(12, 160, "FPS Boost", function() return S.fps end)
local ChipReset = makeKey(120, 160, 104, 22, "Reset Stats", 11, 2)
setKeyColors(ChipReset, PURP)

-- field grid picker (no scrolling)
local Dropdown = Instance.new("Frame")
Dropdown.Size = UDim2.new(0, 224, 0, 218)
Dropdown.Position = UDim2.new(0, 4, 0, 32)
Dropdown.BackgroundColor3 = Color3.fromRGB(14, 16, 30)
Dropdown.BackgroundTransparency = 0.05
Dropdown.BorderSizePixel = 0
Dropdown.Visible = false
Dropdown.Active = true
Dropdown.ZIndex = 50
Dropdown.Parent = Card
corner(Dropdown, 12)
local dstroke = Instance.new("UIStroke", Dropdown)
dstroke.Color = WHITE
dstroke.Transparency = 0.3
addGrad(dstroke)
local dpad = Instance.new("UIPadding", Dropdown)
dpad.PaddingTop = UDim.new(0, 5)
dpad.PaddingLeft = UDim.new(0, 5)
dpad.PaddingRight = UDim.new(0, 5)
dpad.PaddingBottom = UDim.new(0, 5)
local dgrid = Instance.new("UIGridLayout", Dropdown)
dgrid.CellSize = UDim2.new(0, 104, 0, 20)
dgrid.CellPadding = UDim2.new(0, 4, 0, 3)
dgrid.SortOrder = Enum.SortOrder.LayoutOrder

-- toast
local ToastF = Instance.new("Frame")
ToastF.Size = UDim2.new(0, 220, 0, 26)
ToastF.Position = UDim2.new(0.5, -110, 0.86, 0)
ToastF.BackgroundColor3 = Color3.fromRGB(16, 18, 32)
ToastF.BackgroundTransparency = 1
ToastF.BorderSizePixel = 0
ToastF.Parent = Gui
corner(ToastF, 10)
local ToastStroke = Instance.new("UIStroke", ToastF)
ToastStroke.Color = WHITE
ToastStroke.Transparency = 1
local ToastLbl = Instance.new("TextLabel")
ToastLbl.Size = UDim2.new(1, 0, 1, 0)
ToastLbl.BackgroundTransparency = 1
ToastLbl.Font = Enum.Font.GothamBold
ToastLbl.TextSize = 12
ToastLbl.TextColor3 = WHITE
ToastLbl.TextTransparency = 1
ToastLbl.Text = ""
ToastLbl.Parent = ToastF

local toastId = 0
local function toast(msg)
    toastId += 1
    local my = toastId
    ToastLbl.Text = msg
    ToastF.BackgroundTransparency = 0.12
    ToastStroke.Transparency = 0.4
    ToastLbl.TextTransparency = 0
    task.delay(2.2, function()
        if toastId ~= my then return end
        local ti = TweenInfo.new(0.4)
        TweenService:Create(ToastF, ti, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(ToastStroke, ti, { Transparency = 1 }):Play()
        TweenService:Create(ToastLbl, ti, { TextTransparency = 1 }):Play()
    end)
end

-- one-finger drag (not while touching the field grid)
do
    local dragging, dragInput, dragStart, startPos
    Card.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) and not dragging then
            if Dropdown.Visible then
                local ap, as = Dropdown.AbsolutePosition, Dropdown.AbsoluteSize
                local p = input.Position
                if p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y then
                    return
                end
            end
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = Root.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

---------------------------------------------------------------
-- Tap helper, anti-AFK
---------------------------------------------------------------
local function tapScreen()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    local ap, as = Root.AbsolutePosition, Root.AbsoluteSize
    local m = 50
    local cands = { {0.5, 0.5}, {0.35, 0.5}, {0.6, 0.4}, {0.45, 0.3}, {0.25, 0.4} }
    for _, c in ipairs(cands) do
        local x, y = vs.X * c[1], vs.Y * c[2]
        local onMenu = x > ap.X - m and x < ap.X + as.X + m and y > ap.Y - m and y < ap.Y + as.Y + m
        if not onMenu then
            pcall(function()
                VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
                VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
            end)
            return
        end
    end
end

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

---------------------------------------------------------------
-- FPS boost
---------------------------------------------------------------
local fpsBackup = nil
local function applyFps(on)
    pcall(function()
        if on then
            if fpsBackup then return end
            fpsBackup = { shadows = Lighting.GlobalShadows, effects = {}, quality = nil }
            pcall(function() fpsBackup.quality = settings().Rendering.QualityLevel end)
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then
                    table.insert(fpsBackup.effects, { e, e.Enabled })
                    e.Enabled = false
                end
            end
            Lighting.GlobalShadows = false
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        else
            if not fpsBackup then return end
            for _, p in ipairs(fpsBackup.effects) do
                if p[1] and p[1].Parent then p[1].Enabled = p[2] end
            end
            Lighting.GlobalShadows = fpsBackup.shadows
            if fpsBackup.quality then
                pcall(function() settings().Rendering.QualityLevel = fpsBackup.quality end)
            end
            fpsBackup = nil
        end
    end)
end
if S.fps then applyFps(true) end

---------------------------------------------------------------
-- Field picker logic
---------------------------------------------------------------
local itemButtons = {}

local function refreshItems()
    for name, b in pairs(itemButtons) do
        local sel = (name == selectedName)
        b.BackgroundColor3 = sel and Color3.fromRGB(60, 200, 130) or WHITE
        b.BackgroundTransparency = sel and 0.25 or 0.9
    end
end

local function selectField(name)
    Dropdown.Visible = false
    local zones = Workspace:FindFirstChild("FlowerZones")
    local z = zones and zones:FindFirstChild(name)
    selectedName = name
    FieldBtn.Text = name .. " v"
    refreshItems()
    cur = nil
    lastSprinkler = 0
    table.clear(bad)
    saveCfg()
    if not z then
        field = nil
        setStatus(name .. " not found", false)
        return
    end
    field = z
    if S.farm then
        setStatus("Farming...", true)
        local _, root = getChar()
        if root then tpTo(root, fieldPoint()) end
    else
        setStatus("Idle", false)
    end
    toast("Field: " .. name)
end

for i, name in ipairs(FIELDS) do
    local it = Instance.new("TextButton")
    it.BackgroundColor3 = WHITE
    it.BackgroundTransparency = 0.9
    it.Text = name
    it.Font = Enum.Font.GothamBold
    it.TextScaled = true
    it.TextColor3 = WHITE
    it.AutoButtonColor = false
    it.LayoutOrder = i
    it.ZIndex = 51
    it.Parent = Dropdown
    corner(it, 6)
    local tc = Instance.new("UITextSizeConstraint", it)
    tc.MaxTextSize = 11
    tc.MinTextSize = 7
    local tp = Instance.new("UIPadding", it)
    tp.PaddingLeft = UDim.new(0, 3)
    tp.PaddingRight = UDim.new(0, 3)
    itemButtons[name] = it
    it.MouseButton1Click:Connect(function() selectField(name) end)
end

FieldBtn.MouseButton1Click:Connect(function()
    Dropdown.Visible = not Dropdown.Visible
end)

selectField(selectedName)

---------------------------------------------------------------
-- Calm Cam
---------------------------------------------------------------
local camActive = false
local function restoreCam()
    local cam = Workspace.CurrentCamera
    if cam and camActive then
        cam.CameraType = Enum.CameraType.Custom
        local _, _, hum = getChar()
        if hum then cam.CameraSubject = hum end
    end
    camActive = false
end

local rs
rs = RunService.RenderStepped:Connect(function()
    if not alive() then
        restoreCam()
        rs:Disconnect()
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if S.farm and S.cam and field and not converting then
        local center = field.Position
        local span = math.max(field.Size.X, field.Size.Z)
        local h = span * 0.8 + 25
        local back = span * 0.55 + 15
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = CFrame.lookAt(center + Vector3.new(0, h, back), center)
        camActive = true
    elseif camActive then
        restoreCam()
    end
end)

---------------------------------------------------------------
-- Token scan
---------------------------------------------------------------
task.spawn(function()
    while alive() do
        task.wait(0.05)
        bestToken = nil
        if S.farm and field and not converting then
            local _, root = getChar()
            local folder = Workspace:FindFirstChild("Collectibles")
            if root and folder then
                local bd = 150
                local rp = root.Position
                for _, t in ipairs(folder:GetChildren()) do
                    if t:IsA("BasePart") and not (bad[t] and bad[t] > tick()) then
                        local d = (t.Position - rp).Magnitude
                        if d < bd and inField(t.Position, 8) then
                            bestToken, bd = t, d
                        end
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------
-- Heartbeat: effects, stats timers, movement
---------------------------------------------------------------
local frames, fpsT = 0, 0
local hb
hb = RunService.Heartbeat:Connect(function(dt)
    if not alive() then hb:Disconnect() return end

    local t = tick()
    local rot = (t * 50) % 360
    for _, g in ipairs(grads) do g.Rotation = rot end
    barGrad.Offset = Vector2.new(math.sin(t * 1.5) * 0.45, 0)

    frames += 1
    fpsT += dt
    if fpsT >= 1 then
        fps = math.floor(frames / fpsT + 0.5)
        frames, fpsT = 0, 0
    end
    if S.farm then sessionTime += dt end

    if not (S.farm and field and not converting) then
        cur = nil
        return
    end

    local _, root, hum = getChar()
    if not (root and hum and hum.Health > 0) then return end

    if not inField(root.Position, 14) then
        tpTo(root, fieldPoint())
        cur = nil
        return
    end

    if cur and cur.token and not cur.token.Parent then cur = nil end

    if not cur or (cur.roam and bestToken) then
        if bestToken and bestToken.Parent then
            cur = { token = bestToken, born = tick() }
        elseif not cur then
            cur = { pos = fieldPoint(), roam = true, born = tick() }
        end
    end

    local tokenSpeed, roamSpeed = speeds()
    local goal = cur.token and cur.token.Position or cur.pos
    local rp = root.Position
    local flat = Vector3.new(goal.X - rp.X, 0, goal.Z - rp.Z)
    local dist = flat.Magnitude
    local timeout = cur.token and 1 or 3

    if dist <= 4 or tick() - cur.born > timeout then
        if cur.token then bad[cur.token] = tick() + 4 end
        cur = nil
    else
        local spd = cur.token and tokenSpeed or roamSpeed
        local step = math.min(dist, spd * dt)
        local np = rp + flat.Unit * step
        root.CFrame = CFrame.new(np) * (root.CFrame - root.CFrame.Position)
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
    end
end)

---------------------------------------------------------------
-- Hit loop (every frame)
---------------------------------------------------------------
local n3 = 0
local function doHit()
    local char, _, hum = getChar()
    if not (char and hum) then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        local tl = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
        if tl then pcall(function() hum:EquipTool(tl) end) end
    end

    local mode = "ToolCollect"
    local cap = _G.BSS_CAP
    if cap and cap.remote and cap.remote.Parent then
        pcall(function() cap.remote:FireServer(table.unpack(cap.args, 1, cap.args.n)) end)
        mode = "Learned"
    else
        local r = getRemote("ToolCollect")
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer() end)
        end
    end
    if tool then
        local ce = tool:FindFirstChild("ClickEvent")
        if ce and ce:IsA("RemoteEvent") then
            pcall(function() ce:FireServer() end)
        end
        pcall(function() tool:Activate() end)
    else
        mode = mode .. "+NoTool"
    end
    n3 += 1
    if n3 % 2 == 0 then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(0, 0))
        end)
    end
    if n3 % 5 == 0 then tapScreen() end
    hitCount += 1
    hitMethod = mode
end

task.spawn(function()
    while alive() do
        task.wait()
        if S.farm and not converting then
            pcall(doHit)
        end
    end
end)

---------------------------------------------------------------
-- Auto Sell Honey
---------------------------------------------------------------
task.spawn(function()
    while alive() do
        task.wait(1)
        if S.farm and S.sell and field and not converting then
            local p, c = pollen()
            if c > 0 and p >= c * 0.98 then
                converting = true
                pcall(function()
                    local _, root = getChar()
                    local spawnVal = LocalPlayer:FindFirstChild("SpawnPos")
                    if root and spawnVal and spawnVal.Value then
                        setStatus("Selling honey...", true)
                        tpTo(root, spawnVal.Value.Position + Vector3.new(0, 3, 0))
                        task.wait(0.7)
                        local r = getRemote("PlayerHiveCommand")
                        if r then r:FireServer("ToggleHoneyMaking") end
                        local t0 = tick()
                        repeat
                            task.wait(0.5)
                            local pp = pollen()
                        until pp <= 1 or tick() - t0 > 90 or not S.farm or not alive()
                        task.wait(0.5)
                        local _, root2 = getChar()
                        if root2 and field then tpTo(root2, fieldPoint()) end
                        cur = nil
                        lastSprinkler = 0
                        toast("Honey sold")
                    end
                end)
                converting = false
                if S.farm then setStatus("Farming...", true) end
            end
        end
    end
end)

---------------------------------------------------------------
-- Auto Sprinkler
---------------------------------------------------------------
task.spawn(function()
    while alive() do
        task.wait(1)
        if S.farm and S.sprinkler and field and not converting and tick() - lastSprinkler > 120 then
            lastSprinkler = tick()
            local r = getRemote("PlayerActivesCommand")
            if r then
                pcall(function() r:FireServer({ Name = "Sprinkler Builder" }) end)
                toast("Sprinkler placed")
            end
        end
    end
end)

---------------------------------------------------------------
-- Stats ticker
---------------------------------------------------------------
task.spawn(function()
    local lastP = pollen()
    while alive() do
        task.wait(1)
        local p = pollen()
        local delta = p - lastP
        lastP = p
        if delta >= 0 then pollenRate = delta end

        local h = honeyValue()
        if S.farm and honey0 == nil then honey0 = h end
        StatTime.Text = fmtTime(sessionTime)
        StatHoney.Text = "+" .. fmt(honey0 and math.max(0, h - honey0) or 0)
        StatRate.Text = fmt(pollenRate)
        StatFps.Text = tostring(fps)

        local hook
        if not (hookmetamethod and getnamecallmethod) then
            hook = "N/A"
        elseif _G.BSS_CAP and _G.BSS_CAP.remote then
            hook = "learned"
        else
            hook = "tap once"
        end
        Dbg.Text = "Hit: " .. hitMethod .. "  |  Hook: " .. hook
    end
end)

---------------------------------------------------------------
-- Buttons
---------------------------------------------------------------
BtnFarm.lbl.MouseButton1Click:Connect(function()
    Dropdown.Visible = false
    if not field then
        setStatus("Select a field first", false)
        return
    end
    S.farm = not S.farm
    cur = nil
    lastSprinkler = 0
    local _, root = getChar()
    if S.farm then
        BtnFarm.lbl.Text = "STOP"
        setKeyColors(BtnFarm, RED)
        setStatus("Farming...", true)
        setJump(false)
        if root and not inField(root.Position, 14) then
            tpTo(root, fieldPoint())
        end
        toast("Farming: " .. selectedName)
    else
        BtnFarm.lbl.Text = "START"
        setKeyColors(BtnFarm, GREEN)
        setStatus("Idle", false)
        setJump(true)
        toast("Stopped")
    end
end)

ChipSpeed.lbl.MouseButton1Click:Connect(function()
    S.speed = not S.speed
    refSpeed()
    saveCfg()
    toast("Speed Boost: " .. (S.speed and "ON" or "OFF"))
end)

ChipSell.lbl.MouseButton1Click:Connect(function()
    S.sell = not S.sell
    refSell()
    saveCfg()
    toast("Auto Sell: " .. (S.sell and "ON" or "OFF"))
end)

ChipCam.lbl.MouseButton1Click:Connect(function()
    S.cam = not S.cam
    refCam()
    saveCfg()
    toast("Calm Cam: " .. (S.cam and "ON" or "OFF"))
end)

ChipSpr.lbl.MouseButton1Click:Connect(function()
    S.sprinkler = not S.sprinkler
    lastSprinkler = 0
    refSpr()
    saveCfg()
    toast("Sprinkler: " .. (S.sprinkler and "ON" or "OFF"))
end)

ChipFps.lbl.MouseButton1Click:Connect(function()
    S.fps = not S.fps
    applyFps(S.fps)
    refFps()
    saveCfg()
    toast("FPS Boost: " .. (S.fps and "ON" or "OFF"))
end)

ChipReset.lbl.MouseButton1Click:Connect(function()
    sessionTime = 0
    honey0 = honeyValue()
    hitCount = 0
    pollenRate = 0
    toast("Stats reset")
end)

local mini = false
MinBtn.MouseButton1Click:Connect(function()
    mini = not mini
    Dropdown.Visible = false
    Body.Visible = not mini
    Root.Size = UDim2.new(0, W, 0, mini and MINI_H or FULL_H)
    MinBtn.Text = mini and "+" or "-"
end)