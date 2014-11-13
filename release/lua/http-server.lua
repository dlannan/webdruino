--- Turbo.lua Hello world using HTTPServer
--
-- Using the HTTPServer offers more control for the user, but less convenience.
-- In almost all cases you want to use turbo.web.RequestHandler.
--
-- Copyright 2013 John Abrahamsen
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.  

local arg = {...}

-- ***********************************************************************

package.path = package.path..";network/?.lua"
package.path = package.path..";lua/?.lua"

local ffi = require("ffi")

if ffi.os == "Windows" then
if ffi.abi("32bit") then
package.cpath = package.cpath..";bin/win32/?.dll"
else
package.cpath = package.cpath..";bin/win64/?.dll"
end
end

if ffi.os == "Linux" then
package.cpath = package.cpath..";bin/linux/?.so"
end

-- ***********************************************************************

local bit 		= require("bit")
local floor 	= math.floor

local turbo 	= require "turbo"
local cmd 		= require "commands"

local boards 	= require("arduino-boards")

-- ***********************************************************************
-- RS232 Setup for interface 

rs232 = require("sys-comm")

-- Mapped devices - The web-server can update and read/write multiple mapped
--                  devices at once. 
--                  When a user switches device, the served page is from that device 

-- These globals need to go into web client attachments.
bauds 				= { 9600, 19200, 38400, 57600, 115200 }
serial_rate			= 57600 
serial_name 		= "COM5"
-- How fast the web server should attempt to poll the serial port - default 1000ms
update_rate 		= 2000

arduino_board		= "atmega328p"
arduino_sdk_path	= [[C:\Program Files (x86)\Arduino]]
arduino_compile		= ""
arduino_upload		= ""

-- ***********************************************************************
-- This will turn into pin configs.

analog_output 	= { 0, 0, 0, 0, 0 }
digital_output	= { -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0 }

-- Mapping for Arduino Nano
AOP = {	0,1,2,3,4,5,6,7,8,9,10,11,12,13 }

-- ***********************************************************************

read_data 		= ""

require("http-interface")

-- ***********************************************************************
-- Handler that takes a single argument 'username'

local BasePageHandler = class("BasePageHandler", turbo.web.RequestHandler)
function BasePageHandler:get(data, stuff)

	WriteMainPage(self)

	if(data == "ttq") then
		turbo.ioloop.instance():close()
	end	
end

-- ***********************************************************************
-- Handler that takes a single argument 'username'

local ConfigPageHandler = class("ConfigPageHandler", turbo.web.RequestHandler)
function ConfigPageHandler:get(data, stuff)

	WriteConfigPage(self)

	if(data == "ttq") then
		turbo.ioloop.instance():close()
	end	
end

-- ***********************************************************************
-- Handler that takes a single argument 'username'

local CodePageHandler = class("CodePageHandler", turbo.web.RequestHandler)
function CodePageHandler:get(data, stuff)

	WriteCodePage(self)
end

-- ***********************************************************************
-- Handler that takes a single argument 'username'
local CommEnableHandler = class("CommEnableHandler", turbo.web.RequestHandler)
function CommEnableHandler:get(data, stuff)

	rs232:InitComms()
	if rs232.fd == nil then 
		read_data = read_data.."-------- Serial Error --------<br>"
	else
		read_data = read_data.."----- Serial Port Reset ------<br>"
	end

	-- Reset the server.. just to make sure the data is fresh.
	self:redirect("/index.html", false)
end

-- ***********************************************************************
-- Handler that looks after the compilation of the arduino file.
local CompileVerifyHandler = class("CompileVerifyHandler", turbo.web.RequestHandler)
function CompileVerifyHandler:post(data, stuff)

	-- Must reset any comms - avrdude needs it!!
	--rs232:InitComms()
	rs232:CloseComms()

	local code = (self:get_argument("code", "FALSE", true))
	local upload = tonumber(self:get_argument("upload", "0", true))
	
	if code ~= "FALSE" then
		-- set and execute the arduino environment variables
		local envf = io.open("build/arduino_env.bat", "w")
		if envf then
			--envf:write("cd tools\n")
			envf:write("set \"ARDUINO_PATH="..arduino_sdk_path.."\"\n")
			envf:write("set ARDUINO_MCU="..arduino_board.."\n")
			envf:write("set ARDUINO_PROGRAMMER=arduino\n")
			envf:write("set ARDUINO_FCPU=16000000\n")
			envf:write("set ARDUINO_COMPORT="..serial_name.."\n")
			envf:write("set ARDUINO_BURNRATE="..serial_rate.."\n")
			
			if upload == 1 then
				envf:write("abuild.bat -r -u arduino_app.pde\n")
			else
				envf:write("abuild.bat -r -c arduino_app.pde\n")
			end
			
			envf:close()
		end
		
		-- Copy arduin code to temp c file.
		local f = io.open("build/arduino_app.pde", "w")
		if f then
			--f:write("#include <Arduino.h>\n")
			f:write(code)
			f:close()
			
			-- Now run it.
			os.execute("cd build & arduino_env.bat > build.log 2>&1")
			-- get the log file...
			--self:redirect("/code_page.html", false)
		end
	end
end


-- ***********************************************************************
-- Handler that takes a single argument 'username'
local ConfigHandler = class("ConfigHandler", turbo.web.RequestHandler)
function ConfigHandler:get()
	
	local t_name = self:get_argument("name", "FALSE", true)
	local t_update = self:get_argument("update", "FALSE", true)
	local t_srate = self:get_argument("srate", "FALSE", true)
	local t_board = self:get_argument("board", "FALSE", true)
	
	--print("Check: ", t_name, t_update, t_srate)
	
	if t_name ~= "FALSE" then serial_name = t_name end
	if t_update ~= "FALSE" then	update_rate = tonumber(t_update) end	
	if t_srate ~= "FALSE" then	serial_rate = tonumber(t_srate) end	
	if t_board ~= "FALSE" then	arduino_board = t_board end	
end

-- ***********************************************************************
-- Handler that takes a single argument 'username'
local AnalogHandler = class("AnalogHandler", turbo.web.RequestHandler)
function AnalogHandler:get(data)
	
	local input = tonumber(self:get_argument("input", 1, true))
	if input > 0 and input < 5 then
		self:write(tostring(analog_output[input]))
	else
		self:write("0")
	end
end

-- ***********************************************************************
-- Handler that takes a single argument intput for the data id
local DigitalHandler = class("DigitalHandler", turbo.web.RequestHandler)
function DigitalHandler:get(data)
	
	local input = (self:get_argument("input", "", true))
	if input ~= "" then
		local outdata = ""
		local k = tonumber(input)

		-- Check digital
		local v = digital_output[k]
		if v ~= -1 then
		if v > 0 then
				outdata = "img/button_green.png" 
			else
				outdata = "img/button_red.png"
			end
		else
			outdata = "img/button_grey.png"
		end
		self:write(outdata)
	end
end


-- ***********************************************************************
-- Handler that takes a single argument 'username'
local CommHandler = class("CommHandler", turbo.web.RequestHandler)
function CommHandler:get(data)
	local c = sys.msec()
	
	cmd:ReadAnalog()
	cmd:ReadDigital()
	
	local d = rs232:ReadComms()
	if d ~= "nil" then
		local data = cmd:CheckCommand(d)	
		if string.len(data) > 1 then
			data = string.gsub(data, "\n", "<br>")
			read_data = read_data..data
		end
	end	

	cmd:UpdateOutput(rs232, 6)
	self:write(read_data)
	--self:redirect("/index.html", false)
end

-- ***********************************************************************
-- Handler that takes a single argument 'username'
local BuildLogHandler = class("BuildLogHandler", turbo.web.RequestHandler)
function BuildLogHandler:get(data)
	
	local flog = io.open("build/build.log", "r")
	if flog then
		local log_data = flog:read("*a")
		log_data = string.gsub(log_data, "\n", "<br>")
		self:write(log_data)
		flog:close()
	end
	--self:redirect("/index.html", false)
end

-- ***********************************************************************

local AnalogInputHandler = class("AnalogInputHandler", turbo.web.RequestHandler)
function AnalogInputHandler:post()
	local data = self:get_argument("aod", "0.0", true)
	local ival = self:get_argument("aot", "1", true)
	-- print("AnalogInput: ", ival, data)
	
	local output = cmd:BuildCommand("W", AOP[tonumber(ival)], math.floor(data * 1023.0))
	if output then cmd:WriteCommand( output ) end
end

-- ***********************************************************************
local app = turbo.web.Application:new({
    -- Serve single index.html file on root requests.
	{"^/img/(.*)",  turbo.web.StaticFileHandler, "www/img/"},

    {"^/code_page.html", CodePageHandler},
    {"^/config.html", ConfigPageHandler},
    {"^/index.html(.*)", BasePageHandler},

	{"^/enablecomms.html", CommEnableHandler},
	{"^/readcomms.html", CommHandler},
	{"^/buildlog.html", BuildLogHandler},
	{"^/configcomms.html(.*)", ConfigHandler},
	{"^/readanalog.html(.*)", AnalogHandler},
	{"^/readdigital.html(.*)", DigitalHandler},
    {"^/analoginput.html(.*)", AnalogInputHandler},
	
	{"^/compileverify.html(.*)", CompileVerifyHandler},
	
	{"^/$", turbo.web.StaticFileHandler, "www/index.html"},
    -- Serve contents of directory.
    {"^/(.*)$", turbo.web.StaticFileHandler, "www/"}
})

-- ***********************************************************************

app:set_server_name("WebDruino Server")
local srv = turbo.httpserver.HTTPServer(app)
srv:bind(8888)
srv:start(1) -- Adjust amount of processes to fork - does nothing at moment.

turbo.ioloop.instance():start()

-- ***********************************************************************

rs232:CloseComms()
	
-- ***********************************************************************
