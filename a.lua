require("Libs.PID")

function createTableFromString(str)
	local t, num = {}, nil
	for w in string.gmatch(str, "[-0-9.]+") do
		num = tonumber(w)
		if num ~= nil then
			t[#t + 1] = num
		end
	end
	return t
end
function numTo_101(num)
	if num > 0.5 then
		num = 1
	elseif num < -0.5 then
		num = -1
	else
		num = 0
	end
	return num
end

---transform number to 4 bits array
function numTo_4bits(num)
	local bits = {}
	for i = 1, 4 do
		bits[i] = num % 2
		num = math.floor(num / 2)
	end
	return bits
end

SHIFT_UP_RPS = property.getNumber("Shift Up RPS")
SHIFT_DOWN_RPS = property.getNumber("Shift Down RPS")
REV_LIMIT_RPS = property.getNumber("Rev Limit RPS")
IDLE_RPS = property.getNumber("Idle RPS")
SHIFT_CHANGE_COOLTIME = property.getNumber("Shift Change Cooltime")

THROTTLE_PERCENTAGE = property.getNumber("Throttle Percentage")
SPEED_AIMOST_ZERO = property.getNumber("Speed Almost Zero")
NORMAL_GEAR = property.getNumber("Normal Gear")
REVERSE_GEAR = property.getNumber("Reverse Gear")
GEAR_STRING = property.getText("Gear")
GEAR_ORDER = property.getText("Gear Order")
GEAR_ARRAY = createTableFromString(GEAR_STRING)
GEAR_ORDER_ARRAY = createTableFromString(GEAR_ORDER)
GEAR_CHECKER = {}
for i, v in ipairs(GEAR_ARRAY) do
	GEAR_CHECKER[i] = { SHIFT_DOWN_RPS / v, SHIFT_UP_RPS / v }
end
for i in ipairs(GEAR_ORDER_ARRAY) do
	GEAR_ORDER_ARRAY[i] = numTo_4bits(GEAR_ORDER_ARRAY[i])
end

TIME = 0
STEER_IN = 0
THROTTLE_IN = 0
ENGINE_RPS = 0
AXLE_RPS = 0

FLAG = false

THROTTLE_OUT = 0
CLUTCH = 0
BRAKE = 1

GEAR = 0
GEAR_1 = false
GEAR_2 = false
GEAR_3 = false
GEAR_4 = false
GEAR_REVERSE = false
RADIATOR = false

IDLE_THROTTLE_PID = PID:new(property.getNumber("PID_P"), property.getNumber("PID_I"), property.getNumber("PID_D"), 0)

function onTick()
	STEER_IN = input.getNumber(1)
	THROTTLE_IN = input.getNumber(2)
	ENGINE_RPS = input.getNumber(30)
	AXLE_RPS = input.getNumber(31)
	FLAG = false


	--gear block
	if BRAKE ~= 0 then
		TIME = 0
	end
	if TIME > 0 then
		TIME = TIME - 1
	else
		local f, ff = false, false
		if ENGINE_RPS > SHIFT_UP_RPS then
			if GEAR_REVERSE then
				GEAR, f = clamp(GEAR + 1, 0, REVERSE_GEAR)
			else
				GEAR, f = clamp(GEAR + 1, 0, NORMAL_GEAR)
			end
		elseif ENGINE_RPS < SHIFT_DOWN_RPS then
			GEAR, f = clamp(GEAR - 1, 0, NORMAL_GEAR)
			if GEAR == 1 then
				ff = true
			end
		end
		if f then
			if GEAR == 1 and not ff then
				TIME = SHIFT_CHANGE_COOLTIME * 2
			else
				TIME = SHIFT_CHANGE_COOLTIME
			end
		end
	end
	gear3(GEAR)

	--clutch block
	if GEAR == 0 then
		CLUTCH = 0
	elseif GEAR == 1 then
		CLUTCH = clamp(1 - (TIME / (SHIFT_CHANGE_COOLTIME * 2)) / GEAR, 0.005, 1)
		if BRAKE ~= 0 then
			CLUTCH = 0
		end
	else
		CLUTCH = clamp(1 - (TIME / SHIFT_CHANGE_COOLTIME / 2) / GEAR, 0.01, 1)
		if math.abs(AXLE_RPS) < SPEED_AIMOST_ZERO and BRAKE ~= 0 then
			CLUTCH = 0
		end
	end
	
	--throttle and brake block
	local throttle = numTo_101(THROTTLE_IN)
	if throttle == 1 then
		if GEAR == 0 then
			THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
			GEAR_REVERSE = false
			BRAKE = 1
		else
			if GEAR_REVERSE then
				if math.abs(AXLE_RPS) < SPEED_AIMOST_ZERO then
					THROTTLE_OUT = 0
					BRAKE = 1
				else
					THROTTLE_OUT = 0
					BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
				end
			else
				THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
				BRAKE = 0
			end
		end
	elseif throttle == -1 then
		if GEAR == 0 then
			THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
			GEAR_REVERSE = true
			BRAKE = 1
		else
			if GEAR_REVERSE then
				THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
				BRAKE = 0
			else
				if math.abs(AXLE_RPS) < SPEED_AIMOST_ZERO then
					THROTTLE_OUT = 0
					BRAKE = 1
				else
					THROTTLE_OUT = 0
					BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
				end
			end
		end
	else
		THROTTLE_OUT = IDLE_THROTTLE_PID:update(IDLE_RPS - ENGINE_RPS, 0)
		if math.abs(AXLE_RPS) < SPEED_AIMOST_ZERO then
			BRAKE = 1
		elseif math.abs(AXLE_RPS) < SPEED_AIMOST_ZERO * 2 then
			CLUTCH = 0
		else
			THROTTLE_OUT = 0
			BRAKE = 0
		end
	end
	output.setNumber(1, THROTTLE_OUT / 2)
	output.setNumber(2, THROTTLE_OUT)
	output.setNumber(3, CLUTCH ^ (1 / 6))
	output.setNumber(4, BRAKE)
	output.setBool(1, GEAR_1)
	output.setBool(2, GEAR_2)
	output.setBool(3, GEAR_3)
	output.setBool(4, GEAR_4)
	output.setBool(5, GEAR_REVERSE)
end


function gear3(gear)
	local sign, abs = getSign(gear)
	GEAR_1 = false
	GEAR_2 = false
	GEAR_3 = false
	GEAR_4 = false
	if abs == 2 then
		GEAR_1 = true
	elseif abs == 3 then
		GEAR_1 = true
		GEAR_2 = true
	elseif abs == 4 then
		GEAR_2 = true
		GEAR_3 = true
	elseif abs == 5 then
		GEAR_2 = true
		GEAR_4 = true
	elseif abs == 6 then
		GEAR_3 = true
		GEAR_4 = true
	elseif abs == 7 then
		GEAR_1 = true
		GEAR_2 = true
		GEAR_4 = true
	elseif abs == 8 then
		GEAR_2 = true
		GEAR_3 = true
		GEAR_4 = true
	end
end

function getSign(num)
	local sign, abs = false, math.abs(num)
	if num < 0 then
		sign = true
	end
	return sign, abs
end

---@param num number
---@param min number
---@param max number
---@return number Value, boolean notClamped
function clamp(num, min, max)
	local value, flag = num, false
	if num < min then
		value = min
	elseif num > max then
		value = max
	else
		value = num
		flag = true
	end
	return value, flag
end
--[[
	if math.abs(AXLE_RPS) <= SPEED_AIMOST_ZERO then
		if GEAR == 0 then
			if THROTTLE_IN == 1 then
				GEAR_REVERSE = false
				THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
				BRAKE = 1
			elseif THROTTLE_IN == -1 then
				GEAR_REVERSE = true
				THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
				BRAKE = 1
			else
				THROTTLE_OUT = IDLE_THROTTLE_PID:update(IDLE_RPS - ENGINE_RPS, 0)
				if GEAR == 0 then
					BRAKE = 1
				end
			end
		else
			if THROTTLE_IN == 1 then
				if AXLE_RPS > 0 then
					THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
					BRAKE = 0
				else
					THROTTLE_OUT = IDLE_THROTTLE_PID:update(IDLE_RPS - ENGINE_RPS, 0)
					BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
				end
			elseif THROTTLE_IN == -1 then
				if AXLE_RPS > 0 then
					THROTTLE_OUT = IDLE_THROTTLE_PID:update(IDLE_RPS - ENGINE_RPS, 0)
					BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
				else
					THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
					BRAKE = 0
				end
			else
				THROTTLE_OUT = IDLE_THROTTLE_PID:update(IDLE_RPS - ENGINE_RPS, 0)
				BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
			end
		end
	elseif AXLE_RPS > SPEED_AIMOST_ZERO then
		if THROTTLE_IN == 1 then
			THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
			BRAKE = 0
		elseif THROTTLE_IN == -1 then
			THROTTLE_OUT = 0
			BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
		else
			THROTTLE_OUT = 0
			BRAKE = 0
		end
	elseif AXLE_RPS < -SPEED_AIMOST_ZERO then
		if THROTTLE_IN == 1 then
			THROTTLE_OUT = 0
			BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
		elseif THROTTLE_IN == -1 then
			THROTTLE_OUT = THROTTLE_PERCENTAGE / 100
			BRAKE = 0
		else
			THROTTLE_OUT = 0
			BRAKE = clamp(0.1 / math.abs(AXLE_RPS), 0.1, 1)
		end
	end
	
			if GEAR_REVERSE then
				
			else
				
			end
]]