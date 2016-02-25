
local ViewTileInfo = class("ViewTileInfo", cc.Node)

local CONTENT_SIZE_WIDTH, CONTENT_SIZE_HEIGHT = 110, 160
local LEFT_POSITION_X = 20
local LEFT_POSITION_Y = 20
local RIGHT_POSITION_X = display.width - CONTENT_SIZE_WIDTH - 20
local RIGHT_POSITION_Y = LEFT_POSITION_Y

local function createBackground()
    local background = cc.LayerColor:create({r = 0, g = 0, b = 0, a = 80})
    background:ignoreAnchorPointForPosition(true)
        
        :setContentSize(CONTENT_SIZE_WIDTH, CONTENT_SIZE_HEIGHT)
        
    return background
end

function ViewTileInfo:ctor(param)
    self:ignoreAnchorPointForPosition(true)
        :moveToRightSide()
    
        :addChild(createBackground())
        
    if (param) then
        self:load(param)
    end
    
    return self
end

function ViewTileInfo:load(param)
    return self
end

function ViewTileInfo.createInstance(param)
    local view = ViewTileInfo.new():load(param)
    assert(view, "ViewTileInfo.createInstance() failed.")
    
    return view
end

function ViewTileInfo:handleAndSwallowTouch(touch, touchType, event)
    if (touchType == cc.Handler.EVENT_TOUCH_BEGAN) then
        self.m_IsTouchMoved = false
        return false
    elseif (touchType == cc.Handler.EVENT_TOUCH_MOVED) then
        self.m_IsTouchMoved = true
        return false
    elseif (touchType == cc.Handler.EVENT_TOUCH_CANCELLED) then
        return false
    elseif (touchType == cc.Handler.EVENT_TOUCH_ENDED) then
        if (not self.m_IsTouchMoved) then
            local touchLocation = touch:getLocation()
            if (touchLocation.y <= display.height / 2) then
                if (touchLocation.x <= display.width / 2) then
                    self:moveToRightSide()
                else
                    self:moveToLeftSide()
                end
            end
        end
        
        return false
    end
end

function ViewTileInfo:moveToLeftSide()
    self:move(LEFT_POSITION_X, LEFT_POSITION_Y)
    
    return self
end

function ViewTileInfo:moveToRightSide()
    self:move(RIGHT_POSITION_X, RIGHT_POSITION_Y)
    
    return self
end

return ViewTileInfo
