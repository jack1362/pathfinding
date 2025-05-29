# Lua 3D A* Pathfinding

This is a custom pathfinding module for Roblox (Lua) that generates walkable nodes for characters within a defined area. It uses a modified A* algorithm to calculate the nodes. It is designed for use in areas that could benefit from a grid-based pathfinding system with multiple floors and ramps.

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


<blockquote class="twitter-tweet">
<p lang="en" dir="ltr">Made a 3D A* pathfinding system in studio. It automatically scales the node grid to the size of the building. This is a visualization of the system. <a href="https://twitter.com/hashtag/RobloxDev?src=hash&amp;ref_src=twsrc%5Etfw">#RobloxDev</a> <a href="https://twitter.com/hashtag/ROBLOX?src=hash&amp;ref_src=twsrc%5Etfw">#ROBLOX</a> <a href="https://twitter.com/hashtag/RDC23?src=hash&amp;ref_src=twsrc%5Etfw">#RDC23</a> <a href="https://twitter.com/robloxdevrel?ref_src=twsrc%5Etfw">@robloxdevrel</a> <a href="https://t.co/iGeqWjjTRO">pic.twitter.com/iGeqWjjTRO</a></p>&mdash; CodedJack (@jack_coded) <a href="https://twitter.com/jack_coded/status/1713724693096632507?ref_src=twsrc%5Etfw">October 16, 2023</a>
</blockquote> 
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
