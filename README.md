# Lua 3D A* Pathfinding

This is a custom pathfinding module for Roblox (Lua) that generates walkable nodes for characters within a defined area. It uses a modified A* algorithm to calculate the nodes. It is designed for use in areas that could benefit from a grid-based pathfinding system with multiple floors and ramps.

<div align="center">
  <img src="https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExdHNlb2s0OHhjeHZjeHVib3g0MTZtOWtjd2QyeGIydXVhN3hlbzF5MCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/a8mtC8iijqICxy9VA6/giphy.gif" alt="3D A* Pathfinding Demo" width="800" />
</div>

## Structure

- `PathfindingService`: Main module  
  - `Algorithm`: Custom A* pathfinding implementation  
  - `VISUALIZE_NODES`: BoolValue to toggle debug node visualization

## Features

- Generates nodes on a grid, accounting for ramps and floor levels
- Visualizes nodes in real-time when `VISUALIZE_NODES` is enabled
- Dynamically detects valid pathfinding positions with raycasts and overlap checks
- Handles multi-floor navigation
- Supports path execution with live movement monitoring and blockage detection

## Usage

### Initialization

```lua
local Pathfinding = require(path.to.PathfindingService)

-- Create a pathfinding context
local pathfinder = Pathfinding.create(buildingModel, waypointSpacing, customNodeSize)
```

- `buildingModel`: A `Model` with a `Floors` folder containing parts named numerically (`"1"`, `"2"`, etc.) representing walkable floors  
- `waypointSpacing`: Spacing between nodes in studs  
- `customNodeSize`: Optional `Vector3` for node size

### Generating a Path

```lua
local nodeList = pathfinder._nodeList[floorNumber]
local waypoints = pathfinder:CalculatePath(startPosition, endPosition, nodeList, buildingModel)
```

### Moving an Agent

```lua
local success = pathfinder:PathMove(waypoints, agent)
```

- `agent`: A model with a `Humanoid` and `HumanoidRootPart`

## Important Notes

- Ensure the building model has a `Floors` folder with properly named parts  
- Nodes are automatically invalidated if:  
  - They intersect collidable geometry  
  - They are too steeply elevated relative to neighbors  
- Rotation on floor parts should be `(0, 0, 0)` to avoid CFrame inaccuracies

## Debugging

To enable node visualization:

```lua
PathfindingService.VISUALIZE_NODES.Value = true
```

- Invalid nodes = Red  
- Valid nodes = Neon green
