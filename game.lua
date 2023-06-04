-- Plant
local PLANT_MIN_RADIUS = 1.0
local PLANT_MAX_RADIUS = 15.0
local PLANT_COLOURS = {
    7,13,14
}

local TERRAIN_COLOURS = {
    5, 6
}


DEBUG_ENTITY_BOUNDS = false
DEBUG_ENTITY_PADDING = 5

function setDebug(enabled)
    DEBUG_ENTITY_BOUNDS = enabled
end

local Entity = {}
function Entity:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    self.bounds = o.bounds or {
        x = 0,
        y = 0,
        width = 0,
        height = 0
    }
    return o
end

function Entity:update()

end

function Entity:draw()
    if(DEBUG_ENTITY_BOUNDS)
    then
        shape.rect(self.bounds.x - DEBUG_ENTITY_PADDING, self.bounds.y - DEBUG_ENTITY_PADDING, self.bounds.width + DEBUG_ENTITY_PADDING * 2, self.bounds.height + DEBUG_ENTITY_PADDING * 2, 1)
    end
end

function Entity:containsPoint(point)
    return point ~= nil and (point.x >= self.bounds.x
        and point.x <= self.bounds.x + self.bounds.width
        and point.y >= self.bounds.y
        and point.y <= self.bounds.y + self.bounds.height)
end

function Entity:wasClicked()
    local touch = ctrl.touched(0)
    return touch ~= nil and self:containsPoint(touch)
end

function Entity:isClicked()
    local touch = ctrl.touching(0)
    return touch ~= nil and self:containsPoint(touch)
end

local Plant = Entity:new({
    bounds = { x = 0, y = 0 },
    radius = 0,
    height = 0,
    colour = 4,
    water = 0.5,
    minRadius = PLANT_MIN_RADIUS,
    maxRadius = PLANT_MAX_RADIUS
 })


function Plant:consumeWater()
    local w = _clamp(0, self.water - 0.001, 1)
    self.water = w
end

function Plant:addWater()
    if(self:isClicked())
    then
        self.water = _clamp(0, self.water + 0.01, 1)
    end
end

function Plant:updateSize()
    self.radius = _clamp(self.minRadius, self.maxRadius * self.water, self.maxRadius)
end

function Plant:isAlive()
    return self.water > 0
end

function Plant:updateBounds()
    self.bounds.width = self.radius * 2
    self.bounds.height = self.radius * 2
end

function Plant:update()
    self:updateBounds()
    self:consumeWater()
    self:addWater()
    self:updateSize()
end

function Plant:draw()
    Entity.draw(self)
    shape.circlef(self.bounds.x + self.radius, self.bounds.y + self.radius, self.radius, self.colour)
end

-- End Plant

-- Helpers

function _clamp(a, value, b)
    if(value < a)
    then
        return a
    elseif (value > b)
    then
        return b
    else
        return value
    end
end

-- End Helpers
local Button = Entity:new({text = "Click Me!", bounds = {x = 0, y = 0, width = 25, height = 10}, colour = 3, onClick = {}})

function Button:update()
    if(self:wasClicked())
    then
        self.onClick()
    end
end

function Button:draw()
    Entity.draw(self)
    shape.rectf(self.bounds.x, self.bounds.y, self.bounds.width, self.bounds.height, self.colour)
    print(self.text, self.bounds.x + self.bounds.width * 0.25, self.bounds.y + self.bounds.height * 0.25)
end

State = {}
function State:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    self.dbgButton = Button:new({
        text = "DEBUG OFF",
        bounds = {x = 5, y = 5, width = 50, height = 10},
        onClick = function () setDebug(not DEBUG_ENTITY_BOUNDS) end
    })
    return o
end

function State:enter()

end

function State:exit()

end

function State:update()
    if(DEBUG_ENTITY_BOUNDS)
    then
        self.dbgButton.text = "DEBUG ON"
    else
        self.dbgButton.text = "DEBUG OFF"
    end
    self.dbgButton:update()
end

function State:draw()
    self.dbgButton:draw()
end

MainMenu = State:new()
function MainMenu:enter()
    self.button = Button:new({
        text = "Start Gardening",
        bounds = { x = 256 * 0.25, y = 256 * 0.5, width = 256 * 0.5, height = 256 * 0.1},
        onClick = function () setState(STATE_GAME) end
    })
end

function MainMenu:update()
    State.update(self)
    self.button:update()
end

function MainMenu:draw()
    State.draw(self)
    self.button:draw()
end

Game = State:new()
function Game:enter()
    self:randomisePlants(10)
end

function Game:randomisePlants(n)
    self.plants = {}
    for i = 1, n, 1 do
        local x = math.rnd(16, 240)
        local y = math.rnd(16, 240)
        local rMax = math.rnd(PLANT_MAX_RADIUS * 0.5, PLANT_MAX_RADIUS)
        local rMin = math.rnd(PLANT_MIN_RADIUS, PLANT_MAX_RADIUS * 0.25)
        local r = math.rnd(rMin, rMax)
        self.plants[i] = Plant:new({
            bounds = {
                x = x - r,
                y = y + r,
                width = r * 2,
                height = r * 2
            },
            maxRadius = rMax,
            minRadius = rMin,
            colour = PLANT_COLOURS[math.rnd(#PLANT_COLOURS)]
        })
    end
end

function Game:exit()

end

function Game:update()
    State.update(self)
    local gameOver = true
    for _, p in ipairs(self.plants) do
        p:update()
        if(p:isAlive())
        then
            gameOver = false
        end
    end

    if(gameOver)
    then
        setState(STATE_GAME_OVER)
    end
end

function Game:drawTerrain()
    for x = 0, 256, 1 do
        for y = 256, 0, -1 do
            nx = math.sin(x)
            ny = math.sin(y)
            gfx.pset(x, y, nx + ny < 0.5 and TERRAIN_COLOURS[1] or TERRAIN_COLOURS[2])
        end
    end
end

function Game:draw()
    State.draw(self)
    -- self:drawTerrain()
    for _, p in ipairs(self.plants) do
        p:draw()
    end
end

GameOver = State:new()
function GameOver:enter()
    self.button = Button:new({
        text = "Return to Main Menu",
        bounds = { x = 256 * 0.25, y = 256 * 0.5, width = 256 * 0.5, height = 256 * 0.1},
        onClick = function () setState(STATE_MENU) end
    })
end

function GameOver:exit()

end

function GameOver:update()
    State.update(self)
    self.button:update()
end

function GameOver:draw()
    gfx.cls(1)
    State.draw(self)
    self.button:draw()
end


-- Game State 

STATE_MENU = 0
STATE_GAME = 1
STATE_GAME_OVER = 2

STATES = {
    [STATE_MENU] = MainMenu, -- MENU
    [STATE_GAME] = Game, -- GAME
    [STATE_GAME_OVER] = GameOver --GAME_OVER
}

-- End Game State

function setState(s)
    STATES[GAME_STATE]:exit()
    GAME_STATE = s
    STATES[GAME_STATE]:enter()
end

function _init()
    GAME_STATE = STATE_MENU
    STATES[GAME_STATE]:enter()
end

function _update()
    STATES[GAME_STATE]:update()
end

function _draw()
    gfx.cls(5)
    STATES[GAME_STATE]:draw()
end
