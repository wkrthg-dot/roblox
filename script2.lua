repeat task.wait() until game:IsLoaded()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local rootPart = LocalPlayer.Character.HumanoidRootPart
                local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = 35 end
                local flowerFields = Workspace:FindFirstChild("FlowerFields")
                if flowerFields then
                    for _, field in pairs(flowerFields:GetChildren()) do
                        rootPart.CFrame = field.CFrame + Vector3.new(0, 3, 0)
                        task.wait(1)
                    end
                end
            end
        end)
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "BSS Fixed 100%",
    Text = "ระบบทำลายอีโก้ทำงานแล้วครับพี่!",
    Duration = 5
})
