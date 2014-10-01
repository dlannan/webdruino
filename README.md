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

---------------------------------------------------------------------------------------------------------------------
The MIT License (MIT)

Copyright (c) <year> <copyright holders>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
