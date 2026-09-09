local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
   Name = "Auto Rock Cracker, Shop & Upgrades",
   LoadingTitle = "กำลังโหลด...",
   LoadingSubtitle = "โดย โม",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "RockCrackerConfig",
      FileName = "Config"
   },
   Discord = { Enabled = false, Invite = "noinvite", RememberJoins = true },
   KeySystem = false
})

-- ============================================
-- สร้าง Tabs
-- ============================================
local MainTab = Window:CreateTab("หน้าหลัก", 4483362458)
local UpgradeTab = Window:CreateTab("อัปเกรด", 4483362458)

MainTab:CreateSection("ระบบทุบหินและขายของ")
UpgradeTab:CreateSection("อัปเกรดด้วยเงินสด")

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"):WaitForChild("_remotes")

local CrackEvent = RemoteFolder:WaitForChild("CrackService"):WaitForChild("RemoteEvent")
local SellFunction = RemoteFolder:WaitForChild("SellService"):WaitForChild("RemoteFunction")
local UpgradeFunction = RemoteFolder:WaitForChild("UpgradeService"):WaitForChild("RemoteFunction")

local sellCFrame = CFrame.new(198.20314, 250.298203, -262.992493, -0.0905852616, 1.24811503e-08, 0.99588871, 1.47850454e-10, 1, -1.25192274e-08, -0.99588871, -9.86814963e-10, -0.0905852616)

local function teleportTo(cf)
   local character = LocalPlayer.Character
   if character and character:FindFirstChild("HumanoidRootPart") then
      character.HumanoidRootPart.CFrame = cf
   end
end

-- ============================================
-- ฟังก์ชันเกม
-- ============================================
local autoFarmRunning = false
MainTab:CreateToggle({
   Name = "ออโต้ทุบหิน",
   CurrentValue = false,
   Flag = "OneButtonAutoCrack",
   Callback = function(Value)
      autoFarmRunning = Value
      if autoFarmRunning then
         CrackEvent:FireServer("setCrackingVisible", true)
         Rayfield:Notify({ Title = "เปิดใช้งาน", Content = "เริ่มออโต้ทุบหินแล้ว!", Duration = 2 })
         task.spawn(function()
            while autoFarmRunning do
               CrackEvent:FireServer("hitRock")
               task.wait(0.1)
            end
         end)
      else
         Rayfield:Notify({ Title = "ปิดใช้งาน", Content = "หยุดออโต้ทุบหินแล้ว", Duration = 2 })
      end
   end,
})

MainTab:CreateButton({
   Name = "วาร์ปไปจุดขายของทันที",
   Callback = function()
      teleportTo(sellCFrame)
      Rayfield:Notify({ Title = "เทเลพอร์ต", Content = "วาร์ปมาที่จุดขายแล้ว!", Duration = 2 })
   end,
})

MainTab:CreateButton({
   Name = "ขายของทั้งหมด (Sell All)",
   Callback = function()
      pcall(function() SellFunction:InvokeServer("sellAll") end)
      Rayfield:Notify({ Title = "สำเร็จ", Content = "ขายไอเทมทั้งหมดเรียบร้อย!", Duration = 2 })
   end,
})

local autoSellRunning = false
MainTab:CreateToggle({
   Name = "ออโต้ขายของ (วาร์ปไปขาย แล้ววาร์ปกลับ)",
   CurrentValue = false,
   Flag = "AutoSellToggle",
   Callback = function(Value)
      autoSellRunning = Value
      task.spawn(function()
         while autoSellRunning do
            pcall(function()
               local char = LocalPlayer.Character
               if char and char:FindFirstChild("HumanoidRootPart") then
                  local old = char.HumanoidRootPart.CFrame
                  teleportTo(sellCFrame)
                  task.wait(0.3)
                  SellFunction:InvokeServer("sellAll")
                  task.wait(0.3)
                  teleportTo(old)
               end
            end)
            task.wait(10)
         end
      end)
   end,
})

local function buyUpgrade(statType, amount)
   local ok = pcall(function()
      if amount == "Max" then
         UpgradeFunction:InvokeServer("buyCashMax", statType)
      else
         UpgradeFunction:InvokeServer("buyCash", statType, amount)
      end
   end)
   if ok then
      Rayfield:Notify({ Title = "อัปเกรดสำเร็จ", Content = "อัปเกรด "..statType.." เรียบร้อย!", Duration = 1.5 })
   end
end

UpgradeTab:CreateButton({ Name = "อัปเกรดโชค (Luck) +1",            Callback = function() buyUpgrade("Luck", 1) end })
UpgradeTab:CreateButton({ Name = "อัปเกรดโชคสูงสุด (Luck Max)",     Callback = function() buyUpgrade("Luck", "Max") end })
UpgradeTab:CreateButton({ Name = "อัปเกรดมูลค่า (Value) +1",         Callback = function() buyUpgrade("Value", 1) end })
UpgradeTab:CreateButton({ Name = "อัปเกรดมูลค่าสูงสุด (Value Max)",  Callback = function() buyUpgrade("Value", "Max") end })
UpgradeTab:CreateButton({ Name = "อัปเกรดความเร็ว (Speed) +1",       Callback = function() buyUpgrade("Speed", 1) end })
UpgradeTab:CreateButton({ Name = "อัปเกรดความเร็วสูงสุด (Speed Max)", Callback = function() buyUpgrade("Speed", "Max") end })