MathUtil = {}

function MathUtil.round(num)
    return num + (2^52 + 2^51) - (2^52 + 2^51)
end
