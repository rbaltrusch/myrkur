FileUtil = {}

function FileUtil.read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*all") -- reads the whole file
    file:close()
    return content
end
