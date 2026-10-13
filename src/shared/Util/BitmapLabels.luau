--!strict

-- Draws a TextLabel or TextButton in the Jersey 15 bitmap font (Roblox can't load the font itself).
-- The label stays the source of truth: its Text, TextColor3 and TextTransparency are mirrored onto the
-- glyphs whenever code or Studio changes them; its own text is hidden with MaxVisibleGraphemes.
-- A label's TextStrokeColor3 (when its stroke is shown) or its contextual UIStroke becomes a drop shadow.
-- Shared so the ReplicatedFirst loading screen can draw its labels before the client controllers start;
-- BitmapTextController binds every label tagged BitmapText through it, and a label is never bound twice.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BitmapFont = require(script.Parent:WaitForChild("BitmapFont"))
local Jersey15 = require(script.Parent.Parent:WaitForChild("Fonts"):WaitForChild("Jersey15"))

local BitmapLabels = {}

function BitmapLabels.IsReady(): boolean
	return BitmapFont.IsReady(Jersey15)
end

-- TextButtons have the same text properties; one type keeps property access simple.
type Label = TextLabel

local ALIGNMENTS: { [Enum.TextXAlignment]: BitmapFont.Alignment } = {
	[Enum.TextXAlignment.Left] = "Left",
	[Enum.TextXAlignment.Center] = "Center",
	[Enum.TextXAlignment.Right] = "Right",
}

local bound: { [Instance]: { RBXScriptConnection } } = {}

local function shadowColor(label: Label): Color3?
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		return stroke.Color
	end
	if label.TextStrokeTransparency < 1 then
		return label.TextStrokeColor3
	end
	return nil
end

-- Destroys the old line once every glyph of the new one has loaded (or after SWAP_TIMEOUT seconds).
local SWAP_TIMEOUT = 0.25

local function swapWhenLoaded(old: Frame, new: Frame): ()
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(): ()
		local loaded = true
		for _, child in new:GetChildren() do
			if child:IsA("ImageLabel") and not child.IsLoaded then
				loaded = false
				break
			end
		end
		if loaded or new.Parent == nil or os.clock() - started > SWAP_TIMEOUT then
			connection:Disconnect()
			old:Destroy()
		end
	end)
end

function BitmapLabels.Bind(instance: Instance): ()
	if bound[instance] ~= nil or not (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
		return
	end
	-- Templates (StarterGui, ReplicatedStorage) are left alone; only their live clones are drawn.
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not ((playerGui ~= nil and instance:IsDescendantOf(playerGui)) or instance:IsDescendantOf(workspace)) then
		return
	end
	local label = (instance :: any) :: Label
	local line: Frame? = nil
	local drawnText: string? = nil
	label.MaxVisibleGraphemes = 0
	-- A clone of a drawn label arrives with its source's glyphs; draw it fresh.
	for _, child in label:GetChildren() do
		if child.Name == "BitmapText" and child:IsA("Frame") then
			child:Destroy()
		end
	end
	-- A contextual UIStroke would outline the hidden text's box; its color lives on as the shadow.
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local shadow = shadowColor(label)
	if stroke ~= nil and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		stroke.Enabled = false
	end

	local function redraw(): ()
		if label.Text == drawnText then
			return
		end
		drawnText = label.Text
		-- Fresh ImageLabels show nothing until their image is bound, so the old text stays up until the new glyphs load.
		local old = line
		line = nil
		if label.Text == "" then
			if old ~= nil then
				old:Destroy()
			end
			return
		end
		local newLine = BitmapFont.Render(Jersey15, label.Text, label, {
			Name = "BitmapText",
			Color = label.TextColor3,
			Transparency = label.TextTransparency,
			Alignment = ALIGNMENTS[label.TextXAlignment] or "Center",
			ShadowColor = shadow,
		})
		-- A fixed TextSize sets the line height; TextScaled labels fill their box.
		if not label.TextScaled then
			newLine.Size = UDim2.new(1, 0, 0, label.TextSize)
		end
		line = newLine
		if old ~= nil then
			swapWhenLoaded(old, newLine)
		end
	end

	bound[instance] = {
		label:GetPropertyChangedSignal("Text"):Connect(redraw),
		label:GetPropertyChangedSignal("TextColor3"):Connect(function(): ()
			if line ~= nil then
				BitmapFont.SetColor(line, label.TextColor3)
			end
		end),
		label:GetPropertyChangedSignal("TextTransparency"):Connect(function(): ()
			if line ~= nil then
				BitmapFont.SetTransparency(line, label.TextTransparency)
			end
		end),
	}
	redraw()
end

function BitmapLabels.Unbind(instance: Instance): ()
	local connections = bound[instance]
	if connections == nil then
		return
	end
	bound[instance] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
end

return BitmapLabels
