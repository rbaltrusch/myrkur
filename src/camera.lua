Camera = {}

Camera.EPSILON = 0.1

local function floor_epsilon(number)
    if math.abs(number) < Camera.EPSILON then
        return 0
    end
    return number
end

local function update(self, player, dt)
    local dist_x = player.x - self.width / 2 - self.total_x
    local dist_y = player.y - self.height / 2 - self.total_y
    if dist_x ~= 0 then
        self.x = floor_epsilon(dist_x * self.speed_factor * dt)
        --local min = dist_x > 0 and 1 or -1
        --self.x = math.max(min, dist_x * self.speed_factor)
    end

    if dist_y ~= 0 then
        self.y = floor_epsilon(dist_y * self.speed_factor * dt)
        --local min = dist_y > 0 and 1 or -1
        --self.y = math.max(min, dist_y * self.speed_factor)
    end
    -- print(self.x, self.y)
    -- player.x = player.x - self.x
    -- player.y = player.y - self.y
    self.total_x = self.total_x + self.x
    self.total_y = self.total_y + self.y
end

function Camera.construct(args)
    return {
        x = args.x,
        y = args.y,
        total_x = 0,
        total_y = 0,
        speed_factor = args.speed_factor,
        width = args.width,
        height = args.height,
        update = update
    }
end
