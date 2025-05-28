--[[
	@PathfindingService
	Desc: Used to handle pathfinding
	
	Last Editor: jack
--]]

-- // Services //
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService("RunService")
local algorithm = require(script.Algorithm)
local Promise = require(ReplicatedStorage.Packages.Promise)

-- // Constants //
local NODE_SIZE = Vector3.new(3.5,1,3.5)
local VISUALIZE_NODES = script.VISUALIZE_NODES.Value
local MAX_RAMP_HEIGHT = 12

local NODE_OVERLAP_PARAMS = OverlapParams.new()
NODE_OVERLAP_PARAMS.CollisionGroup = "PathfindNode"
NODE_OVERLAP_PARAMS.RespectCanCollide = true
NODE_OVERLAP_PARAMS.MaxParts = 1
NODE_OVERLAP_PARAMS.FilterType = Enum.RaycastFilterType.Include

local NODE_RAYCAST_PARAMS = RaycastParams.new()
NODE_RAYCAST_PARAMS.CollisionGroup = "PathfindNode"
NODE_RAYCAST_PARAMS.RespectCanCollide = true
NODE_RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Include


local BASE_NODE_VISUAL = Instance.new("Part")
BASE_NODE_VISUAL.Size = NODE_SIZE
BASE_NODE_VISUAL.Material = Enum.Material.Neon
BASE_NODE_VISUAL.CanCollide = false
BASE_NODE_VISUAL.CanQuery = false
BASE_NODE_VISUAL.CanTouch = false
BASE_NODE_VISUAL.Color = Color3.new(0.309804, 1, 0.0117647)
BASE_NODE_VISUAL.Transparency = .8
BASE_NODE_VISUAL.Anchored = true

local Pathfinding = {}

Pathfinding.__index = Pathfinding

--Pathfinding.CurrentlyPathfinding = false

function isNodePositionValid(nodeCFrame, building): boolean
	NODE_OVERLAP_PARAMS.FilterDescendantsInstances = {building}
	NODE_RAYCAST_PARAMS.FilterDescendantsInstances = {building}
	
	local partsInNode = workspace:GetPartBoundsInBox(nodeCFrame, NODE_SIZE, NODE_OVERLAP_PARAMS)
	if #partsInNode > 0 then
		return false
	end
	
	local floorCheckResults = workspace:Raycast(nodeCFrame.Position - Vector3.new(0, NODE_SIZE.Y / 2, 0), Vector3.new(0, -3, 0), NODE_RAYCAST_PARAMS)
	if floorCheckResults == nil then
		return false
	end
	
	return true
end

-- // Returns a dictionary of all the valid nodes //
function returnAvailableNodes(nodes, building, waypointSize)
	local goodNodes = {}

	for i, v in pairs(nodes) do
		if v == "Invalid" then
			continue 
		end
		
		local nodeCFrame = building:GetPivot():ToWorldSpace(v[1])
		local isNodeValid = isNodePositionValid(nodeCFrame, building)
		
		--local partsInNode = workspace:GetPartBoundsInBox(checkCFrame, NODE_SIZE, NODE_OVERLAP_PARAMS)
		--[[for i, v in pairs(partsInNode) do
			if not area:IsAncestorOf(v) or not v.CanCollide then
				table.remove(partsInNode, i)
			end
		end]]
		
		if isNodeValid then
			goodNodes[i] = v
		else
			if VISUALIZE_NODES then
				v[2].Color = Color3.new(1, 0, 0)
			end
			goodNodes[i] = "Invalid"
		end
	end

	return goodNodes
end

-- // Returns the floor count by the node position //
function returnFloorByPosition(floorFolder, nodePosition)
	if not floorFolder then return end
	local floors = #floorFolder:GetChildren()

	for floorCount = floors, 1, -1 do
		local floorPosition = floorFolder[tostring(floorCount)].Position
		
		if nodePosition.Y > floorPosition.Y then
			return floorCount
		end
	end
end

--[[
	nodeList Template:
	nodeNumber : {NodePosition, PhysicalNode (if there is one), {NEIGHBORS}}
	OR:
	nodeNumber : "Invalid"
]]
function Pathfinding:GenerateNodes(areaCFrame, areaSize)
	local NODE_SIZE = self._waypointSize
	local nodeHash = {}
	local CornerPos = (areaCFrame * CFrame.new(
		areaSize.X/2,
		areaSize.Y/2 * -1, 
		areaSize.Z/2 * -1)
	).Position
	
	local building = self._area

	local x = math.floor(areaSize.Z/self._waypointSpacing) + 1
	local y = math.floor(areaSize.X/self._waypointSpacing) + 1

	local nodeNumber = 1

	for mainPos = 1, x do -- Iterates through the x axis
		local spacing = 1

		for pos = 0, y do -- Iterates through how many nodes the y axis should have
			local nodePosition = CornerPos + Vector3.new(-pos * spacing, 2, 0)
			local nodeCFrame = CFrame.new(nodePosition)
			
			local isNodeValid = isNodePositionValid(nodeCFrame, building)
			
			-- // If the node is invalid, checks to see if the node can go higher due to a ramp //
			-- Go up by 0.5 studs for each retry
			if not isNodeValid then
				local newNodeCFrame = nodeCFrame
				for count = 1, MAX_RAMP_HEIGHT, 1 do
					newNodeCFrame += Vector3.new(0,1,0)
					if isNodePositionValid(newNodeCFrame, building) then
						nodePosition = newNodeCFrame.Position
						break
					end
				end
			end

			local newNode

			-- // Visualize the nodes if needed //
			if VISUALIZE_NODES then
				newNode = BASE_NODE_VISUAL:Clone()
				newNode.Name = nodeNumber
				newNode.Position = nodePosition
				
				if building then
					newNode.Parent = building
				else
					newNode.Parent = workspace
				end
			end
			
			local relativePosition = building:GetPivot():ToObjectSpace(CFrame.new(nodePosition))
			
			nodeHash[nodeNumber] = {relativePosition, newNode, {}}
			spacing = self._waypointSpacing
			nodeNumber += 1
		end

		CornerPos = CornerPos + Vector3.new(0,0, self._waypointSpacing)
	end

	--[[ 
	Creates a key value (dictionary) set for the specified neighbor. Also checks the neighbors validity
	and magnitude before determining that it's a valid neighbor
	]]
	local function createNeighbor(originalNodeNumber, nodeNumber, value)
		if nodeNumber == 0 or nodeHash[originalNodeNumber] == "Invalid" or nodeHash[nodeNumber] == "Invalid" then return end
		if originalNodeNumber < 1 or nodeNumber < 1 then return end
		
		local nodeMagnitude = (nodeHash[originalNodeNumber][1].Position - nodeHash[nodeNumber][1].Position).Magnitude

		-- // Invalidate nodes that are too far apart from each other (It invalidates the highest node)//
		if nodeMagnitude > self._waypointSpacing + .5 then
			local theNumber = nodeNumber

			if nodeHash[originalNodeNumber][1].Y >= nodeHash[nodeNumber][1].Y then
				theNumber = originalNodeNumber
			end

			if VISUALIZE_NODES then
				nodeHash[theNumber][2].Color = Color3.new(1, 0, 0)
			end
			nodeHash[theNumber] = "Invalid"
			return
		end

		local newNeighbors = nodeHash[originalNodeNumber][3]
		newNeighbors[nodeNumber] = value
		nodeHash[originalNodeNumber] = {nodeHash[originalNodeNumber][1], nodeHash[originalNodeNumber][2], newNeighbors}

		if VISUALIZE_NODES and workspace:FindFirstChild(tostring(originalNodeNumber)) then
			local newNeighborInstance = Instance.new("StringValue")
			newNeighborInstance.Name = value
			newNeighborInstance.Value = tostring(nodeNumber)
			newNeighborInstance.Parent = workspace[tostring(originalNodeNumber)]
		end
	end

	nodeHash = returnAvailableNodes(nodeHash, building, NODE_SIZE)

	-- // Loop through the grid and assign neighbors //
	for nodeNumber = 1, nodeNumber - 1 do
		if nodeHash[nodeNumber-1] and (nodeNumber-1) % (y+1) ~= 0 then -- Up
			createNeighbor(nodeNumber, nodeNumber - 1, "Up")
		end

		if nodeHash[nodeNumber+1] and nodeNumber % (y+1) ~= 0 then -- Down
			createNeighbor(nodeNumber, nodeNumber + 1, "Down")
		end

		if nodeHash[nodeNumber + y+1] then -- Right
			createNeighbor(nodeNumber, nodeNumber + y+1, "Right")
		end

		if nodeHash[nodeNumber - y+1] then -- Left
			createNeighbor(nodeNumber, nodeNumber - y-1, "Left")
		end
	end

	self._xAmount = x
	self._yAmount = y+1
	return nodeHash
end

-- // Creates a new pathfinding object //
function Pathfinding.create(area : Model, waypointSpacing, customSize)
	local floors = area:FindFirstChild("Floors")

	if not floors then
		error('Did not find "Floors" folder (Pathfinding)')
	end

	waypointSpacing = waypointSpacing or 5
	
	-- // Create path class //
	local self = setmetatable(
		{
			_nodeList = {};
			_activePaths = {};
			_xAmount = 0;
			_yAmount = 0;
			_floorsFolder = floors;
			_area = area;
			_waypointSpacing = waypointSpacing;
			_waypointSize = customSize or NODE_SIZE;
		},
		Pathfinding
	)
	
	local originalParent
	if area.Parent ~= workspace then
		originalParent = area.Parent
		area.Parent = workspace
	end

	-- // Set up each floor into the _nodeList //
	for i, floor in pairs(floors:GetChildren()) do
		if floor.Rotation.Magnitude > 1 then
			warn("Floor " .. i .. " for building '" .. area.Name .. "' has a non-zero rotation. Its rotation should be (0, 0, 0)")
		end
		local areaCFrame = floor.CFrame
		local areaSize = floor.Size

		local nodeList = self:GenerateNodes(areaCFrame, areaSize, floor)

		self._nodeList[tonumber(floor.Name)] = nodeList
	end
	
	if originalParent then
		area.Parent = originalParent
	end
	
	return self
end

-- // Moves the agent to the path. "waypoints" is a list of vectors. //
-- Returns true if the moving was successful, or false if the moving was blocked
function Pathfinding:PathMove(waypoints, agent): boolean
	if not waypoints or #waypoints <= 0 then return end
	local humanoidRootPart = agent:FindFirstChild("HumanoidRootPart", true)
	local humanoid = humanoidRootPart.Parent:FindFirstChild("Humanoid")

	if not humanoid then
		error("Could find humanoid in PathMove (Pathfinding)")
	end
	
	local completed = false
	
	-- // Checks the last position compared to current position to see if the character has stopped moving //
	local function determineIfBlocked()
		local lastPos = humanoidRootPart.Position
		local blockedCount = 0
		
		while not completed do
			local currentPos = humanoidRootPart.Position
			
			if (currentPos - lastPos).Magnitude < 1 then
				if blockedCount > 2 then
					return false
				else
					blockedCount += 1
				end
			end
			
			lastPos = currentPos
			task.wait(1)
		end
	end
	
	--[[
	- Iterates through the waypoints.
	- Sends a blocked signal if the character is blocked.
	- Returns if the agent no longer has an active path
	]]
	for i, waypoint in pairs(waypoints) do
		if i == 1 then
			task.spawn(determineIfBlocked)
		elseif i == #waypoints - 1 then
			completed = true
			return true
		end

		humanoid:MoveTo(waypoint)
		humanoid.MoveToFinished:Wait()
	end

	return true
end

-- // Finds the start and end node and uses A* to calculate the waypoints //
function Pathfinding:CalculatePath(startPosition, endPosition, correctList, building)
	local startNode = {}
	local endNode = {}
	
	local area = building or self._area
	
	--print('area is',area:GetFullName())
	
	--[[if optionalPlayer then
		if optionalPlayer:GetAttribute("QuestBuilding") then
			for i, v in pairs(workspace.QuestBuildings:GetChildren()) do
				if v:GetAttribute("Player") == optionalPlayer.Name then
					area = v
					break
				end
			end
		else
			area = optionalPlayer.TutorialBuilding.Value
		end
	end]]
	
	local lowest = math.huge
	local lastRelativePosition
	local lastNodeWorldPosition
	-- // Check closest grid node to the start and end positions, and assign them to startNode and endNode //
	for i, v in pairs(correctList) do
		if v == "Invalid" then 
			continue
		end
		local relativePosition : CFrame = v[1]
		local nodeWorldPosition = area:GetPivot():ToWorldSpace(relativePosition).Position -- problem child
		lastRelativePosition = relativePosition
		lastNodeWorldPosition = nodeWorldPosition
		lowest = math.min((nodeWorldPosition - startPosition).Magnitude, lowest)
		if (nodeWorldPosition - startPosition).Magnitude <= 15 then
			if not startNode[1] or (nodeWorldPosition - startPosition).Magnitude < startNode[2] then
				startNode[1] = i
				startNode[2] = (nodeWorldPosition - startPosition).Magnitude
			end
		end
		if (nodeWorldPosition - endPosition).Magnitude <= 15 then
			if not endNode[1] or (nodeWorldPosition - endPosition).Magnitude < endNode[2] then
				endNode[1] = i
				endNode[2] = (nodeWorldPosition - endPosition).Magnitude
			end
		end
	end
	
	if not startNode[1] or not endNode[1] then
		--[[print("Not a valid start and/or end node (Pathfinding:Begin)")
		print("Lowest start node dist:",lowest)
		print("Start position:",startPosition)
		print("Interior center:",area:GetPivot().Position)
		print("Node relative position:",lastRelativePosition)
		print("Node world position:",lastNodeWorldPosition)
		print("--------")]]
		return false
	end
	
	startNode = startNode[1]
	endNode = endNode[1]
	
	-- // Calculates the path with A* //
	local path = algorithm.AStar(startNode, endNode, self._xAmount, self._yAmount, correctList, area)
	
	-- // Convert path list into a list of vectors //
	if path then
		local waypoints = {}

		for i,v in pairs(path) do
			local reletivePosition : CFrame = correctList[v][1]
			local nodeWorldPosition = area:GetPivot():ToWorldSpace(reletivePosition).Position
			table.insert(waypoints, nodeWorldPosition)
		end

		return waypoints
	else
		return {}
	end
end

-- Tries to pathfind to the given position
function Pathfinding:Begin(agent : Model, position: Vector3, building: Model?)
	-- 'agent' is the ColliderModel of the robot
	
	if not position then
		error("self:Begin must have a position argument")
	end

	if not (agent and agent:IsA("Model")) then
		error("Pathfinding agent must be valid")
	end

	local humanoidRootPart = agent:FindFirstChild("HumanoidRootPart", true)

	if not humanoidRootPart then
		error("Couldn't find HumanoidRootPart (Pathfinding)")
	end

	if table.find(self._activePaths, agent) then
		error("Agent already has an active path")
	end
	
	agent:SetAttribute("PathfindingHash", math.random())
	table.insert(self._activePaths, agent)
	
	return Promise.any{
		Promise.new(function(resolve, reject)
			local area = building or self._area 
			local floorsFolder = if building then building:FindFirstChild("Floors") else self._floorsFolder

			local humanoid = humanoidRootPart.Parent:FindFirstChild("Humanoid")
			local currentFloor = returnFloorByPosition(floorsFolder, humanoidRootPart.Position) or 1
			local floorNumber = returnFloorByPosition(floorsFolder, position) or 1
			
			-- // Go up/down floors until it's the right floor //
			while floorNumber ~= currentFloor do
				local increment = 1

				if floorNumber < currentFloor then
					increment = -1
				end

				local physicalFloor = floorsFolder[tostring(currentFloor + increment)]
				local stairWaypoints = {}
				local startNum
				local endNum

				-- // Depending on if the agent is going up/down a floor, it adjusts it's startnumber and endnumber.
				if increment == -1 then
					endNum = 1
					physicalFloor = floorsFolder[tostring(currentFloor)]
					startNum = #physicalFloor.StairWaypoints:GetChildren()
				else
					startNum = 1
					endNum = #physicalFloor.StairWaypoints:GetChildren()
				end

				-- // Inserts the stair waypoints depending on what floor it's going to //
				for count = startNum, endNum, increment do
					table.insert(stairWaypoints, physicalFloor.StairWaypoints[tostring(count)].Position)
				end
				
				local waypoints = self:CalculatePath(humanoidRootPart.Position, stairWaypoints[1], self._nodeList[currentFloor], area)
				if not waypoints then
					task.wait(.1)
					resolve("NoPath")
				end

				-- // Move to the stair, and then move through the stair's presets //
				local _successful = self:PathMove(waypoints, agent)
				if not _successful then
					resolve("Blocked")
				end
				
				local _successful = self:PathMove(stairWaypoints, agent)
				if not _successful then
					resolve("Blocked")
				end

				currentFloor += increment
			end

			local start = os.clock()
			local waypoints = self:CalculatePath(humanoidRootPart.Position, position, self._nodeList[currentFloor], area)
			if not waypoints then
				resolve("NoPath")
			end

			local _successful = self:PathMove(waypoints, agent)
			if not _successful then
				resolve("Blocked")
			end
			
			resolve("Completed")
		end):catch(warn),
		
		Promise.delay(60):andThenReturn(Promise.resolve("Completed")),
		
		Promise.fromEvent(agent:GetAttributeChangedSignal("PathfindingHash")):andThenReturn(Promise.resolve("Completed"))
	}:finally(function()
		local index = table.find(self._activePaths, agent)
		table.remove(self._activePaths, index)
	end):expect()
end

-- // Stops the current path //
function Pathfinding:Stop(agent)
	local index = table.find(self._activePaths, agent)

	if index then
		table.remove(self._activePaths, index)
	end
	
	-- Cancels any pathfinding that's in progress
	agent:SetAttribute("PathfindingHash", math.random())

	--agent:MoveTo(agent:GetPivot().p)
end

-- // Destroys the path object //
function Pathfinding:Destroy()
	for i, v in pairs(self._events) do
		v:Destroy()
	end

	for i, v in pairs(self) do
		self[i] = nil
	end
	setmetatable(self, nil)
end

return Pathfinding
