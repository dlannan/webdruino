
local util = require "lib_util"

-- ***********************************************************************

function getVal()
	return util.milliSeconds()
end

-- ***********************************************************************

-- Use this for development where html files are being modified
local fetch_static_file = STATIC_CACHE.read_file
-- Use this for deployment - no longer changing, use the cache.
--local fetch_static_file = STATIC_CACHE:get_file

-- ***********************************************************************

function WritePage(handler, data)

	local tval = getVal()
	--print(tval)

	local indicator = ""
	if rs232.fd == nil then
		indicator = [[<li><span class="navbar-new">X</span></li>]]
	end
	
	-- Main page for the utility
	local rc, buf = fetch_static_file(STATIC_CACHE, "www/main_page.html")
	
	if rc == 0 then
		obuff = tostring(buf)
		obuff = string.gsub(obuff, "VAR_bauds1", tostring(bauds[1]) )
		obuff = string.gsub(obuff, "VAR_bauds2", tostring(bauds[2]) )
		obuff = string.gsub(obuff, "VAR_bauds3", tostring(bauds[3]) )
		obuff = string.gsub(obuff, "VAR_bauds4", tostring(bauds[4]) )
		obuff = string.gsub(obuff, "VAR_bauds5", tostring(bauds[5]) )
		obuff = string.gsub(obuff, "VAR_serial_name", tostring(serial_name) )
		obuff = string.gsub(obuff, "VAR_serial_update", tostring(serial_update) )
	
		obuff = string.gsub(obuff, "VAR_analog_output1", tostring(analog_output[1]) )
		obuff = string.gsub(obuff, "VAR_analog_output2", tostring(analog_output[2]) )
		obuff = string.gsub(obuff, "VAR_analog_output3", tostring(analog_output[3]) )
		obuff = string.gsub(obuff, "VAR_analog_output4", tostring(analog_output[4]) )
		
		obuff = string.gsub(obuff, "VAR_read_data", read_data )
		obuff = string.gsub(obuff, "VAR_tval", tostring(tval) )

		handler:write(obuff)
		handler:finish()
	end
end

-- ***********************************************************************

function WriteCodePage(handler, data)

	local tval = getVal()
	--print(tval)
	
	-- Main page for the utility
	local rc, buf = fetch_static_file(STATIC_CACHE, "www/code_page.html")
	
	if rc == 0 then
		obuff = tostring(buf)
	
		handler:write(obuff)
		handler:finish()
	end
end

-- ***********************************************************************
