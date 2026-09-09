local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer

local Packages = ReplicatedStorage:WaitForChild("Packages", 10)
if not Packages then
    warn("ไม่พบโฟลเดอร์ Packages (Timeout)")
    return
end

local Packets = require(Packages:WaitForChild("Packets"))
local client = require(Packages:WaitForChild("DataService")).client
local Configs = ReplicatedStorage:WaitForChild("Configs")
local GameConfig = require(Configs:WaitForChild("GameConfig"))
local UpgradeConfig = require(Configs:WaitForChild("UpgradeConfig"))
local HiveLayout = require(Configs:WaitForChild("HiveLayout"))
local RarityConfig = require(Configs:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ProductionMath = require(Modules:WaitForChild("ProductionMath"))
local ToolBuilderShared = require(Modules:WaitForChild("ToolBuilderShared"))
local BeeConfig = require(Configs:WaitForChild("BeeConfig"))
local MutationConfig = require(Configs:WaitForChild("MutationConfig"))

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Grow a Beehive - iOSCRIPT",
    LoadingTitle = "iOSCRIPT",
    LoadingSubtitle = "by Rayfield",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "iOSCRIPT",
        FileName = "GrowABeehive"
    },
    KeySystem = false,
})

local Tabs = {
    Main = Window:CreateTab("Main", 4483362458),
    Upgrades = Window:CreateTab("Upgrades", 4483362458),
    Delete = Window:CreateTab("Auto Delete", 4483362458),
    Settings = Window:CreateTab("Settings", 4483362458),
}

local DISCORD_LINK = "https://discord.gg/bQDT7nwyz3"

local function copyDiscord()
    if setclipboard then
        setclipboard(DISCORD_LINK)
    elseif toclipboard then
        toclipboard(DISCORD_LINK)
    end
    Rayfield:Notify({
        Title = "Discord",
        Content = "Copied Discord invite to clipboard",
        Duration = 3
    })
end

local RARITY_ORDER = {}
for _, tier in ipairs(RarityConfig.Ladder) do
    RARITY_ORDER[#RARITY_ORDER + 1] = tier.Name
end

local UPGRADE_IDS = { "BeeLuck", "BeeRolls", "FlowerLevel", "BeeSpeed", "VacuumRange" }

local RARITY_INDEX = {}
for i, name in ipairs(RARITY_ORDER) do
    RARITY_INDEX[name] = i
end

local BEE_NAMES = {}
local BEE_NAME_TO_ID = {}
for _, def in ipairs(BeeConfig.Roster) do
    if def.Id and def.Name and not BEE_NAME_TO_ID[def.Name] then
        BEE_NAMES[#BEE_NAMES + 1] = def.Name
        BEE_NAME_TO_ID[def.Name] = def.Id
    end
end
table.sort(BEE_NAMES)

local MUTATION_NAMES = {}
for _, m in ipairs(MutationConfig.List) do
    local name = type(m) == "table" and m.Name or m
    if name then
        MUTATION_NAMES[#MUTATION_NAMES + 1] = tostring(name)
    end
end
table.sort(MUTATION_NAMES)

local function getData(key)
    local ok, value = pcall(function()
        return client:get(key)
    end)
    if ok then
        return value
    end
    return nil
end

local wantedRarities = {}
local selectedUpgrades = {}
local wantedDeleteRarities = {}
local wantedDeleteBees = {}
local wantedDeleteMutations = {}

local Flags = {
    AutoRoll = false,
    RollDelay = 2,
    RollAutoBuy = true,
    RollBuyMode = "Minimum Rarity",
    RollMinRarity = "Rare",
    RollMinOdds = "0",
    RollNotify = true,

    AutoTakeHoney = false,
    AutoSellHoney = false,
    MinHoneyToSell = 0,
    HoneyDelay = 1,

    AutoEquipBest = false,
    EquipDelay = 5,

    AutoUpgrade = false,
    AutoExpandHive = false,
    UpgradeReserve = "0",
    UpgradeDelay = 1,

    AutoUpgradeBees = false,
    BeeMaxLevel = ProductionMath.MaxLevel,
    BeeMaxCost = "0",
    BeeUpgradeReserve = "0",
    BeeUpgradeDelay = 1,

    AutoBuyHives = false,
    HiveReserve = "0",
    HiveDelay = 1,

    AutoDelete = false,
    DeleteMode = "Below Minimum Rarity",
    DeleteMinRarity = "Uncommon",
    DeleteProtectMutated = true,
    DeleteKeepPerType = 0,
    DeleteMaxPerCycle = 10,
    DeleteActionDelay = 0.3,
    DeleteLoopDelay = 3,
    DeleteNotify = false,

    AntiAfk = true,
    IsUnloaded = false
}

local function shouldBuyRolled(result)
    local mode = Flags.RollBuyMode
    local minOdds = tonumber(Flags.RollMinOdds) or 0
    if (result.OddsOneInX or 1) < minOdds then
        return false
    end
    if mode == "Buy All" then
        return true
    elseif mode == "Minimum Rarity" then
        return RarityConfig.AtOrAbove(result.Rarity, Flags.RollMinRarity)
    elseif mode == "Specific Rarities" then
        if next(wantedRarities) == nil then
            return false
        end
        return wantedRarities[result.Rarity] == true
    end
    return false
end

local function doRoll()
    local ok, fired, resp = pcall(function()
        return Packets.RequestRoll:Fire()
    end)
    if not ok or not fired or type(resp) ~= "table" or type(resp.Results) ~= "table" then
        return
    end
    if not Flags.RollAutoBuy then
        return
    end
    for _, result in ipairs(resp.Results) do
        if Flags.IsUnloaded or not Flags.AutoRoll then
            return
        end
        if result.Podium and shouldBuyRolled(result) then
            local bok, bfired, bresp = pcall(function()
                return Packets.BuyBee:Fire({ Podium = result.Podium })
            end)
            if bok and bfired and type(bresp) == "table" and bresp.UUID then
                if Flags.RollNotify then
                    Rayfield:Notify({
                        Title = "Auto Roll",
                        Content = ("Bought %s (1 in %s)"):format(tostring(result.Rarity), tostring(result.OddsOneInX or 1)),
                        Duration = 3
                    })
                end
            end
            task.wait(0.15)
        end
    end
end

local function doHoney()
    if Flags.AutoTakeHoney then
        pcall(function()
            Packets.GrabHoney:Fire()
        end)
    end
    if Flags.AutoSellHoney then
        local carried = tonumber(getData("CarriedHoney")) or 0
        local minSell = tonumber(Flags.MinHoneyToSell) or 0
        if carried > 0 and carried >= minSell then
            pcall(function()
                Packets.SellHoney:Fire()
            end)
        end
    end
end

local function doEquipBest()
    pcall(function()
        Packets.EquipBest:Fire()
    end)
end

local function upgradeLevel(id, floor)
    return tonumber(getData(UpgradeConfig.LevelPath(id, floor))) or 0
end

local function tryUpgrade(id, floor, reserve)
    local level = upgradeLevel(id, floor)
    if UpgradeConfig.IsMaxed(id, level) then
        return false
    end
    local cost = UpgradeConfig.GetCost(id, level, floor)
    local cash = tonumber(getData("Cash")) or 0
    if cost == math.huge or cash - cost < reserve then
        return false
    end
    pcall(function()
        Packets.BuyUpgrade:Fire({ HiveIndex = 0, UpgradeId = id, Floor = floor })
    end)
    return true
end

local function doUpgrades()
    local reserve = tonumber(Flags.UpgradeReserve) or 0
    local revealedFloors = HiveLayout.RevealedFloors(tonumber(getData("ExpandLevel")) or 1)
    for _, id in ipairs(UPGRADE_IDS) do
        if Flags.IsUnloaded or not Flags.AutoUpgrade then
            return
        end
        if selectedUpgrades[id] then
            if UpgradeConfig.IsPerFloor(id) then
                for floor = 1, revealedFloors do
                    if tryUpgrade(id, floor, reserve) then
                        task.wait(0.15)
                    end
                end
            else
                if tryUpgrade(id, 1, reserve) then
                    task.wait(0.15)
                end
            end
        end
    end
    if Flags.AutoExpandHive then
        local expandLevel = tonumber(getData("ExpandLevel")) or 1
        if expandLevel < HiveLayout.MaxExpandLevel then
            pcall(function()
                Packets.ExpandHive:Fire()
            end)
        end
    end
end

local function doUpgradeBees()
    local hives = getData("Hives") or {}
    local reserve = tonumber(Flags.BeeUpgradeReserve) or 0
    local maxLevel = tonumber(Flags.BeeMaxLevel) or ProductionMath.MaxLevel
    local maxCost = tonumber(Flags.BeeMaxCost) or 0
    for key, entry in pairs(hives) do
        if Flags.IsUnloaded or not Flags.AutoUpgradeBees then
            return
        end
        if type(entry) == "table" and entry.BeeId and entry.Unlocked then
            local level = entry.OutputLevel or 0
            if level < maxLevel and not ProductionMath.IsMaxed(level) then
                local cost = ProductionMath.UpgradeCost(entry.BeeId, level)
                local cash = tonumber(getData("Cash")) or 0
                local costOk = cost ~= math.huge and cash - cost >= reserve
                if maxCost > 0 and cost > maxCost then
                    costOk = false
                end
                if costOk then
                    local floor, index = HiveLayout.ParseHiveKey(key)
                    if index then
                        pcall(function()
                            Packets.BuyUpgrade:Fire({ UpgradeId = "HoneyOutput", HiveIndex = index, Floor = floor })
                        end)
                        task.wait(0.15)
                    end
                end
            end
        end
    end
end

local function doBuyHives()
    local hives = getData("Hives") or {}
    local owned = 0
    for _, v in pairs(hives) do
        if v then
            owned = owned + 1
        end
    end
    local prices = GameConfig.HivePrices
    local price = prices[math.clamp(owned, 1, #prices)]
    if not price then
        return
    end
    local reserve = tonumber(Flags.HiveReserve) or 0
    local cash = tonumber(getData("Cash")) or 0
    if cash - price < reserve then
        return
    end
    local expand = tonumber(getData("ExpandLevel")) or 1
    local revealedFloors = HiveLayout.RevealedFloors(expand)
    for floor = 1, revealedFloors do
        for _, index in ipairs(HiveLayout.AllIndices()) do
            if Flags.IsUnloaded or not Flags.AutoBuyHives then
                return
            end
            local layer = HiveLayout.LayerOf(index)
            if layer and HiveLayout.IsFloorLayerUnlocked(floor, layer, expand) then
                local key = HiveLayout.HiveKey(floor, index)
                if not hives[key] then
                    pcall(function()
                        Packets.UnlockHive:Fire({ HiveIndex = index, Floor = floor })
                    end)
                    return
                end
            end
        end
    end
end

local function beeRarityName(beeId)
    local def = BeeConfig.Get(beeId)
    return def and def.Rarity
end

local function matchesDeleteFilter(entry)
    local mode = Flags.DeleteMode
    if mode == "Below Minimum Rarity" then
        local keepIdx = RARITY_INDEX[Flags.DeleteMinRarity]
        local rarity = beeRarityName(entry.BeeId)
        local idx = rarity and RARITY_INDEX[rarity]
        return keepIdx ~= nil and idx ~= nil and idx < keepIdx
    elseif mode == "Selected Rarities" then
        local rarity = beeRarityName(entry.BeeId)
        return rarity ~= nil and wantedDeleteRarities[rarity] == true
    elseif mode == "Selected Bees" then
        return wantedDeleteBees[entry.BeeId] == true
    elseif mode == "Selected Mutations" then
        return entry.Mutation ~= nil and wantedDeleteMutations[entry.Mutation] == true
    end
    return false
end

local function collectDeletable()
    local owned = getData("OwnedBees") or {}
    local counts = {}
    for _, entry in pairs(owned) do
        if type(entry) == "table" and entry.BeeId then
            counts[entry.BeeId] = (counts[entry.BeeId] or 0) + 1
        end
    end
    local keepPerType = tonumber(Flags.DeleteKeepPerType) or 0
    local protectMutated = Flags.DeleteProtectMutated
    local mode = Flags.DeleteMode
    local result = {}
    for _, entry in pairs(owned) do
        if type(entry) == "table" and entry.BeeId and entry.UUID then
            local skip = false
            if protectMutated and entry.Mutation ~= nil and mode ~= "Selected Mutations" then
                skip = true
            end
            if not skip and keepPerType > 0 and (counts[entry.BeeId] or 0) <= keepPerType then
                skip = true
            end
            if not skip and matchesDeleteFilter(entry) then
                result[#result + 1] = entry
                counts[entry.BeeId] = (counts[entry.BeeId] or 1) - 1
            end
        end
    end
    return result
end

local function toolForUUID(uuid)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    for _, container in ipairs({ backpack, character }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute(ToolBuilderShared.ATTR_UUID) == uuid then
                    return tool
                end
            end
        end
    end
    return nil
end

local function trashBee(uuid)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false
    end
    local tool = toolForUUID(uuid)
    if not tool then
        return false
    end
    humanoid:EquipTool(tool)
    task.wait()
    local held = character:FindFirstChildOfClass("Tool")
    if not held or held:GetAttribute(ToolBuilderShared.ATTR_UUID) ~= uuid then
        return false
    end
    pcall(function()
        Packets.TrashBee:Fire()
    end)
    return true
end

local function doAutoDelete()
    local candidates = collectDeletable()
    local maxPer = tonumber(Flags.DeleteMaxPerCycle) or 10
    local delay = tonumber(Flags.DeleteActionDelay) or 0.3
    local done = 0
    for _, entry in ipairs(candidates) do
        if Flags.IsUnloaded or not Flags.AutoDelete then
            return
        end
        if done >= maxPer then
            return
        end
        if trashBee(entry.UUID) then
            done = done + 1
            if Flags.DeleteNotify then
                local def = BeeConfig.Get(entry.BeeId)
                Rayfield:Notify({
                    Title = "Auto Delete",
                    Content = ("Deleted %s"):format(def and def.Name or entry.BeeId),
                    Duration = 3
                })
            end
            task.wait(delay)
        end
    end
end

local function deleteMatchingNow()
    local maxPer = tonumber(Flags.DeleteMaxPerCycle) or 10
    local delay = tonumber(Flags.DeleteActionDelay) or 0.3
    local candidates = collectDeletable()
    local done = 0
    for _, entry in ipairs(candidates) do
        if Flags.IsUnloaded or done >= maxPer then
            break
        end
        if trashBee(entry.UUID) then
            done = done + 1
            task.wait(delay)
        end
    end
    Rayfield:Notify({
        Title = "Auto Delete",
        Content = ("Deleted %d bee(s)"):format(done),
        Duration = 3
    })
end



for _, Tab in pairs(Tabs) do
    AddDiscordButton(Tab)
end

-- Main Tab
Tabs.Main:CreateSection("Auto Roll")
Tabs.Main:CreateToggle({ Name = "Auto Roll", CurrentValue = false, Flag = "AutoRoll", Callback = function(Value) Flags.AutoRoll = Value end })
Tabs.Main:CreateSlider({ Name = "Roll Delay", Range = {1.5, 10}, Increment = 0.1, Suffix = "s", CurrentValue = 2, Flag = "RollDelay", Callback = function(Value) Flags.RollDelay = Value end })
Tabs.Main:CreateToggle({ Name = "Auto Buy Rolled Bees", CurrentValue = true, Flag = "RollAutoBuy", Callback = function(Value) Flags.RollAutoBuy = Value end })
Tabs.Main:CreateDropdown({ Name = "Buy Mode", Options = { "Buy All", "Minimum Rarity", "Specific Rarities" }, CurrentOption = "Minimum Rarity", Flag = "RollBuyMode", Callback = function(Option) Flags.RollBuyMode = Option[1] or Option end })
Tabs.Main:CreateDropdown({ Name = "Minimum Rarity", Options = RARITY_ORDER, CurrentOption = "Rare", Flag = "RollMinRarity", Callback = function(Option) Flags.RollMinRarity = Option[1] or Option end })

Tabs.Main:CreateSection("Auto Honey")
Tabs.Main:CreateToggle({ Name = "Auto Take Honey", CurrentValue = false, Flag = "AutoTakeHoney", Callback = function(Value) Flags.AutoTakeHoney = Value end })
Tabs.Main:CreateToggle({ Name = "Auto Sell Honey", CurrentValue = false, Flag = "AutoSellHoney", Callback = function(Value) Flags.AutoSellHoney = Value end })
Tabs.Main:CreateSlider({ Name = "Min Honey To Sell", Range = {0, 100000}, Increment = 1, Suffix = "", CurrentValue = 0, Flag = "MinHoneyToSell", Callback = function(Value) Flags.MinHoneyToSell = Value end })
Tabs.Main:CreateSlider({ Name = "Honey Loop Delay", Range = {0.2, 10}, Increment = 0.1, Suffix = "s", CurrentValue = 1, Flag = "HoneyDelay", Callback = function(Value) Flags.HoneyDelay = Value end })

Tabs.Main:CreateSection("Auto Equip")
Tabs.Main:CreateToggle({ Name = "Auto Equip Best", CurrentValue = false, Flag = "AutoEquipBest", Callback = function(Value) Flags.AutoEquipBest = Value end })
Tabs.Main:CreateSlider({ Name = "Equip Loop Delay", Range = {1, 30}, Increment = 0.5, Suffix = "s", CurrentValue = 5, Flag = "EquipDelay", Callback = function(Value) Flags.EquipDelay = Value end })

-- Upgrades Tab
Tabs.Upgrades:CreateSection("Auto Upgrades")
Tabs.Upgrades:CreateToggle({ Name = "Auto Upgrade", CurrentValue = false, Flag = "AutoUpgrade", Callback = function(Value) Flags.AutoUpgrade = Value end })
Tabs.Upgrades:CreateToggle({ Name = "Auto Expand Hive", CurrentValue = false, Flag = "AutoExpandHive", Callback = function(Value) Flags.AutoExpandHive = Value end })
Tabs.Upgrades:CreateInput({ Name = "Keep Cash Reserve", PlaceholderText = "0", RemoveTextAfterFocusLost = false, Callback = function(Text) Flags.UpgradeReserve = Text end })
Tabs.Upgrades:CreateSlider({ Name = "Upgrade Loop Delay", Range = {0.2, 10}, Increment = 0.1, Suffix = "s", CurrentValue = 1, Flag = "UpgradeDelay", Callback = function(Value) Flags.UpgradeDelay = Value end })

Tabs.Upgrades:CreateSection("Auto Upgrade Bees")
Tabs.Upgrades:CreateToggle({ Name = "Auto Upgrade Bees", CurrentValue = false, Flag = "AutoUpgradeBees", Callback = function(Value) Flags.AutoUpgradeBees = Value end })
Tabs.Upgrades:CreateSlider({ Name = "Max Bee Level", Range = {1, ProductionMath.MaxLevel}, Increment = 1, Suffix = "", CurrentValue = ProductionMath.MaxLevel, Flag = "BeeMaxLevel", Callback = function(Value) Flags.BeeMaxLevel = Value end })
Tabs.Upgrades:CreateInput({ Name = "Max Cost Per Upgrade (0 = off)", PlaceholderText = "0", RemoveTextAfterFocusLost = false, Callback = function(Text) Flags.BeeMaxCost = Text end })
Tabs.Upgrades:CreateInput({ Name = "Keep Cash Reserve (Bees)", PlaceholderText = "0", RemoveTextAfterFocusLost = false, Callback = function(Text) Flags.BeeUpgradeReserve = Text end })

Tabs.Upgrades:CreateSection("Auto Buy Hives")
Tabs.Upgrades:CreateToggle({ Name = "Auto Buy Hives", CurrentValue = false, Flag = "AutoBuyHives", Callback = function(Value) Flags.AutoBuyHives = Value end })
Tabs.Upgrades:CreateInput({ Name = "Keep Cash Reserve (Hives)", PlaceholderText = "0", RemoveTextAfterFocusLost = false, Callback = function(Text) Flags.HiveReserve = Text end })

-- Auto Delete Tab
Tabs.Delete:CreateSection("Auto Delete Bees")
Tabs.Delete:CreateToggle({ Name = "Auto Delete Bees", CurrentValue = false, Flag = "AutoDelete", Callback = function(Value) Flags.AutoDelete = Value end })
Tabs.Delete:CreateDropdown({ Name = "Delete Filter", Options = { "Below Minimum Rarity", "Selected Rarities", "Selected Bees", "Selected Mutations" }, CurrentOption = "Below Minimum Rarity", Flag = "DeleteMode", Callback = function(Option) Flags.DeleteMode = Option[1] or Option end })
Tabs.Delete:CreateDropdown({ Name = "Delete Below Rarity", Options = RARITY_ORDER, CurrentOption = "Uncommon", Flag = "DeleteMinRarity", Callback = function(Option) Flags.DeleteMinRarity = Option[1] or Option end })

Tabs.Delete:CreateSection("Filters & Safety")
Tabs.Delete:CreateToggle({ Name = "Protect Mutated Bees", CurrentValue = true, Flag = "DeleteProtectMutated", Callback = function(Value) Flags.DeleteProtectMutated = Value end })
Tabs.Delete:CreateSlider({ Name = "Keep Per Bee Type", Range = {0, 50}, Increment = 1, Suffix = "", CurrentValue = 0, Flag = "DeleteKeepPerType", Callback = function(Value) Flags.DeleteKeepPerType = Value end })
Tabs.Delete:CreateSlider({ Name = "Max Deletes Per Cycle", Range = {1, 100}, Increment = 1, Suffix = "", CurrentValue = 10, Flag = "DeleteMaxPerCycle", Callback = function(Value) Flags.DeleteMaxPerCycle = Value end })
Tabs.Delete:CreateSlider({ Name = "Delete Action Delay", Range = {0.1, 2}, Increment = 0.05, Suffix = "s", CurrentValue = 0.3, Flag = "DeleteActionDelay", Callback = function(Value) Flags.DeleteActionDelay = Value end })
Tabs.Delete:CreateButton({ Name = "Count Matching Bees", Callback = function() Rayfield:Notify({ Title = "Auto Delete", Content = ("%d bee(s) match"):format(#collectDeletable()), Duration = 3 }) end })
Tabs.Delete:CreateButton({ Name = "Delete Matching Now", Callback = function() task.spawn(deleteMatchingNow) end })

-- Settings Tab
Tabs.Settings:CreateSection("Menu & System")
local antiAfkConnection
Tabs.Settings:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Flag = "AntiAfk",
    Callback = function(state)
        Flags.AntiAfk = state
        if state then
            if not antiAfkConnection then
                antiAfkConnection = LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        elseif antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
    end,
})

Tabs.Settings:CreateButton({
    Name = "Unload UI",
    Callback = function()
        Flags.IsUnloaded = true
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
        Rayfield:Destroy()
        print("Grow a Beehive unloaded")
    end,
})

-- Background Loops
task.spawn(function()
    while not Flags.IsUnloaded do
        if Flags.AutoRoll then doRoll() end
        task.wait(Flags.RollDelay or 1)
    end
end)

task.spawn(function()
    while not Flags.IsUnloaded do
        if Flags.AutoTakeHoney or Flags.AutoSellHoney then doHoney() end
        task.wait(Flags.HoneyDelay or 1)
    end
end)

task.spawn(function()
    while not Flags.IsUnloaded do
        if Flags.AutoEquipBest then doEquipBest() end
        task.wait(Flags.EquipDelay or 5)
    end
end)

task.spawn(function()
    while not Flags.IsUnloaded do
        if Flags.AutoUpgrade or Flags.AutoExpandHive then doUpgrades() end
        task.wait(Flags.UpgradeDelay or 1)
    end
end)

task.spawn(function()
    while not Flags.IsUnloaded do
        if Flags.AutoBuyHives then doBuyHives() end
        task.wait(Flags.HiveDelay or 1)
    end
end)

task.spawn(function()
    while not Flags.IsUnloaded do
        if Flags.AutoUpgradeBees then doUpgradeBees() end
        task.wait(Flags.BeeUpgradeDelay or 1)
    end
end)

task.spawn(function()
    while not Flags.IsUnloaded do
        if Flags.AutoDelete then doAutoDelete() end
        task.wait(Flags.DeleteLoopDelay or 3)
    end
end)

Rayfield:LoadConfiguration()
Rayfield:Notify({
    Title = "iOSCRIPT",
    Content = "Grow a Beehive loaded successfully with Rayfield UI!",
    Duration = 5
})