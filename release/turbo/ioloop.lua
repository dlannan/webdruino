--- Turbo.lua I/O Loop module
-- Single threaded I/O event loop implementation. The module handles socket 
-- events and timeouts and scheduled intervals with millisecond precision.
--
-- Supports the following implementations: 
-- * epoll
-- The IOLoop class is written in such a way that adding new poll
-- implementations is easy.
--
-- Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >
--
-- "Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE."

local log = require "turbo.log"
local util = require "turbo.util"
local signal = require "turbo.signal"
-- local socket = require "network.lib_socket"
local coctx = require "turbo.coctx"
local ffi = require "ffi"
require "turbo.3rdparty.middleclass"

-- local poll = require "lib_poll"
local sys = require"sys"
local sock = require"sys.sock"

local unpack = util.funpack
local ioloop = {} -- ioloop namespace

-- local epoll_ffi, _poll_implementation
  
-- if pcall(require, "turbo.epoll_ffi") then
    -- -- Epoll FFI module found and loaded.
    -- _poll_implementation = 'epoll_ffi'
    -- epoll_ffi = require 'turbo.epoll_ffi'
    -- -- Populate global with Epoll module constants
		
ioloop.READ 	= 0x001  --bit.bor(POLLIN, POLLOUT)
ioloop.WRITE 	= 0x002  --POLLOUT
ioloop.PRI 		= 0x004  --POLLPRI
ioloop.ACCEPT	= 0x008

ioloop.ERROR	= 0xf00
--ioloop.ERROR 	= 'e'  --bit.bor(POLLERR, POLLHUP)

ioloop.BUFER_OUT_SIZE 	= 32768
ioloop.BUFER_IN_SIZE 	= 8192


--- Create or get the global IOLoop instance.
-- Multiple calls to this function returns the same IOLoop.
-- @return IOLoop class instance.
function ioloop.instance()
    if _G.io_loop_instance then
        return _G.io_loop_instance
    else
        _G.io_loop_instance = ioloop.IOLoop:new()
        return _G.io_loop_instance
    end
end

local event_queue 		= nil

-- Accept new client
local function socket_handler(evq, _evobj, _fd, _evid, eof)

	---print("Processing Handler: =========", _evid, _fd, _, eof)	
	local io_inst = ioloop.instance()
	local pevents = 0
	if _evid == 'accept' then pevents = ioloop.ACCEPT end
	if _evid == 'connect' then pevents = ioloop.READ end	
	if _evid == 'r' then pevents = ioloop.READ end
	if _evid == 'w' then pevents = ioloop.WRITE end	
	io_inst._event_called[_fd] = { fd=_fd, evid=_evid, revents=pevents }  
	-- io_inst:_run_handler(_fd, pevents)
end

function stop_system()

	event_queue:stop()
	local io_inst = _G.io_loop_instance
	io_inst._stopped = true
end	


--- IOLoop is a level triggered I/O loop, with additional support for timeout
-- and time interval callbacks.
-- Heavily influenced by ioloop.py in the Tornado web framework.
-- @note Only one instance of IOLoop can ever run at the same time!
ioloop.IOLoop = class('IOLoop')

--- Create a new IOLoop class instance.
function ioloop.IOLoop:initialize()
    self._co_cbs = {}
    self._co_ctxs = {}
    self._handlers = {}
    self._timeouts = {}
    self._intervals = {}
    self._callbacks = {}
	self._event_called = {}
    self._running = false
    self._stopped = false
	
    -- Must be set to avoid stopping execution when SIGPIPE is recieved.
    --signal.signal(signal.SIGPIPE, signal.SIG_IGN)
	
	if event_queue == nil then
		event_queue = assert(sys.event_queue())
	end
	
	-- Quit by Ctrl-C
	assert(event_queue:add_signal("INT", stop_system))
end

-- local function HandlerHandler(_evq, _evid, _fd, _events)

	-- local io_inst = ioloop.instance()
	-- local pevents = 0
	-- if _events == 'r' then pevents = ioloop.READ end
	-- if _events == 'w' then pevents = ioloop.WRITE end
	-- if _events == 'accept' then pevents = ioloop.READ end
	-- if _events == 'connect' then pevents = ioloop.READ end
	
	-- --print("Handler: ", _fd, _evq, _evid, pevents, _events)
	-- --io_inst:_run_handler(_fd, pevents)
	-- io_inst._event_called[_fd] = { fd=_fd, evid=_evid, revents=pevents }  
-- end

--- Add handler function for given event mask on fd.
-- @param fd (Number) File descriptor to bind handler for.
-- @param events (Number) Events bit mask. Defined in ioloop namespace. E.g
-- ioloop.READ and ioloop.WRITE. Multiple bits can be AND'ed together.
-- @param handler (Function) Handler function.
-- @param arg Optional argument for function handler. Handler is called with 
-- this as first argument if set.
-- @return (Boolean) true if successfull else false.
function ioloop.IOLoop:add_handler(fd, events, handler, arg)

---print("Adding Handler: }}}}}}}", fd, events, handler, arg)
	local evid = 0
	if bit.band(ioloop.WRITE, events) > 0 then
		evid = assert(event_queue:add_socket(fd, 'w', socket_handler))	
		if not evid then
			error(SYS_ERR)
		end
	end	
	if bit.band(ioloop.READ, events) > 0 then
		evid = assert(event_queue:add_socket(fd, 'r', socket_handler))	
		if not evid then
			error(SYS_ERR)
		end
	end
	if bit.band(ioloop.ACCEPT, events) > 0 then
		evid = assert(event_queue:add_socket(fd, 'r', socket_handler))	
		if not evid then
			error(SYS_ERR)
		end
	end
    
	--local rc, errno = poll.add_fd(fd, events) --bit.bor(events, ioloop.ERROR))
    -- if rc ~= 0 then
        -- log.notice(
            -- string.format(
                -- "[ioloop.lua] register() in add_handler() failed: %s", 
                -- socket.strerror(errno)))
        -- return false
    -- end
    self._handlers[fd] = {handler, arg, evid}
    return true
end

--- Update existing handler function's trigger events.
-- @param fd (Number) File descriptor to update events for.
-- @param events (Number) Events bit mask. Defined in ioloop namespace. E.g
-- ioloop.READ and ioloop.WRITE. Multiple bits can be AND'ed together.
-- @return (Boolean) true if successfull else false.
function ioloop.IOLoop:update_handler(fd, events)

	local lhandler = self._handlers[fd]
	if not lhandler then return false end
	if not event_queue then return false end
	local pevent = 'r'

---print("Modding Handler: {{{{{{{{", fd, events)	
if events == 0 then return end

	if bit.band(ioloop.READ, events) > 0 then 
		pevent = 'r' 
	end
	if bit.band(ioloop.WRITE, events) > 0 then 
		pevent = 'w' 
	end
	if bit.band(ioloop.ACCEPT, events) > 0 then 
		pevent = 'r' 
	end
	
	local evid = lhandler[3]
	if event_queue and evid then 
		assert(event_queue:mod_socket(evid, pevent)) 
	end
	
    --local rc, errno = poll.modify_fd(fd, events) --bit.bor(events, ioloop.ERROR))
    -- if rc ~= 0 then
        -- log.notice(
            -- string.format(
                -- "[ioloop.lua] modify() in update_handler() failed: %s",
                -- socket.strerror(errno)))
        -- return false
    -- end
    return true
end

--- Remove a existing handler from the IO Loop.
-- @param fd (Number) File descriptor to remove handler from.
-- @return (Boolean) true if successfull else false.
function ioloop.IOLoop:remove_handler(fd)   

	local lhandler = self._handlers[fd]
	if not lhandler then return false end
	if not event_queue then return false end
	
	if lhandler[3] ~= nil then
		local evid = lhandler[3]
		event_queue:del(evid)
	end
	
    --local rc, errno = poll.remove_fd(fd)
    -- if rc ~= 0 then
        -- log.notice(
            -- string.format(
                -- "[ioloop.lua] unregister() in remove_handler() failed: %s", 
                -- socket.strerror(errno)))
        -- return false
    -- end
	
    self._handlers[fd] = nil
	self._event_called[fd] = nil
	fd:close()
	
    return true
end

--- Check if IOLoop is currently in a running state.
-- @return (Boolean) true or false.
function ioloop.IOLoop:running() return self._running end

--- Add a callback to be run on next iteration of the IOLoop.
-- @param callback (Function) 
-- @param arg Optional argument to call callback with as first argument.
function ioloop.IOLoop:add_callback(callback, arg)
    self._callbacks[#self._callbacks + 1] = {callback, arg}
end

--- List all callbacks scheduled.
-- @return table with all callbacks.
function ioloop.IOLoop:list_callbacks() return self._callbacks end

--- Finalize a coroutine context.
-- @param coctx A CourtineContext instance.
-- @return True if suscessfull else false.
function ioloop.IOLoop:finalize_coroutine_context(coctx)
    local coroutine = self._co_ctxs[coctx]
    if not coroutine then
        log.warning("[ioloop.lua] Trying to finalize a coroutine context \
            that there are no reference to.")
        return false
    end
    self._co_ctxs[coctx] = nil 
    self:_resume_coroutine(coroutine, coctx:get_coroutine_arguments())
    return true
end

--- Add a timeout with function to be called in future.
-- @param timestamp (Number) Timestamp when to call function. Based on 
-- Unix epoch time in milliseconds precision. 
-- E.g util.gettimeofday + 3000 will timeout in 3 seconds.
-- @param func (Function)
-- @param Optional argument for func.
-- @return (Number) Reference to timeout.
function ioloop.IOLoop:add_timeout(timestamp, func, arg)
    local i = 1

    while true do
        if self._timeouts[i] == nil then
            break
        else
            i = i + 1
        end
    end
    self._timeouts[i] = _Timeout:new(timestamp, func, arg)
    return i
end

--- Remove timeout.
-- @param ref (Number) The reference returned by IOLoop:add_timeout.
-- @return (Boolean) True on success, else false.
function ioloop.IOLoop:remove_timeout(ref)  
    if self._timeouts[ref] then
        self._timeouts[ref] = nil
        return true        
    else
        return false
    end
end

--- Set function to be called on given interval.
-- @param msec (Number) Call func every msec.
-- @param func (Function)
-- @param Optional argument for func.
-- @return (Number) Reference to interval.
function ioloop.IOLoop:set_interval(msec, func, arg)
    local i = 1

    while self._intervals[i] ~= nil do
        i = i + 1
    end
    self._intervals[i] = _Interval:new(msec, func, arg)
    return i   
end

--- Clear interval.
-- @param ref (Number) The reference returned by IOLoop:set_interval.
-- @return (Boolean) True on success, else false.
function ioloop.IOLoop:clear_interval(ref)
    if self._intervals[ref] then
        self._intervals[ref] = nil
        return true
    else
        return false
    end
end

--- Start the I/O Loop.
-- The loop will continue running until IOLoop:stop is called via a callback 
-- added.
function ioloop.IOLoop:start()
    self._running = true
    while true do
        local poll_timeout = 3600        
        local co_cbs_sz = #self._co_cbs
        if co_cbs_sz > 0 then
            local co_cbs = self._co_cbs
            self._co_cbs = {}
            for i = 1, co_cbs_sz do
                if co_cbs[i] ~= nil then
                    -- co_cbs[i][1] = coroutine (Lua thread).
                    -- co_cbs[i][2] = yielded function.
                    if self:_resume_coroutine(
                        co_cbs[i][1], 
                        co_cbs[i][2]) ~= 0 then
                        -- Resumed courotine yielded. Adjust timeout.
                        poll_timeout = 0
                    end
                end
            end
        end
        local callbacks = self._callbacks
        self._callbacks = {}
        for i = 1, #callbacks, 1 do 
            if self:_run_callback(callbacks[i]) ~= 0 then
                -- Function yielded and has been scheduled for next iteration. 
                -- Drop timeout.
                poll_timeout = 0
            end
        end
        local timeout_sz = #self._timeouts
        if timeout_sz ~= 0 then
            local current_time = util.gettimeofday()
            for i = 1, timeout_sz do
                if self._timeouts[i] ~= nil then
                    local time_until_timeout = self._timeouts[i]:timed_out(current_time)
                    if time_until_timeout == 0 then
                        self:_run_callback({self._timeouts[i]:callback()})
                        self._timeouts[i] = nil
                    else
                        if poll_timeout > time_until_timeout then
                           poll_timeout = time_until_timeout 
                        end
                    end
                end
            end
        end
        local intervals_sz = #self._intervals
        if intervals_sz ~= 0 then
            local time_now = util.gettimeofday()
            for i = 1, intervals_sz do
                if self._intervals[i] ~= nil then
                    local timed_out = self._intervals[i]:timed_out(time_now)
                    if timed_out == 0 then
                        self:_run_callback({
                            self._intervals[i].callback, 
                            self._intervals[i].arg
                            })
                        -- Get current time to protect against building 
                        -- diminishing interval time on heavy functions.
                        -- It is debatable wether this feature is wanted or not.
                        time_now = util.gettimeofday() 
                        local next_call = self._intervals[i]:set_last_call(
                            time_now)
                        if next_call < poll_timeout then
                            poll_timeout = next_call
                        end
                    else
                        if timed_out < poll_timeout then
                            -- Adjust timeout to not miss time out.
                            poll_timeout = timed_out
                        end
                    end
                end
            end
        end
        if self._stopped == true then 
            self._running = false
            self._stopped = false
            break
        end
				
        if #self._callbacks > 0 then
            -- New callback has been scheduled for next iteration. Drop 
            -- timeout.
            poll_timeout = 0
        end
		--poll.timeout_set(poll_timeout)
        --local rc, events, num = poll.poll()

		event_queue:loop(10)
		
		--print("polling....")

		local events = self._event_called
		-- loop all events, break loop as soon as possible
		for k,v in pairs(events) do
			self:_run_handler(v.fd, v.revents)
		end
    end
end

--- Close the I/O loop. 
-- This call must be made from within the running I/O loop via a 
-- callback, timeout, or interval. Notice: All pending callbacks and handlers 
-- are cleared upon close.
function ioloop.IOLoop:close()
    self._running = false
    self._stopped = true
    self._callbacks = {}
    self._handlers = {}
    self._co_cbs = {}
    self._co_ctxs = {}
    self._timeouts = {}
    self._intervals = {}
end

--- Run IOLoop for specified amount of time. Used in Turbo.lua tests.
-- @param timeout In seconds.
function ioloop.IOLoop:wait(timeout)
    assert(self:running() == false, "Can not wait, already started")
    local timedout
    if timeout then
        local io = self
        self:add_timeout(util.gettimeofday() + (timeout*1000), function() 
            timedout = true
            io:close()
        end)
    end
    self:start()
    assert(self:running() == false, "IO Loop stopped unexpectedly")
    assert(not timedout, "Sync wait operation timed out.")
    return true
end

--- Error handler for IOLoop:_run_handler.
local function _run_handler_error_handler(err)
    log.stacktrace(debug.traceback())
    log.debug("[ioloop.lua] Handler error: " .. err)
end

--- Run callbacks protected with error handlers. Because errors can always
-- happen! If a handler errors, the handler is removed from the IOLoop, and
-- never called again.
--function ioloop.IOLoop:_run_handler(evq, evid, fd, events)
function ioloop.IOLoop:_run_handler(fd, events)

    local ok
    local handler = self._handlers[fd]
 	--print("]]]]]]]]]]]]]]]  Handlers....", fd, events, handler)
	
	-- handler[1] = function.
    -- handler[2] = optional first argument for function.
    -- If there is no optional argument, do not add it as parameter to the
    -- function as that create a big nuisance for consumers of the API.
	if handler[2] then
        ok = xpcall(
            handler[1],
            _run_handler_error_handler, 
            handler[2], 
            fd, 
            events)
    else
        ok = xpcall(
            handler[1],
            _run_handler_error_handler,
            fd, 
            events)
    end
    if ok == false then
        -- Error in handler caught by _run_handler_error_handler.
        -- Remove the handler for the fd as its most likely broken.
        self:remove_handler(fd) 
    end
end

local function _run_callback_error_handler(err)
    log.error("[ioloop.lua] Uncaught error in callback: " .. err)
    log.stacktrace(debug.traceback())
end

local function _run_callback_protected(func, arg)
    xpcall(func, _run_callback_error_handler, arg)
end

function ioloop.IOLoop:_run_callback(callback)
    local co = coroutine.create(_run_callback_protected)
    -- callback index 1 = function
    -- callback index 2 = arg
    local rc = self:_resume_coroutine(co, {callback[1], callback[2]})
    return rc
end

function ioloop.IOLoop:_resume_coroutine(co, arg)
    local err, yielded, st
    local arg_t = type(arg)
    if arg_t == "function" then
        -- Function as argument. Call.
        err, yielded = coroutine.resume(co, arg())
    elseif arg_t == "table" then
        -- Callback table.
        err, yielded = coroutine.resume(co, unpack(arg))
    else
        -- Plain resume.
        err, yielded = coroutine.resume(co, arg)
    end
    st = coroutine.status(co)
    if st == "suspended" then
        local yield_t = type(yielded)
        if instanceOf(coctx.CoroutineContext, yielded) then
            -- Advanced yield scenario.
            -- Use CouroutineContext as key in Coroutine map.
            self._co_ctxs[yielded] = co
            return 1
        elseif yield_t == "function" then
            -- Schedule coroutine to be run on next iteration with function
            -- as result of yield.
            self._co_cbs[#self._co_cbs + 1] = {co, yielded}
            return 2
        elseif yield_t == "nil" then
            -- Empty yield. Schedule resume on next iteration.
            self._co_cbs[#self._co_cbs + 1] = {co, 0}
            return 3
        else
            -- Invalid yielded value. Schedule resume of courotine on next 
            -- iteration with -1 as result of yield (to represent error).
            self._co_cbs[#self._co_cbs + 1] = {co, function() return -1 end}
            log.warning(string.format(
                "[ioloop.lua] Callback yielded with unsupported value, %s.",
                yield_t))
            return 3
        end 
    end
    return 0
end

_Interval = class("_Interval")
function _Interval:initialize(msec, callback, arg)
    self.interval_msec = msec
    self.callback = callback
    self.arg = arg
    self.next_call = util.gettimeofday() + self.interval_msec
end

function _Interval:timed_out(time_now)
    if time_now >= self.next_call then
        return 0
    else
        return self.next_call - time_now
    end
end

function _Interval:set_last_call(time_now)
    self.last_interval = time_now
    self.next_call = time_now + self.interval_msec
    return self.next_call - time_now
end


_Timeout = class('_Timeout')
function _Timeout:initialize(timestamp, callback, arg)
    self._timestamp = timestamp or 
        error('No timestamp given to _Timeout class')
    self._callback = callback or 
        error('No callback given to _Timeout class')
    self._arg = arg
end

function _Timeout:timed_out(time)
    if self._timestamp - time <= 0 then
        return 0
    else 
        return self._timestamp - time
    end
end

function _Timeout:callback()
    return self._callback, self._arg
end


return ioloop

