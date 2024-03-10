TileMap = {}

function TileMap.get_tile_rect(x, y, tilesize)
    return {
        x1 = x * tilesize,
        x2 = (x + 1) * tilesize,
        y1 = y * tilesize,
        y2 = (y + 1) * tilesize,
    }
end

-- accepts tiles of a single layer
function TileMap.get_tile_rects(tiles, tilesize)
    local rects = {}
    for x, col in pairs(tiles) do
        for y, tile in pairs(col) do
            rects[{x, y}] = {tile = tile, rect = TileMap.get_tile_rect(x, y, tilesize)}
        end
    end
    return rects
end

-- returns zero-indexed 2d table of tiles
function TileMap.construct_tiles(tilemap, tileset)
    local layers = {}
    for _, layer in ipairs(tilemap.layers) do
        local name = layer.name
        layers[name] = {
            tiles = {},
            get = function(self, x, y)
                local tiles_x = self.tiles[x]
                return tiles_x ~= nil and tiles_x[y] or nil
            end,
        }
        for i = 0, tilemap.width do
            layers[name].tiles[i] = {}
        end
    end

    local width = tilemap.width
    for _, layer in ipairs(tilemap.layers) do
        local name = layer.name
        for i, tile_index in ipairs(layer.data) do
            if tile_index ~= 0 then -- skips empty tiles
    
                i = i - 1
                local x = i % width
                local y = math.floor(i / width)
                layers[name].tiles[x][y] = {index=tile_index, quad=tileset.quads[tile_index]}
            end
        end
    end

    return layers
end

-- for use with luafinding a 2d table of bools (passable or not)
function TileMap.construct_collision_map(tilemap, layer_name, passable_getter)
    local tiles = {}
    local width = tilemap.width
    for _, layer in ipairs(tilemap.layers) do
        if layer.name == layer_name then
            for i = 0, tilemap.width do
                tiles[i] = {}
            end
            for i, tile_index in ipairs(layer.data) do
                local x = i % width
                local y = math.floor(i / width)
                tiles[x][y] = passable_getter(tile_index)
            end
        end
    end
    return tiles
end

-- function TileMap.render(tiles, tileset, camera, tilesize, y_offset)
--     y_offset = y_offset or 0
--     for x, col in pairs(tiles) do
--         for y, tile in pairs(col) do
--             local transform = love.math.newTransform(
--                 x * tilesize - camera.total_x, y * tilesize - camera.total_y + y_offset
--             )
--             love.graphics.draw(tileset.image, tile.quad, transform)
--         end
--     end
-- end

function TileMap.render(tiles, tileset, camera, tilesize, width, height, y_offset)
    tileset.sprite_batch:clear()
    y_offset = (y_offset or 0) - camera.total_y
    for x, col in pairs(tiles) do
        local x_transform = x * tilesize - camera.total_x
        for y, tile in pairs(col) do
            local y_transform = y * tilesize + y_offset
            if x_transform < width and y_transform < height and not tile.collected then
                tileset.sprite_batch:add(tile.quad, x_transform, y_transform)
            end
        end
    end
    love.graphics.draw(tileset.sprite_batch)
end
