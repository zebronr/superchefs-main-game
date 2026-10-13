--!strict

local RunService = game:GetService("RunService")

local Gif = {}
local running: { [ImageLabel]: boolean } = {}
-- The coin sheet is 7 x 6 cells of 1024 / 7 by 1024 / 6 pixels; the coin fills only this part of each cell, so
-- frames are cropped to it and the coin fills its label (sized to the same 107:134 shape in Studio).
local CELL = Vector2.new(1024 / 7, 1024 / 6)
local CROP_OFFSET = Vector2.new(19, 21)
local CROP_SIZE = Vector2.new(107, 134)

local function showFrame(label: ImageLabel, frame: number): ()
	local column = (frame - 1) % 7
	local row = math.floor((frame - 1) / 7)
	label.ImageRectSize = CROP_SIZE
	label.ImageRectOffset = Vector2.new(column, row) * CELL + CROP_OFFSET
end

function Gif.Reset(label: ImageLabel): ()
	showFrame(label, 1)
end

function Gif.Play(label: ImageLabel): ()
	if running[label] then
		return
	end
	running[label] = true
	task.spawn(function(): ()
		local started = os.clock()
		while label.Parent ~= nil do
			local frame = math.floor((os.clock() - started) * 24) + 1
			if frame > 40 then
				break
			end
			showFrame(label, frame)
			RunService.RenderStepped:Wait()
		end
		running[label] = nil
	end)
end

return Gif
