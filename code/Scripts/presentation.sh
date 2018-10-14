#!/bin/bash
echo "$ hexdump -C -v -n64 /dev/xillybus_mem_8"
read foo
hexdump -C -v -n64 /dev/xillybus_mem_8

echo ""
echo "$ time c_if test/COST2_KEYabc.bin"
read foo
time c_if test/COST2_KEYabc.bin

echo ""
echo "$ hexdump -C -v -n64 /dev/xillybus_mem_8"
read foo
hexdump -C -v -n64 /dev/xillybus_mem_8

echo ""
echo "$ time c_if test/COST2_KEYxxx.bin" 
read foo
time c_if test/COST2_KEYxxx.bin

echo ""
echo "$ hexdump -C -v -n64 /dev/xillybus_mem_8"
read foo
hexdump -C -v -n64 /dev/xillybus_mem_8

