#!/usr/bin/python
# coding: utf-8
from __future__ import print_function
from itertools import repeat

B64C = ("./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")


def cycleKey(x):
    len_x = len(x)
    return bytes(x*(72 // len_x) + x[:72 % len_x])


def encode_base64(data, length):
    p = list(data)
    i = 0
    result = ""
    while i < length:
        c1 = p[i]
        i += 1
        result += B64C[c1 >> 2]
        c1 = (c1 & 0x03) << 4
        if i >= length:
            result += B64C[c1]
            break

        c2 = p[i]
        i += 1
        c1 |= (c2 >> 4) & 0x0f
        result += B64C[c1]
        c1 = (c2 & 0x0f) << 2
        if i >= length:
            result += B64C[c1]
            break

        c2 = p[i]
        i += 1
        c1 |= (c2 >> 6) & 0x03
        result += B64C[c1]
        result += B64C[c2 & 0x3f]
    return result


def decode_base64(data, length):
    def C64(x):
        index_64 = [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x01, 0x36, 0x37,
                    0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0xff, 0xff,
                    0xff, 0xff, 0xff, 0xff, 0xff, 0x02, 0x03, 0x04, 0x05, 0x06,
                    0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
                    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a,
                    0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x1c, 0x1d, 0x1e,
                    0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28,
                    0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32,
                    0x33, 0x34, 0x35, 0xff, 0xff, 0xff, 0xff, 0xff]
        if x > 127:
            return 0xff
        else:
            return index_64[x]
    pad_len = 4-(length % 4)
    p = list(map(ord, data))+[0 for i in range(pad_len)]
    result = []
    while len(p) > 0:
        c1 = C64(p[0])

        c2 = C64(p[1])
        if (c1 == 255) or (c2 == 255):
            break
        result.append((c1 << 2) | ((c2 & 0x30) >> 4))

        c3 = C64(p[2])
        if (c3 == 255):
            break
        result.append(((c2 & 0x0f) << 4) | ((c3 & 0x3c) >> 2))

        c4 = C64(p[3])
        if (c4 == 255):
            break
        result.append(((c3 & 0x03) << 6) | c4)
        p = p[4:]
    return bytes(result[:len(data)-pad_len])


def int2bytestring(data, length):
    i = length-1
    result = []
    while i >= 0:
        result.append((data >> (8*i)) & 0xff)
        i -= 1
    return bytes(result)


def bytestring2int(bs):
    result = int.from_bytes(bs, byteorder='big')
    return result


def printState(s0, s1, s2, s3, p, desc):
    print("---------------------------------------" +
          "---------------------------------------")
    print(desc)
    print("---------------------------------------" +
          "---------------------------------------")
    r = 16
    print("SBox[0]:")
    [print(" ".join(["%0.8X" % s0[i*r+j]for j in range(r)]))for i in range(r)]
    print("SBox[1]:")
    [print(" ".join(["%0.8X" % s1[i*r+j]for j in range(r)]))for i in range(r)]
    print("SBox[2]:")
    [print(" ".join(["%0.8X" % s2[i*r+j]for j in range(r)]))for i in range(r)]
    print("SBox[3]:")
    [print(" ".join(["%0.8X" % s3[i*r+j]for j in range(r)]))for i in range(r)]
    [print("SKey[%0.2d]: %0.8X" % (i, p[i])) for i in range(18)]


def writeConf(salt, key):
    tv_conf_f = open("tv_conf.txt", "w")
    tv_conf = "%0.32x\n%0.144x" % (salt, key)
    print(tv_conf, file=tv_conf_f)
    tv_conf_f.close()


def writeState(s0, s1, s2, s3, p, filename):
    tv_f = open(filename, "w")
    pad = repeat("00")
    int2hexstr = lambda x: "%0.8x" % x
    p_ = list(map(int2hexstr, p)) + list(repeat("00000000", 238))
    s3_ = map(int2hexstr, s3)
    s2_ = map(int2hexstr, s2)
    s1_ = map(int2hexstr, s1)
    s0_ = map(int2hexstr, s0)
    zipped = zip(p_, pad, s3_, pad, s2_, pad, s1_, pad, s0_)
    tvs = ""
    for tpl in zipped:
        tv = tpl[0]+tpl[1]+tpl[2]+tpl[3]+tpl[4]+tpl[5]+tpl[6]+tpl[7]+tpl[8]
        tvs += "\n"+tv
    print("-- Format:\n-- 192 Bit Testvector%s" % tvs, file=tv_f)
    tv_f.close()
