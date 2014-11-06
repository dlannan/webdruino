set "ARDUINO_PATH=C:\Program Files (x86)\Arduino"
set ARDUINO_MCU=atmega328p
set ARDUINO_PROGRAMMER=stk500
set ARDUINO_FCPU=16000000
set ARDUINO_COMPORT=COM5
set ARDUINO_BURNRATE=19200
abuild.bat -r -u arduino_app.pde
