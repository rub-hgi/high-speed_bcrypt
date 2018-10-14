#!/usr/bin/python2
# coding: utf-8
from helper import *
from os import urandom
from sys import argv
import init_state


def initState():
    global p
    global s0
    global s1
    global s2
    global s3
    p = list(init_state.p)
    s0 = list(init_state.s0)
    s1 = list(init_state.s1)
    s2 = list(init_state.s2)
    s3 = list(init_state.s3)


def expandKey(salt=0, key=0):
#   key xor
    working_key = key
    i = 0
    while i < 18:
        xor_key = (working_key >> (32*(17-i))) & 0xffffffff
        p[i] = p[i] ^ xor_key
        i += 1
#   setup salt for encryption loop
    salt = (salt & ((1 << 64)-1)) << 64 | (salt >> 64)
    c = salt & ((1 << 64)-1)
#   replace subkeys
    for i in range(0, 18, 2):
        c = encrypt(c)
        p[i] = c >> 32
        p[i+1] = c & 0xffffffff
        salt = (salt & ((1 << 64)-1)) << 64 | (salt >> 64)
        c ^= salt & ((1 << 64)-1)

#   replace sboxs
    k = -1
    for sbox in [s0, s1, s2, s3]:
        k += 1
        for i in range(0, 256, 2):
            c = encrypt(c)
            sbox[i] = c >> 32
            sbox[i+1] = c & 0xffffffff
            salt = (salt & ((1 << 64)-1)) << 64 | (salt >> 64)
            c ^= salt & ((1 << 64)-1)


def encrypt(ctext):
    def round(i, j, n):
        return ((i ^ f(j) ^ p[n]) << 32) | j

    def f(z):
        a = z >> 24 & 0xff
        b = z >> 16 & 0xff
        c = z >> 8 & 0xff
        d = z & 0xff
        return ((((s0[a] + s1[b]) & 0xffffffff) ^ s2[c]) + s3[d]) & 0xffffffff

    xl = ctext >> 32
    xr = ctext & 0xffffffff
    xl ^= (p[0])

    for i in range(1, 17, 1):
        c = round(xr, xl, i)
        xl = c >> 32
        xr = c & 0xffffffff
    c = (xr ^ p[17]) << 32 | (xl)
    xl = c >> 32
    xr = c & 0xffffffff
    return c


def bcrypt(cost, salt_, key_):
    salt = int(salt_.encode("hex"), 16)
    key = int(cycleKey(key_).encode("hex"), 16)

    salt_key = (((salt << 128*3) | (salt << 128*2) | (salt << 128)
                 | salt) << 64) | (salt >> 64)

    initState()
    expandKey(salt, key)
#   cost loop
    for i in range(2**cost):
        expandKey(0, key)
        expandKey(0, salt_key)
#   encryption
    ctext2 = 0x4f72706865616e42
    ctext1 = 0x65686f6c64657253
    ctext0 = 0x637279446f756274
    for i in range(64):
        ctext2 = encrypt(ctext2)
        ctext1 = encrypt(ctext1)
        ctext0 = encrypt(ctext0)
    ctext = (ctext2 << 128) | (ctext1 << 64) | ctext0

#   return hash
    salt = ("%032x" % salt).decode("hex")
    hash_ = ("%048x" % ctext).decode("hex")

    print("Rounds : %d" % 2**cost)
    print("SaltLen: %d" % len(salt_))
    print("Salt   : %s" % salt_.encode("hex"))
    print("KeyLen : %d" % len(key_))
    print("Key    : %s" % key_.encode("hex"))
    print("HashLen: %d" % len(hash_))
    print("Hash   : %s" % hash_.encode("hex"))
    with open("COST"+str(cost)+"_KEY"+key_[:-1]+".bin", "wb") as tv_if:
        tv_if.write(salt_[::-1])
        tv_if.write(hash_[::-1])


def main(cost, pwd):
    salt = "\x91\x99\x46\xf5\x8a\x4b\x11\x8a\x75\xe6\xc8\x99\x30\x3d\x4a\x93"
    salt = "\xce\x33\x5f\xbf\x78\x49\x59\xc7\x81\x33\x2a\x5d\x8d\xcd\x25\x35"
    #bcrypt(cost, urandom(16), pwd+"\x00")
    bcrypt(cost, salt, pwd+"\x00")


p = []
s0 = []
s1 = []
s2 = []
s3 = []

if __name__ == "__main__":
#    if len(argv) < 3:
#        print("usage: %s cost password" % (argv[0]))
#    else:
#        main(cost=int(argv[1]), pwd=argv[2])
    main(1, "b")
