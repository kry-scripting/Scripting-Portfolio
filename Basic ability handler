-- services used across the script (players, input, ui animation, ids)
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local HttpService=game:GetService("HttpService")
local TweenService=game:GetService("TweenService")

-- local player and gui references
local plr=game.Players.LocalPlayer
local gui=plr:WaitForChild("PlayerGui")
local shop=gui:WaitForChild("ShopGui")
local frame=shop:WaitForChild("MainFrame")

-- buttons are left nil on purpose, meant to be assigned externally
local ob=nil
local cb=nil

-- basic animation timings
local ott=0.35
local ctt=0.25

-- easing settings for open / close
local oes=Enum.EasingStyle.Back
local ces=Enum.EasingStyle.Quad
local oed=Enum.EasingDirection.Out
local ced=Enum.EasingDirection.In

-- ui size & position presets
local cs=UDim2.fromScale(0,0)
local os=UDim2.fromScale(1,1)
local cp=UDim2.fromScale(0.5,0.5)
local op=UDim2.fromScale(0.5,0.5)

-- initial frame state (hidden & centered)
frame.AnchorPoint=Vector2.new(0.5,0.5)
frame.Size=cs
frame.Position=cp
frame.Visible=false

-- tween definitions
local oti=TweenInfo.new(ott,oes,oed)
local cti=TweenInfo.new(ctt,ces,ced)
local ot=TweenService:Create(frame,oti,{Size=os,Position=op})
local ct=TweenService:Create(frame,cti,{Size=cs,Position=cp})

-- prevents spamming open/close during animation
local busy=false

-- opens shop ui with animation
local function open()
	if busy then return end
	busy=true
	frame.Visible=true
	ot:Play()
	ot.Completed:Wait()
	busy=false
end

-- closes shop ui with animation
local function close()
	if busy then return end
	busy=true
	ct:Play()
	ct.Completed:Wait()
	frame.Visible=false
	busy=false
end

-- optional button bindings
if ob then
	ob.MouseButton1Click:Connect(open)
end
if cb then
	cb.MouseButton1Click:Connect(close)
end

-- lightweight custom signal system (similar to BindableEvent but cheaper)
local Signal={}
Signal.__index=Signal
function Signal.new()
	return setmetatable({_list={}},Signal)
end
function Signal:Connect(fn)
	table.insert(self._list,fn)
	return{Disconnect=function()
		for i,v in ipairs(self._list)do
			if v==fn then table.remove(self._list,i)break end
		end
	end}
end
function Signal:Fire(...)
	for _,fn in ipairs(self._list)do
		task.spawn(fn,...)
	end
end

-- utility helpers used by gameplay logic
local Util={}
function Util.clamp(v,min,max)
	if v<min then return min end
	if v>max then return max end
	return v
end
function Util.round(n)
	return math.floor(n+0.5)
end
function Util.randomChance(p)
	return math.random(1,100)<=p
end
function Util.uuid()
	return HttpService:GenerateGUID(false)
end
function Util.shuffle(t)
	for i=#t,2,-1 do
		local j=math.random(i)
		t[i],t[j]=t[j],t[i]
	end
end

-- ability object with cooldown handling
local Ability={}
Ability.__index=Ability
function Ability.new(name,cd,fn)
	return setmetatable({Name=name,Cooldown=cd,Last=0,Exec=fn},Ability)
end
function Ability:Ready()
	return os.clock()-self.Last>=self.Cooldown
end
function Ability:Use(plr)
	if not self:Ready()then return false end
	self.Last=os.clock()
	if self.Exec then self.Exec(plr)end
	return true
end

-- per-player controller holding stats, inventory, abilities
local Controller={}
Controller.__index=Controller
function Controller.new(plr)
	return setmetatable({
		Player=plr,
		Id=Util.uuid(),
		State={Health=100,Energy=50,MaxEnergy=50,Level=1,XP=0,Coins=0},
		Flags={Alive=true,InCombat=false},
		Stats={Kills=0,Deaths=0,Steps=0},
		Inventory={"Potion","Gem","Coin","Scroll","Key"},
		SelectedSlot=1,
		Abilities={},
		Signals={
			OnLevelUp=Signal.new(),
			OnDeath=Signal.new(),
			OnItemUsed=Signal.new()
		},
		DebugCounter=0
	},Controller)
end

function Controller:AddAbility(ab)
	self.Abilities[ab.Name]=ab
end

function Controller:UseAbility(name)
	local ab=self.Abilities[name]
	if not ab then return false end
	return ab:Use(self.Player)
end

-- xp & level progression
function Controller:AddXP(x)
	self.State.XP+=x
	if self.State.XP>=100 then
		self.State.XP-=100
		self.State.Level+=1
		self.State.MaxEnergy+=5
		self.Signals.OnLevelUp:Fire(self.State.Level)
	end
end

-- damage & death handling
function Controller:Damage(d)
	self.State.Health=Util.clamp(self.State.Health-d,0,100)
	if self.State.Health<=0 then
		self.Flags.Alive=false
		self.Stats.Deaths+=1
		self.Signals.OnDeath:Fire()
	end
end

function Controller:Heal(h)
	self.State.Health=Util.clamp(self.State.Health+h,0,100)
end

-- passive energy regen
function Controller:EnergyTick()
	self.State.Energy=Util.clamp(self.State.Energy+0.1,0,self.State.MaxEnergy)
end

-- inventory logic
function Controller:SelectSlot(i)
	self.SelectedSlot=Util.clamp(i,1,#self.Inventory)
end

function Controller:UseItem()
	local item=self.Inventory[self.SelectedSlot]
	if item=="Potion"then self:Heal(10)end
	if item=="Gem"then self.State.Energy+=5 end
	if item=="Coin"then self.State.Coins+=1 end
	if item=="Scroll"then self:AddXP(10)end
	if item=="Key"then self.State.Coins+=0 end
	self.Signals.OnItemUsed:Fire(item)
end

-- random background logic to make the system feel alive
function Controller:RandomJunkLogic()
	if Util.randomChance(5)then self.Stats.Steps+=1 end
	if Util.randomChance(1)then self.State.Coins+=math.random(1,3)end
	if Util.randomChance(2)then self:AddXP(1)end
end

-- default abilities setup
local function createAbilities(ctrl)
	ctrl:AddAbility(Ability.new("Dash",3,function(plr)
		ctrl.State.Energy-=5
	end))
	ctrl:AddAbility(Ability.new("Heal",5,function(plr)
		ctrl:Heal(15)
	end))
	ctrl:AddAbility(Ability.new("Burst",8,function(plr)
		if Util.randomChance(50)then ctrl:AddXP(5)end
	end))
	ctrl:AddAbility(Ability.new("Focus",6,function(plr)
		ctrl.State.Energy+=10
	end))
	ctrl:AddAbility(Ability.new("Luck",12,function(plr)
		ctrl.State.Coins+=math.random(1,5)
	end))
end

-- controller registry
local Controllers={}

-- player lifecycle
local function setup(plr)
	local c=Controller.new(plr)
	createAbilities(c)
	c.Signals.OnLevelUp:Connect(function(lv)
		c.State.Health=100
	end)
	c.Signals.OnDeath:Connect(function()
		c.State.Health=100
		c.Flags.Alive=true
	end)
	c.Signals.OnItemUsed:Connect(function(item)
		c.DebugCounter+=1
	end)
	Controllers[plr]=c
end

local function remove(plr)
	Controllers[plr]=nil
end

Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(remove)
for _,p in ipairs(Players:GetPlayers())do setup(p)end

-- keybinds for inventory & abilities
UserInputService.InputBegan:Connect(function(input,gp)
	if gp then return end
	local plr=Players.LocalPlayer
	local c=Controllers[plr]
	if not c then return end
	if input.KeyCode==Enum.KeyCode.One then c:SelectSlot(1)c:UseItem()end
	if input.KeyCode==Enum.KeyCode.Two then c:SelectSlot(2)c:UseItem()end
	if input.KeyCode==Enum.KeyCode.Three then c:SelectSlot(3)c:UseItem()end
	if input.KeyCode==Enum.KeyCode.Four then c:UseAbility("Dash")end
	if input.KeyCode==Enum.KeyCode.Five then c:UseAbility("Heal")end
end)

-- main loop driving passive systems
local tick=0
RunService.Heartbeat:Connect(function(dt)
	tick+=1
	for _,ctrl in pairs(Controllers)do
		ctrl:EnergyTick()
		ctrl:RandomJunkLogic()
		if Util.randomChance(1)then ctrl:Damage(1)end
		if tick%300==0 then ctrl:AddXP(5)end
		if Util.randomChance(1)then ctrl:UseAbility("Burst")end
		if Util.randomChance(1)then ctrl:UseAbility("Focus")end
		if Util.randomChance(1)then ctrl:UseAbility("Luck")end
	end
end)
