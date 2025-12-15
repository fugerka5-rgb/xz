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
