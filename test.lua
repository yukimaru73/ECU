function numTo_4bits(num)
	local bits = {}
	for i = 1, 4 do
		bits[i] = num % 2
		num = math.floor(num / 2)
	end
	return bits
end
GEAR_ORDER = {0,2,3,4,5}
for i, v in ipairs(GEAR_ORDER_ARRAY) do
	GEAR_ORDER_ARRAY[i] = numTo_4bits(v)
end
