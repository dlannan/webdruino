local serial = {}

sys = require("sys")
serial.fd = nil

function serial:InitComms()
	if self.fd then self:CloseComms() end
	print("serial_name", serial_name)
	self.fd = sys.handle():open(serial_name, "rwb")
	if self.fd == nil then return end
	--print(self.fd)
	--self.fd:comm_queues(1024, 1024)
	self.fd:comm_control("dtr")
	self.fd:comm_timeout(0.100)
	local result = self.fd:comm_init("reset", tonumber(bauds[baud_rate]), "cs8", "sb1")
end

function serial:CloseComms()
	if self.fd == nil then return end
	self.fd:close()
end

function serial:ReadComms()
	if self.fd == nil then return "nil" end
	local d = self.fd:read()
	return tostring(d)
end

function serial:WriteComms(data)
	if self.fd == nil then return "" end
	return self.fd:write(tostring(data))
end

return serial