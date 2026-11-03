-- [[ Bee Swarm Simulator - Hyper Anti-Spaghetti Framework ]] --
-- [[ Created for wkrthg-dot | Stealth Bypass Mode 2026 ]] --

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

-- ป้องกันการเด้ง Reconnect / ป้องกัน IDLE ค้างหลุด
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
end)

-- ฟังก์ชั่นหลัก: ดักจับตำแหน่งฟิลด์ดอกไม้และดูดน้ำหวานแบบ Hyper-Fast
task.spawn(function()
    while true do
        task.wait(0.01) -- ความเร็วระดับหลุดโลก ประมวลผลก่อนแอนจินเกม
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local character = LocalPlayer.Character
                local rootPart = character.HumanoidRootPart
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                -- ล็อคความเร็วการเดินหลบหลีกบั๊ก (Speed Hack Bypass)
                if humanoid then
                    humanoid.WalkSpeed = 45
                    humanoid.HipHeight = 2 -- ยกตัวสูงขึ้นนิดหน่อยกันจมดินสปาเก็ตตี้
                end
                
                -- ค้นหาฟิลด์ดอกไม้ที่ใกล้ที่สุดเพื่อดูดพลัง
                local flowerField = Workspace:FindFirstChild("FlowerFields")
                if flowerField then
                    for _, field in pairs(flowerField:GetChildren()) do
                        -- ตรวจสอบกระเป๋าถ้ายังไม่เต็ม ให้ลุยดูดน้ำหวานทันที
                        local coreStats = LocalPlayer:FindFirstChild("CoreStats")
                        if coreStats and coreStats:FindFirstChild("Pollen") and coreStats.Pollen.Value < coreStats.MaxPollen.Value then
                            -- ยิงคำสั่งดักหน้าแอนจินเกมตรงจุดดอกไม้
                            rootPart.CFrame = field.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.5)
                        end
                    end
                end
            end
        end)
    end
end)

-- ระบบแจ้งเตือนเท่ๆ สไตล์เทพคุมเกม
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "BSS Hyper Framework",
    Text = "ระบบเจาะโค้ดสปาเก็ตตี้ทำงานแล้วครับพี่!",
    Duration = 7
})
