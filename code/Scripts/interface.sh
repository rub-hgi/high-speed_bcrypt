#!/bin/bash
PATH=/root/bin:$PATH

#SALT=(224 197  64 151  10 235 187  73
#      198 134 129 232   7 154 148 126)
SALT=(147 74 61 48 153 200 230 117 138 17 75 138 245 70 153 145)
#HASH=( 78 201 242  62  32 145  97  89
#       59 197  86  15 181 110 162 254
#      217 248 203 148  60 250 130  90)
HASH=(9 125 2 103 156 47 214 42 210 3 153 151 75 101 131 84 218 200 172 104 117 134 251 89)

# reset bcrypt core
memwrite /dev/xillybus_mem_8 63 1

for i in $(seq 0 1 15)
do
    s=${SALT[$i]}
    memwrite /dev/xillybus_mem_8 $i $s
done

for i in $(seq 16 1 39)
do
    h=${HASH[`expr $i - 16`]}
    memwrite /dev/xillybus_mem_8 $i $h
done

# start bcrypt core
memwrite /dev/xillybus_mem_8 63 2

# read bcrypt results
hexdump -C -v -n 64 /dev/xillybus_mem_8