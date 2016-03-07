
local GridIndexFunctions = {}

local GRID_SIZE = require("res.data.GameConstant").GridSize

function GridIndexFunctions.toGridIndex(pos)
    return {x = math.ceil(pos.x / (GRID_SIZE.width )),
            y = math.ceil(pos.y / (GRID_SIZE.height))
    }
end

function GridIndexFunctions.worldPosToGridIndexInNode(worldPos, node)
    return GridIndexFunctions.toGridIndex(node:convertToNodeSpace(worldPos))
end

function GridIndexFunctions.isEqual(index1, index2)
    return (index1.x == index2.x) and (index1.y == index2.y)
end

function GridIndexFunctions.isWithinMap(index, mapSize)
    return (index.x >= 1) and (index.y >= 1)
        and (index.x <= mapSize.width) and (index.y <= mapSize.height)
end

return GridIndexFunctions