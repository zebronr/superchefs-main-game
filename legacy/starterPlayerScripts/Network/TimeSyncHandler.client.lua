local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NetworkRemotes = Remotes:WaitForChild("Network")
local TimeSync = NetworkRemotes:WaitForChild("TimeSync")

local function sync()
    local bestOffsetThisRound = math.huge

    for i = 1, 5 do
        local sendTime = tick()
        local serverTime = TimeSync:InvokeServer()
        local receiveTime = tick()
    
        local rtt = receiveTime - sendTime
        local oneWayDelay = rtt / 2
        local offset = serverTime - (receiveTime - oneWayDelay)
    
        if offset < bestOffsetThisRound then
            bestOffsetThisRound = offset
        end
    
        task.wait(0.1)
    end
    --print(bestOffsetThisRound)
    ReplicatedStorage:SetAttribute("timeOffset", bestOffsetThisRound)
end

for i=1, 5 do
    sync()
    task.wait(3)
end

while true do
    for i=1, 5 do
        sync()
    end
    task.wait(60)
end