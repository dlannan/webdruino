webdruino
=========

Web Control of your favourite Arduino device.

![alt text][id]

[id]: /screenshots/WebDruino001.png "Screenshot001"

WARNING: Very early development - not ready for deployment! Use at own risk!

Currently Win32 only working version (Linux and Win64 versions coming)

TODO:
- Digital pins operational
- Configuration for Analog and Digital pin usage.
- Configuration for Arduino type
- Lua programming panel
- Arduino software in Code page
- Bugs and replacement of Poll system (also Network Tcp Server)

Things to be very wary of:
- The Poll system has been gutted - it works, but its missing all the error systems (I had all sorts of issues with it). 
- The implementation currently uses a mish-mash of Network-tcp-server ffi and Lua syscall. 
  I intend to move it all to the lightweight Lua systcall.this is how the original turbo mostly works
  using linux based system calls.
- WebDruino is built for mainly locally serving an Arduino and ITS NOT COMPLETE. Dont expect too much of it to work.

Feel free to get commit request. I hope to have this fully functional in the next week.
