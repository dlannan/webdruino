-- Make command -
-- Protocol is  <command letter><pin id><value>
--              WP141024  - Write Pin 14 - 1024
--				RP01	  - Read Pin 01
-- Command always starts with & and finishes with @ 
-- The commands will be compressed later for performance.

local commands = {}

-- Mapping for Arduino Nano
AOP = {
	1,2,3,4,5,6,7,8,9,10,11,12,13,14
}

-- ***********************************************************************

function commands:BuildCommand( RW, Pin, value )

	local out = RW..string.format("%02d", Pin)
	if RW == "R" then
		return "&"..out.."@"
	end
	if RW == "r" then
		return "&"..out.."@"
	end
	
	if RW == "W" then
		local val = string.format("%04d",value)
		out = out..val
		return "&"..out.."@"
	end
	if RW == "w" then
		local val = string.format("%01d",value)
		out = out..val
		return "&"..out.."@"
	end	
	
	return nil
end

-- ***********************************************************************

function commands:CheckCommand( buff )

	for cmd, cpt in string.gmatch(buff, "&(%w+)@") do 
		local mode = string.sub(cmd, 1, 1)
		local pin = tonumber(string.sub(cmd, 2, 3))
		local val = tonumber(string.sub(cmd, 4, 7))
		
		if mode == "R" and pin > 0 and pin < 5 then
			--print("Command: ",mode, pin, val)
			analog_output[pin] = string.format("%2.2f", tostring(val * 100/1024.0))
		end
	end
	
	buff = string.gsub(buff, "&%w+@", "")
	-- Check if its just whitespace - return nil
	local ws = string.gsub(buff, "[\r\n]", "")
	if string.len(ws) == 0 then return "nil" end
	return buff
end

-- ***********************************************************************
return commands