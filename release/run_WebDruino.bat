REM ****** call bin\win32\luajit.exe lua\http-server.lua
ECHO OFF
SETLOCAL

set MACHINE=32
IF [%1]==[] (
	REM ECHO "Using 32bit execution."
	set MACHINE=32
) ELSE (
	REM ECHO "Using 64bit execution."
	set MACHINE=64
)

set PATH=bin/win%MACHINE%
set LD_LIBRARY_PATH=bin\win%MACHINE%
bin\win%MACHINE%\luajit.exe lua\http-server.lua