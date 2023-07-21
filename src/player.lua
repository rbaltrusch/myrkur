---@meta

require "src/math_util"
require "src/collision"

Player = {}

function Player.construct(args)
    local player = {
        x = args.x,
        y = args.y,
        previous_x = args.x,
        previous_y = args.y,
        image = love.graphics.newImage(args.image_path),
        speed_x = 0,
        speed_y = 0,
        SPEED = args.speed,
        HITBOX_OFFSET = args.hitbox_offset,
        walk_animation = args.walk_animation,
        TILE_SIZE = args.tile_size,
    }

    function player.move(self, x, y)
        if x == 0 and y == 0 then
            return
        end

        if not self.walk_animation.ongoing then
            self.walk_animation:start()
        end

        self.x = self.x + x
        self.y = self.y + y
    end

    function player.start_move_left(self)
        self.speed_x = - self.SPEED
        self.speed_y = 0
    end

    function player.start_move_right(self)
        self.speed_x = self.SPEED
        self.speed_y = 0
    end

    function player.start_move_up(self)
        self.speed_x = 0
        self.speed_y = - self.SPEED
    end

    function player.start_move_down(self)
        self.speed_x = 0
        self.speed_y = self.SPEED
    end

    function player.stop(self)
        self.speed_x = 0
        self.speed_y = 0
    end

    function player.update(self, dt)
        self.walk_animation:update(dt)

        self.previous_x = self.x
        self.previous_y = self.y
        self:move(self.speed_x * dt, self.speed_y * dt)
    end

    function player.get_current_tile(self)
        local x = MathUtil.round(self.x / self.TILE_SIZE)
        local y = MathUtil.round(self.y / self.TILE_SIZE)
        return x, y
    end

    function player.update_collisions(self, tiles)
        local x, y = self:get_current_tile()
        for x_offs = -1, 1 do
            for y_offs = -1, 1 do
                local tile = tiles:get(x + x_offs, y + y_offs)
                if tile == nil then
                    goto continue
                end

                local tile_x = (x + x_offs) * self.TILE_SIZE
                local tile_y = (y + y_offs) * self.TILE_SIZE
                local tile_rect = {x1 = tile_x, y1 = tile_y, x2 = tile_x + self.TILE_SIZE, y2 = tile_y + self.TILE_SIZE}
                local player_rect = {
                    x1 = self.x + self.HITBOX_OFFSET,
                    y1 = self.y + self.HITBOX_OFFSET,
                    x2 = self.x + self.TILE_SIZE - self.HITBOX_OFFSET,
                    y2 = self.y + self.TILE_SIZE - self.HITBOX_OFFSET
                }
                if Collision.colliding(player_rect, tile_rect) then
                    local speed_x = self.x - self.previous_x
                    local speed_y = self.y - self.previous_y
                    if speed_x ~= 0 then
                        local y_overlap = Collision.get_y_overlap(player_rect, tile_rect)
                        local neighbour = tiles:get(x + x_offs, y + y_offs + (y_overlap > 0 and -1 or 1))
                        if math.abs(y_overlap) < 7 and neighbour == nil then
                            self.y = self.y - y_overlap
                        else
                            self.x = tile_x + self.TILE_SIZE * (speed_x > 0 and -1 or 1)
                        end
                    end
                    if speed_y ~= 0 then
                        local x_overlap = Collision.get_x_overlap(player_rect, tile_rect)
                        local neighbour = tiles:get(x + x_offs + (x_overlap > 0 and -1 or 1), y + y_offs)
                        if math.abs(x_overlap) < 7 and neighbour == nil then
                            self.x = self.x - x_overlap
                        else
                            self.y = tile_y + self.TILE_SIZE * (speed_y > 0 and -1 or 1)
                        end
                    end
                end
                ::continue::
            end
        end
    end

    function player.render(self)
        if self.walk_animation.ongoing then
            local quad = self.walk_animation:get_current_quad()
            love.graphics.draw(self.walk_animation.image, quad, self.x, self.y)
        else
            love.graphics.draw(self.image, love.math.newTransform(self.x, self.y))
        end
    end

    return player
end
