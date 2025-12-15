
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
