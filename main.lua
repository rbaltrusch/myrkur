require "src/colour"
require "src/debug_util"
require "src/player"
require "src/animation"
require "src/error_util"
require "src/sprite_sheet"
require "src/tilemap"
require "src/camera"

function love.load()
    BACKGROUND_COLOUR = Colour.construct(71, 45, 60)
    TILE_SIZE = 16
    DEBUG_ENABLED = true
    DEFAULT_SCALING = 2
    WIDTH, HEIGHT, _ = love.window.getMode()
    WIN_WIDTH, WIN_HEIGHT = love.window.getDesktopDimensions()
    MAX_SCALING = DEFAULT_SCALING * math.min(WIN_WIDTH / WIDTH, WIN_HEIGHT / HEIGHT)
    love.window.setIcon(love.image.newImageData("assets/runeM.png"))

    fps = 0
    muted = false
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
    }
    camera = Camera.construct{x=0, y=0, speed_factor=2.5, width=WIDTH/DEFAULT_SCALING, height=HEIGHT/DEFAULT_SCALING}

    tileset = SpriteSheet.load_sprite_sheet("assets/kenney_1-bit-pack/Tilesheet/colored_packed.png", TILE_SIZE, TILE_SIZE)
    tilemap = require "assets/largetestmap"
    tiles = TileMap.construct_tiles(tilemap, tileset)

    local music = love.audio.newSource("assets/myrkur_menu2.wav", "stream")
    music:setVolume(0.2)
    music:play()
end

local function update(dt)
    fps = 1 / dt
    player:update(dt)
    local x, y = player:get_current_tile()
    player:update_collisions(tiles)
    camera:update(player, dt)
    print(camera.total_x, camera.total_y)
    --print(x, y)
    if tiles:get(x, y) ~= nil then
        print("colliding")
    end
    if love.keyboard.isDown("space") then
    end
end

local function draw()
    local scaling = love.window.getFullscreen() and MAX_SCALING or DEFAULT_SCALING
    love.graphics.scale(scaling, scaling)
    love.graphics.setBackgroundColor(unpack(BACKGROUND_COLOUR))

    --TileMap.render(tilemap, tileset, TILE_SIZE)
    TileMap.render_tiles(tiles.tiles, tileset, camera, TILE_SIZE, WIDTH, HEIGHT)
    player:render(camera)
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
