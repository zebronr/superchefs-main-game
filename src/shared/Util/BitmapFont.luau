--!strict

-- Draws text from a baked font atlas (see art/fonts/bitmap_font.py): one image per font,
-- one ImageLabel per glyph cut out with ImageRectOffset/ImageRectSize. Everything is sized
-- in scale, so the text fills its parent and keeps its proportions at any resolution.

export type Glyph = {
	X: number,
	Y: number,
	Width: number,
	Height: number,
	Left: number,
	Top: number,
	Advance: number,
}

export type Font = {
	Image: string,
	AtlasSize: Vector2,
	Pixelated: boolean, -- pixel font baked at its native size: scale up with hard edges
	Ascent: number,
	LineHeight: number,
	Glyphs: { [number]: Glyph },
}

export type Alignment = "Left" | "Center" | "Right"

export type Options = {
	Color: Color3?,
	Transparency: number?,
	Alignment: Alignment?,
	ZIndex: number?,
	Name: string?,
	-- A drop shadow drawn behind the text, offset down by this fraction of the line height.
	ShadowColor: Color3?,
	ShadowOffset: number?,
}

local BitmapFont = {}

local FALLBACK = string.byte("?")
local ANCHORS: { [Alignment]: number } = { Left = 0, Center = 0.5, Right = 1 }

-- True once the atlas has been uploaded and its id written into the font module.
function BitmapFont.IsReady(font: Font): boolean
	return font.Image ~= "rbxassetid://0"
end

-- Draws `text` as one line that fits inside `parent`, and returns the line's Frame.
-- Destroy the Frame to remove the text.
function BitmapFont.Render(font: Font, text: string, parent: GuiObject, options: Options?): Frame
	local color = if options and options.Color then options.Color else Color3.new(1, 1, 1)
	local transparency = if options and options.Transparency then options.Transparency else 0
	local alignment: Alignment = if options and options.Alignment then options.Alignment else "Center"
	local zIndex = if options and options.ZIndex then options.ZIndex else parent.ZIndex

	-- Lay the glyphs out in atlas pixels first, then convert to fractions of the line.
	local placed: { { Glyph: Glyph, X: number } } = {}
	local pen = 0
	local left = 0
	local right = 0
	for _, code in utf8.codes(text) do
		local glyph = font.Glyphs[code] or font.Glyphs[FALLBACK]
		if glyph ~= nil then
			if glyph.Width > 0 then
				table.insert(placed, { Glyph = glyph, X = pen + glyph.Left })
				left = math.min(left, pen + glyph.Left)
				right = math.max(right, pen + glyph.Left + glyph.Width)
			end
			pen += glyph.Advance
		end
	end
	right = math.max(right, pen)
	local width = math.max(right - left, 1)

	local line = Instance.new("Frame")
	line.Name = if options and options.Name then options.Name else "BitmapText"
	line.BackgroundTransparency = 1
	line.AnchorPoint = Vector2.new(ANCHORS[alignment], 0.5)
	line.Position = UDim2.fromScale(ANCHORS[alignment], 0.5)
	line.Size = UDim2.fromScale(1, 1)
	line.ZIndex = zIndex
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = width / font.LineHeight
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.Parent = line

	local function draw(name: string, tint: Color3, offset: number, layer: number): ()
		for index, entry in placed do
			local glyph = entry.Glyph
			local image = Instance.new("ImageLabel")
			image.Name = `{name}{index}`
			image.BackgroundTransparency = 1
			image.Image = font.Image
			image.ImageColor3 = tint
			if font.Pixelated then
				image.ResampleMode = Enum.ResamplerMode.Pixelated
			end
			image.ImageTransparency = transparency
			image.ImageRectOffset = Vector2.new(glyph.X, glyph.Y)
			image.ImageRectSize = Vector2.new(glyph.Width, glyph.Height)
			image.Position = UDim2.fromScale((entry.X - left) / width, glyph.Top / font.LineHeight + offset)
			image.Size = UDim2.fromScale(glyph.Width / width, glyph.Height / font.LineHeight)
			image.ZIndex = layer
			image.Parent = line
		end
	end
	local shadowColor = if options then options.ShadowColor else nil
	if shadowColor ~= nil then
		draw("Shadow", shadowColor, if options and options.ShadowOffset then options.ShadowOffset else 0.08, zIndex)
		draw("Glyph", color, 0, zIndex + 1)
	else
		draw("Glyph", color, 0, zIndex)
	end
	line.Parent = parent
	return line
end

-- Recolors text drawn by Render (not its shadow).
function BitmapFont.SetColor(line: Frame, color: Color3): ()
	for _, child in line:GetChildren() do
		if child:IsA("ImageLabel") and string.sub(child.Name, 1, 5) == "Glyph" then
			child.ImageColor3 = color
		end
	end
end

return BitmapFont
