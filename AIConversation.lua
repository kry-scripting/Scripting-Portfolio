-- Core Roblox services are cached at the top to avoid repeated GetService calls later which are slightly slower and messier
local Players = game:GetService("Players") -- Used to track player lifecycle and user-specific state
local RunService = game:GetService("RunService") -- Provides frame-based timing without relying on deprecated loops
local ChatService = game:GetService("Chat") -- Handles in-world chat bubbles instead of legacy print-based output
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Shared storage used to avoid unsafe server-only access

-- Random seed is intentionally non-deterministic so responses never repeat between server restarts
local InternalSeed = os.clock() * tick() -- Combines two time sources so seed can't be guessed or synced
math.randomseed(InternalSeed) -- Seeds math.random globally once to avoid predictable output

-- AI table acts as a pseudo-class using metatables instead of Roblox Instances for performance and flexibility
local AI = {}
AI.__index = AI -- Allows AI:Method() syntax without polluting globals

-- Global constants are separated so reviewers can easily tune behavior without touching logic
local GLOBAL_COMPLEXITY_FACTOR = 1.000000137 -- Slight offset avoids flat math results caused by floating point symmetry
local RESPONSE_MEMORY_DEPTH = 64 -- Limits memory so system doesn't grow unbounded and lag over time
local ENTROPY_DRIFT = 0.000042 -- Small drift ensures entropy never stabilizes fully
local PHI = (1 + math.sqrt(5)) / 2 -- Golden ratio used to introduce non-linear irrational math behavior

-- Message history stores previous response weights to influence future replies
local MessageHistory = {} -- Acts like short-term memory rather than full chat logs
local PlayerEntropyMap = {} -- Stores per-player entropy so each player has unique behavior

-- Clamp utility prevents runaway values without throwing errors or hard stopping logic
local function clamp(v, min, max) -- Standard math helper reused in multiple places
	if v < min then return min end -- Lower bound enforcement
	if v > max then return max end -- Upper bound enforcement
	return v -- If in range, value is returned unchanged
end

-- Deep copy avoids table reference bugs when storing historical data
local function deepCopy(tbl) -- Necessary because Lua tables are references, not values
	local copy = {} -- New table ensures isolation
	for k,v in pairs(tbl) do -- Iterates through original table
		if type(v) == "table" then
			copy[k] = deepCopy(v) -- Recursively copies nested tables
		else
			copy[k] = v -- Primitive values are safe to assign directly
		end
	end
	return copy -- Returns fully independent structure
end

-- Pseudo-hash converts strings into numeric influence without needing crypto libraries
local function pseudoHash(str) -- Lightweight hashing purely for entropy and weighting
	local h = 0 -- Starts at zero to keep behavior predictable
	for i = 1, #str do -- Iterates over each character
		h = (h * 31 + string.byte(str, i)) % 2^32 -- 31 chosen because it's prime and fast
	end
	return h -- Result is stable but chaotic enough for weighting
end

-- Fractional extractor used to keep numbers bounded between 0 and 1
local function fract(x) -- Prevents values from exploding during recursive math
	return x - math.floor(x) -- Standard fract operation
end

-- Chaotic noise introduces pseudo-randomness without calling math.random repeatedly
local function chaoticNoise(x) -- Deterministic chaos based on input
	local v = math.sin(x * PHI) * 43758.5453123 -- Magic number commonly used for noise generation
	return fract(v) -- Only fractional part matters
end

-- Generates evolving entropy per player so responses feel alive but consistent per user
local function generateEntropy(player) -- Player-specific randomness layer
	local base = PlayerEntropyMap[player.UserId] -- Retrieve existing entropy if it exists
	if not base then
		base = math.random() -- First-time players start with true randomness
	end
	base = fract(base + ENTROPY_DRIFT + chaoticNoise(base)) -- Slowly drifts over time
	PlayerEntropyMap[player.UserId] = base -- Stored so next call builds on previous state
	return base -- Returned entropy influences response math
end

-- Tokenization breaks input into words without punctuation to simplify semantic math
local function tokenize(text) -- Avoids regex-heavy logic for speed
	local tokens = {} -- Output container
	for word in string.gmatch(text:lower(), "[%w_]+") do -- Normalizes case and strips symbols
		table.insert(tokens, word) -- Preserves order for weighted calculations
	end
	return tokens -- Used downstream for semantic pressure
end

-- Weighted sum assigns influence based on word length and position
local function weightedSum(tokens) -- Longer words later in sentence matter more
	local acc = 0 -- Accumulator
	for i, t in ipairs(tokens) do
		acc = acc + (#t * math.sin(i + #t)) -- Sin introduces non-linearity
	end
	return acc -- Represents raw semantic force
end

-- Prime checking is intentionally naive because numbers are small and infrequent
local function primeCheck(n) -- Used only for classification, not heavy computation
	if n < 2 then return false end -- 0 and 1 are not prime
	for i = 2, math.floor(math.sqrt(n)) do
		if n % i == 0 then
			return false -- Early exit on first divisor
		end
	end
	return true -- No divisors found
end

-- Strange math layer distorts values to avoid linear responses
local function strangeMathLayer(x) -- Central transformation function
	local a = math.sin(x) * math.cos(x / PHI) -- Trigonometric mixing
	local b = math.log(math.abs(x) + 1) -- Log prevents huge jumps
	local c = (a + b) * GLOBAL_COMPLEXITY_FACTOR -- Global tuning hook
	return c -- Output feeds recursive perturbation
end

-- Recursive perturbation deepens complexity without infinite loops
local function recursivePerturb(x, depth) -- Depth is capped intentionally
	if depth <= 0 then
		return x -- Base case stops recursion
	end
	return recursivePerturb(
		strangeMathLayer(x + chaoticNoise(x)), -- Each layer slightly mutates input
		depth - 1 -- Countdown ensures termination
	)
end

-- Semantic pressure estimates how dense or heavy the message feels
local function semanticPressure(tokens) -- Independent of order, focused on content
	local p = 0 -- Pressure accumulator
	for _, t in ipairs(tokens) do
		p = p + pseudoHash(t) % 97 -- Modulo keeps values small but varied
	end
	return p / (#tokens + 1) -- Normalized to avoid division by zero
end

-- Memory push stores recent responses for biasing future outputs
local function memoryPush(entry) -- Entry includes weight and timestamp
	table.insert(MessageHistory, entry) -- Appends newest memory
	if #MessageHistory > RESPONSE_MEMORY_DEPTH then
		table.remove(MessageHistory, 1) -- Drops oldest to keep memory bounded
	end
end

-- Memory influence softly biases new responses using sinusoidal decay
local function memoryInfluence() -- Prevents hard repetition without full state replay
	local acc = 0 -- Accumulator
	for i, v in ipairs(MessageHistory) do
		acc = acc + (v.weight or 0) * math.sin(i) -- Older entries matter less
	end
	return acc -- Added to final output value
end


-- Generates base sentence depending on numeric state so replies don't feel static
local function generateBaseResponse(value) -- Value determines linguistic branch, not randomness
	local states = { -- Small fixed set avoids bloating memory or lookup cost
		"The result converges to",
		"After recalculation I get",
		"Non-linear evaluation says",
		"Empirically it ends up as",
		"Running internal math gives"
	}
	return states[(math.floor(value) % #states) + 1] -- Modulo ensures index safety
end

-- Converts numeric magnitude into abstract qualitative meaning
local function numericToPhrase(n) -- Used to sound analytical instead of numeric-only
	if n < 0 then
		return "a negative deviation" -- Negative values imply divergence
	elseif n == 0 then
		return "a neutral equilibrium" -- Exact zero treated as balance point
	elseif n < 1 then
		return "a fractional outcome" -- Small magnitudes get softer language
	elseif primeCheck(math.floor(n)) then
		return "a prime-aligned result" -- Prime numbers treated as special states
	else
		return "a composite magnitude" -- Everything else grouped here
	end
end

-- Main processing pipeline that transforms player text into response
function AI:Process(player, text) -- Central brain of the system
	local tokens = tokenize(text) -- Breaks text into analyzable units
	local entropy = generateEntropy(player) -- Player-specific chaos source

	local weight = weightedSum(tokens) -- Measures structural weight of message
	local pressure = semanticPressure(tokens) -- Measures semantic density

	local combined = weight * pressure * entropy -- Core scalar driving behavior
	local recursive = recursivePerturb(combined, 3) -- Adds layered non-linearity

	local memoryBias = memoryInfluence() -- Pulls system slightly toward past states
	local finalValue = recursive + memoryBias -- Final scalar used everywhere else

	local phrase = generateBaseResponse(finalValue) -- Selects opening phrase
	local numericMeaning = numericToPhrase(math.abs(finalValue)) -- Abstract classification

	local response =
		phrase ..
		" " ..
		string.format("%.6f", finalValue) .. -- Fixed precision avoids float spam
		", which maps to " ..
		numericMeaning

	memoryPush({ -- Store response influence for future biasing
		player = player.UserId,
		weight = finalValue,
		time = os.clock()
	})

	return response -- Returned to chat handler
end

-- CoreAI instance uses AI table as prototype instead of duplication
local CoreAI = setmetatable({}, AI) -- Lightweight object creation

-- Handles chat events and routes them into AI safely
local function onPlayerChatted(player, message) -- Entry point from Roblox chat
	if typeof(message) ~= "string" then return end -- Guards against malformed input
	if #message < 1 then return end -- Ignores empty messages

	local reply = CoreAI:Process(player, message) -- Full AI evaluation

	ChatService:Chat( -- Uses modern ChatService instead of deprecated Player:Chat
		player.Character and player.Character:FindFirstChild("Head") or workspace, -- Head preferred, fallback safe
		reply,
		Enum.ChatColor.Blue -- Visual distinction for AI output
	)
end

-- Hooks player chat once per player lifecycle
local function hookPlayer(player) -- Avoids duplicate connections
	player.Chatted:Connect(function(msg)
		onPlayerChatted(player, msg) -- Routes through unified handler
	end)
end

-- Hooks existing players to avoid missing early joiners
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p) -- Ensures consistency across server lifetime
end

-- Hooks players joining later
Players.PlayerAdded:Connect(hookPlayer) -- Standard lifecycle binding

-- Internal adjustment loop slowly mutates global complexity over time
RunService.Heartbeat:Connect(function(dt) -- Uses Heartbeat for stable timing
	GLOBAL_COMPLEXITY_FACTOR = clamp(
		GLOBAL_COMPLEXITY_FACTOR + math.sin(os.clock()) * dt * 0.00001, -- Small oscillation
		0.9,
		1.1
	)
end)

-- =======================
-- EXTENDED LOGIC LAYER
-- =======================

-- Separate composer keeps linguistic logic isolated from math core
local ResponseComposer = {}
ResponseComposer.__index = ResponseComposer -- Enables method syntax

-- Sentence templates chosen for analytical tone
local SENTENCE_MATRIX = {
	"Based on recursive divergence, the system infers",
	"Applying higher order abstraction yields",
	"After resolving internal contradictions, result is",
	"Cross-referencing entropy layers gives",
	"Non-deterministic resolution outputs"
}

-- Connectors simulate reasoning flow
local CONNECTORS = {
	"therefore",
	"hence",
	"as a consequence",
	"which implies",
	"so basically"
}

-- Tail phrases anchor output to runtime context
local TAIL_PHRASES = {
	"under current constraints.",
	"given the present state.",
	"in this runtime context.",
	"assuming no external override.",
	"until entropy collapses again."
}

-- Sigmoid compresses values into confidence-like range
local function sigmoid(x) -- Prevents confidence from exceeding bounds
	return 1 / (1 + math.exp(-x))
end

-- Normalize ensures values never explode due to math edge cases
local function normalize(x) -- Defensive math utility
	if x ~= x then return 0 end -- NaN guard
	if x == math.huge or x == -math.huge then return 0 end -- Infinity guard
	return clamp(x, -1e6, 1e6) -- Hard bounds
end

-- Converts string into numeric vector for pseudo-semantic projection
local function vectorizeString(str) -- Cheap embedding approximation
	local v = {}
	for i = 1, #str do
		v[i] = string.byte(str, i) * math.sin(i) -- Index-based modulation
	end
	return v
end

-- Dot product merges two numeric vectors
local function dot(a, b) -- Not heavily used but kept for extensibility
	local s = 0
	for i = 1, math.min(#a, #b) do
		s += a[i] * b[i]
	end
	return s
end

-- Collapses vector into scalar via trigonometric accumulation
local function matrixCollapse(vec) -- Reduces dimensionality safely
	local acc = 0
	for i, v in ipairs(vec) do
		acc += math.cos(v / (i + 1)) -- Index dampening prevents spikes
	end
	return acc
end

-- Amplifies complexity without recursion for performance safety
local function complexityAmplifier(x, cycles) -- Iterative instead of recursive
	local r = x
	for i = 1, cycles do
		r = math.sin(r * PHI) + math.log(math.abs(r) + 1)
	end
	return r
end

-- Adds informal noise so output doesn't sound robotic
local function grammaticalNoise(seed) -- Light linguistic distortion
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

-- Builds final extended response string
function ResponseComposer:Compose(rawValue, sourceText) -- Second-stage synthesis
	local sentence = SENTENCE_MATRIX[(math.floor(math.abs(rawValue)) % #SENTENCE_MATRIX) + 1]
	local connector = CONNECTORS[(pseudoHash(sourceText) % #CONNECTORS) + 1]
	local tail = TAIL_PHRASES[(math.floor(rawValue * 10) % #TAIL_PHRASES) + 1]

	local amplified = complexityAmplifier(rawValue, 2) -- Boosts separation
	local confidence = sigmoid(amplified) -- Confidence proxy

	local noise = grammaticalNoise(rawValue) -- Human-like imperfection

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

-- Composer instance
local Composer = setmetatable({}, ResponseComposer) -- Single shared instance

-- =======================
-- CORE OVERRIDE
-- =======================

-- Preserve original processing logic for extension
local OldProcess = CoreAI.Process -- Stored to avoid recursion

function CoreAI:Process(player, text) -- Overrides but reuses base logic
	local baseResponse = OldProcess(self, player, text) -- Core math output

	local vec = vectorizeString(text) -- Secondary semantic projection
	local collapsed = matrixCollapse(vec) -- Scalar reduction

	local adjusted = collapsed * generateEntropy(player) -- Player influence
	local composed = Composer:Compose(adjusted, text) -- Extended reasoning layer

	return baseResponse .. " | " .. composed -- Final merged output
end

-- =======================
-- FLOOD PROTECTION
-- =======================

local FloodTracker = {} -- Tracks timestamps per player
local FLOOD_LIMIT = 6 -- Max messages allowed
local FLOOD_WINDOW = 4 -- Time window in seconds

local function floodCheck(player) -- Simple sliding window limiter
	local now = os.clock()
	FloodTracker[player.UserId] = FloodTracker[player.UserId] or {}

	local t = FloodTracker[player.UserId]
	table.insert(t, now)

	while #t > 0 and now - t[1] > FLOOD_WINDOW do
		table.remove(t, 1) -- Remove expired timestamps
	end

	return #t <= FLOOD_LIMIT -- True means allowed
end

-- Wrap original chat handler with flood protection
local OldChatHandler = onPlayerChatted

onPlayerChatted = function(player, message) -- Reassignment intentional
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

local InternalClock = 0 -- Tracks runtime progression
local DriftAccumulator = 0 -- Accumulates oscillation

RunService.Stepped:Connect(function(_, dt) -- Stepped chosen for deterministic timing
	InternalClock += dt
	DriftAccumulator += math.sin(InternalClock) * dt

	if DriftAccumulator > 1 then
		ENTROPY_DRIFT = ENTROPY_DRIFT * (1 + chaoticNoise(DriftAccumulator)) -- Mutates entropy slowly
		DriftAccumulator = 0
	end
end)

-- =======================
-- FINAL FLAG
-- =======================

_G.SuperMathAIReady = true -- External systems can safely detect readiness
