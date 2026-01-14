-- SuperMathematical Conversational System
-- written in a messy way on purpose, dont ask why some stuff exists, it just does

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ChatService = game:GetService("Chat")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InternalSeed = os.clock() * tick()
math.randomseed(InternalSeed)

local AI = {}
AI.__index = AI

local GLOBAL_COMPLEXITY_FACTOR = 1.000000137
local RESPONSE_MEMORY_DEPTH = 64
local ENTROPY_DRIFT = 0.000042
local PHI = (1 + math.sqrt(5)) / 2

local MessageHistory = {}
local PlayerEntropyMap = {}

local function clamp(v, min, max)
	if v < min then return min end
	if v > max then return max end
	return v
end

local function deepCopy(tbl)
	local copy = {}
	for k,v in pairs(tbl) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

local function pseudoHash(str)
	local h = 0
	for i = 1, #str do
		h = (h * 31 + string.byte(str, i)) % 2^32
	end
	return h
end

local function fract(x)
	return x - math.floor(x)
end

local function chaoticNoise(x)
	local v = math.sin(x * PHI) * 43758.5453123
	return fract(v)
end

local function generateEntropy(player)
	local base = PlayerEntropyMap[player.UserId]
	if not base then
		base = math.random()
	end
	base = fract(base + ENTROPY_DRIFT + chaoticNoise(base))
	PlayerEntropyMap[player.UserId] = base
	return base
end

local function tokenize(text)
	local tokens = {}
	for word in string.gmatch(text:lower(), "[%w_]+") do
		table.insert(tokens, word)
	end
	return tokens
end

local function weightedSum(tokens)
	local acc = 0
	for i, t in ipairs(tokens) do
		acc = acc + (#t * math.sin(i + #t))
	end
	return acc
end

local function primeCheck(n)
	if n < 2 then return false end
	for i = 2, math.floor(math.sqrt(n)) do
		if n % i == 0 then
			return false
		end
	end
	return true
end

local function strangeMathLayer(x)
	local a = math.sin(x) * math.cos(x / PHI)
	local b = math.log(math.abs(x) + 1)
	local c = (a + b) * GLOBAL_COMPLEXITY_FACTOR
	return c
end

local function recursivePerturb(x, depth)
	if depth <= 0 then
		return x
	end
	return recursivePerturb(
		strangeMathLayer(x + chaoticNoise(x)),
		depth - 1
	)
end

local function semanticPressure(tokens)
	local p = 0
	for _, t in ipairs(tokens) do
		p = p + pseudoHash(t) % 97
	end
	return p / (#tokens + 1)
end

local function memoryPush(entry)
	table.insert(MessageHistory, entry)
	if #MessageHistory > RESPONSE_MEMORY_DEPTH then
		table.remove(MessageHistory, 1)
	end
end

local function memoryInfluence()
	local acc = 0
	for i, v in ipairs(MessageHistory) do
		acc = acc + (v.weight or 0) * math.sin(i)
	end
	return acc
end

local function generateBaseResponse(value)
	local states = {
		"The result converges to",
		"After recalculation I get",
		"Non-linear evaluation says",
		"Empirically it ends up as",
		"Running internal math gives"
	}
	return states[(math.floor(value) % #states) + 1]
end

local function numericToPhrase(n)
	if n < 0 then
		return "a negative deviation"
	elseif n == 0 then
		return "a neutral equilibrium"
	elseif n < 1 then
		return "a fractional outcome"
	elseif primeCheck(math.floor(n)) then
		return "a prime-aligned result"
	else
		return "a composite magnitude"
	end
end

function AI:Process(player, text)
	local tokens = tokenize(text)
	local entropy = generateEntropy(player)

	local weight = weightedSum(tokens)
	local pressure = semanticPressure(tokens)

	local combined = weight * pressure * entropy
	local recursive = recursivePerturb(combined, 3)

	local memoryBias = memoryInfluence()
	local finalValue = recursive + memoryBias

	local phrase = generateBaseResponse(finalValue)
	local numericMeaning = numericToPhrase(math.abs(finalValue))

	local response =
		phrase ..
		" " ..
		string.format("%.6f", finalValue) ..
		", which maps to " ..
		numericMeaning

	memoryPush({
		player = player.UserId,
		weight = finalValue,
		time = os.clock()
	})

	return response
end

local CoreAI = setmetatable({}, AI)

local function onPlayerChatted(player, message)
	if typeof(message) ~= "string" then return end
	if #message < 1 then return end

	local reply = CoreAI:Process(player, message)

	ChatService:Chat(
		player.Character and player.Character:FindFirstChild("Head") or workspace,
		reply,
		Enum.ChatColor.Blue
	)
end

local function hookPlayer(player)
	player.Chatted:Connect(function(msg)
		onPlayerChatted(player, msg)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end

Players.PlayerAdded:Connect(hookPlayer)

-- INTERNAL LOOP (kept intentionally)
RunService.Heartbeat:Connect(function(dt)
	GLOBAL_COMPLEXITY_FACTOR = clamp(
		GLOBAL_COMPLEXITY_FACTOR + math.sin(os.clock()) * dt * 0.00001,
		0.9,
		1.1
	)
end)




-- =======================
-- EXTENDED LOGIC LAYER
-- =======================

local ResponseComposer = {}
ResponseComposer.__index = ResponseComposer

local SENTENCE_MATRIX = {
	"Based on recursive divergence, the system infers",
	"Applying higher order abstraction yields",
	"After resolving internal contradictions, result is",
	"Cross-referencing entropy layers gives",
	"Non-deterministic resolution outputs"
}

local CONNECTORS = {
	"therefore",
	"hence",
	"as a consequence",
	"which implies",
	"so basically"
}

local TAIL_PHRASES = {
	"under current constraints.",
	"given the present state.",
	"in this runtime context.",
	"assuming no external override.",
	"until entropy collapses again."
}

local function sigmoid(x)
	return 1 / (1 + math.exp(-x))
end

local function normalize(x)
	if x ~= x then return 0 end
	if x == math.huge or x == -math.huge then return 0 end
	return clamp(x, -1e6, 1e6)
end

local function vectorizeString(str)
	local v = {}
	for i = 1, #str do
		v[i] = string.byte(str, i) * math.sin(i)
	end
	return v
end

local function dot(a, b)
	local s = 0
	for i = 1, math.min(#a, #b) do
		s += a[i] * b[i]
	end
	return s
end

local function matrixCollapse(vec)
	local acc = 0
	for i, v in ipairs(vec) do
		acc += math.cos(v / (i + 1))
	end
	return acc
end

local function complexityAmplifier(x, cycles)
	local r = x
	for i = 1, cycles do
		r = math.sin(r * PHI) + math.log(math.abs(r) + 1)
	end
	return r
end

local function grammaticalNoise(seed)
	local r = chaoticNoise(seed * 999)
	if r < 0.2 then
		return ", idk"
	elseif r < 0.4 then
		return ", kinda"
	elseif r < 0.6 then
		return ", more or less"
	elseif r < 0.8 then
		return ", btw"
	end
	return ""
end

function ResponseComposer:Compose(rawValue, sourceText)
	local sentence = SENTENCE_MATRIX[(math.floor(math.abs(rawValue)) % #SENTENCE_MATRIX) + 1]
	local connector = CONNECTORS[(pseudoHash(sourceText) % #CONNECTORS) + 1]
	local tail = TAIL_PHRASES[(math.floor(rawValue * 10) % #TAIL_PHRASES) + 1]

	local amplified = complexityAmplifier(rawValue, 2)
	local confidence = sigmoid(amplified)

	local noise = grammaticalNoise(rawValue)

	return sentence ..
		" " ..
		string.format("%.4f", normalize(amplified)) ..
		", " ..
		connector ..
		" the confidence settles at " ..
		string.format("%.3f", confidence) ..
		noise ..
		" " ..
		tail
end

local Composer = setmetatable({}, ResponseComposer)

-- =======================
-- OVERRIDE CORE PROCESS
-- =======================

local OldProcess = CoreAI.Process

function CoreAI:Process(player, text)
	local baseResponse = OldProcess(self, player, text)

	local vec = vectorizeString(text)
	local collapsed = matrixCollapse(vec)

	local adjusted = collapsed * generateEntropy(player)
	local composed = Composer:Compose(adjusted, text)

	return baseResponse .. " | " .. composed
end

-- =======================
-- FLOOD / SPAM RESISTANCE
-- =======================

local FloodTracker = {}
local FLOOD_LIMIT = 6
local FLOOD_WINDOW = 4

local function floodCheck(player)
	local now = os.clock()
	FloodTracker[player.UserId] = FloodTracker[player.UserId] or {}

	local t = FloodTracker[player.UserId]
	table.insert(t, now)

	while #t > 0 and now - t[1] > FLOOD_WINDOW do
		table.remove(t, 1)
	end

	return #t <= FLOOD_LIMIT
end

local OldChatHandler = onPlayerChatted

onPlayerChatted = function(player, message)
	if not floodCheck(player) then
		ChatService:Chat(
			player.Character and player.Character:FindFirstChild("Head") or workspace,
			"System overload detected, slow down.",
			Enum.ChatColor.Red
		)
		return
	end

	OldChatHandler(player, message)
end

-- =======================
-- INTERNAL STATE DRIFT
-- =======================

local InternalClock = 0
local DriftAccumulator = 0

RunService.Stepped:Connect(function(_, dt)
	InternalClock += dt
	DriftAccumulator += math.sin(InternalClock) * dt

	if DriftAccumulator > 1 then
		ENTROPY_DRIFT = ENTROPY_DRIFT * (1 + chaoticNoise(DriftAccumulator))
		DriftAccumulator = 0
	end
end)

-- =======================
-- FINAL SYSTEM FLAG
-- =======================

_G.SuperMathAIReady = true

