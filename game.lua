-- Plant
local PLANT_MIN_RADIUS = 1.0
local PLANT_MAX_RADIUS = 15.0
local PLANT_COLOURS = {
    7,13,14
}

local TERRAIN_COLOURS = {
    5, 6
}

local GAME_RUNTIME_CONFIG = {
    DEBUG_ENTITY_BOUNDS = false,
    DEBUG_ENTITY_PADDING = 5,
    PAUSED = false
}

function setDebug(enabled)
    GAME_RUNTIME_CONFIG.DEBUG_ENTITY_BOUNDS = enabled
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
    if(GAME_RUNTIME_CONFIG.DEBUG_ENTITY_BOUNDS)
    then
        shape.rect(self.bounds.x - GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING, self.bounds.y - GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING, self.bounds.width + GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING * 2, self.bounds.height + GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING * 2, 1)
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
    return touch ~= nil and self:containsPoint(ctrl.touch())
end

PLANT_TYPES = {
    BURIED = 0,
    OVERGROUND = 1,
    TALL = 2
}

local Plant = Entity:new({
    bounds = { x = 0, y = 0 },
    radius = 0,
    height = 0,
    colour = 4,
    water = 0,
    minRadius = PLANT_MIN_RADIUS,
    maxRadius = PLANT_MAX_RADIUS,
    type = PLANT_TYPES.OVERGROUND,
    species = 0,
    stage = 0
 })

 WATER_DECAY_RATE = 0.001
 WATER_ADD_RATE = 0.01

function Plant:consumeWater()
    local w = _clamp(0, self.water - WATER_DECAY_RATE, 1)
    self.water = w
end

function Plant:addWater()
    if(self:isClicked())
    then
        self.water = _clamp(0, self.water + WATER_ADD_RATE, 1)
    end
end

function Plant:updateGrowth()
    self.stage = _clamp(0, math.floor(self.water / 0.2), 4)
end

function Plant:updateSize()
    self.radius = _clamp(self.minRadius, self.maxRadius * self.water, self.maxRadius)
end

function Plant:isAlive()
    return self.water > 0
end

function Plant:updateBounds()
    self.bounds.width = 16 -- self.radius * 2
    self.bounds.height = 16 -- self.radius * 2
end

function Plant:update()
    if(not GAME_RUNTIME_CONFIG.PAUSED)
    then
        self:updateGrowth()
        self:consumeWater()
        self:addWater()
        self:updateSize()
    end
end

function Plant:draw()
    Entity.draw(self)
    spr.sheet(self.type)
    spr.sdraw(self.bounds.x, self.bounds.y - 16, self.stage * 16, self.species, 16, 30, false, false)
    -- shape.circlef(self.bounds.x + self.radius, self.bounds.y + self.radius, self.radius, self.colour)
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
local ButtonBar = Entity:new({
    buttons = {},
    bounds = {x = 0, y = 0, width = 0, height = 0},
    direction = 0,
    padding = 5
})

function ButtonBar:layout()
    if(self.direction == 0)
    then
        self:layoutHorizontal()
    else
        self:layoutVertical()
    end
end

function ButtonBar:layoutVertical()
    local y = self.bounds.y
    local previousHeight = self.padding
    for _, b in ipairs(self.buttons) do
       b.bounds.x = self.bounds.x
       b.bounds.y = y + previousHeight + self.padding
       y = b.bounds.y
       previousHeight = b.bounds.height
    end
end

function ButtonBar:layoutHorizontal()
    local x = self.bounds.x
    local previousWidth = self.padding
    for _, b in ipairs(self.buttons) do
       b.bounds.x = x + previousWidth + self.padding
       b.bounds.y = self.bounds.y
       previousWidth = b.bounds.width
       x = b.bounds.x
    end
end

function ButtonBar:update()
    for _, value in ipairs(self.buttons) do
        value:update()
    end
end

function ButtonBar:draw()
    for _, b in ipairs(self.buttons) do
        b:draw()
    end
end

function ButtonBar:addButton(button)
    table.insert(self.buttons, button)
    self:layout()
end

function ButtonBar:removeButton(id)
    for i, b in ipairs(self.buttons) do
        if(b.id == id)
        then
            table.remove(self.buttons, i)
            break
        end
    end
    self:layout()
end

function ButtonBar:getButton(id)
    for i, b in ipairs(self.buttons) do
        if(b.id == id)
        then
            return b
        end
    end
end

local ToggleBar = ButtonBar:new()
function ToggleBar:new(o)
    o = o or {}
    o = ButtonBar.new(self, o)
    self.buttons = o.buttons
    for _, value in ipairs(self.buttons) do
        table.insert(value.onClick, function(b) self:onButtonClicked(b) end)
        table.insert(value.onUnClick, function(b) self:onButtonUnclicked(b) end)
    end
    return o
end

function ToggleBar:onButtonClicked(b)
    for _, value in ipairs(self.buttons) do
        if(value.id ~= b.id)
        then
            value:deactivate()
        end
    end
end

function ToggleBar:onButtonUnclicked(b)
end

local Button = Entity:new({id = "my_id", text = "Click Me!", bounds = {x = 0, y = 0, width = 25, height = 10}, colour = 3, onClick = {}})

function Button:update()
    Entity.update(self)
    if(self:wasClicked())
    then
        self:fireClickEvent()
    end
end

function Button:fireClickEvent()
    for _, c in ipairs(self.onClick) do
        c(self)
    end
end

function Button:draw()
    Entity.draw(self)
    shape.rectf(self.bounds.x, self.bounds.y, self.bounds.width, self.bounds.height, self.colour)
    tw = string.len(self.text) * 4 -- characters are 4 pixels wide
    print(self.text, self.bounds.x + ((self.bounds.width - tw) * 0.5), self.bounds.y + ((self.bounds.height  - 4) * 0.5))
end

local Toggle = Button:new()
function Toggle:new(o)
    o = o or {}
    o.onClick = o.onClick or {function (b) end}
    o = Button.new(self, o)
    self.on = o.on or false
    self.onUnClick = o.onUnClick or {function (b) end}
    self.normalColour = o.normalColour or 3
    self.activeColour = o.activeColour or 4
    self.colour = self.normalColour
    return o
end

function Toggle:update()
    Entity.update(self)

    if(self:wasClicked())
    then
        if(self.on)
        then
            self:deactivate()
        else
            self:activate()
        end
    end

    if(self.on)
    then
        self.colour = self.activeColour
    else
        self.colour = self.normalColour
    end
end

function Toggle:fireUnClickEvent()
    for _, c in ipairs(self.onUnClick) do
        c(self)
    end
end

function Toggle:activate()
    if(not self.on)
    then
        self.on = true
        self:fireClickEvent()
    end
end

function Toggle:deactivate()
    if(self.on)
    then
        self.on = false
        self:fireUnClickEvent()
    end
end

local State = {}
function State:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    self.buttons = ButtonBar:new()
    return o
end

function State:enter()
    self.buttons:addButton(Button:new({
        id = "debug_button",
        text = "DEBUG: OFF",
        bounds = {x = 0, y = 0, width = 50, height = 10},
        onClick = {function (b) setDebug(not GAME_RUNTIME_CONFIG.DEBUG_ENTITY_BOUNDS) end}
    }))
end

function State:exit()
    self.buttons:removeButton("debug_button")
end

function State:update()
    if(GAME_RUNTIME_CONFIG.DEBUG_ENTITY_BOUNDS)
    then
        self.buttons:getButton("debug_button").text = "DEBUG: ON"
    else
        self.buttons:getButton("debug_button").text = "DEBUG: OFF"
    end
    self.buttons:update()
end

function State:draw()
    self.buttons:draw()
end

local MainMenu = State:new()
function MainMenu:enter()
    State.enter(self)
    self.button = Button:new({
        text = "Start Gardening",
        bounds = { x = 256 * 0.25, y = 256 * 0.5, width = 256 * 0.5, height = 256 * 0.1},
        onClick = {function (b) setState(STATE_GAME) end}
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

WATER = 0
SEEDS = 1

TOOLS = {
    WATER,
    SEEDS
}

local Cursor = Entity:new({
    tool = TOOLS.WATER,
    colour = 3
})

function Cursor:new(o)
    o = o or {}
    o.count = 0
    o.using = false
    o.stage = 0
    o = Entity.new(self, o)
    return o
end

function Cursor:update()
    Entity.update(self)
    local t = ctrl.touch()
    self.bounds.x = t.x
    self.bounds.y = t.y
    self.sprite = 25

    if(self.tool == TOOLS.WATER)
    then
        self.sprite = 25
    elseif (self.tool == TOOLS.SEEDS)
    then
        self.sprite = 21
    end
    if(ctrl.touched(0))
    then
        if(not self.using)
        then
            self.count = 0
        end
        self.using = true
    elseif(ctrl.touching(0))
    then
        self.count = self.count + tiny.dt
    else
        self.using = false
        self.count = 0
    end

    if(self.using)
    then
        self:updateWater()
    end
end

function Cursor:updateWater()
    self.stage = _clamp(0, math.floor(((self.count) * (1 / 18) * 500)), 18)
    if(self.stage >= 18)
    then
        self.count = 0
        self.stage = 0
    end
end

function Cursor:drawWater()
    spr.sheet(3)
    spr.sdraw(self.bounds.x - 16, self.bounds.y, self.stage * 18, 0, 16, 16, false, false)
end

function Cursor:draw()
    if(self.using)
    then
        self:drawWater()
    end
    --shape.circlef(self.bounds.x, self.bounds.y, 2, self.colour)
end



local Game = State:new()
function Game:enter()
    State.enter(self)
    self.cursor = Cursor:new({
        tool = TOOLS.WATER,
        colour = 3
    })

    self.buttons:addButton(Button:new{
        id = "pause_button", 
        bounds = {x = 0, y = 0, width = 50, height = 10},
        text = "PAUSE",
        onClick = {function(b) GAME_RUNTIME_CONFIG.PAUSED = not GAME_RUNTIME_CONFIG.PAUSED end}
    })

    self.tools = ToggleBar:new({
        bounds = {
            x = 10,
            y = 20,
            width = 10
        },
        direction = 1,
        buttons = {
            Toggle:new({
                id = "water_button",
                text = "W",
                bounds = {x = 0, y = 0, width = 10, height = 10},
                on = true
            }),
            Toggle:new({
                id = "seed_button",
                text = "S",
                bounds = {x = 0, y = 0, width = 10, height = 10},
                on = false
            })
        }
    })
    self.tools:layout()
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
                x = x,
                y = y,
                width = 16,
                height = 16
            },
            maxRadius = rMax,
            minRadius = rMin,
            colour = PLANT_COLOURS[math.rnd(#PLANT_COLOURS)],
            species = math.rnd(0, 6),
            type = math.rnd(0, 3),
            stage = 0,
            water = 1
        })
    end
end

function Game:exit()
    State.exit(self)
    self.buttons:removeButton("pause_button")
end

function Game:update()
    State.update(self)

    if(GAME_RUNTIME_CONFIG.PAUSED)
    then
        self.buttons:getButton("pause_button").text = "RESUME"
    else
        self.buttons:getButton("pause_button").text = "PAUSE"
    end

    self.tools:update()
    self.cursor:update()

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

    self.tools:draw()
    self.cursor:draw()
end

local GameOver = State:new()
function GameOver:enter()
    State.enter(self)
    self.button = Toggle:new({
        text = "Return to Main Menu",
        bounds = { x = 256 * 0.25, y = 256 * 0.5, width = 256 * 0.5, height = 256 * 0.1},
        onClick = {function () setState(STATE_MENU) end}
    })
end

function GameOver:exit()
    State.exit(self)
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
    debug("setting state ")
    STATES[GAME_STATE]:exit()
    GAME_STATE = s
    STATES[GAME_STATE]:enter()
end

function _init()
    debug("init")
    GAME_STATE = STATE_GAME
    STATES[GAME_STATE]:enter()
end

function _update()
    STATES[GAME_STATE]:update()
end

function _draw()
    gfx.cls(5)
    STATES[GAME_STATE]:draw()
end
