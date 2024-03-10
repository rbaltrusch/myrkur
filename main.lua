require "src/colour"
require "src/debug_util"
require "src/player"
require "src/animation"
require "src/error_util"
require "src/sprite_sheet"
require "src/tilemap"
require "src/camera"
require "src/collision"
require "src/file_util"
require "src/pathfinding"
require "src/entity"
require "src/timer"
require "src/stat_bar"
require "src/crown_bar"

CROWN = 142
KEY = 571

local function read_lighting_dist_from_config_file()
    for k, v in string.gmatch(FileUtil.read_file("config") or "", "(%w+)=(%w.%w+)") do
        if k == "lightingDist" then
            return v
        end
    end
    return nil
end

local function count_total_crowns_on_map(tiles)
    local count = 0
    for _, col in pairs(tiles) do
        for _, tile in pairs(col) do
            -- we are still offset by 1 here compared to the actual tile id...
            if tile.index == CROWN + 1 then
                count = count + 1
            end
        end
    end
    return count
end

function love.load()
    --BACKGROUND_COLOUR = Colour.construct(71, 45, 60)
    GHOST = 321
    GRAVEYARD_PURGATORY = 591
    BACKGROUND_COLOUR = Colour.construct(0, 0, 0)
    TILE_SIZE = 16
    DEBUG_ENABLED = false
    DEFAULT_SCALING = 2
    WIDTH, HEIGHT = 480, 320
    WIN_WIDTH, WIN_HEIGHT = love.window.getDesktopDimensions()
    MAX_SCALING = DEFAULT_SCALING * math.min(WIN_WIDTH / WIDTH, WIN_HEIGHT / HEIGHT)
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setIcon(love.image.newImageData("assets/runeM.png"))

    muted = false
    death_time = 0
    lighting_dist = read_lighting_dist_from_config_file() or 0.65
    won = false

    local music = love.audio.newSource("assets/myrkur_menu2.wav", "stream")
    music:setVolume(0.2)
    music:setPitch(0.5)
    music:setLooping(true)
    music:play()

    crown_pickup_sound = love.audio.newSource("assets/crown.mp3", "static")
    crown_pickup_sound:setVolume(0.2)

    key_pickup_sound = love.audio.newSource("assets/key.mp3", "static")
    key_pickup_sound:setVolume(0.2)

    heart_pickup_sound = love.audio.newSource("assets/heart.mp3", "static")
    heart_pickup_sound:setVolume(0.2)

    rest_sound = love.audio.newSource("assets/rest.wav", "static")
    rest_sound:setVolume(0.5)
    rest_sound:setPitch(0.5)

    ghost_death_sound = love.audio.newSource("assets/ghost_death.wav", "static")
    ghost_death_sound:setVolume(0.75)

    local walk_sound = love.audio.newSource("assets/walk.wav", "static")
    walk_sound:setVolume(0.2)

    local hurt_sound = love.audio.newSource("assets/hurt.mp3", "static")
    hurt_sound:setVolume(0.5)

    local death_sound = love.audio.newSource("assets/death.mp3", "static")
    death_sound:setVolume(0.5)

    local respawn_sound = love.audio.newSource("assets/respawn.wav", "static")
    respawn_sound:setVolume(0.4)

    local unlock_sound = love.audio.newSource("assets/unlock.wav", "static")
    unlock_sound:setVolume(0.4)

    player = Player.construct{
        image_path="assets/player.png",
        x=98 * TILE_SIZE,
        y=2 * TILE_SIZE,
        speed=80,
        health=3,
        max_health=5,
        invincible_timer=Timer.construct(1),
        hitbox_offset=0,
        tile_size=TILE_SIZE,
        walk_animation=Animation.construct(
            SpriteSheet.load_sprite_sheet("assets/player_walk.png", TILE_SIZE, TILE_SIZE), 0.1
        ),
        walk_left_animation=Animation.construct(
            SpriteSheet.load_sprite_sheet("assets/player_walk_left.png", TILE_SIZE, TILE_SIZE), 0.2 -- WHY different ?
        ),
        hurt_sound=hurt_sound,
        walk_sound=walk_sound,
        death_sound=death_sound,
        respawn_sound=respawn_sound,
        unlock_sound=unlock_sound,
        health_bar=StatBar.construct{
            amount=3, x=5, y=10-TILE_SIZE/4, tile_size=TILE_SIZE, image=love.graphics.newImage("assets/heart.png")
        },
    }
    camera = Camera.construct{x=0, y=0, speed_factor=2.5, width=WIDTH/DEFAULT_SCALING, height=HEIGHT/DEFAULT_SCALING}
    font = love.graphics.newFont("assets/KenneyPixel.ttf")
    font:setFilter("nearest", "nearest")

    --shader = love.graphics.newShader(FileUtil.read_file("assets/shader/lighting.vert") or "")
    shader = love.graphics.newShader(require("src/shader"))
    tileset = SpriteSheet.load_sprite_sheet("assets/kenney_1-bit-pack/Tilesheet/colored_packed.png", TILE_SIZE, TILE_SIZE)
    tilemap = require "assets/map"
    collision_map = TileMap.construct_collision_map(tilemap, "terrain", function(tile_index) return tile_index == 0 end) -- passable if empty
    ghost_collision_map = TileMap.construct_collision_map(tilemap, "terrain", function(tile_index) return true end) -- always passable
    tiles = TileMap.construct_tiles(tilemap, tileset)
    entities = Entity.construct_from_tilemap(
        tiles["enemies"].tiles,
        {speed=20, TILE_SIZE=TILE_SIZE, tile_range=5, tileset=tileset, damage=1, walk_sound=walk_sound:clone()}
    )

    crown_bar = CrownBar.construct{
        x=0,
        y=0,
        image=love.graphics.newImage("assets/crown.png"),
        total_crowns_on_map=count_total_crowns_on_map(tiles["collectibles"].tiles) - 1  -- 1 less for leniency
    }
end

local function remove_collectible(x, y)
    tiles["collectibles"].tiles[x][y] = nil
end

local function collect_rest_site(x, y)
    x = x * TILE_SIZE
    y = y * TILE_SIZE
    if player.last_rest_site.x == x and player.last_rest_site.y == y then
        return
    end
    player.last_rest_site = {x = x, y = y}
    rest_sound:play()
end

local function collect_crown(x, y)
    player.inventory:add("crown")
    crown_pickup_sound:play()
    remove_collectible(x, y)
end

local function collect_key(x, y)
    player.inventory:add("key")
    key_pickup_sound:play()
    remove_collectible(x, y)
end

local function collect_heart(x, y)
    player.inventory:add("heart")
    player:heal(1)
    heart_pickup_sound:play()
    remove_collectible(x, y)
end

local function check_collectible_collisions()
    local collectible_callbacks = {
        [CROWN] = collect_crown,
        [KEY] = collect_key,
        [529] = collect_heart,
        [504] = collect_rest_site,
    }

    local player_rect = player:get_rect()
    local collectibles = TileMap.get_tile_rects(tiles["collectibles"].tiles, TILE_SIZE)
    for pos, tile in pairs(collectibles) do
        if Collision.colliding(player_rect, tile.rect) then
            local x, y = unpack(pos)
            -- ids are one higher here than in tiled
            local callback = (
                collectible_callbacks[tile.tile.index - 1]
                or function() print("no collection callback", tile.tile.index - 1) end
            )
            callback(x, y)
        end
    end
end

local function check_collisions(tiles, index, callback)
    local player_rect = player:get_rect()
    local x, y = unpack(player:get_current_tile())
    for x_offs = -1, 1 do
        for y_offs = -1, 1 do
            local tile = tiles:get(x + x_offs, y + y_offs)

            local tile_rect = TileMap.get_tile_rect(x + x_offs, y + y_offs, TILE_SIZE)
            if tile and tile.index == index and Collision.colliding(player_rect, tile_rect) then
                callback()
            end
        end
    end
end

local function update(dt)
    player.slowed = false
    check_collisions(tiles["decor"], 738, function() player.slowed = true end)  -- cobweb
    player:update(dt)
    player:update_collisions(tiles["terrain"])
    check_collectible_collisions()
    check_collisions(tiles["enemies"], 23, function() player:hurt(1) end)  -- spikes
    camera:update(player, dt)

    if won or crown_bar:check_complete(player.inventory.items["crown"]) then
        won = true
        return
    end

    for _, entity in ipairs(entities) do
        local x, y = unpack(entity:get_current_tile())
        local tile = tiles["terrain"]:get(x, y)
        if not entity.dead and tile and tile.index == GRAVEYARD_PURGATORY and entity.tile.index == GHOST then
            entity:die()
            ghost_death_sound:play()
        end
        entity:update(dt, player, entity.tile.index == GHOST and ghost_collision_map or collision_map)
    end

    if not player:check_alive() then
        death_time = death_time + dt
    end

    if love.keyboard.isDown("space") then
    end
end

local function respawn()
    player:respawn(3)
    death_time = 0
end

local function check_game_over()
    return death_time > 0
end

local function draw()
    local scaling = love.window.getFullscreen() and MAX_SCALING or DEFAULT_SCALING
    love.graphics.scale(scaling, scaling)
    --shader:send("u_light_pos", {player.x - camera.total_x, player.y - camera.total_y})
    local width, height, _ = love.window.getMode()
    shader:send("u_resolution", {width, height})
    shader:send("u_factor", math.min(0.3, death_time / 4))
    shader:send("u_time", love.timer.getTime())
    shader:send("u_lighting_dist", lighting_dist)
    love.graphics.setShader(shader)
    love.graphics.setBackgroundColor(unpack(BACKGROUND_COLOUR))

    --TileMap.render(tilemap, tileset, TILE_SIZE)
    local x_offset = math.sin(love.timer.getTime() * 5) * 1.5
    --TileMap.render_tiles(tiles["terrain"].tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT)
    --TileMap.render_tiles(tiles["decor"].tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT)
    --TileMap.render_tiles(tiles["collectibles"].tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT, x_offset)
    --TileMap.render_tiles(tiles["enemies"].tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT)
    TileMap.render(tiles["terrain"].tiles, tileset, camera, TILE_SIZE)
    TileMap.render(tiles["decor"].tiles, tileset, camera, TILE_SIZE)
    TileMap.render(tiles["collectibles"].tiles, tileset, camera, TILE_SIZE, x_offset)
    player:render(camera)

    for _, entity in ipairs(entities) do
        entity:render(camera)
    end

    love.graphics.setShader() --reset

    love.graphics.setFont(font)
    player.health_bar:render()

    local text = crown_bar:get_text(player.inventory.items["crown"])
    local text_width = font:getWidth(text)
    love.graphics.printf(text, width/scaling - text_width - TILE_SIZE - 10, 10, 200, "left", 0, 1, 1)
    love.graphics.draw(crown_bar.image, width/scaling - TILE_SIZE - 10, 10 - TILE_SIZE/4)

    if won then
        local text = "You won!"
        local text_width = font:getWidth(text)
        love.graphics.printf(text, width/2/scaling - text_width/2, height/2/scaling, 200, "left", 0, 1, 1)
    end

    if check_game_over() then
        local text = "You died! Press r to respawn..."
        local text_width = font:getWidth(text)
        love.graphics.printf(text, width/2/scaling - text_width/2, height/2/scaling, 200, "left", 0, 1, 1)
    end

    if DEBUG_ENABLED then
        love.graphics.print(string.format("fps: %s", math.floor(love.timer.getFPS())), 0, 0, 0, 0.5, 0.5)
    end
    -- love.graphics.circle("line", 50, 50, 10)
end

function love.update(dt)
    ErrorUtil.call_or_exit(function() update(dt) end, not DEBUG_ENABLED)
end

function love.draw()
    ErrorUtil.call_or_exit(draw, not DEBUG_ENABLED)
end

function love.keypressed(key)
    --Debug
    -- type "cont" to exit debug mode
    if DEBUG_ENABLED and key == "rctrl" then
       debug.debug()
    end

    if key == "f" then
        love.window.setFullscreen(not love.window.getFullscreen())
    elseif key == "m" then
        muted = not muted
        love.audio.setVolume(muted and 0 or 1)
    elseif key == "escape" then
        love.event.quit(0)
    end

    if key == "r" and check_game_over() then
        respawn()
    end

    if key == "left" or key == "a" then
        player:start_move_left()
    elseif key == "right" or key == "d" then
        player:start_move_right()
    elseif key == "up" or key == "w" then
        player:start_move_up()
    elseif key == "down" or key == "s" then
        player:start_move_down()
    end
end

local function handle_player_stop_walk(key)
    local keys = {
        ["left"] = player.start_move_left,
        ["right"] = player.start_move_right,
        ["up"] = player.start_move_up,
        ["down"] = player.start_move_down,
        ["a"] = player.start_move_left,
        ["d"] = player.start_move_right,
        ["w"] = player.start_move_up,
        ["s"] = player.start_move_down,
    }
    for key_, _ in pairs(keys) do
        if key_ ~= key then goto continue end

        for key__, func in pairs(keys) do
            if love.keyboard.isDown(key__) then
                func(player)
                return
            end
        end
        player:stop()
        ::continue::
    end
end

function love.keyreleased(key)
    handle_player_stop_walk(key)
end

function love.visible(visible)
    love.audio.setVolume(visible and 1 or 0)
end
