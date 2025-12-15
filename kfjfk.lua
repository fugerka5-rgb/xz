local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "Rayfield Example Window",
   Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
   LoadingTitle = "Rayfield Interface Suite",
   LoadingSubtitle = "by Sirius",
   ShowText = "Rayfield", -- for mobile users to unhide rayfield, change if you'd like
   Theme = "Default", -- Check https://docs.sirius.menu/rayfield/configuration/themes

   ToggleUIKeybind = "K", -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false, -- Prevents Rayfield from warning when the script has a version mismatch with the interface

   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil, -- Create a custom folder for your hub/game
      FileName = "Big Hub"
   },

   Discord = {
      Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
      Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
      RememberJoins = true -- Set this to false to make them join the discord every time they load it up
   },

   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "Untitled",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
      FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"Hello"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
   }
})
--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
--// CONFIG
local ESP = {
	Enabled = false,

	Box = { Enabled = true, Thickness = 2, Color = Color3.fromRGB(255, 255, 255) },
	Skeleton = { Enabled = true, Thickness = 2, Color = Color3.fromRGB(0, 255, 140) },

	DistanceText = { Enabled = true, Size = 16, Color = Color3.fromRGB(255, 255, 255) },

	MaxDistanceStuds = 2500,
	StudToMeter = 0.28,  -- 1 stud ≈ 0.28m (можешь менять)
	BoxPadding = 2,

	-- Сглаживание бокса (чем выше, тем “статичнее”, но медленнее реагирует)
	SmoothAlpha = 0.35, -- 0..1
}

--// UI Root
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESP2D_UI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

--// Helpers
local function w2s(pos)
	local v, on = Camera:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), on, v.Z
end

local function getDistanceStuds(plr)
	local my = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local ch = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not my or not ch then return nil end
	return (my.Position - ch.Position).Magnitude
end

local function makeLine(parent)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Visible = false
	f.Parent = parent
	return f
end

local function setLine(lineFrame, a, b, thickness, color)
	local d = b - a
	local len = d.Magnitude
	if len < 1 then
		lineFrame.Visible = false
		return
	end
	local mid = (a + b) * 0.5
	local rot = math.deg(math.atan2(d.Y, d.X))
	lineFrame.Size = UDim2.fromOffset(len, thickness)
	lineFrame.Position = UDim2.fromOffset(mid.X, mid.Y)
	lineFrame.Rotation = rot
	lineFrame.BackgroundColor3 = color
	lineFrame.Visible = true
end

local function getRigPairs(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local rig = hum and hum.RigType or Enum.HumanoidRigType.R15

	if rig == Enum.HumanoidRigType.R15 then
		return {
			{"Head","UpperTorso"},
			{"UpperTorso","LowerTorso"},

			{"UpperTorso","LeftUpperArm"},
			{"LeftUpperArm","LeftLowerArm"},
			{"LeftLowerArm","LeftHand"},

			{"UpperTorso","RightUpperArm"},
			{"RightUpperArm","RightLowerArm"},
			{"RightLowerArm","RightHand"},

			{"LowerTorso","LeftUpperLeg"},
			{"LeftUpperLeg","LeftLowerLeg"},
			{"LeftLowerLeg","LeftFoot"},

			{"LowerTorso","RightUpperLeg"},
			{"RightUpperLeg","RightLowerLeg"},
			{"RightLowerLeg","RightFoot"},
		}
	else
		return {
			{"Head","Torso"},
			{"Torso","Left Arm"},
			{"Torso","Right Arm"},
			{"Torso","Left Leg"},
			{"Torso","Right Leg"},
		}
	end
end

--========================================================
--// FIX: стабильный бокс (не раздувается от удара/анимаций)
--========================================================
local function getCoreParts(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local rig = hum and hum.RigType or Enum.HumanoidRigType.R15

	if rig == Enum.HumanoidRigType.R15 then
		return {
			char:FindFirstChild("HumanoidRootPart"),
			char:FindFirstChild("LowerTorso"),
			char:FindFirstChild("UpperTorso"),
			char:FindFirstChild("Head"),
		}
	else
		return {
			char:FindFirstChild("HumanoidRootPart"),
			char:FindFirstChild("Torso"),
			char:FindFirstChild("Head"),
		}
	end
end

local function getStable2DBox(char, pad)
	local parts = getCoreParts(char)

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local anyOn = false

	for _, part in ipairs(parts) do
		if part and part:IsA("BasePart") then
			local cf = part.CFrame
			local s = part.Size

			local corners = {
				(cf * CFrame.new( s.X/2,  s.Y/2,  s.Z/2)).Position,
				(cf * CFrame.new( s.X/2,  s.Y/2, -s.Z/2)).Position,
				(cf * CFrame.new( s.X/2, -s.Y/2,  s.Z/2)).Position,
				(cf * CFrame.new( s.X/2, -s.Y/2, -s.Z/2)).Position,
				(cf * CFrame.new(-s.X/2,  s.Y/2,  s.Z/2)).Position,
				(cf * CFrame.new(-s.X/2,  s.Y/2, -s.Z/2)).Position,
				(cf * CFrame.new(-s.X/2, -s.Y/2,  s.Z/2)).Position,
				(cf * CFrame.new(-s.X/2, -s.Y/2, -s.Z/2)).Position,
			}

			for _, p in ipairs(corners) do
				local v2, on, z = w2s(p)
				if on and z > 0 then anyOn = true end
				minX = math.min(minX, v2.X)
				minY = math.min(minY, v2.Y)
				maxX = math.max(maxX, v2.X)
				maxY = math.max(maxY, v2.Y)
			end
		end
	end

	if not anyOn then return nil end
	return (minX - pad), (minY - pad), (maxX + pad), (maxY + pad)
end

--// Per-player UI
local ui = {} -- [Player] = {Holder, BoxFrame, BoxStroke, DistLabel, Lines[1..20], Smooth={x1,y1,x2,y2}}

local function ensureUI(plr)
	if plr == LocalPlayer then return nil end
	if ui[plr] then return ui[plr] end

	local holder = Instance.new("Folder")
	holder.Name = "ESP_" .. plr.Name
	holder.Parent = screenGui

	-- 2D Box outline
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.Visible = false
	box.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = ESP.Box.Thickness
	stroke.Color = ESP.Box.Color
	stroke.Parent = box

	-- Distance text (над боксом)
	local dist = Instance.new("TextLabel")
	dist.Name = "Distance"
	dist.BackgroundTransparency = 1
	dist.AnchorPoint = Vector2.new(0.5, 1)
	dist.Size = UDim2.fromOffset(240, 30)
	dist.Visible = false
	dist.Font = Enum.Font.GothamSemibold
	dist.TextStrokeTransparency = 0.35
	dist.TextScaled = false
	dist.TextSize = ESP.DistanceText.Size
	dist.TextColor3 = ESP.DistanceText.Color
	dist.Text = ""
	dist.Parent = holder

	-- Skeleton lines
	local lines = {}
	for i = 1, 24 do
		lines[i] = makeLine(holder)
	end

	ui[plr] = {
		Holder = holder,
		BoxFrame = box,
		BoxStroke = stroke,
		DistLabel = dist,
		Lines = lines,
		Smooth = nil, -- set on first frame
	}
	return ui[plr]
end

local function removeUI(plr)
	local e = ui[plr]
	if e then
		e.Holder:Destroy()
		ui[plr] = nil
	end
end

Players.PlayerRemoving:Connect(removeUI)

--// Update
local function updatePlayer(plr)
	local e = ensureUI(plr)
	if not e then return end

	-- reset
	e.BoxFrame.Visible = false
	e.DistLabel.Visible = false
	for _, ln in ipairs(e.Lines) do ln.Visible = false end

	if not ESP.Enabled then return end

	local distStuds = getDistanceStuds(plr)
	if not distStuds or distStuds > ESP.MaxDistanceStuds then return end

	local char = plr.Character
	if not char then return end

	--====================================================
	-- FIXED BOX: вместо char:GetBoundingBox() (раздувается при ударах)
	--====================================================
	local pad = ESP.BoxPadding
	local x1, y1, x2, y2 = getStable2DBox(char, pad)
	if not x1 then return end

	-- Smooth box to be “static”
	if not e.Smooth then
		e.Smooth = {x1=x1,y1=y1,x2=x2,y2=y2}
	else
		local a = ESP.SmoothAlpha
		e.Smooth.x1 = e.Smooth.x1 + (x1 - e.Smooth.x1) * a
		e.Smooth.y1 = e.Smooth.y1 + (y1 - e.Smooth.y1) * a
		e.Smooth.x2 = e.Smooth.x2 + (x2 - e.Smooth.x2) * a
		e.Smooth.y2 = e.Smooth.y2 + (y2 - e.Smooth.y2) * a
	end

	local sx1, sy1, sx2, sy2 = e.Smooth.x1, e.Smooth.y1, e.Smooth.x2, e.Smooth.y2
	local w, h = (sx2 - sx1), (sy2 - sy1)

	-- BOX
	if ESP.Box.Enabled then
		e.BoxStroke.Thickness = ESP.Box.Thickness
		e.BoxStroke.Color = ESP.Box.Color
		e.BoxFrame.Position = UDim2.fromOffset(sx1, sy1)
		e.BoxFrame.Size = UDim2.fromOffset(w, h)
		e.BoxFrame.Visible = true
	end

	-- DISTANCE (meters)
	if ESP.DistanceText.Enabled then
		local meters = distStuds * ESP.StudToMeter
		e.DistLabel.TextSize = ESP.DistanceText.Size
		e.DistLabel.TextColor3 = ESP.DistanceText.Color
		e.DistLabel.Text = string.format("%dm", math.floor(meters + 0.5))
		e.DistLabel.Position = UDim2.fromOffset(sx1 + w/2, sy1 - 2)
		e.DistLabel.Visible = true
	end

	-- SKELETON
	if ESP.Skeleton.Enabled then
		local pairs = getRigPairs(char)
		local idx = 1
		for _, pr in ipairs(pairs) do
			local aPart = char:FindFirstChild(pr[1])
			local bPart = char:FindFirstChild(pr[2])
			local line = e.Lines[idx]
			if line then
				if aPart and bPart then
					local a2, aon, az = w2s(aPart.Position)
					local b2, bon, bz = w2s(bPart.Position)
					if aon and bon and az > 0 and bz > 0 then
						setLine(line, a2, b2, ESP.Skeleton.Thickness, ESP.Skeleton.Color)
					else
						line.Visible = false
					end
				else
					line.Visible = false
				end
			end
			idx += 1
		end
	end
end

RunService.RenderStepped:Connect(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			updatePlayer(plr)
		end
	end
end)

--// RAYFIELD UI
local VisualTab = Window:CreateTab("Visuals", 4483362458)

VisualTab:CreateToggle({
	Name = "ESP Enabled",
	CurrentValue = false,
	Flag = "ESP_Enabled",
	Callback = function(v) ESP.Enabled = v end,
})

-- BOX controls
VisualTab:CreateToggle({
	Name = "Box (2D Outline)",
	CurrentValue = true,
	Flag = "ESP_BoxOn",
	Callback = function(v) ESP.Box.Enabled = v end,
})

VisualTab:CreateSlider({
	Name = "Box Thickness",
	Range = {1, 6},
	Increment = 1,
	Suffix = " px",
	CurrentValue = ESP.Box.Thickness,
	Flag = "ESP_BoxThick",
	Callback = function(v) ESP.Box.Thickness = v end,
})

VisualTab:CreateColorPicker({
	Name = "Box Color",
	Color = ESP.Box.Color,
	Flag = "ESP_BoxColor",
	Callback = function(c) ESP.Box.Color = c end,
})

-- SKELETON controls
VisualTab:CreateToggle({
	Name = "Skeleton",
	CurrentValue = true,
	Flag = "ESP_SkelOn",
	Callback = function(v) ESP.Skeleton.Enabled = v end,
})

VisualTab:CreateSlider({
	Name = "Skeleton Thickness",
	Range = {1, 6},
	Increment = 1,
	Suffix = " px",
	CurrentValue = ESP.Skeleton.Thickness,
	Flag = "ESP_SkelThick",
	Callback = function(v) ESP.Skeleton.Thickness = v end,
})

VisualTab:CreateColorPicker({
	Name = "Skeleton Color",
	Color = ESP.Skeleton.Color,
	Flag = "ESP_SkelColor",
	Callback = function(c) ESP.Skeleton.Color = c end,
})

-- DISTANCE controls
VisualTab:CreateToggle({
	Name = "Distance (meters)",
	CurrentValue = true,
	Flag = "ESP_DistOn",
	Callback = function(v) ESP.DistanceText.Enabled = v end,
})

VisualTab:CreateSlider({
	Name = "Distance Text Size",
	Range = {10, 30},
	Increment = 1,
	Suffix = " px",
	CurrentValue = ESP.DistanceText.Size,
	Flag = "ESP_DistSize",
	Callback = function(v) ESP.DistanceText.Size = v end,
})

VisualTab:CreateColorPicker({
	Name = "Distance Text Color",
	Color = ESP.DistanceText.Color,
	Flag = "ESP_DistColor",
	Callback = function(c) ESP.DistanceText.Color = c end,
})

-- Global controls
VisualTab:CreateSlider({
	Name = "Max Distance",
	Range = {100, 5000},
	Increment = 50,
	Suffix = " studs",
	CurrentValue = ESP.MaxDistanceStuds,
	Flag = "ESP_MaxDist",
	Callback = function(v) ESP.MaxDistanceStuds = v end,
})

VisualTab:CreateSlider({
	Name = "Stud → Meter (multiplier)",
	Range = {0.10, 0.50},
	Increment = 0.01,
	Suffix = " m/stud",
	CurrentValue = ESP.StudToMeter,
	Flag = "ESP_StudToM",
	Callback = function(v) ESP.StudToMeter = v end,
})

VisualTab:CreateSlider({
	Name = "Box Smoothness",
	Range = {0.05, 0.90},
	Increment = 0.05,
	Suffix = "",
	CurrentValue = ESP.SmoothAlpha,
	Flag = "ESP_Smooth",
	Callback = function(v) ESP.SmoothAlpha = v end,
})

--// MOVEMENT (Rayfield) — Enable + Speed + Jump
local MovementTab = Window:CreateTab("Movement", 4483362458)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Move = {
	Enabled = false,
	Speed = 16,
	Jump = 50, -- JumpPower (если UseJumpPower=true) иначе будет конверт в JumpHeight
}

local function getHumanoid()
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function applyMovement()
	if not Move.Enabled then return end
	local hum = getHumanoid()
	if not hum then return end

	hum.WalkSpeed = Move.Speed

	if hum.UseJumpPower then
		hum.JumpPower = Move.Jump
	else
		-- если проект использует JumpHeight, делаем простую конверсию
		hum.JumpHeight = math.clamp(Move.Jump / 7, 2, 50)
	end
end

-- Применять после респавна
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.2)
	applyMovement()
end)

-- Принудительно удерживать значения (если другие скрипты их сбрасывают)
RunService.RenderStepped:Connect(function()
	applyMovement()
end)

-- UI
MovementTab:CreateToggle({
	Name = "Movement Enabled",
	CurrentValue = false,
	Flag = "MOV_Enabled",
	Callback = function(v)
		Move.Enabled = v

		-- если выключили — вернём дефолты (можешь поменять)
		if not v then
			local hum = getHumanoid()
			if hum then
				hum.WalkSpeed = 16
				if hum.UseJumpPower then
					hum.JumpPower = 50
				else
					hum.JumpHeight = 7.2
				end
			end
		else
			applyMovement()
		end
	end,
})

MovementTab:CreateSlider({
	Name = "WalkSpeed",
	Range = {8, 100},
	Increment = 1,
	Suffix = " spd",
	CurrentValue = Move.Speed,
	Flag = "MOV_Speed",
	Callback = function(v)
		Move.Speed = v
		applyMovement()
	end,
})

MovementTab:CreateSlider({
	Name = "Jump (Power)",
	Range = {10, 200},
	Increment = 1,
	Suffix = " jmp",
	CurrentValue = Move.Jump,
	Flag = "MOV_Jump",
	Callback = function(v)
		Move.Jump = v
		applyMovement()
	end,
})

MovementTab:CreateButton({
	Name = "Reset Speed/Jump",
	Callback = function()
		Move.Speed = 16
		Move.Jump = 50
		applyMovement()
	end,
})

-- Необходимые переменные (должны быть определены в основном скрипте)
local rs = game:GetService("ReplicatedStorage")
local packets = require(rs.Modules.Packets)
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")
local runs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- Константы для анимации и оружия
local SLASH_ID = 10761451679
local GOD_ROCK_ID = 368

-- Функция для чтения ID из инстанса
local function readIdFrom(inst)
    if not inst then return nil end
    if inst.GetAttribute then
        for _, k in ipairs({"ItemID", "itemID", "Id", "id"}) do
            local v = inst:GetAttribute(k)
            local n = tonumber(v)
            if n then return n end
        end
    end
    if inst:IsA("NumberValue") or inst:IsA("IntValue") then
        return tonumber(inst.Value)
    elseif inst:IsA("StringValue") then
        return tonumber(inst.Value)
    end
    return nil
end

-- Функция для получения текущего оружия
local function currentWeapon()
    local ch = plr.Character
    if not ch then return nil, nil end
    
    for _, t in ipairs(ch:GetChildren()) do
        if t:IsA("Tool") then
            local id = readIdFrom(t)
            if not id then
                for _, d in ipairs(t:GetDescendants()) do
                    id = readIdFrom(d)
                    if id then break end
                end
            end
            return t, id
        end
    end
    
    for _, d in ipairs(ch:GetDescendants()) do
        local id = readIdFrom(d)
        if id then return d, id end
        local n = (d.Name or ""):lower()
        if n:find("god", 1, true) and n:find("rock", 1, true) then
            return d, GOD_ROCK_ID
        end
    end
    return nil, nil
end

-- Функция для проверки God Rock
local function isGodRockEquipped()
    local inst, id = currentWeapon()
    if id == GOD_ROCK_ID then return true, inst end
    if inst and inst.Name then
        local n = inst.Name:lower()
        if n:find("god", 1, true) and n:find("rock", 1, true) then
            return true, inst
        end
    end
    return false, inst
end

-- Функция для атаки
local function swingtool(targets)
    if packets.SwingTool and packets.SwingTool.send then
        packets.SwingTool.send(targets)
    end
end

-- Создание вкладки Combat
local CombatTab = Window:CreateTab("Combat", 4483362458) -- Иконка топора

-- Переменные для Kill Aura
local killAuraEnabled = false
local killAuraRange = 5
local killAuraMaxTargets = 1
local killAuraCooldown = 0.1
local killAuraOnlyGod = true

-- Переменные для анимации
local animator, slashTrack
local animAllow = true
local swingBusy = false
local queued = false
local nextAllowedAt = 0
local animLenGuess = 0.60
local animEnabled = true
local animSpeed = 1.15
local animBlendIn = 0.10
local animMinGap = 0.10

-- Функции для работы с анимацией (определяем ДО использования в UI)
local function refreshAnimator()
    local currentHum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if currentHum then
        animator = currentHum:FindFirstChildOfClass("Animator") or Instance.new("Animator", currentHum)
        slashTrack = nil
    end
end

local function ensureSlashTrack(id)
    if not animator then
        refreshAnimator()
    end
    if animator and not slashTrack then
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. tostring(id or SLASH_ID)
        local ok
        ok, slashTrack = pcall(function()
            return animator:LoadAnimation(a)
        end)
        if not ok then
            slashTrack = nil
            return
        end
        slashTrack.Priority = Enum.AnimationPriority.Action
        slashTrack.Looped = false
    end
end

local function stopSlashSafe(fade)
    if slashTrack then
        pcall(function()
            slashTrack:Stop(fade or 0)
        end)
    end
    swingBusy = false
    queued = false
end

local function playSlashOnce()
    if not animEnabled or not animAllow then return end
    if killAuraOnlyGod and not isGodRockEquipped() then
        stopSlashSafe(0)
        nextAllowedAt = tick()
        return
    end
    
    ensureSlashTrack(SLASH_ID)
    if not slashTrack then return end
    
    local now = tick()
    if now < nextAllowedAt or swingBusy then
        queued = true
        return
    end
    
    swingBusy = true
    queued = false
    
    local blendIn = animBlendIn or 0.10
    local speed = animSpeed or 1.15
    
    pcall(function()
        slashTrack:Play(blendIn, 1, speed)
    end)
    
    task.defer(function()
        if slashTrack then
            local len = tonumber(slashTrack.Length)
            if len and len > 0.01 then
                animLenGuess = len / math.max(speed, 0.01)
            end
        end
    end)
    
    local minGap = animMinGap or 0.10
    local guess = animLenGuess or 0.60
    nextAllowedAt = now + math.max(minGap, guess * 0.70)
    
    slashTrack.Stopped:Once(function()
        swingBusy = false
        if queued and animAllow and animEnabled then
            queued = false
            local t = tick()
            if t < nextAllowedAt then
                task.delay(nextAllowedAt - t, playSlashOnce)
            else
                playSlashOnce()
            end
        end
    end)
end

-- Kill Aura Toggle
local KillAuraToggle = CombatTab:CreateToggle({
    Name = "Kill Aura",
    CurrentValue = false,
    Flag = "KillAuraToggle",
    Callback = function(Value)
        killAuraEnabled = Value
    end,
})

-- Kill Aura Range Slider
local KillAuraRange = CombatTab:CreateSlider({
    Name = "Range",
    Range = {1, 9},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "KillAuraRange",
    Callback = function(Value)
        killAuraRange = Value
    end,
})

-- Max Targets Dropdown
local KillAuraMaxTargets = CombatTab:CreateDropdown({
    Name = "Max Targets",
    Options = {"1", "2", "3", "4", "5", "6"},
    CurrentOption = "1",
    Flag = "KillAuraMaxTargets",
    Callback = function(Option)
        killAuraMaxTargets = tonumber(Option) or 1
    end,
})

-- Attack Cooldown Slider
local KillAuraCooldown = CombatTab:CreateSlider({
    Name = "Attack Cooldown",
    Range = {0.01, 1.01},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.1,
    Flag = "KillAuraCooldown",
    Callback = function(Value)
        killAuraCooldown = Value
    end,
})

-- Only God Rock Toggle
local KillAuraOnlyGod = CombatTab:CreateToggle({
    Name = "Only with God Rock (ID 368)",
    CurrentValue = true,
    Flag = "KillAuraOnlyGod",
    Callback = function(Value)
        killAuraOnlyGod = Value
    end,
})

-- ===================== Target Hub (HUD + Viewport) =====================
local targetHubEnabled = false
local targetHubViewportEnabled = true
local currentTargetInfo = nil -- { player: Player, rootpart: BasePart, entityid: any, dist: number }

local targetHubGui, targetHubFrame, targetHubHeader, targetHubLabel, targetHubHpLabel, targetHubDistLabel
local targetHubHpBarBG, targetHubHpBarFill
local targetHubAvatar
local targetHubViewport, targetHubWorld, targetHubCam
local targetHubMinimized = false
local thumbCache = {} -- [userId] = image
local targetHubClone = nil
local lastTargetUserId = nil
local viewportUpdateAcc = 0

local function getUiParent()
    -- exploit-friendly: gethui() если есть, иначе CoreGui
    local ok, hui = pcall(function() return gethui() end)
    if ok and typeof(hui) == "Instance" then
        return hui
    end
    return game:GetService("CoreGui")
end

local function destroyTargetClone()
    if targetHubClone then
        pcall(function() targetHubClone:Destroy() end)
        targetHubClone = nil
    end
end

local function ensureTargetHub()
    if targetHubGui and targetHubGui.Parent then return end

    local parent = getUiParent()
    local gui = Instance.new("ScreenGui")
    gui.Name = "_TargetHub"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    pcall(function() gui.Parent = parent end)
    targetHubGui = gui

    local frame = Instance.new("Frame")
    frame.Name = "Container"
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Position = UDim2.fromOffset(12, 12)
    frame.Size = UDim2.fromOffset(240, 64) -- по умолчанию компакт
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Parent = gui
    targetHubFrame = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.25
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Parent = frame

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 10)
    uiCorner.Parent = frame

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.65
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Size = UDim2.new(1, 24, 1, 24)
    shadow.Position = UDim2.fromOffset(-12, -12)
    shadow.ZIndex = -1
    shadow.Parent = frame

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 30)
    header.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    header.BackgroundTransparency = 0.0
    header.BorderSizePixel = 0
    header.Parent = frame
    targetHubHeader = header

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    local headerCover = Instance.new("Frame")
    headerCover.Name = "HeaderCover"
    headerCover.Size = UDim2.new(1, 0, 0, 10)
    headerCover.Position = UDim2.new(0, 0, 1, -10)
    headerCover.BackgroundColor3 = header.BackgroundColor3
    headerCover.BorderSizePixel = 0
    headerCover.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(10, 0)
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Target Hub"
    title.Parent = header

    local minBtn = Instance.new("TextButton")
    minBtn.Name = "Minimize"
    minBtn.Size = UDim2.fromOffset(26, 20)
    minBtn.Position = UDim2.new(1, -32, 0, 5)
    minBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    minBtn.BorderSizePixel = 0
    minBtn.Font = Enum.Font.GothamSemibold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    minBtn.Text = "–"
    minBtn.Parent = header
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn
    minBtn.MouseButton1Click:Connect(function()
        targetHubMinimized = not targetHubMinimized
        if targetHubViewport then
            targetHubViewport.Visible = (not targetHubMinimized) and targetHubViewportEnabled
        end
        if targetHubHpBarBG then
            targetHubHpBarBG.Visible = not targetHubMinimized
        end
    end)

    -- Avatar (как на скрине)
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    avatar.BackgroundTransparency = 0
    avatar.BorderSizePixel = 0
    avatar.Size = UDim2.fromOffset(34, 34)
    avatar.Position = UDim2.fromOffset(10, 36)
    avatar.Image = ""
    avatar.ScaleType = Enum.ScaleType.Crop
    avatar.Parent = frame
    targetHubAvatar = avatar
    local aCorner = Instance.new("UICorner")
    aCorner.CornerRadius = UDim.new(0, 8)
    aCorner.Parent = avatar

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -58, 0, 18)
    label.Position = UDim2.fromOffset(50, 34)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = "Target: none"
    label.Parent = frame
    targetHubLabel = label

    local hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "HPLabel"
    hpLabel.Size = UDim2.new(1, -58, 0, 16)
    hpLabel.Position = UDim2.fromOffset(50, 52)
    hpLabel.BackgroundTransparency = 1
    hpLabel.Font = Enum.Font.Gotham
    hpLabel.TextSize = 12
    hpLabel.TextXAlignment = Enum.TextXAlignment.Left
    hpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    hpLabel.Text = "HP: -"
    hpLabel.Parent = frame
    targetHubHpLabel = hpLabel

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, -58, 0, 16)
    distLabel.Position = UDim2.fromOffset(50, 68)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12
    distLabel.TextXAlignment = Enum.TextXAlignment.Left
    distLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    distLabel.Text = "Dist: -"
    distLabel.Parent = frame
    targetHubDistLabel = distLabel

    local hpBarBG = Instance.new("Frame")
    hpBarBG.Name = "HPBarBG"
    hpBarBG.Size = UDim2.new(1, -58, 0, 8)
    hpBarBG.Position = UDim2.fromOffset(50, 86)
    hpBarBG.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    hpBarBG.BorderSizePixel = 0
    hpBarBG.Parent = frame
    targetHubHpBarBG = hpBarBG
    local hpBgCorner = Instance.new("UICorner")
    hpBgCorner.CornerRadius = UDim.new(0, 6)
    hpBgCorner.Parent = hpBarBG

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HPBarFill"
    hpFill.Size = UDim2.new(0, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 220, 120)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBarBG
    targetHubHpBarFill = hpFill
    local hpFillCorner = Instance.new("UICorner")
    hpFillCorner.CornerRadius = UDim.new(0, 6)
    hpFillCorner.Parent = hpFill

    local vp = Instance.new("ViewportFrame")
    vp.Name = "Viewport"
    vp.Size = UDim2.new(1, -20, 0, 40)
    vp.Position = UDim2.fromOffset(10, 108) -- будет включаться/выключаться
    vp.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    vp.BackgroundTransparency = 0.15
    vp.BorderSizePixel = 0
    vp.Parent = frame
    targetHubViewport = vp

    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 10)
    corner2.Parent = vp

    local world = Instance.new("WorldModel")
    world.Parent = vp
    targetHubWorld = world

    local cam = Instance.new("Camera")
    cam.Parent = vp
    vp.CurrentCamera = cam
    targetHubCam = cam

    -- Drag & drop (двигать окно) — как на скрине, за header
    local dragging = false
    local dragStartPos, startFramePos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStartPos = input.Position
            startFramePos = frame.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    uis.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStartPos
        frame.Position = UDim2.new(startFramePos.X.Scale, startFramePos.X.Offset + delta.X, startFramePos.Y.Scale, startFramePos.Y.Offset + delta.Y)
    end)
end

local function applyTargetHubLayout()
    if not targetHubFrame then return end
    local showViewport = targetHubViewportEnabled and (not targetHubMinimized)
    if showViewport then
        targetHubFrame.Size = UDim2.fromOffset(240, 140)
        if targetHubViewport then
            targetHubViewport.Position = UDim2.fromOffset(10, 98)
            targetHubViewport.Size = UDim2.new(1, -20, 1, -108)
            targetHubViewport.Visible = true
        end
    else
        targetHubFrame.Size = UDim2.fromOffset(240, 64)
        if targetHubViewport then targetHubViewport.Visible = false end
    end
end

local function setTargetHubVisible(v)
    if not targetHubGui or not targetHubGui.Parent then return end
    targetHubGui.Enabled = v and true or false
end

local function updateTargetHubLabel()
    if not targetHubLabel then return end
    if not currentTargetInfo or not currentTargetInfo.player then
        targetHubLabel.Text = "Target: none"
        if targetHubHpLabel then targetHubHpLabel.Text = "HP: -" end
        if targetHubDistLabel then targetHubDistLabel.Text = "Dist: -" end
        if targetHubHpBarFill then targetHubHpBarFill.Size = UDim2.new(0, 0, 1, 0) end
        if targetHubAvatar then targetHubAvatar.Image = "" end
        return
    end
    local name = currentTargetInfo.player.Name or "?"
    local d = tonumber(currentTargetInfo.dist) or 0
    targetHubLabel.Text = ("Target: %s"):format(name)
    if targetHubDistLabel then
        targetHubDistLabel.Text = ("Dist: %.1f"):format(d)
    end
    if targetHubHpLabel then
        local hp = tonumber(currentTargetInfo.hp)
        local mhp = tonumber(currentTargetInfo.maxhp)
        if hp and mhp then
            targetHubHpLabel.Text = ("HP: %.0f / %.0f"):format(hp, mhp)
            if targetHubHpBarFill then
                local pct = math.clamp(hp / math.max(mhp, 1), 0, 1)
                targetHubHpBarFill.Size = UDim2.new(pct, 0, 1, 0)
                -- зелёный -> красный
                targetHubHpBarFill.BackgroundColor3 = Color3.fromRGB(
                    math.floor(255 * (1 - pct)),
                    math.floor(220 * pct),
                    80
                )
            end
        else
            targetHubHpLabel.Text = "HP: -"
            if targetHubHpBarFill then targetHubHpBarFill.Size = UDim2.new(0, 0, 1, 0) end
        end
    end

    -- аватарка
    if targetHubAvatar and currentTargetInfo.player.UserId then
        local uid = currentTargetInfo.player.UserId
        local img = thumbCache[uid]
        if not img then
            pcall(function()
                local t, _ = Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                img = t
                thumbCache[uid] = img
            end)
        end
        if img then
            targetHubAvatar.Image = img
        end
    end
end

local function refreshViewportClone()
    if not targetHubViewportEnabled then
        destroyTargetClone()
        return
    end
    if not targetHubWorld then return end
    if not currentTargetInfo or not currentTargetInfo.player then
        destroyTargetClone()
        return
    end

    local uid = currentTargetInfo.player.UserId
    if uid == lastTargetUserId and targetHubClone and targetHubClone.Parent then
        return
    end
    lastTargetUserId = uid

    destroyTargetClone()
    pcall(function()
        local model = (workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(currentTargetInfo.player.Name))
            or currentTargetInfo.player.Character
        if not model or not model:IsA("Model") then return end
        model.Archivable = true
        local clone = model:Clone()
        clone.Parent = targetHubWorld
        targetHubClone = clone
    end)
end

local function updateViewportCamera()
    if not targetHubViewportEnabled then return end
    if not targetHubCam or not targetHubClone or not targetHubClone.Parent then return end

    local hrp = targetHubClone:FindFirstChild("HumanoidRootPart") or targetHubClone:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    -- боковой вид как в примере
    local look = hrp.CFrame.LookVector
    local right = hrp.CFrame.RightVector
    local camPos = hrp.Position + (look * 6) + Vector3.new(0, 2, 0) + (right * 2)
    targetHubCam.CFrame = CFrame.new(camPos, hrp.Position)
end

-- Обновление хаба (не каждый кадр, чтобы не лагало)
runs.RenderStepped:Connect(function(dt)
    if not targetHubEnabled then
        if targetHubGui and targetHubGui.Parent then
            setTargetHubVisible(false)
        end
        return
    end

    ensureTargetHub()
    setTargetHubVisible(true)
    applyTargetHubLayout()
    updateTargetHubLabel()

    if not targetHubViewportEnabled then
        if targetHubViewport then targetHubViewport.Visible = false end
        destroyTargetClone()
        return
    end
    if targetHubViewport then targetHubViewport.Visible = true end

    viewportUpdateAcc += (dt or 0)
    if viewportUpdateAcc < 0.08 then return end -- ~12 FPS
    viewportUpdateAcc = 0

    refreshViewportClone()
    updateViewportCamera()
end)

CombatTab:CreateToggle({
    Name = "Target Hub (show current target)",
    CurrentValue = false,
    Flag = "TargetHubToggle",
    Callback = function(v)
        targetHubEnabled = v
        if not v then
            currentTargetInfo = nil
            lastTargetUserId = nil
            destroyTargetClone()
        end
    end,
})

CombatTab:CreateToggle({
    Name = "Target Hub Viewport",
    CurrentValue = true,
    Flag = "TargetHubViewportToggle",
    Callback = function(v)
        targetHubViewportEnabled = v
        if not v then destroyTargetClone() end
    end,
})

-- Swing Animation Toggle
local SwingAnimationToggle = CombatTab:CreateToggle({
    Name = "Swing Animation",
    CurrentValue = true,
    Flag = "SwingAnimationToggle",
    Callback = function(Value)
        animEnabled = Value
        animAllow = Value
        if not Value then
            stopSlashSafe(0.06)
        end
    end,
})

-- Animation Speed Slider
local AnimationSpeed = CombatTab:CreateSlider({
    Name = "Anim Speed",
    Range = {0.4, 2.2},
    Increment = 0.01,
    Suffix = "x",
    CurrentValue = 1.15,
    Flag = "AnimationSpeed",
    Callback = function(Value)
        animSpeed = Value
        if slashTrack and slashTrack.IsPlaying then
            pcall(function()
                slashTrack:AdjustSpeed(Value)
            end)
        end
    end,
})

-- Blend-in Slider
local AnimationBlendIn = CombatTab:CreateSlider({
    Name = "Blend-in",
    Range = {0.00, 0.25},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.10,
    Flag = "AnimationBlendIn",
    Callback = function(Value)
        animBlendIn = Value
    end,
})

-- Min Gap Between Swings Slider
local AnimationMinGap = CombatTab:CreateSlider({
    Name = "Min gap between swings",
    Range = {0.10, 1.00},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.10,
    Flag = "AnimationMinGap",
    Callback = function(Value)
        animMinGap = Value
    end,
})

-- Обработка респавна персонажа
plr.CharacterAdded:Connect(function()
    task.defer(function()
        animAllow = false
        stopSlashSafe(0)
        refreshAnimator()
        task.wait(0.05)
        animAllow = true
        char = plr.Character
        if char then
            root = char:WaitForChild("HumanoidRootPart")
            hum = char:WaitForChild("Humanoid")
        end
    end)
end)

-- Kill Aura Logic
task.spawn(function()
    while true do
        if not killAuraEnabled then
            task.wait(0.1)
            continue
        end

        -- Проверка God Rock
        if killAuraOnlyGod and not isGodRockEquipped() then
            stopSlashSafe(0)
            nextAllowedAt = tick()
            task.wait(killAuraCooldown)
            continue
        end

        -- Обновляем root при респавне
        if not root or not root.Parent then
            char = plr.Character or plr.CharacterAdded:Wait()
            root = char:WaitForChild("HumanoidRootPart")
            hum = char:WaitForChild("Humanoid")
        end

        local targets = {}

        for _, player in pairs(game.Players:GetPlayers()) do
            if player ~= plr then
                -- Не бить друзей Roblox
                local isFriend = false
                pcall(function()
                    if player.UserId then
                        isFriend = plr:IsFriendsWith(player.UserId)
                    end
                end)
                if isFriend then
                    continue
                end

                local playerfolder = workspace.Players:FindFirstChild(player.Name)
                if playerfolder then
                    local rootpart = playerfolder:FindFirstChild("HumanoidRootPart")
                    local entityid = playerfolder:GetAttribute("EntityID")

                    if rootpart and entityid and root then
                        local dist = (rootpart.Position - root.Position).Magnitude
                        if dist <= killAuraRange then
                            table.insert(targets, { eid = entityid, dist = dist, player = player, rootpart = rootpart })
                        end
                    end
                end
            end
        end

        if #targets > 0 then
            table.sort(targets, function(a, b)
                return a.dist < b.dist
            end)

            local selectedTargets = {}
            local maxTargets = killAuraMaxTargets or 1
            for i = 1, math.min(maxTargets, #targets) do
                table.insert(selectedTargets, targets[i].eid)
            end

            -- Target Hub: текущая цель = ближайшая
            if targetHubEnabled and targets[1] then
                local hp, maxhp
                pcall(function()
                    -- пытаемся взять Humanoid из workspace.Players/<Name>
                    local folder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(targets[1].player.Name)
                    local h = folder and folder:FindFirstChildOfClass("Humanoid")
                    if not h and folder then
                        h = folder:FindFirstChild("Humanoid")
                    end
                    if not h and targets[1].player.Character then
                        h = targets[1].player.Character:FindFirstChildOfClass("Humanoid")
                    end
                    if h then
                        hp = h.Health
                        maxhp = h.MaxHealth
                    end
                end)
                currentTargetInfo = {
                    player = targets[1].player,
                    rootpart = targets[1].rootpart,
                    entityid = targets[1].eid,
                    dist = targets[1].dist,
                    hp = hp,
                    maxhp = maxhp,
                }
            elseif targetHubEnabled then
                currentTargetInfo = nil
            end

            -- Проигрываем анимацию перед атакой
            playSlashOnce()
            swingtool(selectedTargets)
        end

        task.wait(killAuraCooldown)
    end
end)

-- Инициализация аниматора при загрузке
task.defer(function()
    refreshAnimator()
end)


-- ===================== AUTO PICKUP & AUTO DROP (Rayfield UI) =====================

-- Необходимые переменные (должны быть определены в основном скрипте)
local rs = game:GetService("ReplicatedStorage")
local packets = require(rs.Modules.Packets)
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local runs = game:GetService("RunService")

-- Функция для подбора предметов (точная копия из оригинального скрипта)
local function pickup(entityid)
    if packets.Pickup and packets.Pickup.send then
        packets.Pickup.send(entityid)
    end
end

-- Функция для выбрасывания предмета (точная копия из оригинального скрипта)
local function drop(itemname)
    local inventory = game:GetService("Players").LocalPlayer.PlayerGui.MainGui.RightPanel.Inventory:FindFirstChild("List")
    if not inventory then return end

    for _, child in ipairs(inventory:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemname then
            if packets and packets.DropBagItem and packets.DropBagItem.send then
                packets.DropBagItem.send(child.LayoutOrder)
            end
        end
    end
end

-- Создание вкладки Pickup
local PickupTab = Window:CreateTab("Pickup", 4483362458) -- Иконка рюкзака

-- Переменные для Auto Pickup
local autoPickupEnabled = false
local chestPickupEnabled = false
local pickupRange = 20
local selecteditems = {}

-- Переменные для Auto Drop
local autoDropEnabled = false
local autoDropCustomEnabled = false
local dropItem = "Bloodfruit"
local customDropItem = "Bloodfruit"
local dropDebounce = 0
local dropCooldown = 0

-- Auto Pickup Toggle
local AutoPickupToggle = PickupTab:CreateToggle({
    Name = "Auto Pickup",
    CurrentValue = false,
    Flag = "AutoPickupToggle",
    Callback = function(Value)
        autoPickupEnabled = Value
    end,
})

-- Auto Pickup From Chests Toggle
local ChestPickupToggle = PickupTab:CreateToggle({
    Name = "Auto Pickup From Chests",
    CurrentValue = false,
    Flag = "ChestPickupToggle",
    Callback = function(Value)
        chestPickupEnabled = Value
    end,
})

-- Pickup Range Slider
local PickupRangeSlider = PickupTab:CreateSlider({
    Name = "Pickup Range",
    Range = {1, 35},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 20,
    Flag = "PickupRange",
    Callback = function(Value)
        pickupRange = Value
    end,
})

-- Items Dropdown (Multi-select) - точная копия логики из оригинального скрипта
local ItemsDropdown = PickupTab:CreateDropdown({
    Name = "Items",
    Options = {"Berry", "Bloodfruit", "Bluefruit", "Lemon", "Strawberry", "Gold", "Raw Gold", "Crystal Chunk", "Coin", "Coins", "Coin2", "Coin Stack", "Essence", "Emerald", "Raw Emerald", "Pink Diamond", "Raw Pink Diamond", "Void Shard", "Jelly", "Magnetite", "Raw Magnetite", "Adurite", "Raw Adurite", "Ice Cube", "Stone", "Iron", "Raw Iron", "Steel", "Hide", "Leaves", "Log", "Wood", "Pie"},
    CurrentOption = {"Leaves", "Log"},
    Flag = "ItemsDropdown",
    Callback = function(Value)
        -- Точная копия логики из оригинального скрипта
        selecteditems = {}
        if type(Value) == "table" then
            -- Проверяем, это таблица с булевыми значениями (как в оригинале) или массив строк
            local isArray = false
            for k, v in pairs(Value) do
                if type(k) == "number" then
                    isArray = true
                    break
                end
            end
            
            if isArray then
                -- Это массив строк
                for _, item in ipairs(Value) do
                    table.insert(selecteditems, item)
                end
            else
                -- Это таблица с булевыми значениями (как в оригинале)
                for item, State in pairs(Value) do
                    if State then
                        table.insert(selecteditems, item)
                    end
                end
            end
        else
            -- Если это строка, добавляем её
            if Value then
                table.insert(selecteditems, Value)
            end
        end
    end,
})

-- Инициализация выбранных предметов по умолчанию (как в оригинале: Leaves и Log)
selecteditems = {"Leaves", "Log"}

-- Auto Drop Toggle
local AutoDropToggle = PickupTab:CreateToggle({
    Name = "Auto Drop",
    CurrentValue = false,
    Flag = "AutoDropToggle",
    Callback = function(Value)
        autoDropEnabled = Value
    end,
})

-- Drop Item Dropdown
local DropItemDropdown = PickupTab:CreateDropdown({
    Name = "Select Item to Drop",
    Options = {"Bloodfruit", "Jelly", "Bluefruit", "Log", "Leaves", "Wood"},
    CurrentOption = "Bloodfruit",
    Flag = "DropItemDropdown",
    Callback = function(Option)
        dropItem = Option
    end,
})

-- Auto Drop Custom Toggle
local AutoDropCustomToggle = PickupTab:CreateToggle({
    Name = "Auto Drop Custom",
    CurrentValue = false,
    Flag = "AutoDropCustomToggle",
    Callback = function(Value)
        autoDropCustomEnabled = Value
    end,
})

-- Custom Drop Item Input
local CustomDropItemInput = PickupTab:CreateInput({
    Name = "Custom Item",
    PlaceholderText = "Bloodfruit",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        customDropItem = Text
    end,
})

-- Обработка респавна персонажа
local function onplradded(newChar)
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
end

plr.CharacterAdded:Connect(onplradded)

-- Auto Pickup Logic (точная копия логики из оригинального скрипта)
task.spawn(function()
    while true do
        -- Обновляем root при респавне
        if not root or not root.Parent then
            char = plr.Character or plr.CharacterAdded:Wait()
            root = char:WaitForChild("HumanoidRootPart")
        end

        local range = pickupRange or 35

        if autoPickupEnabled and root and #selecteditems > 0 then
            for _, item in ipairs(workspace.Items:GetChildren()) do
                if item:IsA("BasePart") or item:IsA("MeshPart") then
                    local selecteditem = item.Name
                    local entityid = item:GetAttribute("EntityID")

                    if entityid and table.find(selecteditems, selecteditem) then
                        local dist = (item.Position - root.Position).Magnitude
                        if dist <= range then
                            pickup(entityid)
                        end
                    end
                end
            end
        end

        if chestPickupEnabled and root and #selecteditems > 0 then
            for _, chest in ipairs(workspace.Deployables:GetChildren()) do
                if chest:IsA("Model") and chest:FindFirstChild("Contents") then
                    for _, item in ipairs(chest.Contents:GetChildren()) do
                        if item:IsA("BasePart") or item:IsA("MeshPart") then
                            local selecteditem = item.Name
                            local entityid = item:GetAttribute("EntityID")

                            if entityid and table.find(selecteditems, selecteditem) then
                                local dist = (chest.PrimaryPart.Position - root.Position).Magnitude
                                if dist <= range then
                                    pickup(entityid)
                                end
                            end
                        end
                    end
                end
            end
        end

        task.wait(0.01)
    end
end)

-- Auto Drop Logic (точная копия логики из оригинального скрипта)
runs.Heartbeat:Connect(function()
    if autoDropEnabled then
        if tick() - dropDebounce >= dropCooldown then
            local selectedItem = dropItem
            drop(selectedItem)
            dropDebounce = tick()
        end
    end
end)

runs.Heartbeat:Connect(function()
    if autoDropCustomEnabled then
        if tick() - dropDebounce >= dropCooldown then
            local itemname = customDropItem
            drop(itemname)
            dropDebounce = tick()
        end
    end
end)

-- ===================== AUTO HEAL (Rayfield UI) - AGGRESSIVE MODE =====================

print("[AutoHeal] Loading script...")

-- Необходимые переменные (должны быть определены в основном скрипте)
local rs = game:GetService("ReplicatedStorage")
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")
local runs = game:GetService("RunService")

-- ========= [ Packets (без ошибок, если модуля нет) ] =========
local packets do
    local ok, mod = pcall(function() return require(rs:WaitForChild("Modules"):WaitForChild("Packets")) end)
    packets = ok and mod or {}
end

-- ========= [ Общие инвентарь/еды (из оригинального Fluent скрипта) ] =========
function findInventoryList()
    local pg = plr:FindFirstChild("PlayerGui"); if not pg then return nil end
    local mg = pg:FindFirstChild("MainGui");    if not mg then return nil end
    local rp = mg:FindFirstChild("RightPanel"); if not rp then return nil end
    local inv = rp:FindFirstChild("Inventory"); if not inv then return nil end
    return inv:FindFirstChild("List")
end

function getSlotByName(itemName)
    local list = findInventoryList()
    if not list then return nil end
    for _,child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemName then
            return child.LayoutOrder
        end
    end
    return nil
end

function consumeBySlot(slot)
    if not slot then return false end
    if packets and packets.UseBagItem     and packets.UseBagItem.send     then pcall(function() packets.UseBagItem.send(slot) end);     return true end
    if packets and packets.ConsumeBagItem and packets.ConsumeBagItem.send then pcall(function() packets.ConsumeBagItem.send(slot) end); return true end
    if packets and packets.ConsumeItem    and packets.ConsumeItem.send    then pcall(function() packets.ConsumeItem.send(slot) end);    return true end
    if packets and packets.UseItem        and packets.UseItem.send        then pcall(function() packets.UseItem.send(slot) end);        return true end
    return false
end

_G.fruittoitemid = _G.fruittoitemid or {
    Bloodfruit=94, Bluefruit=377, Lemon=99, Coconut=1, Jelly=604, Banana=606, Orange=602,
    Oddberry=32, Berry=35, Strangefruit=302, Strawberry=282, Sunfruit=128, Pumpkin=80,
    ["Prickly Pear"]=378, Apple=243, Barley=247, Cloudberry=101, Carrot=147
}

function getItemIdByName(name) local t=_G.fruittoitemid return t and t[name] or nil end

function consumeById(id)
    if not id then return false end
    if packets and packets.ConsumeItem and packets.ConsumeItem.send then pcall(function() packets.ConsumeItem.send(id) end); return true end
    if packets and packets.UseItem     and packets.UseItem.send     then pcall(function() packets.UseItem.send({itemID=id}) end); return true end
    if packets and packets.Eat         and packets.Eat.send         then pcall(function() packets.Eat.send(id) end); return true end
    if packets and packets.EatFood     and packets.EatFood.send     then pcall(function() packets.EatFood.send(id) end); return true end
    return false
end

-- Обновление char и hum при респавне
plr.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
end)

-- Создание вкладки Heal
local HealTab = Window:CreateTab("Heal", 4483362458) -- Иконка сердца

-- Локальные переменные для хранения значений UI
local heal_toggle_value = false
local heal_item_value = "Bloodfruit"
local heal_min_value = 70
local heal_max_value = 90
local heal_hb_value = true
local heal_cd_value = 0.02
local heal_tick_value = 0.01
local heal_cycle_pause_value = 3.00
local heal_overdrive_value = true
local heal_burst_value = 3
local heal_yield_n_value = 6
local heal_debug_value = false

-- UI элементы (адаптировано для Rayfield) - сохраняем в _G для доступа из config_tab
local heal_toggle = HealTab:CreateToggle({
    Name = "Auto Heal",
    CurrentValue = false,
    Flag = "heal_auto",
    Callback = function(Value)
        _G.heal_toggle_value = Value
        heal_toggle_value = Value
        if heal_debug_value then
            print("[AutoHeal] Toggle changed to:", Value)
        end
    end,
})
_G.heal_toggle = heal_toggle

local heal_item = HealTab:CreateDropdown({
    Name = "Item to use",
    Options = {"Bloodfruit", "Bluefruit", "Berry", "Strawberry", "Coconut", "Apple", "Lemon", "Orange", "Banana"},
    CurrentOption = "Bloodfruit",
    Flag = "heal_item",
    Callback = function(Value)
        _G.heal_item_value = Value or "Bloodfruit"
        heal_item_value = Value or "Bloodfruit"
        if heal_debug_value then
            print("[AutoHeal] Item changed to:", heal_item_value)
        end
    end,
})
_G.heal_item = heal_item

local heal_min = HealTab:CreateSlider({
    Name = "Heal when HP below (%)",
    Range = {1, 99},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 70,
    Flag = "heal_min",
    Callback = function(Value)
        _G.heal_min_value = Value
        heal_min_value = Value
        -- Проверяем диапазон без вызова Set()
        if heal_min_value >= heal_max_value then
            if heal_max_value < 100 then
                _G.heal_min_value = math.max(1, heal_max_value - 1)
                heal_min_value = math.max(1, heal_max_value - 1)
            else
                _G.heal_min_value = 99
                heal_min_value = 99
            end
        end
    end,
})
_G.heal_min = heal_min

local heal_max = HealTab:CreateSlider({
    Name = "Stop when HP reaches (%)",
    Range = {2, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 90,
    Flag = "heal_max",
    Callback = function(Value)
        _G.heal_max_value = Value
        heal_max_value = Value
        -- Проверяем диапазон без вызова Set()
        if heal_min_value >= heal_max_value then
            if heal_max_value < 100 then
                _G.heal_min_value = math.max(1, heal_max_value - 1)
                heal_min_value = math.max(1, heal_max_value - 1)
            else
                _G.heal_min_value = 99
                heal_min_value = 99
            end
        end
    end,
})
_G.heal_max = heal_max

local heal_hb = HealTab:CreateToggle({
    Name = "Use Heartbeat pacing",
    CurrentValue = true,
    Flag = "heal_hb",
    Callback = function(Value)
        _G.heal_hb_value = Value
        heal_hb_value = Value
        if heal_toggle_value then
            if Value then
                startHB()
            else
                stopHB()
            end
        end
    end,
})
_G.heal_hb = heal_hb

local heal_cd = HealTab:CreateSlider({
    Name = "Per-bite delay (s)",
    Range = {0.00, 0.30},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.02,
    Flag = "heal_cd",
    Callback = function(Value)
        _G.heal_cd_value = Value
        heal_cd_value = Value
    end,
})
_G.heal_cd = heal_cd

local heal_tick = HealTab:CreateSlider({
    Name = "Check interval (s) [timer mode]",
    Range = {0.00, 0.20},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.01,
    Flag = "heal_tick",
    Callback = function(Value)
        _G.heal_tick_value = Value
        heal_tick_value = Value
    end,
})
_G.heal_tick = heal_tick

local heal_cycle_pause = HealTab:CreateSlider({
    Name = "Pause after full heal cycle (s)",
    Range = {0.50, 10.00},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 3.00,
    Flag = "heal_cycle_pause",
    Callback = function(Value)
        _G.heal_cycle_pause_value = Value
        heal_cycle_pause_value = Value
    end,
})
_G.heal_cycle_pause = heal_cycle_pause

local heal_overdrive = HealTab:CreateToggle({
    Name = "Overdrive (aggressive bursts)",
    CurrentValue = true,
    Flag = "heal_overdrive",
    Callback = function(Value)
        _G.heal_overdrive_value = Value
        heal_overdrive_value = Value
    end,
})
_G.heal_overdrive = heal_overdrive

local heal_burst = HealTab:CreateSlider({
    Name = "Bites per burst",
    Range = {1, 8},
    Increment = 1,
    CurrentValue = 3,
    Flag = "heal_burst",
    Callback = function(Value)
        _G.heal_burst_value = Value
        heal_burst_value = Value
    end,
})
_G.heal_burst = heal_burst

local heal_yield_n = HealTab:CreateSlider({
    Name = "Yield every N bites (avoid lag)",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = 6,
    Flag = "heal_yield_n",
    Callback = function(Value)
        _G.heal_yield_n_value = Value
        heal_yield_n_value = Value
    end,
})
_G.heal_yield_n = heal_yield_n

local heal_debug = HealTab:CreateToggle({
    Name = "Debug logs (F9)",
    CurrentValue = false,
    Flag = "heal_debug",
    Callback = function(Value)
        _G.heal_debug_value = Value
        heal_debug_value = Value
    end,
})
_G.heal_debug = heal_debug

-- Функция для чтения HP в процентах
local function readHPpct()
    if hum == nil or hum.MaxHealth == 0 then return 100 end
    local v = (hum.Health / hum.MaxHealth) * 100
    return math.clamp(v, 0, 100)
end

-- Функция для проверки диапазона (не используется, проверка встроена в Callback)
-- Оставлена для совместимости, если понадобится в будущем
local function clampBand()
    if heal_min_value >= heal_max_value then
        if heal_max_value < 100 then
            heal_min_value = math.max(1, heal_max_value - 1)
        else
            heal_min_value = 99
        end
    end
end

-- Функция для получения текущего времени
local function nowsec()
    return (typeof(time) == "function" and time()) or os.clock()
end

-- Функция для использования предмета один раз
local function biteOnce(it)
    local slot = getSlotByName(it)
    return (slot ~= nil and consumeBySlot(slot)) or consumeById(getItemIdByName(it))
end

-- Переменные для управления циклом лечения
local lastCycleAt = 0
local healBusy = false

-- Функция для запуска цикла лечения
local function runHealCycle()
    healBusy = true
    local it = heal_item_value or "Bloodfruit"
    local target = math.clamp(heal_max_value, heal_min_value + 1, 100)
    local maxBites = 120
    local totalBites = 0

    if heal_debug_value then
        print(string.format("[AutoHeal] start cycle: hp=%.1f -> target=%.1f (pause %.2fs, overdrive=%s, burst=%d)",
            readHPpct(), target, (heal_cycle_pause_value or 3), tostring(heal_overdrive_value), heal_burst_value))
    end

    while readHPpct() < target and maxBites > 0 do
        local burst = (heal_overdrive_value and math.max(1, math.floor(heal_burst_value))) or 1

        for j = 1, burst do
            if readHPpct() >= target or maxBites <= 0 then break end
            local used = biteOnce(it)
            totalBites += 1
            maxBites -= 1
            if heal_debug_value then
                print("[AutoHeal] bite ->", used)
            end

            if heal_overdrive_value then
                local n = math.max(1, math.floor(heal_yield_n_value))
                if (totalBites % n) == 0 then task.wait() end
            end
        end

        if not heal_overdrive_value then
            local d = heal_cd_value
            if d < 0 then d = 0 end
            if d > 0 then
                task.wait(d)
            else
                task.wait()
            end
        else
            local d = heal_cd_value
            if d < 0 then d = 0 end
            if d > 0 then
                task.wait(d)
            end
        end
    end

    lastCycleAt = nowsec()
    healBusy = false
    if heal_debug_value then
        print(string.format("[AutoHeal] cycle done (bites=%d); pause until %.2f", totalBites, lastCycleAt + (heal_cycle_pause_value or 3)))
    end
end

-- Heartbeat connection
local hbConn
local function stopHB()
    if hbConn then
        hbConn:Disconnect()
        hbConn = nil
    end
end

local function startHB()
    stopHB()
    hbConn = runs.Heartbeat:Connect(function()
        if not heal_toggle_value or not hum or not hum.Parent then return end

        local hp = readHPpct()
        local pause = heal_cycle_pause_value or 3
        local canStart = (nowsec() - lastCycleAt) >= pause

        if hp < heal_min_value and (not healBusy) and canStart then
            task.spawn(function() runHealCycle() end)
        end
    end)
end

-- Обработчики изменений toggle
local originalToggleCallback = heal_toggle.Callback
heal_toggle.Callback = function(Value)
    if originalToggleCallback then originalToggleCallback(Value) end
    if Value and heal_hb_value then
        startHB()
    else
        stopHB()
    end
end

-- Timer mode цикл (когда Heartbeat выключен)
task.spawn(function()
    while true do
        if heal_toggle_value and hum and hum.Parent and not heal_hb_value then
            local hp = readHPpct()
            local pause = heal_cycle_pause_value or 3
            local canStart = (nowsec() - lastCycleAt) >= pause

            if hp < heal_min_value and (not healBusy) and canStart then
                runHealCycle()
            end

            local dt = heal_tick_value
            if dt <= 0 then dt = 0.01 end
            task.wait(dt)
        else
            task.wait(0.10)
        end
    end
end)

print("[AutoHeal] Script loaded successfully!")



-- ===================== FARMING (Rayfield UI) =====================

-- Необходимые переменные (должны быть определены в основном скрипте)
local rs = game:GetService("ReplicatedStorage")
local packets = require(rs.Modules.Packets)
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local runs = game:GetService("RunService")
-- TweenService больше не нужен (движение через CFrame)

-- Обновление root при респавне
plr.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
end)

-- Mapping фруктов -> itemID
local fruittoitemid = {
    Bloodfruit = 94,
    Bluefruit = 377,
    Lemon = 99,
    Coconut = 1,
    Jelly = 604,
    Banana = 606,
    Orange = 602,
    Oddberry = 32,
    Berry = 35,
    Strangefruit = 302,
    Strawberry = 282,
    Sunfruit = 128,
    Pumpkin = 80,
    ["Prickly Pear"] = 378,
    Apple = 243,
    Barley = 247,
    Cloudberry = 101,
    Carrot = 147
}

-- ВАЖНО: эти переменные должны быть объявлены ДО циклов (Lua scope)
local selectedFruit = "Bloodfruit"

-- Посадка/подбор
local function plant(entityid, itemID)
    if packets.InteractStructure and packets.InteractStructure.send then
        packets.InteractStructure.send({ entityID = entityid, itemID = itemID })
    end
end

local function pickup(entityid)
    if packets.Pickup and packets.Pickup.send then
        packets.Pickup.send(entityid)
    end
end

-- Поиск Plant Box в радиусе
local function getpbs(range)
    local plantboxes = {}
    pcall(function()
        local dep = workspace:FindFirstChild("Deployables")
        if not dep or not root or not root.Parent then return end
        local rootPos = root.Position

        for _, deployable in ipairs(dep:GetChildren()) do
            if deployable:IsA("Model") and deployable.Name == "Plant Box" then
                local entityid = deployable:GetAttribute("EntityID")
                local ppart = deployable.PrimaryPart or deployable:FindFirstChildWhichIsA("BasePart")
                if entityid and ppart then
                    local dist = (ppart.Position - rootPos).Magnitude
                    if dist <= range then
                        plantboxes[#plantboxes+1] = {
                            entityid = entityid,
                            deployable = deployable,
                            dist = dist,
                            cf = ppart.CFrame,
                            pos = ppart.Position,
                        }
                    end
                end
            end
        end

        table.sort(plantboxes, function(a,b) return a.dist < b.dist end)
    end)
    return plantboxes
end

-- Поиск кустов (по имени) в радиусе
local function getbushes(range, fruitname)
    local bushes = {}
    pcall(function()
        if not root or not root.Parent then return end
        local rootPos = root.Position

        local key = tostring(fruitname or "")
        for _, model in ipairs(workspace:GetChildren()) do
            local ok, hasKey = pcall(function() return model:IsA("Model") and model.Name:find(key) end)
            if ok and hasKey then
                local ppart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if ppart then
                    local dist = (ppart.Position - rootPos).Magnitude
                    if dist <= range then
                        local entityid = model:GetAttribute("EntityID")
                        if entityid then
                            bushes[#bushes+1] = {
                                entityid = entityid,
                                model = model,
                                dist = dist,
                                cf = ppart.CFrame,
                                pos = ppart.Position,
                            }
                        end
                    end
                end
            end
        end

        table.sort(bushes, function(a,b) return a.dist < b.dist end)
    end)
    return bushes
end

-- ===================== Movement (Heartbeat + Lerp rotation, constant speed) =====================
local moveToPlantBoxEnabled = false
local moveToBushPlantBoxEnabled = false
local moveRange = 250
local moveHeight = 5
local moveSmoothness = 0.08 -- как в примере
local moveSpeed = 20.7 -- ВСЕГДА постоянная скорость
local MOVE_SCAN_CD = 0.25 -- кэш целей (не лагало)
local MOVE_MIN_DIST = 2 -- игнорируем цели "под ногами"
local MOVE_ARRIVE_DIST = 1.2 -- чтобы не было микро-остановок у цели
local MOVE_BLACKLIST_TTL = 0.8 -- сек: чтобы не залипать на одном пустом боксе пока не посадит seed

local moveTarget = nil -- { kind="pb"/"bush", id=number|string|nil, cf=CFrame, pos=Vector3 }
local moveLastScan = 0
local cachedMovePbs = {}
local cachedMoveBushes = {}
local moveBlacklistUntil = {} -- [entityID]=timeUntil

local function refreshMoveCache()
    local now = tick()
    if (now - moveLastScan) < MOVE_SCAN_CD then return end
    moveLastScan = now

    -- не трогаем Workspace слишком часто
    cachedMovePbs = getpbs(moveRange)
    cachedMoveBushes = getbushes(moveRange, selectedFruit)
end

local function isBlacklisted(entityID)
    if entityID == nil then return false end
    local t = moveBlacklistUntil[entityID]
    return (t ~= nil) and (t > tick())
end

local function blacklist(entityID)
    if entityID == nil then return end
    moveBlacklistUntil[entityID] = tick() + MOVE_BLACKLIST_TTL
end

local function pickMoveTarget()
    if not root or not root.Parent then return nil end
    refreshMoveCache()

    -- выбираем первый валидный пустой plant box (кэш уже отсортирован)
    local function firstEmptyBox()
        for _, box in ipairs(cachedMovePbs) do
            if box.deployable and box.deployable.Parent and box.pos then
                if not box.deployable:FindFirstChild("Seed") then
                    if box.dist and box.dist >= MOVE_MIN_DIST then
                        if not isBlacklisted(box.entityid) then
                            return box
                        end
                    end
                end
            end
        end
        return nil
    end

    -- выбираем первый валидный bush (кэш уже отсортирован)
    local function firstBush()
        for _, b in ipairs(cachedMoveBushes) do
            if b.pos and b.dist and b.dist >= MOVE_MIN_DIST then
                if not isBlacklisted(b.entityid) then
                return b
                end
            end
        end
        return nil
    end

    local chosen = nil -- {kind,id,pos}

    if moveToBushPlantBoxEnabled then
        local b = firstBush()
        local box = firstEmptyBox()
        if b and box then
            chosen = (box.dist < b.dist)
                and { kind = "pb", id = box.entityid, pos = box.pos }
                or  { kind = "bush", id = b.entityid, pos = b.pos }
        elseif box then
            chosen = { kind = "pb", id = box.entityid, pos = box.pos }
        elseif b then
            chosen = { kind = "bush", id = b.entityid, pos = b.pos }
        end
    elseif moveToPlantBoxEnabled then
        local box = firstEmptyBox()
        if box then chosen = { kind = "pb", id = box.entityid, pos = box.pos } end
    end

    if not chosen or not chosen.pos then return nil end

    local pos = Vector3.new(chosen.pos.X, chosen.pos.Y + moveHeight, chosen.pos.Z)
    return {
        kind = chosen.kind,
        id = chosen.id,
        pos = pos,
    }
end

runs.Heartbeat:Connect(function(deltaTime)
    if not root or not root.Parent then return end
    if (not moveToPlantBoxEnabled) and (not moveToBushPlantBoxEnabled) then
        moveTarget = nil
        return
    end

    -- если цели нет или мы "долетели" — выбираем следующую
    if not moveTarget then
        moveTarget = pickMoveTarget()
        return
    end

    local curPos = root.Position
    local goalPos = moveTarget.pos
    if not goalPos then
        moveTarget = nil
        return
    end

    -- защита от "битых" координат, которые могут ломать камеру/улетать
    if goalPos.X ~= goalPos.X or goalPos.Y ~= goalPos.Y or goalPos.Z ~= goalPos.Z then
        blacklist(moveTarget.id)
        moveTarget = nil
        return
    end
    if math.abs(goalPos.X) > 1e7 or math.abs(goalPos.Y) > 1e7 or math.abs(goalPos.Z) > 1e7 then
        blacklist(moveTarget.id)
        moveTarget = nil
        return
    end

    local flatDist = (Vector3.new(curPos.X, 0, curPos.Z) - Vector3.new(goalPos.X, 0, goalPos.Z)).Magnitude

    -- долетели: blacklist и сразу берём следующую (НЕ ждём seed)
    if flatDist < MOVE_ARRIVE_DIST then
        blacklist(moveTarget.id)
        moveLastScan = 0 -- форсим перескан
        moveTarget = pickMoveTarget()
        return
    end

    -- постоянная скорость 20.7
    local diff = goalPos - curPos
    if diff.Magnitude < 0.01 then return end
    local dir = diff.Unit
    local step = math.min(diff.Magnitude, moveSpeed * deltaTime)
    local newPos = curPos + dir * step

    -- ВАЖНО: не крутим персонажа (чтобы камера не "улетала"), двигаем только позицию.
    local rot = root.CFrame - root.CFrame.Position
    root.CFrame = CFrame.new(newPos) * rot
end)

-- ===================== UI =====================
local FarmingTab = Window:CreateTab("Farming", 4483362458)

local autoPlantEnabled = false
local plantRange = 30
local plantDelay = 0.10
local plantMaxPerCycle = 4

local autoHarvestEnabled = false
local harvestRange = 30
local harvestMaxPerCycle = 20

selectedFruit = "Bloodfruit"

-- ===================== Visual: Plant Range Ring (Optimized) =====================
local showPlantRange = false
local plantRingFolder = nil
local plantRingParts = {}
local RING_SEGMENTS = 12
local ringLastRadius = 0

local function destroyPlantRing()
    if plantRingFolder then
        pcall(function() plantRingFolder:Destroy() end)
        plantRingFolder = nil
        plantRingParts = {}
        ringLastRadius = 0
    end
end

local function ensurePlantRing()
    if plantRingFolder and plantRingFolder.Parent and #plantRingParts > 0 then return end
    destroyPlantRing()
    local folder = Instance.new("Folder")
    folder.Name = "_PlantRangeRing"
    folder.Parent = workspace
    plantRingFolder = folder
    plantRingParts = {}
    local ringColor = Color3.fromRGB(0, 255, 120)
    for i = 0, RING_SEGMENTS - 1 do
        local part = Instance.new("Part")
        part.Name = "_RingSeg" .. i
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Color = ringColor
        part.Transparency = 0.3
        part.Size = Vector3.new(1, 0.2, 0.2)
        part.Parent = folder
        table.insert(plantRingParts, part)
    end
end

-- Обновление кольца Plant Range (оптимизировано)
task.spawn(function()
    while true do
        if showPlantRange and root and root.Parent then
            ensurePlantRing()
            local centerPos = Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z)
            local radius = plantRange
            local needSizeUpdate = (ringLastRadius ~= radius)
            ringLastRadius = radius
            local segLen = radius * 2 * math.sin(math.pi / RING_SEGMENTS) + 0.15
            for i, part in ipairs(plantRingParts) do
                local midAngle = ((i - 1) / RING_SEGMENTS) * math.pi * 2 + (math.pi / RING_SEGMENTS)
                local x = centerPos.X + math.cos(midAngle) * radius
                local z = centerPos.Z + math.sin(midAngle) * radius
                if needSizeUpdate then
                    part.Size = Vector3.new(segLen, 0.2, 0.2)
                end
                part.CFrame = CFrame.new(x, centerPos.Y, z) * CFrame.Angles(0, -midAngle + math.rad(90), 0)
            end
            task.wait(0.03)
        else
            destroyPlantRing()
            task.wait(0.1)
        end
    end
end)

FarmingTab:CreateDropdown({
    Name = "Select Fruit",
    Options = {"Bloodfruit", "Bluefruit", "Lemon", "Coconut", "Jelly", "Banana", "Orange", "Oddberry", "Berry", "Strangefruit", "Strawberry", "Sunfruit", "Pumpkin", "Prickly Pear", "Apple", "Barley", "Cloudberry", "Carrot"},
    CurrentOption = "Bloodfruit",
    Flag = "fruitdropdown",
    Callback = function(v) selectedFruit = v or "Bloodfruit" end,
})

FarmingTab:CreateToggle({
    Name = "Auto Plant",
    CurrentValue = false,
    Flag = "planttoggle",
    Callback = function(v) autoPlantEnabled = v end,
})

FarmingTab:CreateSlider({
    Name = "Plant Range",
    Range = {1, 30},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 30,
    Flag = "plantrange",
    Callback = function(v) plantRange = v end,
})

FarmingTab:CreateToggle({
    Name = "Show Plant Range",
    CurrentValue = false,
    Flag = "showPlantRange",
    Callback = function(v)
        showPlantRange = v
        if not v then destroyPlantRing() end
    end,
})

FarmingTab:CreateSlider({
    Name = "Plant Delay (s)",
    Range = {0.01, 1.00},
    Increment = 0.01,
    Suffix = " s",
    CurrentValue = 0.10,
    Flag = "plantdelay",
    Callback = function(v) plantDelay = v end,
})

FarmingTab:CreateSlider({
    Name = "Max plants / cycle",
    Range = {1, 12},
    Increment = 1,
    CurrentValue = 4,
    Flag = "plantmax",
    Callback = function(v) plantMaxPerCycle = v end,
})

FarmingTab:CreateToggle({
    Name = "Auto Harvest",
    CurrentValue = false,
    Flag = "harvesttoggle",
    Callback = function(v) autoHarvestEnabled = v end,
})

FarmingTab:CreateSlider({
    Name = "Harvest Range",
    Range = {1, 30},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 30,
    Flag = "harvestrange",
    Callback = function(v) harvestRange = v end,
})

FarmingTab:CreateSlider({
    Name = "Max pickups / cycle",
    Range = {1, 80},
    Increment = 1,
    CurrentValue = 20,
    Flag = "harvestmax",
    Callback = function(v) harvestMaxPerCycle = v end,
})

-- ===================== Movement UI =====================
FarmingTab:CreateToggle({
    Name = "Move to Plant Box (Lerp)",
    CurrentValue = false,
    Flag = "moveToPlantBox",
    Callback = function(v)
        moveToPlantBoxEnabled = v
        if v then
            moveToBushPlantBoxEnabled = false
        else
            moveTargetCF = nil
        end
    end,
})

FarmingTab:CreateToggle({
    Name = "Move to Bush + Plant Box (Lerp)",
    CurrentValue = false,
    Flag = "moveToBushPlantBox",
    Callback = function(v)
        moveToBushPlantBoxEnabled = v
        if v then
            moveToPlantBoxEnabled = false
        else
            moveTargetCF = nil
        end
    end,
})

FarmingTab:CreateSlider({
    Name = "Move Range",
    Range = {1, 250},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 250,
    Flag = "moveRange",
    Callback = function(v) moveRange = v end,
})

FarmingTab:CreateSlider({
    Name = "Move Height",
    Range = {0, 8},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "moveHeight",
    Callback = function(v) moveHeight = v end,
})

FarmingTab:CreateSlider({
    Name = "Move Smoothness",
    Range = {0.01, 0.20},
    Increment = 0.01,
    CurrentValue = 0.08,
    Flag = "moveSmoothness",
    Callback = function(v) moveSmoothness = v end,
})

-- Скорость фиксированная 20.7, слайдера нет (по запросу)

-- ===================== Loops =====================

-- Auto Plant (оптимизировано)
task.spawn(function()
    local lastScan = 0
    local cachedPbs = {}
    local SCAN_INTERVAL = 0.5

    while true do
        if autoPlantEnabled then
            if not root or not root.Parent then
                char = plr.Character or plr.CharacterAdded:Wait()
                root = char:WaitForChild("HumanoidRootPart")
            end

            local now = tick()
            if (now - lastScan) >= SCAN_INTERVAL then
                cachedPbs = getpbs(plantRange)
                lastScan = now
            end

            local itemID = fruittoitemid[selectedFruit] or 94
            local planted = 0
            for _, box in ipairs(cachedPbs) do
                if planted >= plantMaxPerCycle then break end
                if box.deployable and box.deployable.Parent and not box.deployable:FindFirstChild("Seed") then
                    plant(box.entityid, itemID)
                    planted = planted + 1
                    if planted < plantMaxPerCycle then
                        task.wait() -- мини-пауза между посадками
                    end
                end
            end

            task.wait(math.max(0.25, plantDelay))
        else
            task.wait(0.2)
        end
    end
end)

-- Auto Harvest (оптимизировано)
task.spawn(function()
    local lastScan = 0
    local cachedBushes = {}
    local SCAN_INTERVAL = 0.4

    while true do
        if autoHarvestEnabled then
            if not root or not root.Parent then
                char = plr.Character or plr.CharacterAdded:Wait()
                root = char:WaitForChild("HumanoidRootPart")
            end

            local now = tick()
            if (now - lastScan) >= SCAN_INTERVAL then
                cachedBushes = getbushes(harvestRange, selectedFruit)
                lastScan = now
            end

            local n = 0
            for _, b in ipairs(cachedBushes) do
                if n >= harvestMaxPerCycle then break end
                pickup(b.entityid)
                n = n + 1
            end

            task.wait(0.15)
        else
            task.wait(0.2)
        end
    end
end)

-- (ЛОГИКА ПЕРЕДВИЖЕНИЯ УДАЛЕНА ПО ЗАПРОСУ)
