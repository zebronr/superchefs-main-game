--!strict

-- Hard rule: particle emitters are never Enabled. Low graphics quality thins out enabled emitters, so they stay
-- off and are fed with :Emit(), which draws the same particles on every device.

local Particles = {}

type Stream = { Last: number, Accumulator: number }

-- Weak keys: a destroyed emitter's stream goes with it (losing a fraction of a particle is harmless).
local streams: { [ParticleEmitter]: Stream } = setmetatable({}, { __mode = "k" }) :: any

-- Call every frame while the emitter should stream: emits at `rate` per second (the emitter's own Rate when
-- omitted), timed on its own clock. Turns the emitter off the first time it sees it.
function Particles.Stream(emitter: ParticleEmitter, rate: number?): ()
	local now = os.clock()
	local stream = streams[emitter]
	if stream == nil then
		emitter.Enabled = false
		streams[emitter] = { Last = now, Accumulator = 0 }
		return
	end
	-- A long gap (the emitter was paused) doesn't dump a backlog of particles.
	local dt = math.min(now - stream.Last, 0.25)
	stream.Last = now
	stream.Accumulator += (rate or emitter.Rate) * dt
	local count = math.floor(stream.Accumulator)
	if count > 0 then
		emitter:Emit(count)
		stream.Accumulator -= count
	end
end

-- Call when an emitter stops streaming, so starting again doesn't count the pause.
function Particles.Stop(emitter: ParticleEmitter): ()
	streams[emitter] = nil
end

return Particles
