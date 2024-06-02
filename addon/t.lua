local IOStream = {}

---@param from string
---@param to string
---@param ... number|string
---@return number|string ...
function iostream_packunpack(from, to, ...)
	return string.unpack(to, string.pack(from, ...))
end


-- local min, max, precision = -130000, 130000, 0.0001
local min, max, precision = 0.1, 50, 0.00125
local value = max

print(min, max, precision)
print()
print(value)

__bitCount = math.floor(math.log((max-min)/precision, 2) + 0.5)
__precision = (2 ^ -__bitCount) * (max-min)
__bytes = {iostream_packunpack("J", string.rep("B", math.ceil(__bitCount/8)), math.floor((value-min)/__precision))}
table.remove(__bytes, #__bytes)

print(table.concat(__bytes, " "))

__bitCount = math.floor(math.log((max-min)/precision, 2) + 0.5)
__byteCount = math.ceil(__bitCount/8)
__quant, __frac = math.modf((iostream_packunpack(string.rep("B", __byteCount) .. string.rep("x", 8-__byteCount), "J", table.unpack(__bytes))*((2 ^ -__bitCount) * (max-min)) + min)/precision)
print(precision * (__quant + (__frac > 0 and 1 or 0)))
