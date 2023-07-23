---@meta

require "src/math_util"
require "src/collision"
require "src/tilemap"
require "src/inventory"
require "src/timer"

Player = {}

function Player.construct(args)
    local player = {
        x = args.x,
        y = args.y,
        previous_x = args.x,
        previous_y = args.y,
        health = args.health,
        max_health = args.max_health,
        invincible_timer = args.invincible_timer,
        hurt_timer = Timer.construct(0.5),
        image = love.graphics.newImage(args.image_path),
        walk_sound = args.walk_sound,
        hurt_sound = args.hurt_sound,
        death_sound = args.death_sound,
        respawn_sound = args.respawn_sound,
        health_bar = args.health_bar,
        speed_x = 0,
        speed_y = 0,
        inventory = Inventory.create(),
        SPEED = args.speed,
        HITBOX_OFFSET = args.hitbox_offset,
        walk_animation = args.walk_animation,
        walk_left_animation = args.walk_left_animation,
        TILE_SIZE = args.tile_size,
        last_rest_site = {x = args.x, y = args.y},
        looking_right = true,
        -- how forgiving terrain edge collisions are
        EDGE_LENIENCE = 7,
    }

    function player.move(self, x, y)
        if x == 0 and y == 0 or not self:check_alive() then
            return
        end

        if not self:get_walk_animation().ongoing then
            self:get_walk_animation():start()
        end

        if not self.walk_sound:isPlaying() then
            self.walk_sound:play()
        end

        self.x = self.x + x
        self.y = self.y + y
    end

    function player.start_move_left(self)
        self.looking_right = false
        self.walk_animation:stop()
        self.speed_x = - self.SPEED
        self.speed_y = 0
    end

    function player.start_move_right(self)
        self.looking_right = true
        self.walk_left_animation:stop()
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
        if self.walk_sound:isPlaying() then
            self.walk_sound:stop()
        end
    end

    function player.get_walk_animation(self)
        return self.looking_right and self.walk_animation or self.walk_left_animation
    end

    function player.update(self, dt)
        self:get_walk_animation():update(dt)
        self.walk_left_animation:update(dt)
        self.invincible_timer:update(dt)
        self.hurt_timer:update(dt)

        self.previous_x = self.x
        self.previous_y = self.y
        self:move(self.speed_x * dt, self.speed_y * dt)
    end

    function player.get_current_tile(self)
        local x = MathUtil.round(self.x / self.TILE_SIZE)
        local y = MathUtil.round(self.y / self.TILE_SIZE)
        return {x, y}
    end

    function player.get_rect(self)
        return {
            x1 = self.x + self.HITBOX_OFFSET,
            y1 = self.y + self.HITBOX_OFFSET,
            x2 = self.x + self.TILE_SIZE - self.HITBOX_OFFSET,
            y2 = self.y + self.TILE_SIZE - self.HITBOX_OFFSET
        }
    end

    function player.check_alive(self)
        return self.health > 0
    end

    function player.respawn(self, health)
        self.x = self.last_rest_site.x
        self.y = self.last_rest_site.y
        self.health = health
        self.health_bar.amount = health
        self.invincible_timer:start()
        if not self.respawn_sound:isPlaying() then
            self.respawn_sound:play()
        end
        print("respawned")
    end

    function player.die(self)
        self.walk_sound:stop()
        self:get_walk_animation():stop()
        if not self.death_sound:isPlaying() then
            self.death_sound:play()
        end
        print("died")
    end

    function player.heal(self, amount)
        local health = math.min(self.health + amount, self.max_health)
        if health > self.health then
            self.health_bar:add(health - self.health)
            self.health = health
        end
    end

    function player.hurt(self, damage)
        if damage <= 0 or self.invincible_timer:is_ongoing() or not self:check_alive() then
            return
        end

        self.hurt_timer:start()
        self.health_bar:add(- damage) -- HACK
        self.health = self.health - damage
        print("hurt", self.health)
        if not self:check_alive() then
            self:die()
            self.hurt_timer:stop()
            return
        end

        if self.hurt_sound:isPlaying() then
            self.hurt_sound:stop()
        end
        self.hurt_sound:play()
        self.invincible_timer:start()
    end

    function player.update_collisions(self, tiles)
        local x, y = unpack(self:get_current_tile())
        for x_offs = -1, 1 do
            for y_offs = -1, 1 do
                local tile = tiles:get(x + x_offs, y + y_offs)
                if tile == nil then
                    goto continue
                end

                local tile_rect = TileMap.get_tile_rect(x + x_offs, y + y_offs, self.TILE_SIZE)
                local player_rect = player:get_rect()
                if Collision.colliding(player_rect, tile_rect) then
                    local speed_x = self.x - self.previous_x
                    local speed_y = self.y - self.previous_y
                    if speed_x ~= 0 then
                        local y_overlap = Collision.get_y_overlap(player_rect, tile_rect)
                        local neighbour = tiles:get(x + x_offs, y + y_offs + (y_overlap > 0 and -1 or 1))
                        if math.abs(y_overlap) < self.EDGE_LENIENCE and neighbour == nil then
                            self.y = self.y - y_overlap
                        else
                            self.x = tile_rect.x1 + self.TILE_SIZE * (speed_x > 0 and -1 or 1)
                        end
                    end
                    if speed_y ~= 0 then
                        local x_overlap = Collision.get_x_overlap(player_rect, tile_rect)
                        local neighbour = tiles:get(x + x_offs + (x_overlap > 0 and -1 or 1), y + y_offs)
                        if math.abs(x_overlap) < self.EDGE_LENIENCE and neighbour == nil then
                            self.x = self.x - x_overlap
                        else
                            self.y = tile_rect.y1 + self.TILE_SIZE * (speed_y > 0 and -1 or 1)
                        end
                    end
                end
                ::continue::
            end
        end
    end

    function player.render(self, camera)
        if self.hurt_timer:is_ongoing() and math.sin(self.hurt_timer.time * 25) > 0 then
            return
        end

        local transform = love.math.newTransform(self.x - camera.total_x, self.y - camera.total_y)
        local anim = self:get_walk_animation()
        if anim.ongoing then
            local quad = anim:get_current_quad()
            love.graphics.draw(anim.image, quad, transform)
        else
            love.graphics.draw(self.image, transform)
        end
    end

    return player
end
