@echo off
REM ---------------------------------------------------------------------------
REM     agetpref.bat  -  Don Cross  -  http://cosinekitty.com
REM     (slight modifications for 0011 by raptorofaxys)
REM     Utility batch file used by abuild.bat and aupload.bat.
REM     This batch file makes sure all the right environment variables are set.
REM		

set rc=1
if not "%1" == "agetpref_internal" (
    echo.
    echo.This batch file is designed for use by abuild.bat and aupload.bat.
    echo.
    echo.This batch file was released on September 10, 2008.
    echo.
    echo.Check the following web page for the latest version:
    echo.
    echo.    http://playground.arduino.cc/Code/WindowsCommandLine
    echo.
    echo.Please report any issues or questions on this forum thread:
    echo.
    echo.    http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1168127321/all-0
    echo.
    goto end
)

REM ---------------------------------------------------------------------------
REM     Check for ARDUINO_PATH environment variable
if not defined arduino_path (
    !abuild_error! Must define environment variable ARDUINO_PATH to point to Arduino installation.
    goto end
)

REM ---------------------------------------------------------------------------
REM     Verify that ARDUINO_PATH points to a valid Arduino-0011 installation...

set arduino_runtime=!arduino_path!\hardware\cores\arduino
for %%f in (
    "!arduino_path!\cygwin1.dll"
) do (
    if not exist %%f (
        !abuild_error! The ARDUINO_PATH environment variable does not point to a valid Arduino installation.
        !abuild_error! Expected file [%%f] was missing
        goto end
    )
)

REM ---------------------------------------------------------------------------
REM Set path to find avr tools
set path=%path%;!arduino_path!\hardware\tools\avr\bin

REM ---------------------------------------------------------------------------
REM     Make sure we can find cygwin1.dll and compiler/linker tools...
set path=!arduino_path!;!arduino_path!\tools\avr\bin;!path!
!abuild_report! set path to: !path!

REM ---------------------------------------------------------------------------
REM     Verify ARDUINO_MCU
if not defined arduino_mcu (
    !abuild_error! The environment variable ARDUINO_MCU must be set to the name of your microcontroller (for example, atmega168^).
    goto end
)

REM ---------------------------------------------------------------------------
REM     Verify ARDUINO_PROGRAMMER
if not defined arduino_programmer (
    !abuild_error! The environment variable ARDUINO_PROGRAMMER must be set to the type of programmer you're using (usually stk500^).
    goto end
)

REM ---------------------------------------------------------------------------
REM     Verify ARDUINO_FCPU
if not defined arduino_fcpu (
    !abuild_error! The environment variable ARDUINO_FCPU must be set to the clock frequency of your microcontroller (16000000 for atmega168, 8000000 for atmega8^).
    goto end
)

REM ---------------------------------------------------------------------------
REM     Verify ARDUINO_COMPORT
if not defined arduino_comport (
    !abuild_error! The environment variable ARDUINO_COMPORT must be defined the port on which sits your programmer (e.g. COM1, COM2, etc.^).
    goto end
)

REM ---------------------------------------------------------------------------
REM     Verify ARDUINO_BURNRATE
if not defined arduino_burnrate (
    !abuild_error! The environment variable ARDUINO_BURNRATE must be defined the baud rate at which the download is to occur (often 115200^).
    goto end
)

set rc=0
:end
exit /b %rc%


REM ---------------------------------------------------------------------------
REM     $Log: agetpref.bat,v $
REM     Revision 1.6  2008/09/10 10:57:12  Don.Cross
REM     Updated release date.
REM     Specify exact URL for discussing problems, so users don't have to search for it.
REM
REM     Revision 1.5  2008/09/10 10:49:56  Don.Cross
REM     Modifications for Arduino 0011 by raptorofaxys.
REM     He added support for libraries, with -n option to disable.
REM     He also replaced scanning the Arduino 0007 method of scanning for settings in preferences.txt (broken in 0011)
REM     with user-configured environment variables for all settings.
REM
REM     Revision 1.4  2007/01/07 22:53:53  dcross
REM     Usage text now displays link to where to get latest version on Arduino Playground.
REM     Also displays its own release date so user can tell whether what he has is up-to-date.
REM
REM     Revision 1.3  2007/01/07 22:42:51  dcross
REM     Sorted the preferences in alphabetical order.  Let's keep them that way for easy maintenance.
REM
REM     Revision 1.2  2007/01/07 22:31:38  dcross
REM     Added cvs log tag.
REM

