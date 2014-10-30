@echo off
setlocal EnableDelayedExpansion
REM ---------------------------------------------------------------------------
REM     abuild.bat  -  by Don Cross  -  http://cosinekitty.com
REM     (slight modifications for 0011 and very experimental external library support by raptorofaxys)
REM     Arduino command-line build for Windows.
REM ---------------------------------------------------------------------------

REM     Initialize stuff here...
set abuild_release_date=September 10, 2008
set abuild_error=echo.abuild.bat: *** ERROR:
set abuild_report=rem 
set abuild_retcode=1
set abuild_output=.\obj
set abuild_rebuild_runtime=false
set abuild_upload=true
set abuild_verbose=false
set abuild_nolibs=false
set abuild_promptForUpload=true

REM ---------------------------------------------------------------------------
REM     Look for command line options...
:NextOption
if /i "%1" == "-v" (
    set abuild_report=echo.abuild.bat:
    set abuild_verbose=true
    shift
    goto NextOption
)

if /i "%1" == "-o" (
    if "%2" == "" (
        !abuild_error! expected output path after '-o'
        goto end
    )
    set abuild_output=%2
    shift
    shift
    goto NextOption
)

if /i "%1" == "-r" (
    set abuild_rebuild_runtime=true
    shift
    goto NextOption
)

if /i "%1" == "-n" (
	set abuild_nolibs=true
	shift
	goto NextOption
)

if /i "%1" == "-c" (
    set abuild_upload=false
    shift
    goto NextOption
)

if /i "%1" == "-u" (
    set abuild_promptForUpload=false
    shift
    goto NextOption
)

if "%1" == "" (goto usage)

set abuild_SketchName=%~1
if not exist !abuild_SketchName! (
    !abuild_error! File !abuild_SketchName! does not exist.
    goto end
)

REM ---------------------------------------------------------------------------
REM     Parse the Arduino preferences.txt file and set environment variables accordingly...

call agetpref.bat agetpref_internal
if not !errorlevel! == 0 (
    goto end
)

REM ---------------------------------------------------------------------------

if not exist !abuild_output! (
    md !abuild_output!
    if not exist !abuild_output! (
        !abuild_error! Cannot create output path !abuild_output!
        goto end
    )
)

!abuild_report! sketch input file: !abuild_SketchName!
!abuild_report! sketch extension: !abuild_SketchName:~-4!

if /i "!abuild_SketchName:~-4!" == ".pde" (
    REM     If we see .pde on the end, we will do a tiny amount of preprocessing,
    REM     but not as much as the Arduino IDE would do.
    set abuild_cppname=!abuild_output!\!abuild_SketchName!.cpp
    set abuild_preprocess=true
    !abuild_report! found PDE file; will do minor preprocessing ==^>  !abuild_cppname!
    > !abuild_cppname! echo.#include ^<Arduino.h^>
    >>!abuild_cppname! type !abuild_SketchName!
    if exist "!arduino_runtime!\main.cxx" (
        REM     Getting here means we are using the library optimization patch.
        >>!abuild_cppname! type "!arduino_runtime!\main.cxx"
    )
) else (
    !abuild_report! found non-PDE file; will not preprocess.
    set abuild_cppname=!abuild_SketchName!
    set abuild_preprocess=false
)

!abuild_report! Compiler output will go to:  !abuild_output!

REM ---------------------------------------------------------------------------
REM     Clean up any stale output from the previous build...

for %%f in (
    !abuild_output!\*.elf
    !abuild_output!\*.hex 
    !abuild_output!\*.rom
) do (
    !abuild_report! deleting old %%f
    del %%f
    if exist %%f (
        !abuild_error! Cannot delete %%f
        goto end
    )
) 

REM ---------------------------------------------------------------------------
REM     Find all external libraries, and compile a list of include paths...

if !abuild_nolibs! == false (
	set abuild_include_paths=
	set abuild_include_paths_root=!arduino_path!\hardware\libraries

	REM HACK: for some reason, I am unable to get for work with both /R and /D, when it needs to expand
	REM an environment variable for the /R root..? hardcoding the path works... using pushd/popd as a workaround
	pushd !abuild_include_paths_root!
	for /R /D %%d in ("*.*") do (
		REM Don't include example directories
		set test_dir=%%d
		set test=!test_dir:*examples=examples!
		set test=!test:~0,8!
		
		if NOT !test! EQU examples (
			set abuild_include_paths=!abuild_include_paths! -I"%%~d"
		)
	)
	popd
)
rem echo.!abuild_include_paths!

REM ---------------------------------------------------------------------------
REM     Compile the user's sketch first, to help her find errors quicker...

set abuild_gcc_opts=-c -g -Os -I"!arduino_runtime!" !abuild_include_paths! -mmcu=!arduino_mcu! -DF_CPU=!arduino_fcpu! -DABUILD_BATCH=1
set abuild_gpp_opts=!abuild_gcc_opts! -fno-exceptions
set abuild_short_name=

for %%f in (!abuild_cppname!) do (
    set abuild_short_name=%%~nf
    set abuild_user_objfile=!abuild_output!\%%~nf.cpp.o
    set abuild_cmd=avr-g++ !abuild_gpp_opts! %%f -o!abuild_user_objfile!
    !abuild_report! !abuild_cmd!
    if exist !abuild_user_objfile! (del !abuild_user_objfile!)
    !abuild_cmd!
    if not exist !abuild_user_objfile! (
        !abuild_error! cannot compile %%f using command:
        !abuild_error! !abuild_cmd!
        goto end
    )
)

if not defined abuild_short_name (
    !abuild_error! Problem finding short name for !abuild_cppname!
    goto end
)

REM ---------------------------------------------------------------------------
REM     Compile all the C/C++ code for the runtime library...
REM     Note that we encode the microcontroller name in the runtime library
REM     name, so if the user switches microcontrollers, we build a new one.
REM     We also differentiate between the archive which contains external
REM     libraries and the one that doesn't (-l option).

REM Suppress library warnings
set abuild_gcc_opts=!abuild_gcc_opts! -w

if !abuild_nolibs! == true (
	set abuild_runtime_shortname=arduino_runtime_!arduino_mcu!.a
) else (
	set abuild_runtime_shortname=arduino_runtime_!arduino_mcu!_withlibs.a
)
set abuild_runtime_library=!abuild_output!\!abuild_runtime_shortname!
if !abuild_rebuild_runtime! == false (
    if exist !abuild_runtime_library! (
        !abuild_report! Runtime library already exists
        goto link_phase
    ) else (
        !abuild_report! Runtime library does not exist; building it now
    )
) else (
    !abuild_report! Forcing rebuild of runtime library because of -r option
)

if exist !abuild_runtime_library! (
    del !abuild_runtime_library!
)

for %%f in ("!arduino_runtime!\*.c") do (
    set abuild_objfile=!abuild_output!\%%~nf.c.o
    set abuild_cmd=avr-gcc !abuild_gcc_opts! "%%~f" "-o!abuild_objfile!"
    !abuild_report! !abuild_cmd!
    if exist !abuild_objfile! (del !abuild_objfile!)
    !abuild_cmd!
    if not exist !abuild_objfile! (goto end)
    if not !errorlevel! == 0 (goto end)
    
    set abuild_cmd=avr-ar rcs !abuild_runtime_library! !abuild_objfile!
    !abuild_report! !abuild_cmd!
    !abuild_cmd!
    if not !errorlevel! == 0 (goto end)
)

for %%f in ("!arduino_runtime!\*.cpp") do (
    set abuild_objfile=!abuild_output!\%%~nf.cpp.o
    set abuild_cmd=avr-g++ !abuild_gpp_opts! "%%~f" "-o!abuild_objfile!"
    !abuild_report! !abuild_cmd!
    if exist !abuild_objfile! (del !abuild_objfile!)
    !abuild_cmd!
    if not exist !abuild_objfile! (goto end)
    if not !errorlevel! == 0 (goto end)
    
    set abuild_cmd=avr-ar rcs !abuild_runtime_library! !abuild_objfile!
    !abuild_report! !abuild_cmd!
    !abuild_cmd!
    if not !errorlevel! == 0 (goto end)
)

REM ---------------------------------------------------------------------------
REM     Compile all the external libraries, and lump them into the runtime library...
REM     (note that some symbols might not be stripped by the linker,
REM     so we provide the -n option to minimize code size)

REM Once again, do the pushd/pop hack for the recursive for loop...
REM Also, all abuild_cmd are CALL'ed below, otherwise the shell passes arguments incorrectly
REM to the avr toolchain on the second iteration through the inner loops..!
if !abuild_nolibs! == false (
	for /D %%d in ("!arduino_path!\hardware\libraries\*.*") do (
		!abuild_report! Building library: %%d
		
		pushd %%d
		for /R %%f in ("*.c") do (
			rem Make sure we're not building an example
			set test_file=%%f
			set test=!test_file:*examples=examples!
			set test=!test:~0,8!
			
			if NOT !test! EQU examples (
				popd
				set abuild_objfile=!abuild_output!\%%~nf.c.o
				set abuild_cmd=avr-gcc !abuild_gcc_opts! "%%~f" "-o!abuild_objfile!"
				!abuild_report! !abuild_cmd!
				if exist !abuild_objfile! (del !abuild_objfile!)
				call !abuild_cmd!
				if not exist !abuild_objfile! (goto end)
				if not !errorlevel! == 0 (goto end)
			    
				set abuild_cmd=avr-ar rcs !abuild_runtime_library! !abuild_objfile!
				!abuild_report! !abuild_cmd!
				call !abuild_cmd!
				if not !errorlevel! == 0 (goto end)
				pushd %%d
			)
		)

		for /R %%f in ("*.cpp") do (
			rem Make sure we're not building an example
			set test_file=%%f
			set test=!test_file:*examples=examples!
			set test=!test:~0,8!
			
			if NOT !test! EQU examples (
				popd
				set abuild_objfile=!abuild_output!\%%~nf.cpp.o
				set abuild_cmd=avr-g++ !abuild_gpp_opts! "%%~f" "-o!abuild_objfile!"
				!abuild_report! !abuild_cmd!
				if exist !abuild_objfile! (del !abuild_objfile!)
				call !abuild_cmd!
				if not exist !abuild_objfile! (goto end)
				if not !errorlevel! == 0 (goto end)
			    
				set abuild_cmd=avr-ar rcs !abuild_runtime_library! !abuild_objfile!
				!abuild_report! !abuild_cmd!
				call !abuild_cmd!
				if not !errorlevel! == 0 (goto end)
				pushd %%d
			)
		)
		popd
	)
)

REM ---------------------------------------------------------------------------
REM     Link everything...

:link_phase

REM     Link to an ELF file...
set abuild_elf=!abuild_output!\!abuild_short_name!.elf
set abuild_cmd=avr-gcc -Os "-Wl,-u,vfprintf -lprintf_flt -lm,-Map=!abuild_output!\!abuild_short_name!.map,--cref" -mmcu=!arduino_mcu! -o !abuild_elf! !abuild_user_objfile! !abuild_runtime_library! -L!abuild_output!
!abuild_report! !abuild_cmd!
!abuild_cmd!
if not exist !abuild_elf! (goto end)

REM     Convert ELF to ROM...

set abuild_rom=!abuild_output!\!abuild_short_name!.rom
set abuild_cmd=avr-objcopy -O srec -R .eeprom !abuild_elf! !abuild_rom!
!abuild_report! !abuild_cmd!
!abuild_cmd!
if not exist !abuild_rom! (goto end)
echo.abuild.bat: Successfully built !abuild_rom!

REM     Convert ELF to HEX...

set abuild_hex=!abuild_output!\!abuild_short_name!.hex
set abuild_cmd=avr-objcopy -O ihex -R .flash !abuild_elf! !abuild_hex!
!abuild_report! !abuild_cmd!
!abuild_cmd!
if not exist !abuild_hex! (goto end)
echo.abuild.bat: Successfully built !abuild_hex!

REM     Display binary size...
avr-size !abuild_hex!

REM ---------------------------------------------------------------------------

if not !abuild_upload! == true (
    goto success
)

:get_choice

echo.
if not !abuild_promptForUpload! == true (
    echo.abuild.bat: Uploading sketch...
    call aupload.bat !abuild_hex!
    if not !errorlevel! == 0 (
        echo.*** ERROR uploading ***
        goto end
    )
    goto success
)

echo.[Remember to reset your board right before uploading.]
echo.Enter the first character of your choice...
set abuild_choice=
set /p abuild_choice=Upload, Quit? 

if /i "!abuild_choice!" == "q" (
    goto success
)

if /i "!abuild_choice!" == "u" (
    call aupload.bat !abuild_hex!
    if not !errorlevel! == 0 (goto get_choice)
    goto success
)

echo.*** Invalid choice ***
goto get_choice


REM ---------------------------------------------------------------------------
REM     Getting here means everything completed successfully...
:success
set abuild_retcode=0
goto end

REM ---------------------------------------------------------------------------

:usage
echo.
echo.abuild.bat  -  Arduino command-line build for Windows.
echo.
echo.Usage:
echo.
echo.    abuild [options] sketchname
echo.
echo.where sketchname is the name of your sketch, 
echo.e.g. MySketch.cpp or MySketch.pde.
echo.This batch file will do minor preprocessing to sketches
echo.ending with .pde, such as including Arduino.h and inserting
echo.main^(^) code for you.  You may need to modify sketches developed
echo.in the Arduino IDE a little bit to have their own function
echo.prototypes, etc.  Sketches with other extensions will be 
echo.compiled as-is using the C++ compiler.
echo.
echo.Options:
echo.
echo.    -c        Compile only; do not upload
echo.    -r        Force rebuild of runtime library
echo.    -n        Exclude external libraries ^(SoftwareSerial, Stepper,
echo.              LiquidCrystal, etc.^).  Use this if you have no
echo.              dependencies on external libraries and are strapped
echo.              for code size; depending on the libraries you have
echo.              installed, this may help some.
echo.              NOTE: external library support is quite experimental;
echo.              for help, see:
echo.              http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1168127321/all-0
echo.    -o dir    Sets compiler output path to dir.  default = .\obj
echo.    -v        Display verbose messages
echo.    -u        Immediately upload without asking ^(ignored if -c is used^)
echo.
echo.This batch file was released on !abuild_release_date!.
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

REM ---------------------------------------------------------------------------

:end
!abuild_report! exiting with return value !abuild_retcode!
exit /b !abuild_retcode!

REM ---------------------------------------------------------------------------
REM     $Log: abuild.bat,v $
REM     Revision 1.16  2008/09/10 20:05:20  Don.Cross
REM     Based on user request on Arduino forum, added "-u" option to immediately upload without prompting.
REM     Changed rbuild.bat to abuild.bat in echo statements.
REM
REM     Revision 1.15  2008/09/10 10:58:15  Don.Cross
REM     Fixed bug: was not processing command line arguments correctly when -c option was present.
REM
REM     Revision 1.14  2008/09/10 10:57:11  Don.Cross
REM     Updated release date.
REM     Specify exact URL for discussing problems, so users don't have to search for it.
REM
REM     Revision 1.13  2008/09/10 10:49:56  Don.Cross
REM     Modifications for Arduino 0011 by raptorofaxys.
REM     He added support for libraries, with -n option to disable.
REM     He also replaced scanning the Arduino 0007 method of scanning for settings in preferences.txt (broken in 0011)
REM     with user-configured environment variables for all settings.
REM
REM     Revision 1.12  2007/03/09 23:07:24  dcross
REM     Oops!  Forgot to update the release date.  Now made it easier to do in the future.
REM
REM     Revision 1.11  2007/03/09 22:58:17  dcross
REM     Arduino forum member "brunob" found a bug where ARDUINO_PATH contains spaces.
REM     Fixed this batch file to work in that case.
REM
REM     Revision 1.10  2007/01/07 23:43:01  dcross
REM     Oops!  Forgot about the fact that I am testing with my library patch, not original distribution.
REM     Now fixed to work with both.
REM
REM     Revision 1.9  2007/01/07 22:53:53  dcross
REM     Usage text now displays link to where to get latest version on Arduino Playground.
REM     Also displays its own release date so user can tell whether what he has is up-to-date.
REM
REM     Revision 1.8  2007/01/07 22:31:08  dcross
REM     Now call agetpref.bat to get Arduino preferences, instead of having hardcoded options.
REM
REM     Revision 1.7  2007/01/07 21:40:55  dcross
REM     Improved upload step by allowing user to either Upload or Quit.
REM     If upload is selected, and fails, we loop back and allow user to try again.
REM
REM     Revision 1.6  2007/01/06 23:15:50  dcross
REM     Now prompt to upload the sketch after compiling and linking successfully,
REM     unless -c is specified on the command line.
REM
REM     Revision 1.5  2007/01/06 22:23:20  dcross
REM     Now define C/C++ preprocessor symbol ABUILD_BATCH so that sketches can easily be made
REM     to work in both the IDE and in the command line.
REM
REM     Revision 1.4  2007/01/06 21:35:29  dcross
REM     Now call avr-size to display binary size.
REM
REM     Revision 1.3  2007/01/06 21:31:37  dcross
REM     Discovered that if you run the IDE after running abuild.bat, the presence of an extra .cpp file
REM     confuses the IDE into thinking you have added a new module, causing both files to be compiled
REM     and linked... resulting in lots of linker errors!  Now generate preprocessed .cpp file in the obj subdirectory.
REM
REM     Revision 1.2  2007/01/06 17:22:51  dcross
REM     Good news!  It looks like we will be able to get rid of the icky link_order file.
REM     It turns out that we can put all the .o object files into a single .a library file, in
REM     which case the order appears to be irrelevant.
REM     Still need to port this over to the IDE java code.
REM
REM     Revision 1.1  2007/01/05 22:34:27  dcross
REM     First version... seems to work for building ROM and HEX files, but I don't yet know how to
REM     upload and test them on a real microcontroller board.
REM
