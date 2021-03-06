
--[[--------------------------------------------------------------------------------
-- GridIndexFunctions是和GridIndex相关的函数集合。
-- 关于GridIndex，请参看GridIndexable的注释。
-- 主要职责：
--   提供接口用于对GridIndex进行各种操作，包括加、减、缩放、克隆、计算距离、获取一定范围内的其他GridIndex的集合等
--   同时也提供接口用于对GridIndex和绘图用到的position进行相互转换
-- 使用场景举例：
--   到处都在用，因为本集合里的都是小工具函数，应该不必过多描述了，直接看名字基本都可以懂
--]]--------------------------------------------------------------------------------

local GridIndexFunctions = {}

local GRID_SIZE               = require("src.app.utilities.GameConstantFunctions").getGridSize()
local GRID_WIDTH, GRID_HEIGHT = GRID_SIZE.width, GRID_SIZE.height
local ADJACENT_GRIDS_OFFSET   = {
    {x = -1, y =  0, direction = "left",  clockwiseOffset = {x =  1, y =  1},},
    {x =  1, y =  0, direction = "right", clockwiseOffset = {x = -1, y = -1},},
    {x =  0, y = -1, direction = "down",  clockwiseOffset = {x = -1, y =  1},},
    {x =  0, y =  1, direction = "up",    clockwiseOffset = {x =  1, y = -1},},
}

function GridIndexFunctions.toGridIndex(pos)
    return {x = math.ceil(pos.x / (GRID_SIZE.width )),
            y = math.ceil(pos.y / (GRID_SIZE.height))
    }
end

function GridIndexFunctions.toPositionWithXY(x, y)
    return (x - 1) * GRID_WIDTH, (y - 1) * GRID_HEIGHT
end

function GridIndexFunctions.toPosition(gridIndex)
    return GridIndexFunctions.toPositionWithXY(gridIndex.x, gridIndex.y)
end

function GridIndexFunctions.toPositionTable(gridIndex)
    local x, y = GridIndexFunctions.toPosition(gridIndex)
    return {x = x, y = y}
end

function GridIndexFunctions.worldPosToGridIndexInNode(worldPos, node)
    return GridIndexFunctions.toGridIndex(node:convertToNodeSpace(worldPos))
end

function GridIndexFunctions.isEqual(index1, index2)
    return (index1) and (index2) and (index1.x == index2.x) and (index1.y == index2.y)
end

function GridIndexFunctions.isAdjacent(index1, index2)
    local offset = GridIndexFunctions.sub(index1, index2)
    for _, o in ipairs(ADJACENT_GRIDS_OFFSET) do
        if (GridIndexFunctions.isEqual(offset, o)) then
            return true
        end
    end

    return false
end

function GridIndexFunctions.isWithinMap(index, mapSize)
    return (index.x >= 1) and (index.y >= 1)
        and (index.x <= mapSize.width) and (index.y <= mapSize.height)
end

function GridIndexFunctions.add(index1, index2)
    return {x = index1.x + index2.x, y = index1.y + index2.y}
end

function GridIndexFunctions.sub(index1, index2)
    return {x = index1.x - index2.x, y = index1.y - index2.y}
end

function GridIndexFunctions.scale(index, scale)
    return {x = index.x * scale, y = index.y * scale}
end

function GridIndexFunctions.clone(index)
    return {x = index.x, y = index.y}
end

function GridIndexFunctions.getAdjacentGrids(index, mapSize)
    local grids = {}
    for _, offset in ipairs(ADJACENT_GRIDS_OFFSET) do
        local adjacentGridIndex = GridIndexFunctions.add(index, offset)
        if ((not mapSize)                                                 or
            (GridIndexFunctions.isWithinMap(adjacentGridIndex, mapSize))) then
            grids[#grids + 1] = GridIndexFunctions.add(index, offset)
        end
    end

    return grids
end

-- If index1 is at the right side of index2, then "right" is returned.
function GridIndexFunctions.getAdjacentDirection(index1, index2)
    if (not index1) or (not index2) then
        return "invalid"
    end

    local offset = GridIndexFunctions.sub(index1, index2)
    for i, item in ipairs(ADJACENT_GRIDS_OFFSET) do
        if (GridIndexFunctions.isEqual(offset, item)) then
            return item.direction
        end
    end

    return "invalid"
end

function GridIndexFunctions.getDistance(index1, index2)
    local offset = GridIndexFunctions.sub(index1, index2)
    return math.abs(offset.x) + math.abs(offset.y)
end

function GridIndexFunctions.getGridsWithinDistance(origin, minDistance, maxDistance, mapSize, predicate)
    local grids       = {}
    local isWithinMap = GridIndexFunctions.isWithinMap
    if ((minDistance == 0)                                and
        (minDistance <= maxDistance)                      and
        ((not mapSize) or (isWithinMap(origin, mapSize))) and
        ((not predicate) or (predicate(origin))))         then
        grids[1] = GridIndexFunctions.clone(origin)
    end

    for distance = minDistance, maxDistance do
        for _, offsetItem in ipairs(ADJACENT_GRIDS_OFFSET) do
            local gridIndex = GridIndexFunctions.add(origin, GridIndexFunctions.sub(GridIndexFunctions.scale(offsetItem, distance), offsetItem.clockwiseOffset))
            for i = 1, distance do
                gridIndex = GridIndexFunctions.add(gridIndex, offsetItem.clockwiseOffset)
                if (((not mapSize) or (isWithinMap(gridIndex, mapSize))) and
                    ((not predicate) or (predicate(gridIndex))))         then
                    grids[#grids + 1] = gridIndex
                end
            end
        end
    end

    return grids
end

return GridIndexFunctions
