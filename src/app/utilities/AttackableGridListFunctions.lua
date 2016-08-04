
--[[--------------------------------------------------------------------------------
-- AttackableGridListFunctions是和“可攻击的格子的列表”相关的函数集合。
-- 所谓可攻击格子列表，其内容物是某unit可以攻击到的格子的坐标、预计的伤害和反击伤害等。在视觉上就是点击Attack指令后，画面上泛红的格子。
-- 主要职责：
--   计算及访问上述列表
-- 使用场景举例：
--   玩家操作单位，点击Attack指令后，需要调用本文件函数来计算可攻击格子以及预估伤害
-- 其他：
--   格子上能够被攻击的对象可能是unit或tile，计算时需要考虑在内。
--   这些函数原本都是在ModelActionPlanner内的，由于planner日益臃肿，因此独立出来。
--]]--------------------------------------------------------------------------------

local AttackableGridListFunctions = {}

local GridIndexFunctions     = require("src.app.utilities.GridIndexFunctions")
local ReachableAreaFunctions = require("src.app.utilities.ReachableAreaFunctions")
local isWithinMap            = GridIndexFunctions.isWithinMap

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function updateAttackableArea(area, mapSize, originX, originY, minRange, maxRange)
    local width, height = mapSize.width, mapSize.height
    for rotated = 1, 2 do
        for sign = -1, 1, 2 do
            for offset1 = 0, maxRange - 1 do
                for offset2 = math.max(1, minRange - offset1), maxRange - offset1 do
                    local x = originX + sign * ((rotated == 1) and (offset1) or (offset2))
                    local y = originY + sign * ((rotated == 1) and (offset2) or (-offset1))
                    if ((x >= 1) and (x <= width) and (y >= 1) and (y <= height)) then
                        area[x] = area[x] or {}
                        area[x][y] = true
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function AttackableGridListFunctions.getListNode(list, gridIndex)
    for i = 1, #list do
        if (GridIndexFunctions.isEqual(list[i], gridIndex)) then
            return list[i]
        end
    end

    return nil
end

function AttackableGridListFunctions.createList(attacker, attackerGridIndex, modelTileMap, modelUnitMap)
    if ((not attacker.getEstimatedBattleDamage)                                                                                 or
        ((not attacker:canAttackAfterMove()) and (not GridIndexFunctions.isEqual(attacker:getGridIndex(), attackerGridIndex)))) then
        return {}
    end

    local mapSize            = modelTileMap:getMapSize()
    local minRange, maxRange = attacker:getAttackRangeMinMax()
    return GridIndexFunctions.getGridsWithinDistance(
        attackerGridIndex,
        minRange,
        maxRange,
        function(targetGridIndex)
            if (not isWithinMap(targetGridIndex, mapSize)) then
                return false
            else
                local targetTile = modelTileMap:getModelTile(targetGridIndex)
                local target     = modelUnitMap:getModelUnit(targetGridIndex) or targetTile
                targetGridIndex.estimatedAttackDamage, targetGridIndex.estimatedCounterDamage = attacker:getEstimatedBattleDamage(target, attackerGridIndex, modelTileMap)

                return targetGridIndex.estimatedAttackDamage ~= nil
            end
        end
    )
end

function AttackableGridListFunctions.createAttackableArea(attackerGridIndex, modelTileMap, modelUnitMap)
    local attacker            = modelUnitMap:getModelUnit(attackerGridIndex)
    local attackerPlayerIndex = attacker:getPlayerIndex()
    local attackerMoveType    = attacker:getMoveType()
    local mapSize             = modelTileMap:getMapSize()
    local minRange, maxRange  = attacker:getAttackRangeMinMax()

    if (not attacker:canAttackAfterMove()) then
        local area = {}
        updateAttackableArea(area, mapSize, attackerGridIndex.x, attackerGridIndex.y, minRange, maxRange)
        return area
    else
        local reachableArea = ReachableAreaFunctions.createArea(
            attackerGridIndex,
            math.min(attacker:getMoveRange(), attacker:getCurrentFuel()),
            function(gridIndex)
                if (not isWithinMap(gridIndex, mapSize)) then
                    return nil
                else
                    local existingModelUnit = modelUnitMap:getModelUnit(gridIndex)
                    if ((existingModelUnit)                                          and
                        (existingModelUnit:getPlayerIndex() ~= attackerPlayerIndex)) then
                        return nil
                    else
                        return modelTileMap:getModelTile(gridIndex):getMoveCost(attackerMoveType)
                    end
                end
            end
        )
        local area             = {}
        local originX, originY = attackerGridIndex.x, attackerGridIndex.y
        for x, column in pairs(reachableArea) do
            if (type(column) == "table") then
                for y, _ in pairs(column) do
                    if (((x == originX) and (y == originY))              or
                        (not modelUnitMap:getModelUnit({x = x, y = y}))) then
                        updateAttackableArea(area, mapSize, x, y, minRange, maxRange)
                    end
                end
            end
        end

        return area
    end
end

return AttackableGridListFunctions
