StatBar = {}

function StatBar.construct(args)
    local bar = {
        amount = args.amount,
        image = args.image,
        x = args.x,
        y = args.y,
        TILE_SIZE = args.tile_size,
    }

    function bar.add(self, amount)
        self.amount = self.amount + amount
    end

    function bar.render(self)
        if self.amount == 0 then
            return
        end
        for x = 1, self.amount do
            love.graphics.draw(self.image, self.x + x * self.TILE_SIZE, self.y)
        end
    end

    return bar
end
