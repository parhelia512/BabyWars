
--[[--------------------------------------------------------------------------------
-- ModelTileMap是战场上的地形地图，实质上就是ModelTile组成的矩阵。
--
-- 主要职责和使用场景举例：
--   构造地形地图，维护相关数值，提供接口给外界访问
--
-- 其他：
--   - 如何用数据文件完全描述一个ModelTileMap
--     最直接的做法，就是详细描述地图上每一个tile的数据。使用该文件重建ModelTileMap时，只需用这些数据分别重建每一个tile，再合成矩阵就可以了。
--     但，考虑到ModelTileMap一般都有上百个tile，如果采取这种做法的话，数据文件就会很大。
--
--     再考虑到tile的特性：很多tile是没有“非模板”的状态的（参考ModelTile的注释），因此多数情况下，用tiledID，配合GameConstant中的模板，就可以完全描述一个tile了。
--     那么，只要有一个由tiledID组成的矩阵（严格来说是分了两层的矩阵），配合模板，我们就能重建一个“满血满状态”的ModelTileMap。而tiledID矩阵，正是Tiled软件所生成的数据。
--     最后，要如何描述被打到残血的meteor，或被占领了一半的city呢？模板无法描述这些数据，因此我们需要用到类似instantialData的数据来描述它们。
--
--     综上，描述ModelTileMap的数据文件可以分为两个部分：一个是模板地图的名字，一个是instantialData（参考res/data/tileMap/TileMap_Overwrite1.lua）。
--
--   - 使用数据文件重建ModelTileMap的步骤：
--     1. 通过文件中的模板地图的名字，找到模板地图数据文件（该文件由Tiled软件生成，在客户端和服务端上都要有，以免无谓的数据传输），并用该文件重建满血满状态的地图
--     2. 使用instantialData，更新对应的tile的数据
--
--   - 递归的数据文件
--     如果仔细考虑，可以想到，数据文件可以通过模板地图进行递归构造（也就是说，模板地图里引用了另一个模板地图）
--     递归构造不能说完全没用，但它会导致理解上的麻烦以及某些其他问题（如A地图引用了B地图，那么A地图的作者是不是也要加上B地图作者的名字），因此我决定禁用这种构造。
--
--   - 创建新战局时，程序需要创建相应的数据文件。由于战局都是建立在模板地图之上的，所以这个数据文件将引用该模板地图，同时附带一个空的instantialData（在ModelTileMap还没被玩家所改变的情况下）。
--     若玩家的操作改变了ModelTileMap上的某些属性（比如占领，攻击meteor，发射导弹），那么相应的数据就记在instantialData中即可。
--]]--------------------------------------------------------------------------------

local ModelTileMap = require("src.global.functions.class")("ModelTileMap")

local GridIndexFunctions     = require("src.app.utilities.GridIndexFunctions")
local SerializationFunctions = require("src.app.utilities.SerializationFunctions")
local SingletonGetters       = require("src.app.utilities.SingletonGetters")
local VisibilityFunctions    = require("src.app.utilities.VisibilityFunctions")
local Actor                  = require("src.global.actors.Actor")

local isTileVisible = VisibilityFunctions.isTileVisibleToPlayerIndex
local toErrMsg      = SerializationFunctions.toErrorMessage

local IS_SERVER               = require("src.app.utilities.GameConstantFunctions").isServer()
local TEMPLATE_WAR_FIELD_PATH = "res.data.templateWarField."

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function requireMapData(param)
    local t = type(param)
    if (t == "string") then
        return require(TEMPLATE_WAR_FIELD_PATH .. param)
    elseif (t == "table") then
        return param
    else
        return error("ModelTileMap-requireMapData() the param is invalid.")
    end
end

local function getTiledTileBaseLayer(tiledData)
    return tiledData.layers[1]
end

local function getTiledTileObjectLayer(tiledData)
    return tiledData.layers[2]
end

local function createEmptyMap(width)
    local map = {}
    for x = 1, width do
        map[x] = {}
    end

    return map
end

local function createTileActorsMapWithTiledLayers(objectLayer, baseLayer, isPreview)
    local width, height = baseLayer.width, baseLayer.height
    local map = createEmptyMap(width)

    for x = 1, width do
        for y = 1, height do
            local idIndex = x + (height - y) * width
            local actorData = {
                objectID      = objectLayer.data[idIndex],
                baseID        = baseLayer.data[idIndex],
                GridIndexable = {gridIndex = {x = x, y = y}},
                isPreview     = isPreview,
            }

            map[x][y] = Actor.createWithModelAndViewName("sceneWar.ModelTile", actorData, "sceneWar.ViewTile", actorData)
        end
    end

    return map, {width = width, height = height}
end

local function updateTileActorsMapWithGridsData(map, mapSize, gridsData)
    for _, gridData in ipairs(gridsData) do
        local gridIndex = gridData.GridIndexable.gridIndex
        assert(GridIndexFunctions.isWithinMap(gridIndex, mapSize), "ModelTileMap-updateTileActorsMapWithGridsData() the data of overwriting grid is invalid.")
        map[gridIndex.x][gridIndex.y]:getModel():ctor(gridData)
    end
end

--------------------------------------------------------------------------------
-- The composition tile actors map.
--------------------------------------------------------------------------------
local function createTileActorsMap(param)
    local mapData         = requireMapData(param)
    local templateMapData = requireMapData(mapData.template)
    local map, mapSize    = createTileActorsMapWithTiledLayers(getTiledTileObjectLayer(templateMapData), getTiledTileBaseLayer(templateMapData), param.isPreview)
    updateTileActorsMapWithGridsData(map, mapSize, mapData.grids or {})

    return map, mapSize, mapData.template
end

local function initWithTileActorsMap(self, map, mapSize, templateName)
    self.m_ActorTilesMap = map
    self.m_MapSize       = mapSize
    self.m_TemplateName  = templateName
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelTileMap:ctor(param)
    initWithTileActorsMap(self, createTileActorsMap(param))

    return self
end

function ModelTileMap:initView()
    local view = self.m_View
    assert(view, "ModelTileMap:initView() no view is attached to the owner actor of the model.")
    view:removeAllChildren()

    local mapSize = self:getMapSize()
    for y = mapSize.height, 1, -1 do
        for x = mapSize.width, 1, -1 do
            view:addChild(self.m_ActorTilesMap[x][y]:getView())
        end
    end

    return self
end

function ModelTileMap:updateOnModelFogMapStartedRunning()
    assert(not IS_SERVER, "ModelTileMap:updateOnModelFogMapStartedRunning() this shouldn't be called on the server.")

    if (not SingletonGetters.isTotalReplay()) then
        local playerIndex      = SingletonGetters.getPlayerIndexLoggedIn()
        local sceneWarFileName = self.m_SceneWarFileName
        self:forEachModelTile(function(modelTile)
            modelTile:initHasFogOnClient(not isTileVisible(sceneWarFileName, modelTile:getGridIndex(), playerIndex))
                :updateView()
        end)
    end

    return self
end

--------------------------------------------------------------------------------
-- The function for serialization.
--------------------------------------------------------------------------------
function ModelTileMap:toSerializableTable()
    local grids = {}
    self:forEachModelTile(function(modelTile)
        grids[#grids + 1] = modelTile:toSerializableTable()
    end)

    return {
        template = self.m_TemplateName,
        grids    = grids,
    }
end

function ModelTileMap:toSerializableTableForPlayerIndex(playerIndex)
    local grids = {}
    self:forEachModelTile(function(modelTile)
        grids[#grids + 1] = modelTile:toSerializableTableForPlayerIndex(playerIndex)
    end)

    return {
        template = self.m_TemplateName,
        grids    = grids,
    }
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelTileMap:onStartRunning(sceneWarFileName)
    self.m_SceneWarFileName = sceneWarFileName
    self:forEachModelTile(function(modelTile)
        modelTile:onStartRunning(sceneWarFileName)
    end)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelTileMap:getMapSize()
    return self.m_MapSize
end

function ModelTileMap:getTemplateName()
    return self.m_TemplateName
end

function ModelTileMap:getMapName()
    return requireMapData(self.m_TemplateName).warFieldName
end

function ModelTileMap:getAuthorName()
    return requireMapData(self.m_TemplateName).authorName
end

function ModelTileMap:getModelTile(gridIndex)
    assert(GridIndexFunctions.isWithinMap(gridIndex, self:getMapSize()),
        "ModelTileMap-getModelTile() invalid param gridIndex: " .. toErrMsg(gridIndex))

    return self.m_ActorTilesMap[gridIndex.x][gridIndex.y]:getModel()
end

function ModelTileMap:forEachModelTile(func)
    local mapSize = self:getMapSize()
    for x = 1, mapSize.width do
        for y = 1, mapSize.height do
            func(self.m_ActorTilesMap[x][y]:getModel())
        end
    end

    return self
end

return ModelTileMap
