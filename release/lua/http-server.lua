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

package.cpath = package.cpath..";../?.dll"

-- ***********************************************************************

local ffi = require("ffi")
local bit = require("bit")
local floor = math.floor

local turbo = require "turbo"
local cmd = require "commands"

-- ***********************************************************************
-- RS232 Setup for interface 

rs232 = require("sys-comm")
bauds 			= { 9600, 19200, 38400, 57600, 115200 }
baud_rate 		= 1
serial_name 	= "COM5"
serial_update 	= 2000

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

	WritePage(self)

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
-- Handler that takes a single argument 'username'
local ConfigHandler = class("ConfigHandler", turbo.web.RequestHandler)
function ConfigHandler:get()
	
	serial_name = self:get_argument("name", "COM5", true)
	serial_update = tonumber(self:get_argument("rate", "2000", true))
	--print("Check: ", serial_name, serial_update)
	
	self:redirect("/index.html?"..tostring(getVal()), false)
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
	local data = cmd:CheckCommand(d)	
	if data ~= "nil" then
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
	{"^/enablecomms.html", CommEnableHandler},
	{"^/readcomms.html", CommHandler},
	{"^/configcomms.html(.*)", ConfigHandler},
	{"^/readanalog.html(.*)", AnalogHandler},
	{"^/readdigital.html(.*)", DigitalHandler},
    {"^/analoginput.html(.*)", AnalogInputHandler},
    {"^/code_page.html(.*)", CodePageHandler},
    {"^/index.html(.*)", BasePageHandler},
	{"^/img/(.*)",  turbo.web.StaticFileHandler, "www/img/"},
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
