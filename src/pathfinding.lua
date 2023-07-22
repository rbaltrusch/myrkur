Vector = require("luafinding/vector")
PathFinding = require("luafinding/luafinding")

function PathFinding.find_path(tile1, tile2, collision_map, max_range)
    local dist = MathUtil.dist(tile1, tile2)
    if dist > max_range then
        local x1, y1 = unpack(tile1)
        local x2, y2 = unpack(tile2)
        print(dist, x1, y1, x2, y2)
        return nil
    end

    local x1, y1 = unpack(tile1)
    local x2, y2 = unpack(tile2)

    -- luafinding is 1-indexed
    local path = PathFinding(Vector(x1 + 1, y1 + 1), Vector(x2 + 1, y2 + 1), collision_map):GetPath()
    if path == nil then
        return nil
    end

    -- convert 1-indices to 0
    for _, vec in ipairs(path) do
        vec.x = vec.x - 1
        vec.y = vec.y - 1
    end

    -- for _, v in ipairs(path or {}) do
    --     print(v)
    -- end
    -- print("---")
    return path
end
