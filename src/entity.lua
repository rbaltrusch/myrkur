require "src/math_util"
require "src/pathfinding"

Entity = {}

function Entity.construct(args)
    local entity = {
        tileset = args.tileset,
        tile_range = args.tile_range,
        TILE_SIZE = args.TILE_SIZE,
        speed = args.speed,
        damage = args.damage,
        walk_sound = args.walk_sound,

        x = args.x,
        y = args.y,
        tile = args.tile,
        target = nil,
        dead = false,
    }

    function entity.get_current_tile(self)
        local x = MathUtil.round(self.x / self.TILE_SIZE)
        local y = MathUtil.round(self.y / self.TILE_SIZE)
        return {x, y}
    end

    function entity.die(self)
        self.dead = true
    end

    function entity.walk_to_target(self, current_tile, dt)
        if not self.walk_sound:isPlaying() then
            self.walk_sound:play()
        end

        local x, y = unpack(current_tile)
        self.x = self.x + (self.target.x - x) * self.speed * dt
        self.y = self.y + (self.target.y - y) * self.speed * dt
    
        if self.x / self.TILE_SIZE == self.target.x and self.y / self.TILE_SIZE == self.target.y then
            self.target = nil
        end
    end

    function entity.update(self, dt, player, collision_map)
        if self.dead then
            return
        end

        local current_tile = self:get_current_tile()
        if self.target then
            self:walk_to_target(current_tile, dt)
        end

        local path = PathFinding.find_path(
            player:get_current_tile(),
            current_tile,
            collision_map,
            self.tile_range
        )

        if path then
            self.target = path[#path - 1]
            if self.target == nil then --reached
                player:hurt(self.damage)
                return
            end
        end

        if self.target then
            self:walk_to_target(current_tile, dt)
        end

        -- if self.target then

            -- print(self.x, self.y)
            -- local x, y = unpack(self:get_current_tile())
            -- print(x, y)

            -- for _, v in ipairs(path or {}) do
            --     print(v)
            -- end
            -- print("---")
        -- end
    end

    function entity.render(self, camera)
        if self.dead then
            return
        end

        local transform = love.math.newTransform(self.x - camera.total_x, self.y - camera.total_y)
        love.graphics.draw(self.tileset.image, self.tile.quad, transform)
        -- if self.walk_animation.ongoing then
        --     local quad = self.walk_animation:get_current_quad()
        --     love.graphics.draw(self.walk_animation.image, quad, transform)
        -- else
        --     love.graphics.draw(self.image, transform)
        -- end
    end

    return entity
end

-- returns a list of entities constructed from the specified tilemap
function Entity.construct_from_tilemap(tiles, args)
    local entities = {}
    for x, col in pairs(tiles) do
        for y, tile in pairs(col) do
            entities[#entities + 1] = Entity.construct{
                tile = tile,
                x = x * args.TILE_SIZE,
                y = y * args.TILE_SIZE,
                tileset = args.tileset,
                tile_range = args.tile_range,
                TILE_SIZE = args.TILE_SIZE,
                speed = args.speed,
                damage = args.damage,
                walk_sound = args.walk_sound,
            }
        end
    end
    return entities
end
