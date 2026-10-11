
--[[
    AIMBOT + ESP
    LocalScript
    Place inside:
    StarterPlayer > StarterPlayerScripts

    FEATURES
    ------------------------------------------------
    Aimbot
    • Enable / disable
    • Configurable aim key
    • Head / Torso
    • FOV
    • Team check

    ESP
    • Character outline / Highlight
    • Player names
    • Team colors
    • Team check
    • Works after respawning

    UI
    • Draggable
    • Minimize
    • Completely hide/show UI
    • Configurable UI toggle key
    • Configurable aim key
]]

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--==================================================
-- PLAYER
--==================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--==================================================
-- SETTINGS
--==================================================

local Settings = {

	Aimbot = {
		Enabled = false,

		AimKey = Enum.KeyCode.Q,

		TargetPart = "Head",

		ClosestToYou = false,

		WallCheck = false,
		SilentAim = false,

		FOV = 200,

		MaxDistance = 1000,

		TeamCheck = false,
	},

	ESP = {
		Enabled = false,

		ShowOutline = true,
		ShowNames = true,
		ShowTracer = false,
		ShowBox = false,

		TeamCheck = false,
		TeammateColor = Color3.fromRGB(70, 160, 255),
		EnemyColor = Color3.fromRGB(255, 70, 70),
	},

	UI = {
		ToggleKey = Enum.KeyCode.RightShift,
	},
}

--==================================================
-- STATE
--==================================================

local Aiming = false

local UIVisible = true
local Minimized = false

local KeybindListening = false

local ESPObjects = {}

--==================================================
-- CHARACTER FUNCTIONS
--==================================================

local function IsAlive(character)

	if not character then
		return false
	end

	local humanoid =
		character:FindFirstChildOfClass("Humanoid")

	return humanoid
		and humanoid.Health > 0
end

local function GetTargetPart(character)

	if not character then
		return nil
	end

	if Settings.Aimbot.TargetPart == "Head" then

		return character:FindFirstChild("Head")

	end

	if Settings.Aimbot.TargetPart == "Torso" then

		return character:FindFirstChild("UpperTorso")
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("HumanoidRootPart")

	end

	return character:FindFirstChild("Head")
end

local function IsSameTeam(player)

	if not player then
		return false
	end

	if player.Team == nil or LocalPlayer.Team == nil then
		return false
	end

	return player.Team == LocalPlayer.Team
end

local function GetESPColor(player)
	return IsSameTeam(player) and Settings.ESP.TeammateColor or Settings.ESP.EnemyColor
end

--==================================================
-- WALL CHECK
--==================================================

local function HasLineOfSight(character, targetPart)
	local camera = workspace.CurrentCamera
	if not camera or not character or not targetPart then
		return false
	end

	local origin = camera.CFrame.Position
	local direction = targetPart.Position - origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		LocalPlayer.Character,
		camera,
	}

	local result = workspace:Raycast(origin, direction, params)
	return result == nil or result.Instance:IsDescendantOf(character)
end

--==================================================
-- AIMBOT TARGET CHECK
--==================================================

local function IsValidTarget(player)

	if player == LocalPlayer then
		return false
	end

	local character = player.Character

	if not character then
		return false
	end

	if not IsAlive(character) then
		return false
	end

	if Settings.Aimbot.TeamCheck then

		if IsSameTeam(player) then
			return false
		end
	end

	local targetPart =
		GetTargetPart(character)

	if not targetPart then
		return false
	end

	if Settings.Aimbot.WallCheck and not HasLineOfSight(character, targetPart) then
		return false
	end

	return true
end

--==================================================
-- FIND CLOSEST PLAYER
--==================================================

local function GetNearestPlayerToMouse()
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mousePosition = UserInputService:GetMouseLocation()
	local localCharacter = LocalPlayer.Character
	local localRoot = localCharacter and (
		localCharacter:FindFirstChild("HumanoidRootPart")
		or localCharacter:FindFirstChild("UpperTorso")
		or localCharacter:FindFirstChild("Torso")
	)

	local closestPlayer = nil
	local closestDistance = Settings.Aimbot.ClosestToYou
		and math.huge
		or Settings.Aimbot.FOV

	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player) then
			local character = player.Character
			local targetPart = GetTargetPart(character)

			if targetPart then
				local worldDistance = (
					camera.CFrame.Position - targetPart.Position
				).Magnitude

				if worldDistance <= Settings.Aimbot.MaxDistance then
					local qualifies = false
					local distanceToCompare

					if Settings.Aimbot.ClosestToYou then
						if localRoot then
							distanceToCompare = (
								localRoot.Position - targetPart.Position
							).Magnitude
							qualifies = distanceToCompare < closestDistance
						end
					else
						local screenPosition, visible =
							camera:WorldToViewportPoint(targetPart.Position)

						if visible and screenPosition.Z > 0 then
							distanceToCompare = (
								Vector2.new(screenPosition.X, screenPosition.Y)
								- mousePosition
							).Magnitude
							qualifies = distanceToCompare < closestDistance
						end
					end

					if qualifies then
						closestDistance = distanceToCompare
						closestPlayer = player
					end
				end
			end
		end
	end

	return closestPlayer
end

--==================================================
-- AIM
--==================================================

local function AimAt(player)

	if not player then
		return
	end

	local character = player.Character

	if not character then
		return
	end

	local targetPart =
		GetTargetPart(character)

	local camera =
		workspace.CurrentCamera

	if not targetPart or not camera then
		return
	end

	camera.CFrame =
		CFrame.lookAt(
			camera.CFrame.Position,
			targetPart.Position
		)
end

--==================================================
-- ESP
--==================================================

local ClearESPVisuals, MakeESPVisuals

local function RemoveESP(player)

	local data =
		ESPObjects[player]

	if not data then
		return
	end

	if data.Highlight then
		data.Highlight:Destroy()
	end

	if data.Billboard then
		data.Billboard:Destroy()
	end

	ClearESPVisuals(player)
	ESPObjects[player] = nil
end

--==================================================
-- CREATE ESP
--==================================================

local function CreateESP(player)

	if player == LocalPlayer then
		return
	end

	local character =
		player.Character

	if not character then
		return
	end

	if not IsAlive(character) then
		return
	end

	-- Remove old ESP first
	RemoveESP(player)

	--==================================================
	-- HIGHLIGHT
	--==================================================

	local highlight =
		Instance.new("Highlight")

	highlight.Name =
		"CustomPlayerESP"

	highlight.Adornee =
		character

	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop

	highlight.FillTransparency =
		1

	highlight.OutlineTransparency =
		0

	highlight.Parent =
		character

	--==================================================
	-- TEAM COLOR
	--==================================================

	highlight.OutlineColor = GetESPColor(player)

	highlight.Enabled =
		Settings.ESP.ShowOutline

	--==================================================
	-- NAME
	--==================================================

	local billboard =
		Instance.new("BillboardGui")

	billboard.Name =
		"CustomPlayerName"

	billboard.Adornee =
		character:FindFirstChild("Head")

	billboard.AlwaysOnTop =
		true

	billboard.Size =
		UDim2.fromOffset(
			200,
			40
		)

	billboard.StudsOffset =
		Vector3.new(
			0,
			3,
			0
		)

	billboard.Enabled =
		Settings.ESP.ShowNames

	billboard.Parent =
		PlayerGui

	local nameLabel =
		Instance.new("TextLabel")

	nameLabel.BackgroundTransparency =
		1

	nameLabel.Size =
		UDim2.fromScale(
			1,
			1
		)

	nameLabel.Font =
		Enum.Font.GothamBold

	nameLabel.TextSize =
		14

	nameLabel.TextStrokeTransparency =
		0

	nameLabel.Text =
		player.DisplayName

	nameLabel.Parent =
		billboard

	nameLabel.TextColor3 = GetESPColor(player)

	local visuals = MakeESPVisuals(player)

	ESPObjects[player] = {

		Visuals = visuals,

		Highlight = highlight,

		Billboard = billboard,

		Name = nameLabel,
	}
end

--==================================================
-- UPDATE ESP
--==================================================

local function UpdateESP(player)

	if player == LocalPlayer then
		return
	end

	if not Settings.ESP.Enabled then

		RemoveESP(player)

		return
	end

	local character =
		player.Character

	if not character then

		RemoveESP(player)

		return
	end

	if not IsAlive(character) then

		RemoveESP(player)

		return
	end

	if Settings.ESP.TeamCheck
		and IsSameTeam(player) then

		RemoveESP(player)

		return
	end

	local head =
		character:FindFirstChild("Head")

	if not head then

		RemoveESP(player)

		return
	end

	local data =
		ESPObjects[player]

	-- Create if missing
	if not data then

		CreateESP(player)

		data =
			ESPObjects[player]

	end

	if not data then
		return
	end

	--==================================================
	-- MAKE SURE ESP IS ATTACHED TO CURRENT CHARACTER
	--==================================================

	if data.Highlight.Adornee ~= character then

		data.Highlight.Adornee =
			character

	end

	if data.Billboard.Adornee ~= head then

		data.Billboard.Adornee =
			head

	end

	--==================================================
	-- VISIBILITY
	--==================================================

	data.Highlight.Enabled =
		Settings.ESP.ShowOutline

	data.Billboard.Enabled =
		Settings.ESP.ShowNames

	--==================================================
	-- COLORS
	--==================================================

	local espColor = GetESPColor(player)
	data.Highlight.OutlineColor = espColor
	data.Name.TextColor3 = espColor
end

--==================================================
-- UPDATE ALL ESP
--==================================================

local function UpdateAllESP()

	for _, player in ipairs(Players:GetPlayers()) do

		if player ~= LocalPlayer then

			UpdateESP(player)

		end
	end
end

--==================================================
-- CLEAR ESP
--==================================================

local function ClearESP()

	for player in pairs(ESPObjects) do

		RemoveESP(player)

	end

	-- Safety cleanup for orphaned objects
	for _, player in ipairs(Players:GetPlayers()) do

		if player.Character then

			for _, object in ipairs(
				player.Character:GetChildren()
			) do

				if object.Name ==
					"CustomPlayerESP" then

					object:Destroy()

				end
			end
		end
	end
end

--==================================================
-- GUI
--==================================================

local ScreenGui =
	Instance.new("ScreenGui")

ScreenGui.Name =
	"AimESP_UI"

ScreenGui.ResetOnSpawn =
	false

ScreenGui.IgnoreGuiInset =
	true

ScreenGui.Parent =
	PlayerGui

-- Overlay layer used for ESP tracers and 2D boxes.
local ESPOverlay = Instance.new("Frame")
ESPOverlay.Name = "ESPOverlay"
ESPOverlay.BackgroundTransparency = 1
ESPOverlay.Size = UDim2.fromScale(1, 1)
ESPOverlay.Position = UDim2.fromScale(0, 0)
ESPOverlay.Parent = ScreenGui

local ESPVisuals = {}

ClearESPVisuals = function(player)
	local visual = ESPVisuals[player]
	if visual then
		for _, object in ipairs(visual) do
			object:Destroy()
		end
		ESPVisuals[player] = nil
	end
end

local function MakeLine(parent, color, thickness)
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = color
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = UDim2.fromOffset(1, thickness)
	line.Visible = false
	line.Parent = parent
	return line
end

MakeESPVisuals = function(player)
	ClearESPVisuals(player)
	local objects = {}

	local tracer = MakeLine(ESPOverlay, Color3.fromRGB(255, 70, 70), 2)
	table.insert(objects, tracer)

	local boxLines = {}
	for i = 1, 4 do
		local line = MakeLine(ESPOverlay, Color3.fromRGB(255, 70, 70), 2)
		table.insert(boxLines, line)
		table.insert(objects, line)
	end

	ESPVisuals[player] = objects
	return {Tracer = tracer, BoxLines = boxLines}
end

--==================================================
-- MAIN WINDOW
--==================================================

local Main =
	Instance.new("Frame")

Main.Name =
	"Main"

Main.Size =
	UDim2.fromOffset(
		480,
		500
	)

Main.Position =
	UDim2.new(
		0.5,
		-240,
		0.5,
		-250
	)

Main.BackgroundColor3 =
	Color3.fromRGB(
		20,
		20,
		25
	)

Main.BorderSizePixel =
	0

Main.Parent =
	ScreenGui

local MainCorner =
	Instance.new("UICorner")

MainCorner.CornerRadius =
	UDim.new(
		0,
		10
	)

MainCorner.Parent =
	Main

local MainStroke =
	Instance.new("UIStroke")

MainStroke.Color =
	Color3.fromRGB(
		55,
		55,
		65
	)

MainStroke.Parent =
	Main

--==================================================
-- TITLE BAR
--==================================================

local TitleBar =
	Instance.new("Frame")

TitleBar.Size =
	UDim2.new(
		1,
		0,
		0,
		45
	)

TitleBar.BackgroundColor3 =
	Color3.fromRGB(
		28,
		28,
		35
	)

TitleBar.BorderSizePixel =
	0

TitleBar.Parent =
	Main

local Title =
	Instance.new("TextLabel")

Title.BackgroundTransparency =
	1

Title.Position =
	UDim2.fromOffset(
		15,
		0
	)

Title.Size =
	UDim2.new(
		1,
		-150,
		1,
		0
	)

Title.Font =
	Enum.Font.GothamBold

Title.Text =
	"AIM  •  ESP"

Title.TextColor3 =
	Color3.fromRGB(
		240,
		240,
		245
	)

Title.TextSize =
	17

Title.TextXAlignment =
	Enum.TextXAlignment.Left

Title.Parent =
	TitleBar

local Byline = Instance.new("TextLabel")
Byline.Name = "Byline"
Byline.BackgroundTransparency = 1
Byline.Position = UDim2.fromOffset(150, 0)
Byline.Size = UDim2.fromOffset(150, 45)
Byline.Font = Enum.Font.Gotham
Byline.Text = "by umcarafoda"
Byline.TextColor3 = Color3.fromRGB(145, 145, 160)
Byline.TextSize = 11
Byline.TextXAlignment = Enum.TextXAlignment.Left
Byline.Parent = TitleBar

local Status =
	Instance.new("TextLabel")

Status.BackgroundTransparency =
	1

Status.Position =
	UDim2.new(
		1,
		-160,
		0,
		0
	)

Status.Size =
	UDim2.fromOffset(
		90,
		45
	)

Status.Font =
	Enum.Font.Gotham

Status.Text =
	"READY"

Status.TextColor3 =
	Color3.fromRGB(
		100,
		255,
		140
	)

Status.TextSize =
	12

Status.TextXAlignment =
	Enum.TextXAlignment.Right

Status.Parent =
	TitleBar

--==================================================
-- MINIMIZE
--==================================================

local Minimize =
	Instance.new("TextButton")

Minimize.BackgroundTransparency =
	1

Minimize.Position =
	UDim2.new(
		1,
		-65,
		0,
		0
	)

Minimize.Size =
	UDim2.fromOffset(
		30,
		45
	)

Minimize.Font =
	Enum.Font.GothamBold

Minimize.Text =
	"—"

Minimize.TextColor3 =
	Color3.fromRGB(
		220,
		220,
		225
	)

Minimize.TextSize =
	20

Minimize.Parent =
	TitleBar

--==================================================
-- DRAGGING
--==================================================

local dragging =
	false

local dragStart
local startPosition

TitleBar.InputBegan:Connect(function(input)

	if input.UserInputType ==
		Enum.UserInputType.MouseButton1 then

		dragging =
			true

		dragStart =
			input.Position

		startPosition =
			Main.Position

	end
end)

TitleBar.InputEnded:Connect(function(input)

	if input.UserInputType ==
		Enum.UserInputType.MouseButton1 then

		dragging =
			false

	end
end)

UserInputService.InputChanged:Connect(function(input)

	if dragging
		and input.UserInputType ==
			Enum.UserInputType.MouseMovement then

		local delta =
			input.Position -
			dragStart

		Main.Position =
			UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)

	end
end)

--==================================================
-- CONTENT
--==================================================

local Content =
	Instance.new("Frame")

Content.Position =
	UDim2.fromOffset(
		0,
		45
	)

Content.Size =
	UDim2.new(
		1,
		0,
		1,
		-45
	)

Content.BackgroundTransparency =
	1

Content.Parent =
	Main

--==================================================
-- SIDEBAR
--==================================================

local Sidebar =
	Instance.new("Frame")

Sidebar.Size =
	UDim2.fromOffset(
		125,
		455
	)

Sidebar.BackgroundColor3 =
	Color3.fromRGB(
		24,
		24,
		30
	)

Sidebar.BorderSizePixel =
	0

Sidebar.Parent =
	Content

local SidebarLayout =
	Instance.new("UIListLayout")

SidebarLayout.Padding =
	UDim.new(
		0,
		5
	)

SidebarLayout.HorizontalAlignment =
	Enum.HorizontalAlignment.Center

SidebarLayout.Parent =
	Sidebar

local SidebarPadding =
	Instance.new("UIPadding")

SidebarPadding.PaddingTop =
	UDim.new(
		0,
		10
	)

SidebarPadding.Parent =
	Sidebar

--==================================================
-- PAGES
--==================================================

local Pages =
	Instance.new("Frame")

Pages.Position =
	UDim2.fromOffset(
		125,
		0
	)

Pages.Size =
	UDim2.new(
		1,
		-125,
		1,
		0
	)

Pages.BackgroundTransparency =
	1

Pages.Parent =
	Content

local function CreatePage()

	local page =
		Instance.new("Frame")

	page.Size =
		UDim2.fromScale(
			1,
			1
		)

	page.BackgroundTransparency =
		1

	page.Visible =
		false

	page.Parent =
		Pages

	return page
end

local AimPage =
	CreatePage()

local ESPPage =
	CreatePage()

local SettingsPage =
	CreatePage()

AimPage.Visible =
	true

--==================================================
-- TAB CREATOR
--==================================================

local function CreateTab(text, page)

	local button =
		Instance.new("TextButton")

	button.Size =
		UDim2.fromOffset(
			110,
			38
		)

	button.BackgroundColor3 =
		Color3.fromRGB(
			32,
			32,
			40
		)

	button.BorderSizePixel =
		0

	button.Font =
		Enum.Font.GothamMedium

	button.Text =
		text

	button.TextColor3 =
		Color3.fromRGB(
			190,
			190,
			200
		)

	button.TextSize =
		13

	button.Parent =
		Sidebar

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			0,
			6
		)

	corner.Parent =
		button

	button.MouseButton1Click:Connect(function()

		for _, pageObject in
			ipairs(Pages:GetChildren()) do

			if pageObject:IsA("Frame") then

				pageObject.Visible =
					false

			end
		end

		page.Visible =
			true

		for _, tab in
			ipairs(Sidebar:GetChildren()) do

			if tab:IsA("TextButton") then

				tab.BackgroundColor3 =
					Color3.fromRGB(
						32,
						32,
						40
					)

			end
		end

		button.BackgroundColor3 =
			Color3.fromRGB(
				60,
				60,
				75
			)
	end)

	return button
end

local AimTab =
	CreateTab(
		"Aimbot",
		AimPage
	)

local ESPTab =
	CreateTab(
		"ESP",
		ESPPage
	)

local SettingsTab =
	CreateTab(
		"Settings",
		SettingsPage
	)

AimTab.BackgroundColor3 =
	Color3.fromRGB(
		60,
		60,
		75
	)

--==================================================
-- TOGGLE
--==================================================

local function CreateToggle(
	parent,
	text,
	default,
	callback,
	y
)

	local button =
		Instance.new("TextButton")

	button.Position =
		UDim2.fromOffset(
			20,
			y
		)

	button.Size =
		UDim2.new(
			1,
			-40,
			0,
			38
		)

	button.BackgroundColor3 =
		Color3.fromRGB(
			31,
			31,
			38
		)

	button.BorderSizePixel =
		0

	button.Font =
		Enum.Font.GothamMedium

	button.TextSize =
		13

	button.TextXAlignment =
		Enum.TextXAlignment.Left

	button.Parent =
		parent

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			0,
			6
		)

	corner.Parent =
		button

	local value =
		default

	local function Update()

		button.Text =
			"  "
			.. text
			.. "     "
			.. (
				value
				and "ON"
				or "OFF"
			)

		button.TextColor3 =
			value
			and Color3.fromRGB(
				100,
				255,
				140
			)
			or Color3.fromRGB(
				190,
				190,
				200
			)
	end

	Update()

	button.MouseButton1Click:Connect(function()

		value =
			not value

		Update()

		callback(value)
	end)

	return button
end

--==================================================
-- SELECTOR
--==================================================

local function CreateSelector(
	parent,
	text,
	values,
	defaultIndex,
	callback,
	y
)

	local button =
		Instance.new("TextButton")

	button.Position =
		UDim2.fromOffset(
			20,
			y
		)

	button.Size =
		UDim2.new(
			1,
			-40,
			0,
			38
		)

	button.BackgroundColor3 =
		Color3.fromRGB(
			31,
			31,
			38
		)

	button.BorderSizePixel =
		0

	button.Font =
		Enum.Font.GothamMedium

	button.TextSize =
		13

	button.TextColor3 =
		Color3.fromRGB(
			200,
			200,
			210
		)

	button.TextXAlignment =
		Enum.TextXAlignment.Left

	button.Parent =
		parent

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			0,
			6
		)

	corner.Parent =
		button

	local index =
		defaultIndex

	local function Update()

		button.Text =
			"  "
			.. text
			.. ": "
			.. tostring(
				values[index]
			)

	end

	Update()

	button.MouseButton1Click:Connect(function()

		index += 1

		if index > #values then
			index = 1
		end

		Update()

		callback(
			values[index]
		)
	end)

	return button
end

--==================================================
-- KEYBIND SYSTEM
--==================================================

local function KeyName(input)

	if typeof(input) ~= "EnumItem" then
		return "NONE"
	end

	return input.Name
end

local function CreateKeybind(
	parent,
	text,
	defaultKey,
	callback,
	y
)

	local button =
		Instance.new("TextButton")

	button.Position =
		UDim2.fromOffset(
			20,
			y
		)

	button.Size =
		UDim2.new(
			1,
			-40,
			0,
			38
		)

	button.BackgroundColor3 =
		Color3.fromRGB(
			31,
			31,
			38
		)

	button.BorderSizePixel =
		0

	button.Font =
		Enum.Font.GothamMedium

	button.TextColor3 =
		Color3.fromRGB(
			200,
			200,
			210
		)

	button.TextSize =
		13

	button.TextXAlignment =
		Enum.TextXAlignment.Left

	button.Parent =
		parent

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			0,
			6
		)

	corner.Parent =
		button

	local currentKey =
		defaultKey

	local waiting =
		false

	local connection

	local function UpdateText()

		button.Text =
			"  "
			.. text
			.. ": ["
			.. KeyName(currentKey)
			.. "]"

	end

	UpdateText()

	button.MouseButton1Click:Connect(function()

		if waiting then
			return
		end

		waiting =
			true

		KeybindListening =
			true

		button.Text =
			"  "
			.. text
			.. ": [PRESS KEY]"

		button.TextColor3 =
			Color3.fromRGB(
				255,
				210,
				100
			)

		connection =
			UserInputService.InputBegan:Connect(
				function(input)

					-- Keyboard
					if input.UserInputType ==
						Enum.UserInputType.Keyboard then

						if input.KeyCode ==
							Enum.KeyCode.Unknown then

							return
						end

						currentKey =
							input.KeyCode

					-- Mouse
					elseif input.UserInputType ==
						Enum.UserInputType.MouseButton1
						or input.UserInputType ==
						Enum.UserInputType.MouseButton2
						or input.UserInputType ==
						Enum.UserInputType.MouseButton3 then

						currentKey =
							input.UserInputType

					else

						return
					end

					waiting =
						false

					KeybindListening =
						false

					if connection then

						connection:Disconnect()
						connection =
							nil

					end

					button.TextColor3 =
						Color3.fromRGB(
							200,
							200,
							210
						)

					UpdateText()

					callback(
						currentKey
					)
				end
			)
	end)

	return button
end

--==================================================
-- AIM PAGE
--==================================================

local AimHeader =
	Instance.new("TextLabel")

AimHeader.BackgroundTransparency =
	1

AimHeader.Position =
	UDim2.fromOffset(
		20,
		10
	)

AimHeader.Size =
	UDim2.new(
		1,
		-40,
		0,
		30
	)

AimHeader.Font =
	Enum.Font.GothamBold

AimHeader.Text =
	"Aimbot"

AimHeader.TextColor3 =
	Color3.fromRGB(
		240,
		240,
		245
	)

AimHeader.TextSize =
	20

AimHeader.TextXAlignment =
	Enum.TextXAlignment.Left

AimHeader.Parent =
	AimPage

CreateToggle(
	AimPage,
	"Aimbot",
	Settings.Aimbot.Enabled,
	function(value)

		Settings.Aimbot.Enabled =
			value

	end,
	50
)

CreateToggle(
	AimPage,
	"Team Check",
	Settings.Aimbot.TeamCheck,
	function(value)

		Settings.Aimbot.TeamCheck =
			value

	end,
	93
)

CreateToggle(
	AimPage,
	"Closest to You",
	Settings.Aimbot.ClosestToYou,
	function(value)
		Settings.Aimbot.ClosestToYou = value
	end,
	136
)

CreateToggle(
	AimPage,
	"Wall Check",
	Settings.Aimbot.WallCheck,
	function(value)
		Settings.Aimbot.WallCheck = value
	end,
	179
)

CreateToggle(
	AimPage,
	"Silent Aim",
	Settings.Aimbot.SilentAim,
	function(value)
		Settings.Aimbot.SilentAim = value
		if not value then
			LocalPlayer:SetAttribute("SilentAimTargetUserId", nil)
		end
	end,
	222
)

CreateSelector(
	AimPage,
	"Target",
	{
		"Head",
		"Torso"
	},
	1,
	function(value)

		Settings.Aimbot.TargetPart =
			value

	end,
	265
)

CreateSelector(
	AimPage,
	"FOV",
	{
		100,
		200,
		300,
		400,
		600
	},
	2,
	function(value)

		Settings.Aimbot.FOV =
			tonumber(value)

	end,
	308
)

--==================================================
-- ESP PAGE
--==================================================

local ESPHeader =
	Instance.new("TextLabel")

ESPHeader.BackgroundTransparency =
	1

ESPHeader.Position =
	UDim2.fromOffset(
		20,
		10
	)

ESPHeader.Size =
	UDim2.new(
		1,
		-40,
		0,
		30
	)

ESPHeader.Font =
	Enum.Font.GothamBold

ESPHeader.Text =
	"ESP"

ESPHeader.TextColor3 =
	Color3.fromRGB(
		240,
		240,
		245
	)

ESPHeader.TextSize =
	20

ESPHeader.TextXAlignment =
	Enum.TextXAlignment.Left

ESPHeader.Parent =
	ESPPage

CreateToggle(
	ESPPage,
	"ESP",
	Settings.ESP.Enabled,
	function(value)

		Settings.ESP.Enabled =
			value

		if value then

			UpdateAllESP()

		else

			ClearESP()

		end

	end,
	50
)

CreateToggle(
	ESPPage,
	"Player Outline",
	Settings.ESP.ShowOutline,
	function(value)

		Settings.ESP.ShowOutline =
			value

		for _, data in pairs(
			ESPObjects
		) do

			if data.Highlight then

				data.Highlight.Enabled =
					value

			end
		end

	end,
	93
)

CreateToggle(
	ESPPage,
	"Player Names",
	Settings.ESP.ShowNames,
	function(value)

		Settings.ESP.ShowNames =
			value

		for _, data in pairs(
			ESPObjects
		) do

			if data.Billboard then

				data.Billboard.Enabled =
					value

			end
		end

	end,
	136
)

CreateToggle(
	ESPPage,
	"Tracer",
	Settings.ESP.ShowTracer,
	function(value)
		Settings.ESP.ShowTracer = value
	end,
	179
)

CreateToggle(
	ESPPage,
	"Box",
	Settings.ESP.ShowBox,
	function(value)
		Settings.ESP.ShowBox = value
	end,
	222
)

CreateToggle(
	ESPPage,
	"Team Check",
	Settings.ESP.TeamCheck,
	function(value)

		Settings.ESP.TeamCheck =
			value

		UpdateAllESP()

	end,
	265
)

--==================================================
-- ESP COLOR PERSONALIZER (HEX)
--==================================================

local ColorHeader = Instance.new("TextLabel")
ColorHeader.BackgroundTransparency = 1
ColorHeader.Position = UDim2.fromOffset(20, 307)
ColorHeader.Size = UDim2.new(1, -40, 0, 24)
ColorHeader.Font = Enum.Font.GothamBold
ColorHeader.Text = "ESP COLORS  •  HEX"
ColorHeader.TextColor3 = Color3.fromRGB(235, 235, 245)
ColorHeader.TextSize = 12
ColorHeader.TextXAlignment = Enum.TextXAlignment.Left
ColorHeader.Parent = ESPPage

local function ColorToHex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function MakeColorInput(labelText, y, initialColor, applyCallback)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(20, y)
	label.Size = UDim2.fromOffset(92, 30)
	label.Font = Enum.Font.GothamMedium
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(195, 195, 205)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = ESPPage

	local input = Instance.new("TextBox")
	input.Position = UDim2.fromOffset(110, y + 1)
	input.Size = UDim2.fromOffset(100, 28)
	input.BackgroundColor3 = Color3.fromRGB(31, 31, 38)
	input.BorderSizePixel = 0
	input.Font = Enum.Font.Code
	input.Text = ColorToHex(initialColor)
	input.PlaceholderText = "#RRGGBB"
	input.TextColor3 = initialColor
	input.TextSize = 12
	input.ClearTextOnFocus = false
	input.Parent = ESPPage
	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 5)
	inputCorner.Parent = input

	local apply = Instance.new("TextButton")
	apply.Position = UDim2.fromOffset(218, y + 1)
	apply.Size = UDim2.fromOffset(62, 28)
	apply.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
	apply.BorderSizePixel = 0
	apply.Font = Enum.Font.GothamMedium
	apply.Text = "Apply"
	apply.TextColor3 = Color3.fromRGB(240, 240, 245)
	apply.TextSize = 11
	apply.Parent = ESPPage
	local applyCorner = Instance.new("UICorner")
	applyCorner.CornerRadius = UDim.new(0, 5)
	applyCorner.Parent = apply

	local function applyColor()
		local hex = input.Text:gsub("#", "")
		if #hex ~= 6 or not hex:match("^%x%x%x%x%x%x$") then
			input.TextColor3 = Color3.fromRGB(255, 100, 100)
			return
		end
		local r = tonumber(hex:sub(1, 2), 16)
		local g = tonumber(hex:sub(3, 4), 16)
		local b = tonumber(hex:sub(5, 6), 16)
		local color = Color3.fromRGB(r, g, b)
		input.Text = ColorToHex(color)
		input.TextColor3 = color
		applyCallback(color)
		UpdateAllESP()
	end

	apply.MouseButton1Click:Connect(applyColor)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then applyColor() end
	end)
end

MakeColorInput("Teammates", 337, Settings.ESP.TeammateColor, function(color)
	Settings.ESP.TeammateColor = color
end)
MakeColorInput("Enemies", 374, Settings.ESP.EnemyColor, function(color)
	Settings.ESP.EnemyColor = color
end)

--==================================================
-- SETTINGS PAGE
--==================================================

local SettingsHeader =
	Instance.new("TextLabel")

SettingsHeader.BackgroundTransparency =
	1

SettingsHeader.Position =
	UDim2.fromOffset(
		20,
		10
	)

SettingsHeader.Size =
	UDim2.new(
		1,
		-40,
		0,
		30
	)

SettingsHeader.Font =
	Enum.Font.GothamBold

SettingsHeader.Text =
	"Keybinds"

SettingsHeader.TextColor3 =
	Color3.fromRGB(
		240,
		240,
		245
	)

SettingsHeader.TextSize =
	20

SettingsHeader.TextXAlignment =
	Enum.TextXAlignment.Left

SettingsHeader.Parent =
	SettingsPage

CreateKeybind(
	SettingsPage,
	"Aim Key",
	Settings.Aimbot.AimKey,
	function(key)

		Settings.Aimbot.AimKey =
			key

		Aiming =
			false

	end,
	50
)

CreateKeybind(
	SettingsPage,
	"UI Toggle",
	Settings.UI.ToggleKey,
	function(key)

		Settings.UI.ToggleKey =
			key

	end,
	93
)

local Info =
	Instance.new("TextLabel")

Info.BackgroundTransparency =
	1

Info.Position =
	UDim2.fromOffset(
		20,
		145
	)

Info.Size =
	UDim2.new(
		1,
		-40,
		0,
		100
	)

Info.Font =
	Enum.Font.Gotham

Info.Text =
	"Click a keybind and press a key.\n\n"
	.. "The UI Toggle key completely hides the menu.\n"
	.. "Press the same key again to bring it back."

Info.TextColor3 =
	Color3.fromRGB(
		175,
		175,
		185
	)

Info.TextSize =
	13

Info.TextXAlignment =
	Enum.TextXAlignment.Left

Info.TextYAlignment =
	Enum.TextYAlignment.Top

Info.Parent =
	SettingsPage

--==================================================
-- MINIMIZE
--==================================================

Minimize.MouseButton1Click:Connect(function()

	Minimized =
		not Minimized

	if Minimized then

		Content.Visible =
			false

		Main.Size =
			UDim2.fromOffset(
				480,
				45
			)

	else

		Content.Visible =
			true

		Main.Size =
			UDim2.fromOffset(
				480,
				500
			)

	end
end)

--==================================================
-- UI TOGGLE / AIM INPUT
--==================================================

UserInputService.InputBegan:Connect(
	function(input, gameProcessed)

		if KeybindListening then
			return
		end

		--==================================================
		-- UI TOGGLE
		--==================================================

		if input.UserInputType ==
			Enum.UserInputType.Keyboard then

			if input.KeyCode ==
				Settings.UI.ToggleKey then

				UIVisible =
					not UIVisible

				Main.Visible =
					UIVisible

				return
			end
		end

		--==================================================
		-- AIM KEY
		--==================================================

		if input.KeyCode ==
			Settings.Aimbot.AimKey then

			Aiming =
				true

		elseif input.UserInputType ==
			Settings.Aimbot.AimKey then

			Aiming =
				true
		end
	end
)

UserInputService.InputEnded:Connect(
	function(input)

		if input.KeyCode ==
			Settings.Aimbot.AimKey then

			Aiming =
				false

		elseif input.UserInputType ==
			Settings.Aimbot.AimKey then

			Aiming =
				false

		end
	end
)

--==================================================
-- PLAYER CONNECTIONS
--==================================================

local function SetupPlayer(player)

	if player == LocalPlayer then
		return
	end

	--==================================================
	-- CHARACTER SPAWN
	--==================================================

	player.CharacterAdded:Connect(
		function(character)

			-- Remove the old character's ESP
			RemoveESP(player)

			-- Wait until Roblox has finished
			-- creating the character
			local head =
				character:WaitForChild(
					"Head",
					5
				)

			local humanoid =
				character:WaitForChild(
					"Humanoid",
					5
				)

			if not head or not humanoid then
				return
			end

			-- Small delay prevents ESP being
			-- created before the character
			-- is completely replicated.
			task.wait(0.15)

			if Settings.ESP.Enabled then

				UpdateESP(player)

			end
		end
	)

	-- Handle players who were already spawned
	if player.Character then

		task.defer(
			function()

				if Settings.ESP.Enabled then

					UpdateESP(player)

				end
			end
		)
	end
end

for _, player in ipairs(
	Players:GetPlayers()
) do

	SetupPlayer(player)

end

Players.PlayerAdded:Connect(
	function(player)

		SetupPlayer(player)

	end
)

Players.PlayerRemoving:Connect(
	function(player)

		RemoveESP(player)

	end
)

--==================================================
-- UPDATE 2D ESP VISUALS
--==================================================

local function UpdateESPVisuals()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local data = ESPObjects[player]
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local head = character and character:FindFirstChild("Head")

			if data and data.Visuals and root and head and IsAlive(character)
				and Settings.ESP.Enabled then
				local visuals = data.Visuals
				local rootPos, rootVisible = camera:WorldToViewportPoint(root.Position)
				local headPos, headVisible = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
				local feetPos, feetVisible = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
				local visible = rootVisible and headVisible and feetVisible
					and rootPos.Z > 0 and headPos.Z > 0 and feetPos.Z > 0

				local color = GetESPColor(player)

				local tracer = visuals.Tracer
				tracer.Visible = visible and Settings.ESP.ShowTracer
				if tracer.Visible then
					local startPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
					local endPos = Vector2.new(rootPos.X, rootPos.Y)
					local delta = endPos - startPos
					tracer.Position = UDim2.fromOffset((startPos.X + endPos.X) / 2, (startPos.Y + endPos.Y) / 2)
					tracer.Size = UDim2.fromOffset(delta.Magnitude, 2)
					tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					tracer.BackgroundColor3 = color
				end

				local boxLines = visuals.BoxLines
				for _, line in ipairs(boxLines) do
					line.Visible = false
				end

				if visible and Settings.ESP.ShowBox then
					local height = math.abs(feetPos.Y - headPos.Y)
					local width = height * 0.55
					local left = rootPos.X - width / 2
					local right = rootPos.X + width / 2
					local top = headPos.Y
					local bottom = feetPos.Y
					local segments = {
						{Vector2.new(left, top), Vector2.new(right, top)},
						{Vector2.new(right, top), Vector2.new(right, bottom)},
						{Vector2.new(right, bottom), Vector2.new(left, bottom)},
						{Vector2.new(left, bottom), Vector2.new(left, top)},
					}

					for i, segment in ipairs(segments) do
						local line = boxLines[i]
						local a, b = segment[1], segment[2]
						local delta = b - a
						line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
						line.Size = UDim2.fromOffset(delta.Magnitude, 2)
						line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
						line.BackgroundColor3 = color
						line.Visible = true
					end
				end
			elseif data and data.Visuals then
				data.Visuals.Tracer.Visible = false
				for _, line in ipairs(data.Visuals.BoxLines) do
					line.Visible = false
				end
			end
		end
	end
end

--==================================================
-- MAIN LOOP
--==================================================

local espTimer =
	0

RunService.RenderStepped:Connect(
	function(deltaTime)

		--==================================================
		-- AIMBOT
		--==================================================

		if Settings.Aimbot.Enabled
			and Aiming then

			local target =
				GetNearestPlayerToMouse()

			if target then

				if Settings.Aimbot.SilentAim then
					-- Your own weapon/shooting code can read this attribute.
					LocalPlayer:SetAttribute("SilentAimTargetUserId", target.UserId)
				else
					LocalPlayer:SetAttribute("SilentAimTargetUserId", nil)
					AimAt(target)
				end

				Status.Text =
					"AIMING"

				Status.TextColor3 =
					Color3.fromRGB(
						100,
						255,
						140
					)

			else

				LocalPlayer:SetAttribute("SilentAimTargetUserId", nil)
				Status.Text =
					"NO TARGET"

				Status.TextColor3 =
					Color3.fromRGB(
						255,
						180,
						100
					)
			end

		elseif not Settings.Aimbot.Enabled then

			LocalPlayer:SetAttribute("SilentAimTargetUserId", nil)
			Status.Text =
				"READY"

			Status.TextColor3 =
				Color3.fromRGB(
					100,
					255,
					140
				)
		end

		UpdateESPVisuals()

		--==================================================
		-- ESP
		--==================================================

		if Settings.ESP.Enabled then

			espTimer +=
				deltaTime

			-- Refresh 10 times per second.
			if espTimer >= 0.1 then

				espTimer =
					0

				UpdateAllESP()

			end
		end
	end
)

--==================================================
-- INITIAL STATE
--==================================================

Status.Text =
	"READY"

Status.TextColor3 =
	Color3.fromRGB(
		100,
		255,
		140
	)
