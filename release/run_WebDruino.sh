#!/bin/bash

echo "Running webdruino...."
export LD_LIBRARY_PATH=bin/linux:$LD_LIBRARY_PATH
bin/linux/luajit lua/http-server.lua


