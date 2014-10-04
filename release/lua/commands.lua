-- Make command -
-- Protocol is  <command letter><pin id><value>
--              WP141024  - Write Pin 14 - 1024
--				RP01	  - Read Pin 01
-- Command always starts with & and finishes with @ 
-- The commands will be compressed later for performance.

local commands = {}

-- Command queue - use Cooroutines to execute them
commands.queue = {}
commands.front = 1
commands.back  = 1

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

function commands:WriteCommand( command )

	self.queue[self.back] = command
	self.back = self.back + 1
end

-- ***********************************************************************
-- Execute commands in queue if possible
function commands:UpdateOutput( rs232, count )

	while count > 0 do
		local cmd = self.queue[self.front]
		
		if cmd ~= nil then
			rs232:WriteComms(cmd)
			self.queue[self.front] = nil
			self.front = self.front + 1
			if self.front > self.back then self.front = self.back end
		else 
			return
		end
		count = count - 1
	end
end

-- ***********************************************************************

function commands:RunCommand(cmd)
	local mode = string.char(string.byte(cmd, 1))
	
	if mode == 'R' then
		local pin = tonumber(string.char(string.byte(cmd, 2,3)))
		local val = tonumber(string.char(string.byte(cmd, 4,5,6,7)))

		analog_output[pin] = string.format("%2.2f", tostring(val * 100/1023.0))
	end
	
	if mode == "r" then
		local pin = tonumber(string.sub(cmd, 2, 5), 16)
		local val = tonumber(string.sub(cmd, 6, 9), 16)

		for p = 1, #digital_output do
			local test = bit.lshift(1, p-1)
			local m = bit.band(pin, test)
			if m > 0 and digital_output[p] ~= -1 then
				digital_output[p] = bit.rshift( bit.band(val, test), p-1 ) 
			end
		end
	end
end

-- ***********************************************************************

function commands:CheckCommand( buff )

	-- Collect commands
	local new_command = ""
	local start_command = false

	for c=1, #buff do
		local ch = string.char(buff:byte(c))
		
		if start_command == true and ch ~= '@' then 
			new_command = new_command..ch 
		end
		if ch == '&' then start_command = true end
		if ch == '@' then 
			start_command = false 
			self:RunCommand(new_command) 
		end
	end
	
	buff = string.gsub(buff, "&.*@", "")
	-- Check if its just whitespace - return nil
	local ws = string.gsub(buff, "[\r\n]", "")
	if string.len(ws) == 0 then return "nil" end
	return buff
end

-- ***********************************************************************

function commands:ReadDigital()

	-- Make a digital mask
	local val = 0
	local pin = 0
	local b = 0
	for b = 0, #digital_output-1 do
		local v = digital_output[b+1]
		if v > -1 then
			val = bit.bor(val, bit.lshift(v, b))
			pin = bit.bor(pin, bit.lshift(1, b))
		end
	end
	
	-- Always write even going to zero
	self:WriteCommand("&r"..string.format("%04x%04x", pin, val).."@")
end

-- ***********************************************************************

function commands:ReadAnalog()

	self:WriteCommand("&R00@")
	self:WriteCommand("&R01@") 
	--rs232:WriteComms("&R03@")
	--rs232:WriteComms("&R04@")
end

-- ***********************************************************************

return commands