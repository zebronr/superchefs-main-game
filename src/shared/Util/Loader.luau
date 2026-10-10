--!strict

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local Loader = {}
-- Run waits this long at most for every Start to return before it gives up waiting.
local START_TIMEOUT = 10

function Loader.LoadChildren(parent: Instance): { [string]: any }
	local children = parent:GetChildren()
	table.sort(children, function(left: Instance, right: Instance): boolean
		return left.Name < right.Name
	end)

	local modules: { [string]: any } = {}
	local dynamicRequire = require :: (ModuleScript) -> any
	for _, child in children do
		if child:IsA("ModuleScript") then
			modules[child.Name] = dynamicRequire(child)
		end
	end
	return modules
end

function Loader.Run(modules: { [string]: any }): ()
	local names: { string } = {}
	for name in modules do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in names do
		local module: Module = modules[name]
		local init = module.Init
		if init ~= nil then
			local success, message = xpcall(function()
				init(module)
			end, debug.traceback)
			if not success then
				warn(`Module {name} Init failed: {message}`)
			end
		end
	end

	local pending = 0
	for _, name in names do
		local module: Module = modules[name]
		local start = module.Start
		if start ~= nil then
			pending += 1
			task.spawn(function(): ()
				local success, message = xpcall(function()
					start(module)
				end, debug.traceback)
				if not success then
					warn(`Module {name} Start failed: {message}`)
				end
				pending -= 1
			end)
		end
	end

	-- Starts run side by side, but Run returns only once they have all returned (or timed out),
	-- so callers know every module has connected its listeners.
	local deadline = os.clock() + START_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
	if pending > 0 then
		warn(`{pending} module Start calls were still running after {START_TIMEOUT} seconds`)
	end
end

function Loader.Start(parent: Instance): ()
	Loader.Run(Loader.LoadChildren(parent))
end

return Loader
