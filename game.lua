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
    DEBUG_ENTITY_PADDING = 0,
    PAUSED = false,
    DEBUG_ALLOW_GAME_END = true,
    WATER_ADD_RATE = 0.01,
    WATER_DECAY_RATE = 0.001
}

function setDebug(enabled)
    GAME_RUNTIME_CONFIG.DEBUG_ENTITY_BOUNDS = enabled
end

function Collision(a, b)
    return function(fn) return fn(a, b) end
end

function _collision_a(a, b)
    return a
end

function _collision_b(a, b)
    return b
end

local EntityCollection = {entities = {}}
function EntityCollection:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.entities = o.entities or {}
    self.collisionMap = {}
    return o
end

function EntityCollection:add(e)
    for _, value in ipairs(self.entities) do
        if(value.__entityId == e.__entityId)
        then
            --debug("Refusing to add entity " .. e.__entityId .. " - already exists")
        else
            table.insert(self.entities, e)
        end
    end
end

function EntityCollection:remove(e)
    for i, value in ipairs(self.entities) do
        if(value.__entityId == e.__entityId)
        then
            table.remove(self.entities, i)
        end
    end
end

function EntityCollection:colliding(a, b)
    return a:overlaps(b)
end

function EntityCollection:checkCollisions()
    --debug("Running collision checks for " .. #self.entities .. " entities")
    for i, value in ipairs(self.collisionMap) do
        local a = value(_collision_a)
        local b = value(_collision_b)

        if(not self:colliding(a, b))
        then
            table.remove(self.collisionMap, i)
            a:endCollision(b)
            b:endCollision(a)
        end
    end

    for i = 1, #self.entities, 1 do
        local a = self.entities[i]
        local anyCollision = false
        for x = i + 1, #self.entities, 1 do
            local b = self.entities[x]
            if(self:colliding(a, b))
            then
                anyCollision = true
                table.insert(self.collisionMap, Collision(a, b))
                a:collideWith(b)
                b:collideWith(a)
            end
        end

        if(a.colliding and not anyCollision)
        then
            a.colliding = false
        end
    end
end

ENTITY_ID_COUNTER = 0
local Entity = {__entityId = ENTITY_ID_COUNTER}
function Entity:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    ENTITY_ID_COUNTER = ENTITY_ID_COUNTER + 1
    self.__entityId = ENTITY_ID_COUNTER
    self.__index = self
    self.bounds = o.bounds or {
        x = 0,
        y = 0,
        width = 0,
        height = 0
    }
    self.colliding = false
    return o
end



function Entity:update()

end

function Entity:draw()
    if(GAME_RUNTIME_CONFIG.DEBUG_ENTITY_BOUNDS or self.colliding)
    then
        local debugColour = 1
        if(self:containsPoint(ctrl.touch()))
        then
            debugColour = 8
        end
        shape.rect(self.bounds.x - GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING, self.bounds.y - GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING, self.bounds.width + GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING * 2, self.bounds.height + GAME_RUNTIME_CONFIG.DEBUG_ENTITY_PADDING * 2, debugColour)
    end
end

function Entity:containsPoint(point)
    return point ~= nil and (point.x >= self.bounds.x
        and point.x <= self.bounds.x + self.bounds.width
        and point.y >= self.bounds.y
        and point.y <= self.bounds.y + self.bounds.height)
end

function Entity:overlaps(e)
    local tl = { x = e.bounds.x, y = e.bounds.y }
    local tr = { x = e.bounds.x + e.bounds.width, y = e.bounds.y }
    local bl = { x = e.bounds.x, y = e.bounds.y + e.bounds.height }
    local br = { x = e.bounds.x + e.bounds.width, y = e.bounds.y + e.bounds.height }
    return self:containsPoint(tl)
        or self:containsPoint(tr)
        or self:containsPoint(bl)
        or self:containsPoint(br)
end

function Entity:collideWith(e)
    self.colliding = true
end

function Entity:endCollision(e)
end

function Entity:wasClicked()
    local touch = ctrl.touched(0)
    return touch ~= nil and self:containsPoint(touch)
end

function Entity:isClicked()
    local touch = ctrl.touching(0)
    return touch ~= nil and self:containsPoint(ctrl.touch())
end

PLANT_SPRITE_Y_OFFSET = -16
PLANT_SPRITE_WIDTH = 16
PLANT_SPRITE_HEIGHT = 16

PLANT_TYPES = {
    BURIED = 0,
    OVERGROUND = 1,
    TALL = 2
}

local Plant = Entity:new({
    bounds = { x = 0, y = 0 },
    colour = 4,
    water = 0,
    type = PLANT_TYPES.OVERGROUND,
    species = 0,
    stage = 0
 })

 function Plant:new(o)
    o = o or {}
    o.bounds.y = o.bounds.y
    return Entity.new(self, o)
 end

function Plant:consumeWater()
    local w = _clamp(0, self.water - GAME_RUNTIME_CONFIG.WATER_DECAY_RATE, 1)
    self.water = w
end

function Plant:addWater()
    self.water = _clamp(0, self.water + GAME_RUNTIME_CONFIG.WATER_ADD_RATE, 1)
end

function Plant:updateGrowth()
    self.stage = _clamp(0, math.floor(self.water / 0.2), 4)
end

function Plant:isAlive()
    return self.water > 0
end

function Plant:updateBounds()
    self.bounds.width = PLANT_SPRITE_WIDTH
    self.bounds.height = PLANT_SPRITE_HEIGHT
end

function Plant:update()
    if(not GAME_RUNTIME_CONFIG.PAUSED)
    then
        self:updateGrowth()
        self:consumeWater()
    end
end

function Plant:draw()
    Entity.draw(self)
    spr.sheet(self.type)
    spr.sdraw(self.bounds.x, self.bounds.y - self.bounds.height, self.stage * PLANT_SPRITE_WIDTH, self.species * (PLANT_SPRITE_HEIGHT * 2), PLANT_SPRITE_WIDTH, PLANT_SPRITE_HEIGHT * 2, false, false)

    -- Water bar
    shape.rectf(self.bounds.x, self.bounds.y + self.bounds.height + 4, self.bounds.width, 2, 2)
    shape.rectf(self.bounds.x, self.bounds.y + self.bounds.height + 4, self.bounds.width * self.water, 2, 3)
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
    for _, b in ipairs(self.buttons) do
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
    self.entities = EntityCollection:new({
        entities = { self.buttons }
    })
    self.active = false
    
    return o
end

function State:enter()
    self.active = true
    local dbg_button = Button:new({
        id = "debug_button",
        text = "DEBUG: OFF",
        bounds = {x = 0, y = 0, width = 50, height = 10},
        onClick = {function (b) setDebug(not GAME_RUNTIME_CONFIG.DEBUG_ENTITY_BOUNDS) end}
    })

    self.entities:add(dbg_button)
    self.buttons:addButton(dbg_button)
end

function State:isActive()
    return self.active
end

function State:exit()
    self.active = false
    local dbg_button = self.buttons:getButton("debug_button")
    self.buttons:removeButton("debug_button")
    self.entities:remove(dbg_button)
end

function State:update()
    -- self.entities:checkCollisions()

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
    WATER = WATER,
    SEEDS = SEEDS
}

local Cursor = Entity:new({
    tool = TOOLS.WATER,
    colour = 3,
    bounds = {x = 0, y = 0, width = 10, height = 10}
})

-- PARTICLES
WATER_PARTICLE_COLOURS = {2, 3, 4}
SEED_PARTICLE_COLOURS = {12,13,14}
local Particles = {
    x = {0}, -- x position of the particle
    y = {0}, -- y position of the particle
    radius = {4}, -- start radius of the particle
    colors = {1}, -- color used to draw the particle
    sx = 0, -- x speed of the particle
    sy = 1, -- y speed of the particle
    sr = 0.1, -- radius speed of the particle
    ttl = 1, -- ttl, time to live in seconds. The particle is detroy when reach 0
    particles = {} -- list of the particles managed by this particle generator
}

-- Update all particles of the generator
-- This methods should be called by the user in the _update function.
function Particles:_update()
    --local colors = self.__asTable(self.colors)
    --debug(#colors)
    for k, v in rpairs(self.particles) do
        v.x = v.x + v.sx
        v.y = v.y + v.sy
        v.r = v.r - v.sr
        v.ttl = v.ttl - tiny.dt
        v.frame = v.frame + 1
        v.color = self.colors[math.min(#self.colors, v.frame)]
        if v.ttl < 0 then
            table.remove(self.particles, k)
        end
    end
end

-- Draw all particles of the generator
-- This methods should be called by the user in the _draw function.
function Particles:_draw()
    for p in all(self.particles) do
        self:__draw(p)
    end
end

-- PRIVATE --

local __Particle = {
    x = 0,
    y = 0,
    r = 0,
    sx = 0,
    sy = 0,
    sr = 0,
    ttl = 0,
    frame = 0,
    color = 0
}

-- return the value or the random value of a table
function Particles:__get(value)
    if (type(value) == "table") then
        return math.rnd(value)
    else
        return value
    end
end

function Particles:__asTable(value)
    if (type(value) == "table") then
        return value
    else
        return {value}
    end
end

function Particles:emit(number)
    for i = 0, number do
        table.insert(
                self.particles,
                new(
                        __Particle,
                        {
                            x = self:__get(self.x),
                            y = self:__get(self.y),
                            r = self:__get(self.radius),
                            sx = self:__get(self.sx),
                            sy = self:__get(self.sy),
                            sr = self:__get(self.sr),
                            ttl = self:__get(self.ttl)
                        }
                )
        )
    end
end

function Particles:__draw(particle)
    shape.circlef(particle.x, particle.y, particle.r, particle.color)
end
-- END PARTICLES


function Cursor:new(o)
    o = o or {}
    o.using = false
    o = Entity.new(self, o)

    Cursor.setTool(self, o.tool)

    return o
end

function Cursor:initWaterParticles()
    self.generator = new(Particles, {
        x = { 0 },
        y = { 0  },
        sx = { 0 },
        sy = 1,
        colors = WATER_PARTICLE_COLOURS,
        ttl = { 0.5 },
        radius = { 0.25 },
    })
    self.generator:_update()
end

function Cursor:initSeedParticles()
    self.generator = new(Particles, {
        x = { 0 },
        y = { 0  },
        sx = { 0 },
        sy = 1,
        colors = SEED_PARTICLE_COLOURS,
        ttl = { 0.5 },
        radius = { 0.25 },
    })
    self.generator:_update()
end

function Cursor:update(garden)
    local t = ctrl.touch()
    self.bounds.x = t.x - self.bounds.width * 0.5
    self.bounds.y = t.y - self.bounds.height * 0.5
    
    Entity.update(self)
    self:updateStatus(garden)
    self:updateTool()
end

function Cursor:updateStatus(garden)
    if(garden:overlaps(self))
    then
        if(ctrl.touched(0))
        then
            if(not self.using)
            then
                self.count = 0
            end
            self.using = true
        elseif(ctrl.touching(0))
        then
            if(self.tool == TOOLS.SEEDS)
            then
                self.using = false
            end
        else
            self.using = false
            self.count = 0
        end
    else
        self.using = false
    end
end

function Cursor:updateTool()
        if(self.tool == TOOLS.WATER)
        then
            self:updateWater()
        elseif (self.tool == TOOLS.SEEDS)
        then
            self:updateSeeds()
        end
end

function Cursor:setTool(t)
    if(t == TOOLS.WATER)
    then
        self.tool = t
        self:initWaterParticles()
    elseif(t == TOOLS.SEEDS)
    then
        self.tool = t
    end
end

function Cursor:updateWater()
    if(self.using)
    then
        local p = ctrl.touch()
        self.generator.x = { p.x, p.x - 3, p.x + 3 }
        self.generator.y = { p.y - 20 , p.y - 20, p.y - 20}
        self.generator.radius = 1
        self.generator.sx = 0
        self.generator.sy = 1
        self.generator.ttl = 1
        self.generator:emit(3)
        self.stage = _clamp(0, math.floor(((self.count) * (1 / 18) * 200)), 18)
        if(self.stage >= 18)
        then
            self.count = 0
            self.stage = 0
        end
    end

    if(self.generator ~= nil)
    then
        self.generator:_update()
    end
end

function Cursor:updateSeeds()
    if(self.using)
    then
        local p = ctrl.touch()
        self.generator.x = { p.x, p.x - 3, p.x + 3 }
        self.generator.y = { p.y - 10 , p.y - 10, p.y - 10}
        self.generator.radius = 2
        self.generator.sx = 0
        self.generator.sy = 0.25
        self.generator.sr = 0.05
        self.generator.ttl = 0.5
        self.generator:emit(3)
    end

    if(self.generator ~= nil)
    then
        self.generator:_update()
    end
end

function Cursor:drawWater()
    self.generator:_draw()
end

function Cursor:drawSeeds()
    self.generator:_draw()
end

function Cursor:draw()
    Entity.draw(self)
    if(self.tool == TOOLS.WATER)
    then
        self:drawWater()
    elseif (self.tool == TOOLS.SEEDS)
    then
        self:drawSeeds()
    end
end

GARDEN_BOUNDS = {x = 20, y = 20, width = 240 - 20, height = 240 - 20}

local Garden = Entity:new({
    bounds = GARDEN_BOUNDS,
    colour = 6
})

function Garden:new(o)
    o = o or {}
    o.bounds = o.bounds or GARDEN_BOUNDS
    o.plants = o.plants or {}
    o.colour = o.colour or 6
    return Entity.new(self, o)
end

function Garden:randomisePlants(n)
    for i = 1, n, 1 do
        self:addRandomPlant()
    end
end

function Garden:randomPlant()
    local x = math.rnd(self.bounds.x, self.bounds.width)
    local y = math.rnd(self.bounds.y, self.bounds.height)
    return self:randomPlantAt({x = x, y = y}, 1)
end

function Garden:randomPlantAt(position, water)
    return Plant:new({
        bounds = {
            x = position.x,
            y = position.y,
            width = PLANT_SPRITE_WIDTH,
            height = PLANT_SPRITE_HEIGHT
        },
        species = math.rnd(0, 5),
        type = math.rnd(0, 3),
        stage = 0,
        water = water
    })
end

function Garden:addRandomPlant()
    local p = self:randomPlant()
    self:addPlant(p)
end

function Garden:addPlant(p)
    table.insert(self.plants, p)
end

function Garden:addRandomPlantAt(position)
    local p = self:randomPlantAt(position, 0)
    self:addPlant(p)
end

function Garden:update(cursor, season)
    Entity.update(self)
    self.colour = SEASON_COLOURS[season]
    for _, p in ipairs(self.plants) do
        if(cursor.using and p:overlaps(cursor) and not GAME_RUNTIME_CONFIG.PAUSED)
        then
            p:addWater()
        end

        p:update()
    end

    if(cursor.using and cursor.tool == TOOLS.SEEDS and self:overlaps(cursor))
    then
        self:addRandomPlantAt({x = cursor.bounds.x, y = cursor.bounds.y})
    end
end

function Garden:anyPlantsAlive()
    for _, p in ipairs(self.plants) do
        if(p:isAlive())
        then
            return true
        end
    end
    
    return false
end

function Garden:draw()
    Entity.draw(self)
    shape.rect(self.bounds.x - 1, self.bounds.y - 1 , self.bounds.width + 2, self.bounds.height + 2, 14)
    shape.rectf(self.bounds.x, self.bounds.y, self.bounds.width, self.bounds.height, self.colour)

    for _, p in ipairs(self.plants) do
        p:draw()
    end
end

SEASONS = {
    "SPRING",
    "SUMMER",
    "AUTUMN",
    "WINTER"
}

SEASON_COLOURS = {
    SPRING = 9,
    SUMMER = 5,
    AUTUMN = 7,
    WINTER = 2
}

local Seasons = Entity:new({

})

function Seasons:new(o)
    o = o or {}
    o.bounds = {x = 20, y = 12, width = 240 - 20, height = 4}
    o.progress = 0
    o.rate = 0.05
    return Entity.new(self, o)
end

function Seasons:update()
    local p = self.progress + (tiny.dt * self.rate)
    if(p > 1)
    then
        p = 0
    end
    self.progress = _clamp(0, p, 1)
end

function Seasons:draw()
    shape.rectf(self.bounds.x, self.bounds.y, self.bounds.width, 4, 2)
    shape.rectf(self.bounds.x, self.bounds.y, self.bounds.width * 0.25, 4, SEASON_COLOURS["SPRING"])
    shape.rectf(self.bounds.x + (self.bounds.width * 0.25), self.bounds.y, self.bounds.width * 0.25, 4, SEASON_COLOURS["SUMMER"])
    shape.rectf(self.bounds.x + (self.bounds.width * 0.5), self.bounds.y, self.bounds.width * 0.25, 4, SEASON_COLOURS["AUTUMN"])
    shape.rectf(self.bounds.x + (self.bounds.width * 0.75), self.bounds.y, self.bounds.width * 0.25, 4, SEASON_COLOURS["WINTER"])

    shape.circlef(self.bounds.x + self.bounds.width * self.progress, self.bounds.y + 2, 4, 15)
end

function Seasons:currentSeason()
    local s = math.floor(juice.linear(1, 5, self.progress))
    return SEASONS[s]
end

local Game = State:new()
function Game:enter()
    State.enter(self)
    self.garden = Garden:new({
        bounds = GARDEN_BOUNDS,
        colour = SEASON_COLOURS["SPRING"]
    })
    self.entities:add(self.garden)
    self.garden:randomisePlants(10)
    self.seasons = Seasons:new({})

    self.cursor = Cursor:new({
        tool = TOOLS.WATER,
        colour = 3,
        bounds = {x = 0, y = 0, width = 5, height = 5}
    })
    self.entities:add(self.cursor)

    self.buttons:addButton(Button:new{
        id = "pause_button", 
        bounds = {x = 0, y = 0, width = 50, height = 10},
        text = "PAUSE",
        onClick = {function(b) GAME_RUNTIME_CONFIG.PAUSED = not GAME_RUNTIME_CONFIG.PAUSED end}
    })

    self.tools = ToggleBar:new({
        bounds = {
            x = 5,
            y = 20,
            width = 10
        },
        direction = 1,
        buttons = {
            Toggle:new({
                id = "water_button",
                text = "W",
                bounds = {x = 0, y = 0, width = 10, height = 10},
                on = true,
                onClick = {function(b) self.cursor:setTool(TOOLS.WATER) end}
            }),
            Toggle:new({
                id = "seed_button",
                text = "S",
                bounds = {x = 0, y = 0, width = 10, height = 10},
                on = false,
                onClick = {function(b) self.cursor:setTool(TOOLS.SEEDS) end}
            })
        }
    })
    self.tools:layout()
    self:startMusic()
end

function Game:startMusic()
    self:stopMusic()
    sfx.loop(1)
end

function Game:stopMusic()
    sfx.stop(1)
end

function Game:exit()
    State.exit(self)
    self.buttons:removeButton("pause_button")
    self:stopMusic()
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
    self.cursor:update(self.garden)

    if(not GAME_RUNTIME_CONFIG.PAUSED)
    then
        self.seasons:update()
        self.seasons:currentSeason()
        self.garden:update(self.cursor, self.seasons:currentSeason())
    end

    local gameover = self.garden:anyPlantsAlive()
    if(not (gameover) and GAME_RUNTIME_CONFIG.DEBUG_ALLOW_GAME_END)
    then
        setState(STATE_GAME_OVER)
    end
end

function Game:draw()
    State.draw(self)
    self.garden:draw()
    self.seasons:draw()
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
    gfx.cls(6)
    STATES[GAME_STATE]:draw()
end
