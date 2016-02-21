
local ViewUnit = class("ViewUnit", function()
	return display.newSprite()
end)

local Requirer          = require"app.utilities.Requirer"
local ComponentManager  = Requirer.component("ComponentManager")
local TypeChecker       = Requirer.utility("TypeChecker")
local TemplateViewUnits = Requirer.gameConstant().Mapping_TiledIdToTemplateViewTileOrUnit
local GridSize          = Requirer.gameConstant().GridSize

function ViewUnit:createTouchListener()
    local function onTouchBegan(touch, event)
        local locationInNodeSpace = self:convertToNodeSpace(touch:getLocation())
        local x, y = locationInNodeSpace.x, locationInNodeSpace.y
        return x >= 0 and y >= 0 and x <= GridSize.width and y <= GridSize.height
    end
    local function onTouchEnded(touch, event)
        print("ViewUnit touched.")
    end

    local listener = cc.EventListenerTouchOneByOne:create()
    listener:registerScriptHandler(onTouchBegan, cc.Handler.EVENT_TOUCH_BEGAN)
	listener:registerScriptHandler(onTouchEnded, cc.Handler.EVENT_TOUCH_ENDED)
    
    return listener
end

function ViewUnit:ctor(param)
    self:ignoreAnchorPointForPosition(true)
    self:getEventDispatcher():addEventListenerWithSceneGraphPriority(self:createTouchListener(), self)

    if (param) then self:load(param) end

	return self
end

function ViewUnit:load(param)
    local tiledID = param.TiledID
    assert(TypeChecker.isTiledID(tiledID), "ViewUnit:load() the param hasn't a valid TiledID.")

    self:updateWithTiledID(tiledID)

	return self
end

function ViewUnit.createInstance(param)
	local view = ViewUnit.new():load(param)
    assert(view, "ViewUnit.createInstance() failed.")

	return view
end

function ViewUnit:updateWithTiledID(tiledID)
    assert(TypeChecker.isTiledID(tiledID))
    if (self.m_TiledID_ == tiledID) then return end

    local template = TemplateViewUnits[tiledID]
    assert(template, "ViewUnit:updateWithTiledID() failed to get the template with param tiledID.")

    self.m_TiledID_ = tiledID
    self:stopAllActions()
        :playAnimationForever(template.Animation)
    
    return self
end

return ViewUnit