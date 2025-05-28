--[[
	@Algorithm
	Desc: Handles the A* algorithm portion of pathfinding // This file should be under PathfindingServer
	
	Last Editor: jack
--]]

local Algorithm = {}
local SharedModules = game:GetService("ReplicatedStorage").Modules
local Stack = require(SharedModules.DataStructures.Stack)
local Queue = require(SharedModules.DataStructures.Queue)
local PriorityQueue = require(SharedModules.DataStructures.PriorityQueue)
local VISUALIZE_NODES = false

local function Heuristic(n1, n2, SlotsX, SlotsY)
	local n1X = math.ceil(n1/SlotsY)
	local n2X = math.ceil(n2/SlotsY)
	local n1Y = n1%SlotsY ~= 0 and n1%SlotsY or SlotsY
	local n2Y = n2%SlotsY ~= 0 and n2%SlotsY or SlotsY

	return math.abs(n1X-n2X) + math.abs(n1Y-n2Y)
end

-- // Calculates the most optimized path to it's goal. Returns a list of grid numbers. //
function Algorithm.AStar(start, goal, SlotsX, SlotsY, slotsTable, area)
	local Frontier = PriorityQueue.new()
	local Explored = {}
	local CostSoFar = {}
	local goalReached = false

	Frontier:Push(start, 1)
	CostSoFar[start] = 0

	while not Frontier:isEmpty() do
		local slot = Frontier:Pop()

		if slot == goal then
			goalReached = true
			break
		end
		
		if slotsTable[slot] == "Invalid" then continue end
		
		if VISUALIZE_NODES and slot ~= start then
			task.wait()
			if area and area:FindFirstChild(tostring(slot)) then
				area[tostring(slot)].Color = Color3.new(0.615686, 0, 1)
			else
				slotsTable[slot][2].Color = Color3.new(0.615686, 0, 1)
			end
		end
		
		local neighbors
		if not slotsTable[slot] then
			error("not a valid slot (A*)")
		else
			neighbors = slotsTable[slot][3]
		end
		
		local dictionaryLength = 0
		for i,v in pairs(neighbors) do
			dictionaryLength += 1
		end
		
		if dictionaryLength > 0 then
			for i,v in pairs(neighbors) do
				local newCost = CostSoFar[slot] + Heuristic(slot, i, SlotsX, SlotsY)
				if not CostSoFar[i] or newCost < CostSoFar[i] then
					CostSoFar[i] = newCost
					Explored[i] = slot
					Frontier:Push(i, Heuristic(goal, i, SlotsX, SlotsY))
				end
			end
		else
			break
		end
	end

	if goalReached then
		local path = {}
		local currentNode = goal
		while currentNode do
			table.insert(path, 1, currentNode)
			currentNode = Explored[currentNode]
		end
		
		if VISUALIZE_NODES then
			for _,node in pairs(path) do
				if area and area:FindFirstChild(tostring(node)) then
					area[tostring(node)].Color = Color3.new(0.0666667, 0, 1)
				else
					slotsTable[node][2].Color = Color3.new(0.0666667, 0, 1)
				end
				task.wait()
			end
		end
		
		return path
	end
end

return Algorithm
