
local ViewFogMap = class("ViewFogMap", cc.Node)

local GridIndexFunctions  = require("src.app.utilities.GridIndexFunctions")
local SingletonGetters    = require("src.app.utilities.SingletonGetters")
local VisibilityFunctions = require("src.app.utilities.VisibilityFunctions")

local getModelTurnManager = SingletonGetters.getModelTurnManager
local isTileVisible       = VisibilityFunctions.isTileVisibleToPlayerIndex
local toPositionWithXY    = GridIndexFunctions.toPositionWithXY

local FOG_OPACITY = 95

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewFogMap:ctor(param)
    self:ignoreAnchorPointForPosition(true)

    return self
end

function ViewFogMap:setMapSize(mapSize)
    assert(self.m_MapSize == nil, "ViewFogMap:setMapSize() the size has been initialized already.")

    local map           = {}
    local width, height = mapSize.width, mapSize.height
    for x = 1, width do
        local column = {}
        for y = 1, height do
            local viewFog = cc.Sprite:createWithSpriteFrameName("c01_t99_s07_f01.png")
            viewFog:ignoreAnchorPointForPosition(true)
                :setPosition(toPositionWithXY(x, y))

            column[y] = viewFog
            self:addChild(viewFog)
        end
        map[x] = column
    end

    self.m_Map     = map
    self.m_MapSize = mapSize
    self:setCascadeOpacityEnabled(true)
        :setOpacity(FOG_OPACITY)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ViewFogMap:updateWithModelFogMap()
    local playerIndex   = getModelTurnManager():getPlayerIndex()
    local width, height = self.m_MapSize.width, self.m_MapSize.height
    local map           = self.m_Map

    for x = 1, width do
        local column = map[x]
        for y = 1, height do
            column[y]:setVisible(not isTileVisible(nil, {x = x, y = y}, playerIndex))
        end
    end

    return self
end

return ViewFogMap
