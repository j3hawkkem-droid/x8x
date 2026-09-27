-- https://www.roblox.com/games/17450551531 | Co-op coded with @Leadmarker

local service = setmetatable({}, {
    __index = function(self, key)
        local service = cloneref(game:GetService(key))
        rawset(self, key, service)
        
        return rawget(self, key)
    end
})

local players = service.Players
local runservice = service.RunService
local pathfindservice =  service.PathfindingService
local replicatedstorage = service.ReplicatedStorage
local ReplicatedStorage = service.ReplicatedStorage
local EquipmentsModule = require(ReplicatedStorage.Shared.presets.equipments)
local BigNum = require(ReplicatedStorage.Packages.BigNum)
local KnitModule = require(ReplicatedStorage.Packages.knit)
local GymsList = require(ReplicatedStorage.HotControllers:WaitForChild('GymsList_Loaded'))
local WorldsModule = require(ReplicatedStorage.Shared.presets.worlds)
local LibraryModule = require(ReplicatedStorage.Shared.library)
local WorldService = KnitModule.GetService("WorldService")
local DataController = KnitModule.GetController("DataController")
local ArmWrestleInfo = require(ReplicatedStorage.Shared.minigames.ArmWrestle.Info)
local ActiveWorlds = GymsList.Config.GetActiveWorlds and GymsList.Config.GetActiveWorlds()

local Material = loadstring(game:HttpGet("https://gist.githubusercontent.com/afyzone/8874e6a5f489d7e548db2ed8f5b87004/raw/"))()
local UI = Material.Load({Title = "@cats - Gym League",Style = 1,SizeX = 500,SizeY = 400, ColorOverrides = { MainFrame = Color3.fromRGB(15,15,15), Minimise = Color3.fromRGB(68, 208, 255), MinimiseAccent = Color3.fromRGB(3, 188, 182), Maximise = Color3.fromRGB(25,255,0), MaximiseAccent = Color3.fromRGB(0,255,110), NavBar = Color3.fromRGB(15,15,15), NavBarAccent = Color3.fromRGB(255,255,255), NavBarInvert = Color3.fromRGB(15,15,15), TitleBar = Color3.fromRGB(30, 30, 30), TitleBarAccent = Color3.fromRGB(255,255,255), Overlay = Color3.fromRGB(30, 30, 30), Banner = Color3.fromRGB(30, 30, 30), BannerAccent = Color3.fromRGB(255,255,255), Content = Color3.fromRGB(85,85,85), Button = Color3.fromRGB(40, 40, 40), ButtonAccent = Color3.fromRGB(235, 235, 235), ChipSet = Color3.fromRGB(170, 170, 170), ChipSetAccent = Color3.fromRGB(100,100,100), DataTable = Color3.fromRGB(160,160,160), DataTableAccent = Color3.fromRGB(45,45,45), Slider = Color3.fromRGB(45,45,45), SliderAccent = Color3.fromRGB(235,235,235), Toggle = Color3.fromRGB(230, 230, 230), ToggleAccent = Color3.fromRGB(235, 235, 235), Dropdown = Color3.fromRGB(45, 45, 45), DropdownAccent = Color3.fromRGB(235,235,235), ColorPicker = Color3.fromRGB(10, 10, 10), ColorPickerAccent = Color3.fromRGB(235,235,235), TextField = Color3.fromRGB(55,55,55), TextFieldAccent = Color3.fromRGB(235,235,235), }})

local client = players.LocalPlayer
local playergui = client:WaitForChild('PlayerGui')
local label_timer = workspace.Podium.entrance.billboard.billboard.labelTimer
local label_text = workspace.Podium.entrance.billboard.billboard.labelText

local powerups, fast_mode = {}, {
    ['Stamina'] = false,
    ['Chest'] = true,
    ['Triceps'] = not workspace.Equipments:FindFirstChild('triceppushdown'),
    ['Shoulder'] = true,
    ['Abs'] = true,
    ['Forearm'] = true,
    ['Legs'] = false,
    ['Back'] = true,
    ['Biceps'] = true,
    ['Calves'] = true,
}

-- local equipment_rewards = {
--     ['Stamina'] = 'treadmill',
--     ['Chest'] = 'benchpress',
--     ['Triceps'] = workspace.Equipments:FindFirstChild('triceppushdown') and 'triceppushdown' or 'tricepscurl',
--     ['Shoulder'] = 'pushpress',
--     ['Abs'] = 'crunch',
--     ['Forearm'] = 'wristcurl',
--     ['Legs'] = 'legpress',
--     ['Back'] = 'deadlift',
--     ['Biceps'] = 'hammercurl',
--     ['Calves'] = 'frontsquat',
-- }

local Equipments = {} -- {['hammercurl'] = {['Biceps'] = 0.7, ['Forearm'] = 0.3}, ...}
local EquipmentNaming = {}
for Index, EquipmentInfo in EquipmentsModule do
	if type(EquipmentInfo) == 'table' and (EquipmentInfo.type == 'machine' or EquipmentInfo.type == 'weight' or EquipmentInfo.type == 'treadmill') then
        Equipments[Index] = EquipmentInfo.earnings
        table.insert(EquipmentNaming, Index)
	end
end

local function GetBestEquipmentName(Muscle, EncodedMuscles, World)
    local Highest, Best = 0, nil

    for MachineName, Info in Equipments do
        local Machine = workspace.Equipments:FindFirstChild(MachineName)
        if not Machine then continue end

        local Stat = Info[Muscle]
        if not Stat then continue end

        local Req = EquipmentsModule.required(MachineName, World)
        if Req then
            local CanUse = true
            for RequiredMuscle, RequiredValue in pairs(Req) do
                local PlayerEncoded = EncodedMuscles[RequiredMuscle] or "0"
                local PlayerStat = BigNum.fromString64(PlayerEncoded):native()
                if PlayerStat < RequiredValue then
                    CanUse = false
                    break
                end
            end
            if not CanUse then continue end
        end

        if Stat > Highest then
            Highest = Stat
            Best = MachineName
        end
    end

    return Best
end

for Index, Connection in getconnections(client.Idled) do
    Connection:Disconnect()
end

for i,v in (playergui.Frames.GymStore.PowerUps.CanvasGroup.List:GetChildren()) do
    if (not v:IsA('Frame')) then continue end

    powerups[v.Name] = false
end

local get_char, get_backpack, get_root, get_hum; do 
    get_char = function(player)
        return player.Character
    end

    get_root = function(char)
        return char and char:FindFirstChild('HumanoidRootPart')
    end

    get_hum = function(char)
        return char and char:FindFirstChildWhichIsA('Humanoid')
    end

    get_backpack = function(player)
        return player:FindFirstChildWhichIsA('Backpack')
    end
end

local script_handler = {}; do
    script_handler.__index = script_handler

    function script_handler.new() 
        local self = setmetatable({}, script_handler)
        self.debounces = {}
        self.fast_mode_delay = 0
        self.current_path = nil
        self.current_farming = nil
        self.current_farming_instance = nil

        self.manual_farm = nil
        self.farmmode = false
        self.autofarm = false

        self.farmstatus = 'Disabled'

        self.enable_fast_mode = false
        self.fast_mode = false

        self.manual = false
        
        self.auto_click = false
        self.autocomp = false
        self.comp_yield = false

        self.auto_alter = false
        self.auto_trainer = false
        
        self.auraautoroll = false
        self.buyaurarolls = false

        self.buy_powerup = false
        self.use_powerup = false
        self.use_all_powerups = false
        self.selected_powerup = {}

        self.ClientData = DataController:GetData()._replica.Data

        self.auto_dailygift = false
        self.auto_fortune = false
        self.auto_roulette = false
        self.auto_galaxy = false
        self.auto_battlepass = false
        self.auto_battlepass_premium = false
        self.auto_eventquest = false
        self.auto_gear = false
        self.buygear = false
        self.autoclaim_clan = false
        self.auto_squidgame = false
        self.auto_trainmods = false

        self._knitBase = nil

        -- self.ui_funcs = {}; do
        --     for i,v in (equipment_rewards) do
        --         self.ui_funcs[i] = function(self)
        --             self.SetText(v)
        --         end
        --     end
        -- end

        return self
    end 

    function script_handler:update_farm(text: string)
        if (not self.manual and self.current_farming ~= text) then 
            self:call('EquipmentService', 'RF', 'Leave')
            self.current_farming_instance = nil
        end

        self.farmstatus = text
        self.current_farming = text
    end
 
    function script_handler:toggle_autofarm(state: boolean) 
        self.autofarm = state
        
        if (not self.autofarm) then 
            self:call('EquipmentService', 'RF', 'Leave')
            self.current_farming_instance = nil
        end
    end
    
    function script_handler:get_equipment(name: string)
        local dist, closest, prompt = math.huge
        local char = get_char(client)
        local root = get_root(char)

        if not (char and root) then return end

        for i,v in (workspace:FindFirstChild('Equipments'):GetChildren()) do
            if (v.Name ~= name) then continue end
            if (self.current_farming_instance) then
                if (self.current_farming_instance ~= v and v:GetAttribute('occupied')) then continue end
            else
                if (v:GetAttribute('occupied')) then continue end
            end

            local mag = vector.magnitude(v:GetPivot().Position - root.Position)

            if (mag < dist) then
                dist = mag
                closest = v
                prompt = v:FindFirstChildWhichIsA('Part'):FindFirstChildWhichIsA('ProximityPrompt')
            end
        end

        return closest, prompt
    end
    
    function script_handler:grab_stamina()
        local Stamina = BigNum.fromString64(client:GetAttribute('stamina') or BigNum.One)
        local MaxStamina = BigNum.fromString64(client:GetAttribute('maxStamina') or BigNum.One)

        return (Stamina:native() / MaxStamina:native()) * 100
    end
    
    function script_handler:grab_cash()
        local Cash = BigNum.fromString64(self.ClientData.cash or BigNum.One)

        return Cash:native()
    end

    function script_handler:move(pos: Vector3)
        local char = get_char(client)
        local humanoid = get_hum(char)
        local root = get_root(char)

        if not (humanoid and root) then return end

        -- humanoid:MoveTo(pos)
        if (vector.magnitude(pos - root.Position) > 0.2) then
            humanoid.WalkToPoint = pos
        end
    end

    function script_handler:pathmove(pos: Vector3)
        if (self.current_path) then return end
        self.current_path = true
        local char = get_char(client)
        local hum = get_hum(char)
        local root = get_root(char)
    
        if (char and hum and root) then
            if (hum.SeatPart) then
                hum.Sit = false
            end
    
            local path = pathfindservice:CreatePath({AgentRadius = 3, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4})

            local success = pcall(function()
                path:ComputeAsync(root.Position, pos)

                if path.Status ~= Enum.PathStatus.Success then
                    local SpawnLocation = workspace.Map:FindFirstChild('SpawnLocation')
                    root.CFrame = SpawnLocation.CFrame + vector.create(0, 4, 0)
                    return
                end

                local waypoints = path:GetWaypoints()
    
                for _, waypoint in (waypoints) do
                    local waypointPosition = waypoint.Position
                    self:move(waypointPosition)
    
                    local distance = vector.magnitude(waypointPosition - root.Position)

                    while (distance > 5) do
                        local char = get_char(client)
                        local hum = get_hum(char)

                        if (not self.current_path or not hum or hum.MoveToPoint == vector.zero) then break end

                        self:move(waypointPosition)
                        distance = vector.magnitude(waypointPosition - root.Position)

                        task.wait()
                    end
                    if (not self.current_path) then return end
                end
            end)
    
            -- if (not success) then
            --     self:move(pos)
            -- end
        end
        self.current_path = nil
    end

    function script_handler:can_collide(bool: boolean)
        local char = get_char(client)
        if (not char) then return end 

        for i, v in char:GetDescendants() do 
            if (not v:IsA('BasePart')) then continue end 
            v.CanCollide = bool 
        end
    end

    function script_handler:get_knit_service(service)
        if not self._knitBase then
            for _, child in ipairs(replicatedstorage.Packages._Index:GetChildren()) do
                if child.Name:find("sleitnick_knit@") then
                    self._knitBase = child:FindFirstChild("knit") or child
                    break
                end
            end
        end
        if not self._knitBase then return end
        local ServicesFolder = self._knitBase:FindFirstChild("Services")
        if not ServicesFolder then return end
        return ServicesFolder:FindFirstChild(service)
    end

    function script_handler:call(service, folder, remote, ...)
        local remote_service = self:get_knit_service(service)
        local remote_folder = remote_service and remote_service[folder]
        local remoteObj = remote_folder and remote_folder[remote]
        local args = {...}

        if (not remoteObj) then return end

        if (remoteObj:IsA('RemoteEvent') or remoteObj:IsA('UnreliableRemoteEvent')) then
            return remoteObj:FireServer(unpack(args))
        end
        
        if (remoteObj:IsA('RemoteFunction')) then
            return remoteObj:InvokeServer(unpack(args))
        end
    end

    function script_handler:roll(service, buy)
        if (buy) then
            self:call(service, 'RF', 'Buy')
        end

        self:call(service, 'RF', 'Spin')
    end

    function script_handler:update()
        local char = get_char(client)
        local root = get_root(char)
        local hum = get_hum(char)

        if self.AutoFarmTextField then
            self.AutoFarmTextField:SetText('Status: '..self.farmstatus)
        end

        if self.autonextworld then
            self:unlock_world()
            self:try_next_world()
        end

        if self.auto_trainer then
            local Id = (self.ClientData.ownedTrainers or 0) + 1
            local TrainerData = LibraryModule.trainers[Id]
            local TrainerPrice = TrainerData and TrainerData.price
            local ClientCash = self:grab_cash()

            if TrainerPrice and ClientCash and ClientCash >= TrainerPrice then
                self:call('TrainerService', 'RF', 'NextTrainer', Id)
            end
        end

        if not (char and hum and root) then 
            self.current_path = nil
            return 
        end

        self:competition()
        if (self.comp_yield) then
            self.farmstatus = 'Competition'
            return
        else
            self:can_collide(client:GetAttribute('ragdolled'))
        end

        if (self.buy_powerup or self.use_powerup) then
            for i,v in (self.selected_powerup) do
                if (not self.use_all_powerups and not v) then continue end
                if (self.use_all_powerups and i == 'Milk') then continue end

                local IsActive = playergui.Main.BottomCenter.Boosts.Scrolling.Inside:FindFirstChild(i)
                if IsActive then continue end
                
                self:powerup_handler(i)
            end
        end

        if (self.auraautoroll) then
            self:roll('AuraService', self.buyaurarolls)
        end

        if (self.auraposeroll) then
            self:roll('PoseService', self.buyposerolls)
        end

        self:collect_daily_gift()
        self:spin_fortune()
        self:spin_roulette()
        self:buy_galaxy_level()
        self:claim_battlepass()
        self:complete_event_quests()
        self:roll_gear()
        self:claim_clan_rewards()
        self:join_squid_game()
        self:upgrade_training_mods()

        if (self.autoquest) then
            for Index, Quest in playergui.Frames.Quests.MainQuestsList:GetChildren() do
                local Reward = Quest:FindFirstChild('Reward')
                if not Reward or not Quest:IsA('Frame') or #Quest:GetChildren() == 0 then continue end

                if Reward.BackgroundColor3 == Color3.fromRGB(94, 255, 19) then
                    local Name = Quest.Name

                    self:call('QuestService', 'RF', 'complete', Name)
                    self:call('QuestService', 'RF', 'giveStoryQuest', Name)
                end
            end
        end

        if (self.autofarm or self.manual) then
            if (self.comp_yield) then return end

            if (root.Anchored) then
                local stamina = self:grab_stamina()

                if (stamina > 90) then 
                    self.farmmode = true
                elseif (stamina < 20) then 
                    self.farmmode = false 
                end
                
                if (self.current_farming == 'treadmill') then 
                    if (self.farmmode) then
                        self:call('EquipmentService', 'RF', 'ChangeSpeed', true)
                        
                        if (self.auto_click) then
                            self:call('EquipmentService', 'RE', 'click')
                        end
                    else
                        self:call('EquipmentService', 'RF', 'ChangeSpeed', false)
                    end
                else
                    if (self.farmmode) then 
                        self:call('EquipmentService', 'RF', 'AutoLoad')

                        -- if (not self.enable_fast_mode) then
                        --     task.spawn(function()
                        --         task.wait(0.1)
                        --         self:call('EquipmentService', 'RE', 'autoTrain', false)
                        --     end)
                        -- end

                        if (self.auto_click) then
                            self:call('EquipmentService', 'RE', 'click')
                        end
                        
                        if (self.enable_fast_mode and self.fast_mode and os.clock() - self.fast_mode_delay > 0.015) then
                            self:call('EquipmentService', 'RF', 'Leave')

                            local target, target_prompt = self:get_equipment(self.current_farming)
                            if (target and target_prompt) then 
                                root.CFrame = target:FindFirstChildWhichIsA('Part').CFrame
                                fireproximityprompt(target_prompt, 1, true)
                            end
                            
                            self.fast_mode_delay = os.clock()
                        end
                    end
                end
            else
                local target, target_prompt = self:get_equipment(self.current_farming)
                if (target and target_prompt) then 
                    self:pathmove(target:GetPivot().Position)
                    
                    if vector.magnitude(root.Position - target:GetPivot().Position) < 10 then
                        self.current_farming_instance = target
                        fireproximityprompt(target_prompt, 1, true)
                    end
                end
            end
        end
    end

    function script_handler:grab_farm()
        local current_stats = {
            ['Stamina'] = tonumber(playergui.Frames.Stats.Main.MuscleList.Stamina.Frame.APercentage.Text:match('%d+'))
        }

        for i,v in (playergui.Frames.Stats.Main.MuscleList.Stats:GetChildren()) do
            if (not v:IsA('ImageButton')) then continue end
            current_stats[v.Name] = tonumber(v.Frame.APercentage.Text:match('%d+'))
        end

        local all_stats_maxed = true
        local selected_farm = (function()
            for i,v in (current_stats) do
                if (v == 100) then continue end
                all_stats_maxed = false

                local EquipmentName = GetBestEquipmentName(i, self.ClientData.muscles, self.ClientData.currentWorld)
                if not EquipmentName then continue end

                local equipment = self:get_equipment(EquipmentName)
                if (not equipment) then continue end

                self.fast_mode = fast_mode[i]

                return EquipmentName
            end
        end)()

        if (all_stats_maxed and self.auto_alter) then
            self:call('CharacterService', 'RF', 'NextAlter')
        end
    
        if (self.manual and self.manual_farm) then
            return self.manual_farm
        end

        return selected_farm or GetBestEquipmentName('Stamina', self.ClientData.muscles, self.ClientData.currentWorld)
    end

    function script_handler:can_do_armwrestle()
        local TotalPower = BigNum.fromString64(self.ClientData.calculatedTotalPower):native()
        local MinTP = ArmWrestleInfo.WorldMinTp or 0
        if TotalPower < MinTP then return false end

        local ReqStats = ArmWrestleInfo.RecommendedStats
        if not ReqStats then return true end

        for StatName, Required in pairs(ReqStats) do
            local MuscleKey = StatName
            if StatName == "Bicep" then MuscleKey = "Biceps"
            elseif StatName == "Tricep" then MuscleKey = "Triceps" end
            local Encoded = self.ClientData.muscles[MuscleKey]
            if not Encoded then return false end
            local Actual = BigNum.fromString64(Encoded):native()
            if Actual < Required then return false end
        end

        return true
    end

    function script_handler:competition()
        if (not self.autocomp) then return end

        local podium = playergui.Podium
        local rewards = podium.RewardsFrame

        if (podium.Enabled) then
            -- replicatedstorage:WaitForChild("Shared"):WaitForChild("minigames"):WaitForChild("Competition"):WaitForChild("comm"):FireServer()

            for i,v in (getconnections(rewards.CanvasGroup.Continue.MouseButton1Up)) do
                v:Function()
            end
            
            for i,v in (getconnections(podium.winners.ok.MouseButton1Up)) do
                v:Function()
            end
        else
            if (label_timer.Text:lower():find('starting')) then 
                self.comp_yield = true

                if label_text and label_text.Text:lower():find("arm") then
                    if not self:can_do_armwrestle() then
                        self.comp_yield = false
                        return
                    end
                end

                if (os.clock() - (self.debounces['competition'] or 0) > 3) then
                    self.current_farming_instance = nil
                    -- self:can_collide(true)
                    self:call('EquipmentService', 'RF', 'Leave')
                    self:call('MiniPodiumService', 'RF', 'Teleport')

                    self.debounces['competition'] = os.clock()
                end
            else
                if (self.comp_yield) then
                    self.current_path = nil
                end
                self.comp_yield = false
            end
        end
    end

    function script_handler:powerup_handler(item)
        local char = get_char(client)
        local backpack = get_backpack(client)
        local boost = playergui.Frames.PlayerInventory.PowerUps.CanvasGroup.List:FindFirstChild(item)

        if (char and backpack) then
            -- local character_item = char:FindFirstChild(item)
            -- local backpack_item = backpack:FindFirstChild(item)

            if (boost) then
                if (self.use_powerup) then
                    -- if (backpack_item) then
                    --     backpack_item.Parent = char
                    -- end

                    -- if (character_item) then
                    --     character_item:Activate()
                    --     character_item.Parent = backpack
                    -- end
                    
                    self:call('ToolService', 'RF', 'ActivateTool', { powerupName = item, player = client })
                end
            else
                if (not boost and self.buy_powerup and os.clock() - (self.debounces[item] or 0) >= 2) then
                    self.debounces[item] = os.clock()
                    self:call('PowerUpsService', 'RF', 'Buy', item, 1)
                end
            end
        end
    end

    function script_handler:unlock_world()
        local Locked = playergui.Frames.Stats.Main.MuscleList.FullBody.Locked
        if not Locked or not Locked.Visible then return end

        self:call('WorldService', 'RF', 'unlock')
    end

    function script_handler:try_next_world()
        local BestWorld = self.ClientData.world
        if not BestWorld then return end
        local WorldData = WorldsModule[BestWorld]
        if not WorldData then return end
        if WorldData.place == game.PlaceId then return end
        
        WorldService:teleport(BestWorld)
    end

    function script_handler:collect_daily_gift()
        if not self.auto_dailygift then return end
        if os.clock() - (self.debounces['dailygift'] or 0) < 5 then return end
        self.debounces['dailygift'] = os.clock()
        self:call('DailyService', 'RE', 'GetGift')
    end

    function script_handler:spin_fortune()
        if not self.auto_fortune then return end
        if os.clock() - (self.debounces['fortune_spin'] or 0) < 3 then return end
        self.debounces['fortune_spin'] = os.clock()
        self:call('FortuneService', 'RF', 'Spin')
    end

    function script_handler:spin_roulette()
        if not self.auto_roulette then return end
        if os.clock() - (self.debounces['roulette'] or 0) < 3 then return end
        self.debounces['roulette'] = os.clock()
        self:call('RouletteService', 'RF', 'Roll')
    end

    function script_handler:buy_galaxy_level()
        if not self.auto_galaxy then return end
        if os.clock() - (self.debounces['galaxy'] or 0) < 5 then return end

        local CurrentLevel = self.ClientData.galaxyLevel or 1
        local NextLevel = CurrentLevel + 1
        local GalaxyData = LibraryModule.galaxyLevels[NextLevel]
        if not GalaxyData then return end

        local Cash = self:grab_cash()
        local Price = GalaxyData.price
        if type(Price) ~= "number" then return end

        if Cash >= Price then
            self.debounces['galaxy'] = os.clock()
            self:call('EquipmentService', 'RF', 'changeGalaxyLevel', NextLevel)
        end
    end

    function script_handler:claim_battlepass()
        if not self.auto_battlepass then return end
        if os.clock() - (self.debounces['battlepass'] or 0) < 3 then return end

        local BPData = self.ClientData
        local FreeRewards = BPData.battlepassFreeRewards or {}
        local PremiumRewards = BPData.battlepassPremiumRewards or {}
        local Level = BPData.battlepassLevel or 0

        local BattlepassData = LibraryModule.battlepass
        for Tier = 1, Level do
            local TierData = BattlepassData[Tier]
            if not TierData then break end
            local FreeReward = TierData.free
            if FreeReward and not FreeRewards[Tier] then
                self.debounces['battlepass'] = os.clock()
                self:call('BattlepassService', 'RE', 'Claim')
                break
            end

            if self.auto_battlepass_premium then
                local PremReward = TierData.premium
                if PremReward and not PremiumRewards[Tier] then
                    self.debounces['battlepass'] = os.clock()
                    self:call('BattlepassService', 'RE', 'Claim')
                    break
                end
            end
        end
    end

    function script_handler:complete_event_quests()
        if not self.auto_eventquest then return end
        if os.clock() - (self.debounces['eventquest'] or 0) < 5 then return end

        local EventQuests = self.ClientData.eventQuests
        if not EventQuests then return end

        for QuestName, QuestData in pairs(EventQuests) do
            if type(QuestData) ~= "table" then continue end
            if QuestData.isCompleted then continue end

            self.debounces['eventquest'] = os.clock()
            self:call('QuestService', 'RF', 'complete', QuestName)
            break
        end
    end

    function script_handler:roll_gear()
        if not self.auto_gear then return end
        if os.clock() - (self.debounces['gear_roll'] or 0) < 3 then return end
        self.debounces['gear_roll'] = os.clock()
        if self.buygear then
            self:call('GearService', 'RF', 'BuyGear')
        end
        self:call('GearService', 'RF', 'CollectGear')
    end

    function script_handler:claim_clan_rewards()
        if not self.autoclaim_clan then return end
        if os.clock() - (self.debounces['clan'] or 0) < 10 then return end
        self.debounces['clan'] = os.clock()
        self:call('ClanService', 'RF', 'ClaimReward')
    end

    function script_handler:join_squid_game()
        if not self.auto_squidgame then return end
        if os.clock() - (self.debounces['squid'] or 0) < 30 then return end
        self.debounces['squid'] = os.clock()
        self:call('SquidGameService', 'RF', 'Teleport')
    end

    function script_handler:upgrade_training_mods()
        if not self.auto_trainmods then return end
        if os.clock() - (self.debounces['trainmods'] or 0) < 5 then return end
        self.debounces['trainmods'] = os.clock()
        self:call('TrainingModifiersService', 'RF', 'Upgrade')
    end
end
-- ================================================================
    --  GEARS & OTHER  (added features, v3)
    --
    --  The previous version had two bugs that broke the UI:
    --    1) the KeybindButton was a `local` in one scope and a
    --       global assignment in another (different variables in
    --       Lua), so the rebind button text never updated;
    --    2) the InputBegan listener fired while a Roblox TextBox was
    --       focused, stealing keypresses intended for textboxes.
    --  Both are fixed below. CloseUI toggle now flips BOTH
    --  ScreenGui.Enabled AND MainFrame.Visible so it works regardless
    --  of which container the exploit parked the GUI in.
    -- ================================================================
    local MAX_GEAR_SLOTS = 3

    local gear_state = {
        equip_remote = nil,
        unequip_remote = nil,
        manual_path = nil,
    }

    -- ----------------------------------------------------------------
    --  shared UI handles (declared here so block_b below can write to
    --  them and the InputBegan listener can read them without turning
    --  them into Lua globals)
    -- ----------------------------------------------------------------
    local KeybindButton
    local CloseUiButton -- not strictly needed, kept for symmetry

    local function dbg(...)
        print('[Gears]', ...)
    end

    local function is_gearish(name: string): boolean
        name = string.lower(name or '')
        return name:find('gear') ~= nil
            or name:find('equip') ~= nil
            or name:find('tool') ~= nil
    end

    local function resolve_path(path: string)
        if (type(path) ~= 'string' or path == '') then return nil end

        local ok, obj = pcall(function()
            local current = game
            for _, part in ipairs(string.split(path, '.')) do
                if (part ~= 'game' and part ~= 'Game') then
                    current = current:WaitForChild(part, 3)
                end
            end
            return current
        end)

        if (ok and obj) then return obj end
        return nil
    end

    local function parse_multiplier(text)
        if (type(text) ~= 'string') then return nil end

        text = text:lower()

        local mult = text:match('x%s*(%d+%.?%d*)')
        if (mult) then return tonumber(mult) end

        local pct = text:match('+%s*(%d+%.?%d*)%s*%%')
        if (pct) then return 1 + (tonumber(pct) / 100) end

        return nil
    end

    local function scan_gear_entry(entry)
        local info = {name = entry.Name, muscle = 0, cash = 0, instance = nil}

        for _, label in ipairs(entry:GetDescendants()) do
            if (label:IsA('TextLabel') or label:IsA('TextButton')) then
                local text = label.Text or ''
                local value = parse_multiplier(text)
                if value then
                    text = text:lower()

                    if (text:find('cash') or text:find('money')) then
                        info.cash = math.max(info.cash, value)
                    elseif (text:find('muscle')) then
                        info.muscle = math.max(info.muscle, value)
                    else
                        info.muscle = math.max(info.muscle, value)
                        info.cash = math.max(info.cash, value)
                    end
                end
            end
        end

        return info
    end

    local function collect_gears()
        local gears = {}
        local by_name = {}

        local function add_gear(name: string, instance)
            if (not name or name == '') then return end

            local existing = by_name[name]
            if existing then
                if (instance and not existing.instance) then
                    existing.instance = instance
                end
                return
            end

            local info = {name = name, muscle = 0, cash = 0, instance = instance}
            by_name[name] = info
            table.insert(gears, info)
        end

        local backpack = client:FindFirstChildWhichIsA('Backpack')
        dbg('Backpack:', backpack and ('found, ' .. #backpack:GetChildren() .. ' children') or 'NOT FOUND')
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if (item:IsA('Tool')) then
                    dbg('  Backpack item:', item.Name, '(' .. item.ClassName .. ')')
                    if is_gearish(item.Name) then
                        add_gear(item.Name, item)
                    end
                end
            end
        end

        local char = client.Character
        dbg('Character:', char and 'found' or 'NOT FOUND')
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if (item:IsA('Tool')) then
                    dbg('  Character tool:', item.Name)
                    if is_gearish(item.Name) then
                        add_gear(item.Name, item)
                    end
                end
            end
        end

        -- the inventory UI sometimes opens under a different parent than
        -- `playergui.Frames` (e.g. `playergui.Main.Inventory`), so we walk
        -- every notable descendant and look for a section whose name
        -- matches any of the gear-related keywords.
        local gear_section

        local function try_descend(root)
            if (not root or gear_section) then return end

            for _, candidate in ipairs(root:GetDescendants()) do
                if (candidate:IsA('Frame') or candidate:IsA('ScrollingFrame')) then
                    local n = string.lower(candidate.Name or '')
                    if (n == 'gears' or n == 'gear' or n == 'gearsinventory' or n == 'geartab') then
                        gear_section = candidate
                        return
                    end
                end
            end
        end

        try_descend(playergui)
        try_descend(gethui and gethui())

        dbg('Gears section:', gear_section and ('found (' .. gear_section:GetFullName() .. ')') or 'NOT FOUND')

        if gear_section then
            for _, entry in ipairs(gear_section:GetDescendants()) do
                if (entry:IsA('Frame') or entry:IsA('ImageButton') or entry:IsA('TextButton')) then
                    local info = scan_gear_entry(entry)
                    if (info.muscle > 0 or info.cash > 0) then
                        dbg('  Inventory gear:', info.name,
                            'muscle x' .. info.muscle, 'cash x' .. info.cash)
                        add_gear(info.name, nil)

                        local existing = by_name[info.name]
                        existing.muscle = info.muscle
                        existing.cash = info.cash
                    end
                end
            end
        end

        if (#gears == 0) then
            dbg('NO gears found - open your inventory once so the gear section loads, then try again.')
        end

        return gears
    end

    local function call_remote(remote, ...)
        if (not remote) then return false end

        local args = {...}

        local ok = pcall(function()
            if (remote:IsA('RemoteFunction')) then
                remote:InvokeServer(unpack(args))
            elseif (remote:IsA('RemoteEvent')) then
                remote:FireServer(unpack(args))
            else
                error('not a remote')
            end
        end)

        return ok
    end

    function script_handler:invoke_gear_remote(remote, gear_name: string)
        if (call_remote(remote, gear_name)) then return true end
        if (call_remote(remote, gear_name, true)) then return true end
        if (call_remote(remote, {name = gear_name})) then return true end
        if (call_remote(remote, {gearName = gear_name})) then return true end
        return false
    end

    function script_handler:scan_gear_remotes(assign: boolean)
        local found = {}

        -- walk every plausible remote container; the game's GearService
        -- lives inside `replicatedstorage.Packages._Index.<sleitnick_knit>
        -- .knit.Services.GearService` per the existing get_knit_service
        -- path, but remotes that clients interact with are also frequently
        -- exposed directly under ReplicatedStorage.Shared.
        local function scan(root)
            if (not root) then return end
            for _, obj in ipairs(root:GetDescendants()) do
                if ((obj:IsA('RemoteEvent') or obj:IsA('RemoteFunction'))
                    and (is_gearish(obj.Name) or is_gearish(obj.Parent and obj.Parent.Name))) then
                    table.insert(found, obj)
                end
            end
        end

        scan(replicatedstorage)
        scan(shared and shared._KnitServices) -- rare executor hook
        scan(self:get_knit_service('GearService'))

        dbg(('scan finished: %d gear-ish remote(s) found'):format(#found))
        for _, obj in ipairs(found) do
            dbg('  ' .. obj.ClassName .. ' -> ' .. obj:GetFullName())
        end

        if (not assign) then return found end

        gear_state.equip_remote = nil
        gear_state.unequip_remote = nil

        for _, obj in ipairs(found) do
            local name = string.lower(obj.Name)

            if (not gear_state.equip_remote and name:find('equip') and not name:find('un')) then
                gear_state.equip_remote = obj
            elseif (not gear_state.unequip_remote
                and (name:find('unequip') or name:find('un_equip') or name == 'remove' or name == 'unequipped')) then
                gear_state.unequip_remote = obj
            end
        end

        dbg('auto-picked equip remote:', gear_state.equip_remote and gear_state.equip_remote:GetFullName() or 'none')
        dbg('auto-picked unequip remote:', gear_state.unequip_remote and gear_state.unequip_remote:GetFullName() or 'none')

        if (gear_state.equip_remote or gear_state.unequip_remote) then
            UI.Banner({Text = 'Scan done (' .. #found .. ' remote(s)). Picked: '
                .. (gear_state.equip_remote and gear_state.equip_remote.Name or 'no equip') .. ' / '
                .. (gear_state.unequip_remote and gear_state.unequip_remote.Name or 'no unequip')
                .. '. Check console output.'})
        else
            UI.Banner({Text = 'Scan found ' .. #found .. ' remote(s) but could not auto-pick. Set the manual path. See console for full list.'})
        end

        return found
    end

    function script_handler:get_gear_remote(kind: string)
        if gear_state.manual_path then
            local manual = resolve_path(gear_state.manual_path)
            if (manual and (manual:IsA('RemoteEvent') or manual:IsA('RemoteFunction'))) then
                return manual
            end
            dbg('manual path did not resolve to a remote:', gear_state.manual_path)
        end

        return (kind == 'unequip') and gear_state.unequip_remote or gear_state.equip_remote
    end

    function script_handler:equip_best_gears(kind)
        local gears = collect_gears()
        if (#gears == 0) then
            UI.Banner({Text = 'No gears found - open your inventory once, then try again. Check console [Gears] output.'})
            return
        end

        local any_multiplier = false
        for _, gear in ipairs(gears) do
            if ((gear[kind] or 0) > 0) then
                any_multiplier = true
                break
            end
        end

        if any_multiplier then
            table.sort(gears, function(a, b)
                return (a[kind] or 0) > (b[kind] or 0)
            end)
        else
            dbg('no multiplier labels readable - using scan order')
        end

        dbg('best ' .. kind .. ' gear:', gears[1].name)

        local remote = self:get_gear_remote('equip')
        if (not remote) then
            UI.Banner({Text = 'No equip remote yet - click "Scan Gear Remotes" (Gears tab) or set the manual path. Check console output.'})
            return
        end

        local equipped = 0
        for _, gear in ipairs(gears) do
            if (equipped >= MAX_GEAR_SLOTS) then break end

            if (self:invoke_gear_remote(remote, gear.name)) then
                equipped += 1
            end
        end

        UI.Banner({Text = ('Equipped %d of %d scanned gear(s) for %s.'):format(equipped, #gears, kind)})
    end

    function script_handler:unequip_gears()
        local char = get_char(client)
        local humanoid = get_hum(char)

        if humanoid then
            pcall(function() humanoid:UnequipTools() end)
        end

        local remote = self:get_gear_remote('unequip')
        if remote then
            call_remote(remote)

            local char2 = get_char(client)
            if char2 then
                for _, item in ipairs(char2:GetChildren()) do
                    if (item:IsA('Tool') and is_gearish(item.Name)) then
                        call_remote(remote, item.Name)
                    end
                end
            end
        end

        if (humanoid or remote) then
            UI.Banner({Text = 'Unequip request sent.'})
        else
            UI.Banner({Text = 'Could not unequip - click "Scan Gear Remotes" (Gears tab) and check console output.'})
        end
    end

    -- ----------------------------------------------------------------
    --  OTHER: Server Hop + Close UI keybind
    -- ----------------------------------------------------------------
    local function get_http_fn()
        local ok, fn

        ok, fn = pcall(function() return syn and syn.request end)
        if (ok and fn) then return fn end

        ok, fn = pcall(function() return http and http.request end)
        if (ok and fn) then return fn end

        ok, fn = pcall(function() return http_request end)
        if (ok and fn) then return fn end

        ok, fn = pcall(function() return request end)
        if (ok and fn) then return fn end

        return nil
    end

    function script_handler:server_hop()
        local place_id = game.PlaceId
        local job_id = game.JobId
        local teleport = service.TeleportService

        local ok = pcall(function()
            local http_fn = get_http_fn()
            assert(http_fn, 'no http request function available in this executor')

            local response = http_fn({
                Url = ('https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true'):format(place_id),
                Method = 'GET'
            })

            local decoded = service.HttpService:JSONDecode(response.Body)
            local candidates = {}

            for _, server in ipairs(decoded.data or {}) do
                if (server.id ~= job_id and (server.playing or 0) < (server.maxPlayers or 0)) then
                    table.insert(candidates, server.id)
                end
            end

            if (#candidates == 0) then
                teleport:Teleport(place_id, client)
                return
            end

            teleport:TeleportToPlaceInstance(place_id, candidates[math.random(1, #candidates)], client)
        end)

        if (not ok) then
            pcall(function() teleport:Teleport(place_id, client) end)
        end
    end

    -- ----------------------------------------------------------------
    --  Close UI wiring (Shared state)
    -- ----------------------------------------------------------------
    local close_ui_key = Enum.KeyCode.RightShift

    -- the listener and the toggle both close over these locals, so the
    -- UI block_b only has to update one of them.
    local waiting_for_bind = false

    local function find_main_window()
        -- search every common container because exploits stash ScreenGuis
        -- differently (CoreGui, PlayerGui, gethui, get_hidden_gui).
        local candidates = {}

        if gethui then table.insert(candidates, gethui()) end

        pcall(function()
            service.CoreGui and table.insert(candidates, service.CoreGui)
        end)

        table.insert(candidates, playergui)

        for _, container in ipairs(candidates) do
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if (child:IsA('ScreenGui') and child.Name:find('cats - Gym League')) then
                        return child
                    end
                end
            end
        end

        return getgenv().OldInstance
    end

    local function toggle_ui()
        local gui = find_main_window()
        if (not gui) then
            warn('[CloseUI] ScreenGui not found in any container.')
            return
        end

        -- flip BOTH ScreenGui.Enabled and the MainFrame.Visible so the
        -- hide works on every exploit regardless of where the GUI is
        -- parented. We never Destroy() the GUI - the same key will
        -- reopen it.
        local next_state = not (gui.Enabled ~= false)
        gui.Enabled = not gui.Enabled

        local main = gui:FindFirstChild('MainFrame')
        if main then
            main.Visible = gui.Enabled
        end
    end

    local function refresh_keybind_button()
        local label = 'Close UI: ' .. close_ui_key.Name
        if (KeybindButton and type(KeybindButton.SetText) == 'function') then
            pcall(function() KeybindButton:SetText(label) end)
        end
        if (CloseUiButton and type(CloseUiButton.SetText) == 'function') then
            pcall(function() CloseUiButton:SetText(label) end)
        end
    end

    local function set_close_ui_key(key)
        close_ui_key = key
        waiting_for_bind = false
        refresh_keybind_button()

        if (type(keybind_bridge.save) == 'function') then
            pcall(keybind_bridge.save, key.Name)
        end
    end

    -- Config bridge: declared here so the listener and the UI block can
    -- reach Config.save even though Config itself is defined further
    -- down in the script.
    local keybind_bridge = {}

    service.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- while rebinding: capture ONLY keyboard input. Ignore mouse,
        -- ignore Escape, ignore anything that came in while a TextBox
        -- was focused (otherwise typing in the manual remote path box
        -- would steal the keypress).
        if waiting_for_bind then
            if (input.UserInputType == Enum.UserInputType.Keyboard) then
                if (input.KeyCode == Enum.KeyCode.Escape) then
                    waiting_for_bind = false
                    refresh_keybind_button()
                    return
                end

                if (service.UserInputService:GetFocusedTextBox() == nil) then
                    set_close_ui_key(input.KeyCode)
                end
            end
            return
        end

        -- normal mode: don't fire when typing in a textbox or when
        -- Roblox has consumed the input
        if gameProcessed then return end
        if (service.UserInputService:GetFocusedTextBox()) then return end
        if (input.UserInputType ~= Enum.UserInputType.Keyboard) then return end

        if (input.KeyCode == close_ui_key) then
            toggle_ui()
        end
    end)


local handler = script_handler.new()


-- ================================================================
--  Persistent Settings  (auto save + auto load)
--  Material (this build) has no built-in config saving, so settings
--  are written to a JSON file in the executor's workspace folder and
--  re-applied automatically on the next execution.
-- ================================================================

local HttpService = service.HttpService

local CONFIG_FOLDER = 'cats_gymleague'
local CONFIG_FILE = CONFIG_FOLDER .. '/settings.json'

local Config = {
	data = {},
	saved = {},
	building = true,
	registry = {},
	restoring = {},
	ui_fired = {},
	enabled = false,
}

do
	local ok = pcall(function()
		assert(type(isfolder) == 'function')
		assert(type(makefolder) == 'function')
		assert(type(isfile) == 'function')
		assert(type(readfile) == 'function')
		assert(type(writefile) == 'function')

		if (not isfolder(CONFIG_FOLDER)) then
			makefolder(CONFIG_FOLDER)
		end
	end)

	Config.enabled = ok
end

if (Config.enabled and isfile(CONFIG_FILE)) then
	pcall(function()
		local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE))

		if (type(decoded) == 'table') then
			Config.data = decoded

			-- untouched snapshot of the settings on disk: the UI elements are
			-- built with default values (which fires their callbacks), and this
			-- snapshot is what gets restored afterwards.
			Config.saved = HttpService:JSONDecode(HttpService:JSONEncode(decoded)) or {}
		end
	end)
end

function Config.save(key: string, value)
	Config.data[key] = value

	if (not Config.enabled or Config.building) then return end

	pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode(Config.data))
	end)
end

function Config.apply_ui(element, value)
	if (type(element) ~= 'table') then return end

	local function try_methods(object)
		if (type(object) ~= 'table') then return false end

		for _, method_name in ipairs({'Set', 'SetState', 'SetValue', 'set'}) do
			local method = object[method_name]

			if (type(method) == 'function' and pcall(method, object, value)) then
				return true
			end
		end

		return false
	end

	if (try_methods(element)) then return end

	for _, key in ipairs({'Core', 'Instance', 'Object', 'Component'}) do
		if (try_methods(element[key])) then return end
	end

	for _, field in ipairs({'Enabled', 'Value', 'State', 'Toggled'}) do
		if (type(element[field]) == 'boolean') then
			pcall(function() element[field] = value end)
			return
		end
	end
end

function Config.register(key: string, element, callback, visual)
	Config.registry[key] = {element = element, callback = callback, visual = visual}
end

function Config.track(original, key: string)
	return function(state)
		Config.save(key, state)

		if (Config.restoring[key]) then
			Config.ui_fired[key] = true
		end

		if (original) then
			original(state)
		end
	end
end

function Config.PersistentToggle(parent, key: string, options)
	local original = options.Callback
	options.Callback = Config.track(original, key)

	local element = parent.Toggle(options)
	Config.register(key, element, original)

	return element
end

function Config.PersistentDropdown(parent, key: string, options)
	local original = options.Callback
	options.Callback = Config.track(original, key)

	local element = parent.Dropdown(options)

	Config.register(key, element, original, function(value)
		if (type(value) == 'string' and type(element.SetText) == 'function') then
			pcall(function() element:SetText(value) end)
		end
	end)

	return element
end

function Config.PersistentChipSet(parent, key: string, options)
	local original = options.Callback
	options.Callback = Config.track(original, key)

	local element = parent.ChipSet(options)
	Config.register(key, element, original)

	return element
end

function Config.load()
	Config.building = false

	if (not Config.enabled) then
		warn('[Config] This executor has no file functions - settings will not persist.')
		return
	end

	local restored, failed = 0, 0

	for key, entry in (Config.registry) do
		local saved = Config.saved[key]
		if (saved == nil) then continue end

		-- Ask the UI to show the saved value. If the library fires the
		-- element callback, ui_fired flips and we do not run it twice.
		Config.ui_fired[key] = false
		Config.restoring[key] = true

		if (type(entry.visual) == 'function') then
			pcall(entry.visual, saved)
		end
		Config.apply_ui(entry.element, saved)
		Config.restoring[key] = false

		-- The visual setter did not trigger the real callback (or does not
		-- exist), so start the saved behaviour manually.
		if (not Config.ui_fired[key] and type(entry.callback) == 'function') then
			if (not pcall(entry.callback, saved)) then
				failed = failed + 1
			end
		end

		-- keep the in-memory copy consistent with what was just restored
		Config.save(key, saved)

		restored = restored + 1
	end

	print(('[Config] Loaded %d saved setting(s).%s'):format(restored, failed > 0 and (" " .. failed .. " failed to apply.") or ''))
end

local PersistentToggle = Config.PersistentToggle
local PersistentDropdown = Config.PersistentDropdown
local PersistentChipSet = Config.PersistentChipSet

local main_tab = UI.New({Title = 'Main'}); do 
    main_tab.Label({Text = 'Farming'})
    
    PersistentToggle(main_tab, 'autofarm', {Text = 'Autofarm', Enabled = false, Callback = function(self)
        handler:toggle_autofarm(self)
    end, Menu = { Information = function(self) UI.Banner({Text = "Finds the best equipment to farm based on your stats." }) end}})
    handler.AutoFarmTextField = main_tab.TextField({Text = 'Status: '..handler.farmstatus, Type = 'NoSuggestions'})

    main_tab.Label({Text = 'Manual Farming'})
    PersistentToggle(main_tab, 'manual_farm', {Text = 'Manual Farm', Enabled = false, Callback = function(self)
        handler.manual = self
    end, Menu = { Information = function(self) UI.Banner({Text = "Turning on manual mode wont auto complete your stats." }) end}})

    -- main_tab.TextField({
    --     Text = "Manual Farms",
    --     Editable = false,
    --     Callback = function(Value)
    --         handler.manual_farm = Value
    --     end,
    --     Menu = handler.ui_funcs
    -- })

    PersistentDropdown(main_tab, 'manual_farm_choice', {Text = 'Choose manual farm', Options = EquipmentNaming, Callback = function(Value)
        handler.manual_farm = Value
    end})
    
    -- main_tab.Toggle({Text = 'Fast Mode (Blatant)', Enabled = false, Callback = function(self)
    --     handler.enable_fast_mode = self
    -- end, Menu = { Information = function(self) UI.Banner({Text = "Sometimes faster stat gain." }) end}})

    main_tab.Label({Text = 'Progression'})
    PersistentToggle(main_tab, 'auto_quest', {Text = 'Auto Quest', Callback = function(self)
        handler.autoquest = self
    end})
    PersistentToggle(main_tab, 'auto_world', {Text = 'Auto World', Callback = function(self)
        if self then
            local GetQuest = workspace:FindFirstChild('GetQuest', true)

            if GetQuest then
                local Prox = GetQuest:FindFirstChild('GetQuest')
                local Quest = Prox and Prox:GetAttribute('Quest')

                if Quest then
                    handler:call('QuestService', 'RF', 'giveStoryQuest', Quest)
                end
            end
        end

        handler.autonextworld = self
    end})

    PersistentToggle(main_tab, 'auto_body_alter', {Text = 'Auto Body Alter', Callback = function(self)
        handler.auto_alter = self
    end})
    PersistentToggle(main_tab, 'auto_trainer', {Text = 'Auto Trainer', Callback = function(self)
        handler.auto_trainer = self
    end})
    
    PersistentToggle(main_tab, 'auto_clicker', {Text = 'Auto Clicker', Enabled = false, Callback = function(self)
        handler.auto_click = self
    end, Menu = { Information = function(self) UI.Banner({Text = "Auto clicks for you when needed." }) end}})

end

local powerup_tab = UI.New({Title = 'PowerUps'}); do
    powerup_tab.Label({Text = 'Auto PowerUp'})

    PersistentToggle(powerup_tab, 'auto_buy_power_up', {Text = 'Auto Buy Power-Up', Callback = function(self)
        handler.buy_powerup = self
    end})

    PersistentToggle(powerup_tab, 'auto_use_power_up', {Text = 'Auto Use Power-Up', Callback = function(self)
        handler.use_powerup = self
    end})

    PersistentToggle(powerup_tab, 'choose_all_power_ups_except_milk', {Text = 'Choose All Power-Ups (Except Milk)', Callback = function(self)
        handler.use_all_powerups = self
    end})

    PersistentChipSet(powerup_tab, 'choose_powerups', {
        Text = "Choose Power-Ups",
        Callback = function(selected_powerup)
            handler.selected_powerup = selected_powerup
        end,
        Options = powerups
    })
end

local misc_tab = UI.New({Title = 'Misc'}); do
    misc_tab.Label({Text = 'Misc'})
    PersistentToggle(misc_tab, 'auto_competition', {Text = 'Auto Competition', Callback = function(self)
        handler.autocomp = self 

        if (not handler.autocomp) then
            handler.comp_yield = false
            handler.current_path = nil
        end
    end})

    misc_tab.Label({Text = 'Aura'})
    PersistentToggle(misc_tab, 'aura_roll', {Text = 'Aura Roll', Callback = function(self)
        handler.auraautoroll = self
    end})

    PersistentToggle(misc_tab, 'buy_aura_roll', {Text = 'Buy Aura Roll', Callback = function(self)
        handler.buyaurarolls = self
    end})

    misc_tab.Label({Text = 'Pose'})
    PersistentToggle(misc_tab, 'pose_roll', {Text = 'Pose Roll', Callback = function(self)
        handler.auraposeroll = self
    end})

    PersistentToggle(misc_tab, 'buy_pose_roll', {Text = 'Buy Pose Roll', Callback = function(self)
        handler.buyposerolls = self
    end})

    misc_tab.Label({Text = 'Fortune & Roulette'})
    PersistentToggle(misc_tab, 'auto_fortune_spin', {Text = 'Auto Fortune Spin', Callback = function(self)
        handler.auto_fortune = self
    end})
    PersistentToggle(misc_tab, 'auto_roulette_spin', {Text = 'Auto Roulette Spin', Callback = function(self)
        handler.auto_roulette = self
    end})

    misc_tab.Label({Text = 'Gear'})
    PersistentToggle(misc_tab, 'auto_gear_roll', {Text = 'Auto Gear Roll', Callback = function(self)
        handler.auto_gear = self
    end})
end

local progression_tab = UI.New({Title = 'Progression'}); do
    progression_tab.Label({Text = 'Daily & Battlepass'})
    PersistentToggle(progression_tab, 'auto_daily_gift', {Text = 'Auto Daily Gift', Callback = function(self)
        handler.auto_dailygift = self
    end})
    PersistentToggle(progression_tab, 'auto_battlepass_claim', {Text = 'Auto Battlepass Claim', Callback = function(self)
        handler.auto_battlepass = self
    end})
    PersistentToggle(progression_tab, 'claim_premium_too', {Text = 'Claim Premium Too', Callback = function(self)
        handler.auto_battlepass_premium = self
    end})

    progression_tab.Label({Text = 'World & Galaxy'})
    PersistentToggle(progression_tab, 'auto_galaxy_level', {Text = 'Auto Galaxy Level', Callback = function(self)
        handler.auto_galaxy = self
    end, Menu = { Information = function(self) UI.Banner({Text = "Buys next galaxy level when you can afford it." }) end}})
    PersistentToggle(progression_tab, 'auto_event_quests', {Text = 'Auto Event Quests', Callback = function(self)
        handler.auto_eventquest = self
    end})
    PersistentToggle(progression_tab, 'auto_clan_rewards', {Text = 'Auto Clan Rewards', Callback = function(self)
        handler.autoclaim_clan = self
    end})

    progression_tab.Label({Text = 'Minigames & Modifiers'})
    -- progression_tab.Toggle({Text = 'Auto Join Squid Game', Callback = function(self)
    --     handler.auto_squidgame = self
    -- end, Menu = { Information = function(self) UI.Banner({Text = "Teleports to squid game minigames when available." }) end}})
    PersistentToggle(progression_tab, 'auto_upgrade_training_mods', {Text = 'Auto Upgrade Training Mods', Callback = function(self)
        handler.auto_trainmods = self
    end, Menu = { Information = function(self) UI.Banner({Text = "Buys training modifier upgrades when affordable." }) end}})
end
local gears_tab = UI.New({Title = 'Gears'}); do
    gears_tab.Label({Text = 'Gears'})

    gears_tab.Button({Text = 'Equip Best Gears (Muscle)', Callback = function()
        handler:equip_best_gears('muscle')
    end, Menu = { Information = function(self) UI.Banner({Text = "Equips your gears with the highest muscle multiplier." }) end}})

    gears_tab.Button({Text = 'Equip Best Gears (Cash)', Callback = function()
        handler:equip_best_gears('cash')
    end, Menu = { Information = function(self) UI.Banner({Text = "Equips your gears with the highest cash multiplier." }) end}})

    gears_tab.Button({Text = 'Unequip Gears', Callback = function()
        handler:unequip_gears()
    end, Menu = { Information = function(self) UI.Banner({Text = "Unequips whatever gears you are wearing." }) end}})

    gears_tab.Label({Text = 'Gear Remote Discovery'})

    gears_tab.Button({Text = 'Scan Gear Remotes', Callback = function()
        handler:scan_gear_remotes(true)
    end, Menu = { Information = function(self) UI.Banner({Text = "Lists every gear/equip/tool remote in the console and auto-picks the equip/unequip ones." }) end}})

    gears_tab.TextField({Text = 'Manual remote path (e.g. ReplicatedStorage.Services.GearService.RF.EquipGear)', Type = 'NoSuggestions', Callback = function(value)
        gear_state.manual_path = (type(value) == 'string' and value ~= '') and value or nil
        UI.Banner({Text = gear_state.manual_path and ('Manual gear remote path set: ' .. gear_state.manual_path) or 'Manual gear remote path cleared.'})
    end})
end

local other_tab = UI.New({Title = 'Other'}); do
    other_tab.Label({Text = 'Other'})

    other_tab.Button({Text = 'Server Hop', Callback = function()
        handler:server_hop()
    end, Menu = { Information = function(self) UI.Banner({Text = "Moves you to a different public server." }) end}})

    other_tab.Label({Text = 'Close UI'})

    -- The "box" beside Close UI: a Button whose TEXT is the current
    -- keybind. Clicking it starts the rebind capture; whatever key the
    -- user presses next becomes the new toggle key, and the button
    -- text updates immediately.
    KeybindButton = other_tab.Button({
        Text = 'Close UI: ' .. close_ui_key.Name,
        Callback = function()
            waiting_for_bind = true
            local ok = pcall(function() KeybindButton:SetText('Close UI: ... (press a key)') end)
            if (not ok) then
                warn('[CloseUI] Button ref missing - try again after the tab is visible.')
            end
            UI.Banner({Text = 'Press any key to set the Close UI keybind. Escape cancels.'})
        end,
        Menu = { Information = function(self) UI.Banner({Text = "Shows the current Close UI keybind. Click it, then press a key to rebind." }) end}
    })

    other_tab.Button({Text = 'Toggle UI (Manually Close / Open)', Callback = function()
        toggle_ui()
    end, Menu = { Information = function(self) UI.Banner({Text = "Same as pressing your keybind." }) end}})
end
-- wire the keybind save bridge to the config system (Config is declared
-- further down in the script, so the bridge was empty until now)
keybind_bridge.save = function(name)
    Config.save('close_ui_key', name)
end

-- restore a previously saved keybind
do
    local saved_key = Config.data['close_ui_key']
    if (type(saved_key) == 'string') then
        local ok, key = pcall(function() return Enum.KeyCode[saved_key] end)
        if (ok and key) then
            set_close_ui_key(key)
        end
    end
end


Config.load()

if shared.afy then
    shared.afy:Disconnect()
end

shared.afy = runservice.Heartbeat:Connect(function()
    handler:update_farm(handler:grab_farm())
    handler:update()
end)
