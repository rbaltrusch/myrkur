CrownBar = {}

function CrownBar.construct(args)
    local crown_bar = {image = args.image, total_crowns_on_map = args.total_crowns_on_map, x = args.x, y = args.y}

    function crown_bar.get_text(self, crowns)
        crowns = crowns or 0
        return string.format("%s/%s", crowns, self.total_crowns_on_map)
    end

    function crown_bar.check_complete(self, crowns)
        crowns = crowns or 0
        return crowns >= self.total_crowns_on_map
    end

    return crown_bar
end
