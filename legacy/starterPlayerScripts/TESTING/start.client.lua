local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local startButton = PlayerGui:WaitForChild("TESTING"):WaitForChild("ScreenGui"):WaitForChild("Start")

if LocalPlayer.Name == "zebronr" then
    startButton.Visible = true

    startButton.MouseButton1Click:Connect(function()
        game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TESTING"):WaitForChild("StartGame"):FireServer()
        startButton.Visible = false
    end)
end

