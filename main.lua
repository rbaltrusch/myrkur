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

function love.load()
    --BACKGROUND_COLOUR = Colour.construct(71, 45, 60)
    BACKGROUND_COLOUR = Colour.construct(0, 0, 0)
    TILE_SIZE = 16
    DEBUG_ENABLED = true
    DEFAULT_SCALING = 2
    WIDTH, HEIGHT, _ = love.window.getMode()
    WIN_WIDTH, WIN_HEIGHT = love.window.getDesktopDimensions()
    MAX_SCALING = DEFAULT_SCALING * math.min(WIN_WIDTH / WIDTH, WIN_HEIGHT / HEIGHT)
    love.window.setIcon(love.image.newImageData("assets/runeM.png"))

    fps = 0
    muted = false

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

    local walk_sound = love.audio.newSource("assets/walk.wav", "static")
    walk_sound:setVolume(0.2)

    player = Player.construct{
        image_path="assets/player.png",
        x=0,
        y=0,
        speed=80,
        hitbox_offset=0,
        tile_size=TILE_SIZE,
        walk_animation=Animation.construct(
            SpriteSheet.load_sprite_sheet("assets/player_walk.png", TILE_SIZE, TILE_SIZE), 0.1
        ),
        walk_sound=walk_sound
    }
    camera = Camera.construct{x=0, y=0, speed_factor=2.5, width=WIDTH/DEFAULT_SCALING, height=HEIGHT/DEFAULT_SCALING}

    shader = love.graphics.newShader(FileUtil.read_file("assets/shader/lighting.vert") or "")
    tileset = SpriteSheet.load_sprite_sheet("assets/kenney_1-bit-pack/Tilesheet/colored_packed.png", TILE_SIZE, TILE_SIZE)
    tilemap = require "assets/largetestmap"
    collision_map = TileMap.construct_collision_map(tilemap, "terrain")
    tiles = TileMap.construct_tiles(tilemap, tileset)
    entities = Entity.construct_from_tilemap(
        tiles["enemies"].tiles,
        {speed=30, TILE_SIZE=TILE_SIZE, tile_range=10, tileset=tileset, damage=1, walk_sound=walk_sound:clone()}
    )
end

local function collect_crown()
    player.inventory:add("crown")
    crown_pickup_sound:play()
end

local function collect_key()
    player.inventory:add("key")
    key_pickup_sound:play()
end

local function collect_heart()
    player.inventory:add("heart")
    heart_pickup_sound:play()
end

local function check_collectible_collisions()
    local collectible_callbacks = {
        [142] = collect_crown,
        [571] = collect_key,
        [529] = collect_heart,
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
            callback()
            tiles["collectibles"].tiles[x][y] = nil
        end
    end
end

local function update(dt)
    fps = 1 / dt
    player:update(dt)
    player:update_collisions(tiles["terrain"])
    check_collectible_collisions()
    camera:update(player, dt)

    for _, entity in ipairs(entities) do
        entity:update(dt, player, collision_map)
    end

    -- local x, y = player:get_current_tile()
    -- print(x, y)
    -- -- luafinding is 1-indexed
    -- local path = PathFinding(Vector(x + 1, y + 1), Vector(1, 4), collision_map):GetPath()
    -- for _, v in ipairs(path or {}) do
    --     print(v)
    -- end
    -- print("---")

    if love.keyboard.isDown("space") then
    end
end

local function draw()
    local scaling = love.window.getFullscreen() and MAX_SCALING or DEFAULT_SCALING
    love.graphics.scale(scaling, scaling)
    --shader:send("u_light_pos", {player.x - camera.total_x, player.y - camera.total_y})
    local width, height, _ = love.window.getMode()
    shader:send("u_resolution", {width, height})
    --print(player.x - camera.total_x, player.y - camera.total_y)
    love.graphics.setShader(shader)
    love.graphics.setBackgroundColor(unpack(BACKGROUND_COLOUR))

    --TileMap.render(tilemap, tileset, TILE_SIZE)
    TileMap.render_tiles(tiles["terrain"].tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT)
    TileMap.render_tiles(tiles["collectibles"].tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT)
    --TileMap.render_tiles(tiles["enemies"].tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT)
    player:render(camera)

    for _, entity in ipairs(entities) do
        entity:render(camera)
    end

    love.graphics.setShader() --reset
    if DEBUG_ENABLED then
        love.graphics.print(string.format("fps: %s", math.floor(fps)), 0, 0, 0, 0.5, 0.5)
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
        muted = true
    elseif key == "escape" then
        love.event.quit(0)
    end

    if key == "left" then
        player:start_move_left()
    elseif key == "right" then
        player:start_move_right()
    elseif key == "up" then
        player:start_move_up()
    elseif key == "down" then
        player:start_move_down()
    end
end

local function handle_player_stop_walk(key)
    local keys = {
        ["left"] = player.start_move_left,
        ["right"] = player.start_move_right,
        ["up"] = player.start_move_up,
        ["down"] = player.start_move_down,
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
