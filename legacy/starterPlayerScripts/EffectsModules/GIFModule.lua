local module = {}

local RunService = game:GetService("RunService")

local loadedAnimations = {}

function module.load(label, frames, rows, columns, fps, full60fps)
    local anim = {}
    anim.label = label
    anim.frames = frames
    anim.rows = rows
    anim.columns = columns
    anim.fps = fps
    anim.full60fps = full60fps
    anim.running = false

    local frameWidth, frameHeight = 1/columns, 1/rows 

    anim.frameWidth = frameWidth
    anim.frameHeight = frameHeight

    loadedAnimations[label] = anim

    return anim
end

function module.loadFrame(label, frame)
    local loaded = loadedAnimations[label]
    
	local currentRow = 0
	local currentColumn = 0

    currentColumn = (frame - 1) % loaded.columns
	currentRow = math.floor((frame - 1) / loaded.columns)

	loaded.label.ImageRectSize = Vector2.new(loaded.frameWidth * loaded.label.ImageRectSize.X, loaded.frameHeight * loaded.label.ImageRectSize.Y)

	local spriteSheetWidth = 1024 
	local spriteSheetHeight = 1024

	local framePixelWidth = spriteSheetWidth / loaded.columns
	local framePixelHeight = spriteSheetHeight / loaded.rows

	loaded.label.ImageRectSize = Vector2.new(framePixelWidth, framePixelHeight)
	loaded.label.ImageRectOffset = Vector2.new(currentColumn * framePixelWidth, currentRow * framePixelHeight)
end

function module.playGIF(label)
    local loaded = loadedAnimations[label]

	if loaded.running then return end 
	loaded.running = true

	local currentFrame = 1
	local currentRow = 0
	local currentColumn = 0

	while currentFrame <= loaded.frames do
		if not loaded.full60fps then 
			wait(1/loaded.fps) 
		else 
			RunService.Stepped:Wait() 
		end

		currentColumn = (currentFrame - 1) % loaded.columns
		currentRow = math.floor((currentFrame - 1) / loaded.columns)

		loaded.label.ImageRectSize = Vector2.new(loaded.frameWidth * loaded.label.ImageRectSize.X, loaded.frameHeight * loaded.label.ImageRectSize.Y)

		local spriteSheetWidth = 1024 
		local spriteSheetHeight = 1024

		local framePixelWidth = spriteSheetWidth / loaded.columns
		local framePixelHeight = spriteSheetHeight / loaded.rows

		loaded.label.ImageRectSize = Vector2.new(framePixelWidth, framePixelHeight)
		loaded.label.ImageRectOffset = Vector2.new(currentColumn * framePixelWidth, currentRow * framePixelHeight)

		currentFrame = currentFrame + 1
	end
	loaded.running = false
end

return module