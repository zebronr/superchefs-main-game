--!strict

local RunService = game:GetService("RunService")

local Gif = {}
local running: { [ImageLabel]: boolean } = {}

local function showFrame(label: ImageLabel, frame: number): ()
	local column = (frame - 1) % 7
	local row = math.floor((frame - 1) / 7)
	label.ImageRectSize = Vector2.new(1024 / 7, 1024 / 6)
	label.ImageRectOffset = Vector2.new(column * 1024 / 7, row * 1024 / 6)
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
