@echo off
setlocal EnableDelayedExpansion
REM     aupload.bat  -  Don Cross  -  http://cosinekitty.com
rem		(some slight modifications for 0011 by raptorofaxys)

set rc=1

REM ---------------------------------------------------------------------------
   
if "%1" == "" (
    echo.
    echo.Usage  -  aupload hexfile
    echo.
    echo.Uploads the given hexfile [e.g. "mysketch.hex"] to your Arduino board.
    echo.If hexfile is an asterisk [*], aupload will search in .\obj for a .hex
    echo.file, and if exactly one such .hex file is found, that will be uploaded.
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

if "%1" == "*" (
    set hexcount=0
    for %%f in (obj\*.hex) do (
        set hexfile=%%f
        echo.Found !hexfile!
        set /a hexcount+=1
    )
    
    if !hexcount! == 1 (
        REM   Unique file was found.  We are happy.
    ) else (
        if !hexcount! == 0 (
            echo.
            echo.aupload.bat:  No hex files were found in obj\*.hex
            echo.
        ) else (
            echo.
            echo.aupload.bat:  Found !hexcount! hex files.  
            echo.Please specify which should be uploaded, or delete all but one of them.
            echo.
        )
        goto end
    )                  
) else (
    set hexfile=%1
    if not exist !hexfile! (
        echo.aupload.bat:  File !hexfile! does not exist.
        goto end
    )
)

call agetpref.bat agetpref_internal
if not !errorlevel! == 0 (
    goto end
)

REM ---------------------------------------------------------------------------

REM The old uisp command doesn't seem to do it for me - based on cursory investigation,
REM it seems the arduino environment now uses avrdude as well
rem set cmd=uisp -v=3 -dpart=!arduino_mcu! -dprog=!arduino_programmer! -dserial=/dev/!arduino_comport! -dspeed=!arduino_burnrate! --upload if=!hexfile!
set cmd=avrdude -C "!arduino_path!\hardware\tools\avr\etc\avrdude.conf" -p !arduino_mcu! -P !arduino_comport! -c !arduino_programmer! -b !arduino_burnrate! -U "flash:w:!hexfile!"
!abuild_report! !cmd!
!cmd!
set rc=!errorlevel!
goto end

REM ---------------------------------------------------------------------------

:end
echo.aupload.bat:  exiting with return code !rc!
exit /b !rc!

REM     $Log: aupload.bat,v $
REM     Revision 1.11  2008/09/10 10:57:12  Don.Cross
REM     Updated release date.
REM     Specify exact URL for discussing problems, so users don't have to search for it.
REM
REM     Revision 1.9  2008/09/10 10:50:56  Don.Cross
REM     Fixed typo in error message when more than one hex file is found.
REM
REM     Revision 1.8  2008/09/10 10:49:56  Don.Cross
REM     Modifications for Arduino 0011 by raptorofaxys.
REM     He added support for libraries, with -n option to disable.
REM     He also replaced scanning the Arduino 0007 method of scanning for settings in preferences.txt (broken in 0011)
REM     with user-configured environment variables for all settings.
REM
REM     Revision 1.6  2007/01/07 22:53:53  dcross
REM     Usage text now displays link to where to get latest version on Arduino Playground.
REM     Also displays its own release date so user can tell whether what he has is up-to-date.
REM
REM     Revision 1.5  2007/01/07 22:31:08  dcross
REM     Now call agetpref.bat to get Arduino preferences, instead of having hardcoded options.
REM
REM     Revision 1.4  2007/01/07 21:39:59  dcross
REM     Discovered weird behavior if uisp is fed a file that does not exist:  it acts like it is still trying to upload something!
REM     So now we check for existence of file.
REM     Exit with return code so calling process can determine whether upload was successful or not.
REM
REM     Revision 1.3  2007/01/06 23:15:00  dcross
REM     Now generate much less verbose uisp output with -v=3 instead of -v=4.
REM
REM     Revision 1.2  2007/01/06 22:33:10  dcross
REM     Now allow user to pass * on the command line, which causes us to search for a unique hex file in the obj dir.
REM
REM     Revision 1.1  2007/01/06 22:05:33  dcross
REM     First draft of an uploader batch file.  Right now all the parameters are hardcoded for my own configuration.
REM     To make this usable by other people, I will need to figure out how to get their configuration.
REM                                                            
