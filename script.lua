-- [[ Bee Swarm Simulator - Delta Optimized Framework ]] --
-- [[ Created for wkrthg-dot | Bypass Mode 2026 ]] --

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ฟังก์ชั่นหลัก: ดักจับตำแหน่งฟิลด์ดอกไม้และดูดน้ำหวานแบบปรับปรุงใหม่
task.spawn(function()
    while true do
        task.wait(0.5) -- ปรับดีเลย์ให้พอดี ไม่ให้ตัวรันค้างหรือหลุด
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local character = LocalPlayer.Character
                local rootPart = character.HumanoidRootPart
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                -- ล็อคความเร็วการเดินสำหรับ Delta 
                if humanoid then
                    humanoid.WalkSpeed = 35
                end
                
                -- ระบบฟาร์มดึงตัวไปหาดอกไม้
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

-- แจ้งเตือนขึ้นหน้าจอ
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "BSS Delta Fixed",
    Text = "สคริปต์ของพี่รันสำเร็จแล้วครับ!",
    Duration = 5
})
