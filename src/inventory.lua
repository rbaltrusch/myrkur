Inventory = {}

function Inventory.create()
    local inventory = {items = {}}

    function inventory.add(self, name)
        if self.items[name] == nil then
            self.items[name] = 1
        else
            self.items[name] = self.items[name] + 1
        end

        -- debug print
        for k, v in pairs(player.inventory.items) do
            print(k, v)
        end
    end

    return inventory
end
