local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerPet = require(ReplicatedStorage.Library.Client.PlayerPet)
local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer and LocalPlayer:GetAttribute("__LOADED")

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

local HRP = LocalPlayer.Character:WaitForChild("HumanoidRootPart")
local NLibrary = ReplicatedStorage.Library
local Network = require(NLibrary.Client.Network)
local PetNetworking = require(NLibrary.Client.PetNetworking)
local MapCmds = require(NLibrary.Client.MapCmds)

getgenv().BreakableFolder = workspace.__THINGS.Breakables

local function GetNearbyBreakables()
    local breakablesList = {}
    local CurrentZone = MapCmds.GetCurrentZone()

    for _, breakableInstance in pairs(getgenv().BreakableFolder:GetChildren()) do
        local parentID = breakableInstance:GetAttribute("ParentID")
        if parentID ~= "TimeTrial" and parentID ~= CurrentZone then continue end

        local physicalPart = breakableInstance:FindFirstChildWhichIsA("BasePart")
        if physicalPart and (physicalPart.Position - HRP.Position).Magnitude <= 1000 then
            table.insert(breakablesList, breakableInstance:GetAttribute("BreakableUID"))
        end
    end

    return breakablesList
end

local EquippedPets = {}
for _, v in pairs(PetNetworking.EquippedPets()) do
    if not EquippedPets[v.euid] then
        table.insert(EquippedPets, v.euid)
    end
end

Network.Fired("Pets_LocalPetsUpdated"):Connect(function(petData)
    for _, v in pairs(petData) do
        if not EquippedPets[v.ePet.euid] then
            table.insert(EquippedPets, v.ePet.euid)
        end
    end
end)

Network.Fired("Pets_LocalPetsUnequipped"):Connect(function(petList)
    for _, unequippedID in pairs(petList) do
        for i, euid in ipairs(EquippedPets) do
            if euid == unequippedID then
                table.remove(EquippedPets, i)
                break
            end
        end
    end
end)

local function AutoCollect()
    local function ConnectLoot(folder, eventName)
        if folder then
            folder.ChildAdded:Connect(function(item)
                task.wait()
                pcall(function()
                    Network.Fire(eventName, {item.Name})
                    item:Destroy()
                end)
            end)
        end
    end

    ConnectLoot(workspace.__THINGS:FindFirstChild("Lootbags"), 'Lootbags_Claim')
    ConnectLoot(workspace.__THINGS:FindFirstChild("Orbs"), 'Orbs: Collect')
end
AutoCollect()

hookfunction(PlayerPet.CalculateSpeedMultiplier, function() return 200 end)

local function FarmBreakables()
    local RemoteList = {}

    local PetArray = {}
    for _, ID in pairs(EquippedPets) do
        table.insert(PetArray, ID)
    end

    local BreakableArray = GetNearbyBreakables()
    local PetCount = #PetArray
    local BreakableCount = #BreakableArray

    if PetCount == 0 or BreakableCount == 0 then
        return
    end

    local PetIndex = 1
    local BreakableIndex = 1

    while PetIndex <= PetCount do
        local PetID = PetArray[PetIndex]
        local BreakableUID = BreakableArray[BreakableIndex]
        RemoteList[PetID] = BreakableUID

        PetIndex += 1
        BreakableIndex += 1
        if BreakableIndex > BreakableCount then
            BreakableIndex = 1
        end
    end

    if next(RemoteList) then
        Network.UnreliableFire("Breakables_PlayerDealDamage", BreakableArray[1])
        Network.Fire("Breakables_JoinPetBulk", RemoteList)
    end
end

task.spawn(function()
    while true do
        FarmBreakables()
        task.wait(1)
    end
end)