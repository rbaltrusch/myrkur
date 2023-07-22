TileMap = {}

-- returns zero-indexed 2d table of tiles
function TileMap.construct_tiles(tilemap, tileset)
    local tiles = {}
    for i = 0, tilemap.width do
        tiles[i] = {}
    end

    local width = tilemap.width
    for _, layer in ipairs(tilemap.layers) do
        for i, tile_index in ipairs(layer.data) do
            if tile_index == 0 then goto continue end
    
            i = i - 1
            local x = i % width
            local y = math.floor(i / width)
            tiles[x][y] = tileset.quads[tile_index]
            ::continue::
        end
    end

    return {
        tiles = tiles,
        get = function(self, x, y)
            local tiles_x = self.tiles[x]
            return tiles_x ~= nil and tiles_x[y] or nil
        end,
    }
end

function TileMap.render_tiles(tiles, tileset, camera, tilesize, width, height)
    local tiles_x = width / tilesize
    local tiles_y = height / tilesize

    for x, col in pairs(tiles) do
        if x > tiles_x then break end
        for y, quad in pairs(col) do
            if y > tiles_y then break end
            local transform = love.math.newTransform(
                x * tilesize - camera.total_x, y * tilesize - camera.total_y
            )
            love.graphics.draw(tileset.image, quad, transform)
        end
    end
end

function TileMap.render(tilemap, tileset, tilesize)
    local width = tilemap.width
    for _, layer in ipairs(tilemap.layers) do
        for i, tile_index in ipairs(layer.data) do
            if tile_index == 0 then goto continue end

            i = i - 1
            local x = i % width * tilesize
            local y = math.floor(i / width) * tilesize
            love.graphics.draw(tileset.image, tileset.quads[tile_index], love.math.newTransform(x, y))
            ::continue::
        end
    end
end
