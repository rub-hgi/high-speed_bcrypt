#!/usr/bin/python3
# coding: utf-8
from helper import *
from os import urandom
import init_state

dbug_foo = False


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


def expandKey(salt=0, key=0, debug=False, desc="Exp ():"):
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
    if debug:
        printState(s0, s1, s2, s3, p, desc)


def encrypt(ctext):
    def round(i, j, n):
        return ((i ^ f(j) ^ p[n]) << 32) | j

    def f(z):
        a = z >> 24 & 0xff
        b = z >> 16 & 0xff
        c = z >> 8 & 0xff
        d = z & 0xff
        return ((((s0[a] + s1[b]) & 0xffffffff) ^ s2[c]) + s3[d]) & 0xffffffff

    global dbug_foo
    if dbug_foo:
        print("in ", hex(ctext))

    xl = ctext >> 32
    xr = ctext & 0xffffffff
    xl ^= (p[0])

    for i in range(1, 17, 1):
        c = round(xr, xl, i)
        xl = c >> 32
        xr = c & 0xffffffff
        if dbug_foo:
            print("c ", hex(c))
    c = (xr ^ p[17]) << 32 | (xl)
    xl = c >> 32
    xr = c & 0xffffffff
    return c


def bcrypt(salt, key, cost, debug=False, generate_tv_files=False):
    if debug:
        print("Rounds : %d" % 2**cost)
        print("SaltLen: %d" % len(salt))
        print("Salt   : %s" % " ".join([("%0.2X" % x) for x in salt]))
        print("Key_Len: %d" % len(key))
        print("Key    : %s" % " ".join([("%0.2X" % x) for x in key]))

    salt = bytestring2int(salt)
    key = bytestring2int(cycleKey(key))

    salt_key = (((salt << 128*3) | (salt << 128*2) | (salt << 128)
                 | salt) << 64) | (salt >> 64)
    writeConf(salt, key)

    initState()
    if debug:
        printState(s0, s1, s2, s3, p, "Initstate: ")
    if generate_tv_files:
        writeState(s0, s1, s2, s3, p, "tv_init.txt")

    expandKey(salt, key, debug=debug, desc="Exp (s, k):")
    if generate_tv_files:
        writeState(s0, s1, s2, s3, p, "tv_exp.txt")

#   cost loop
    for i in range(2**cost):
        expandKey(0, key, debug=debug, desc="Exp (k):")
        expandKey(0, salt_key, debug=debug, desc="Exp (s):")
    if generate_tv_files:
        writeState(s0, s1, s2, s3, p, "tv_cost.txt")

#   encryption
    global dbug_foo
    print("start encrypt")
    dbug_foo = True
    ctext2 = 0x4f72706865616e42
    ctext1 = 0x65686f6c64657253
    ctext0 = 0x637279446f756274
    for i in range(64):
        ctext2 = encrypt(ctext2)
        ctext1 = encrypt(ctext1)
        ctext0 = encrypt(ctext0)

#   return hash
    salt = int2bytestring(salt, 16)
    ctext = int2bytestring((ctext2 << 128) | (ctext1 << 64) | ctext0, 24)
    value = ("%0.8x%0.8x%0.8x%0.8x%0.8x%0.8x" %
            (ctext2 >> 32, ctext2 & 0xffffffff,
             ctext1 >> 32, ctext1 & 0xffffffff,
             ctext0 >> 32, ctext0 & 0xffffffff))
    result = ("$2a$%0.2d$%s%s" %
             (cost, encode_base64(salt, 16), encode_base64(ctext, 23)))
    if generate_tv_files:
        tv_enc_f = open("tv_enc.txt", "w")
        print("-- Format:\n-- 192 Bit Testvector", file=tv_enc_f)
        print(value, file=tv_enc_f)
        tv_enc_f.close()

    return result


def gensalt(log_rounds=2):
    prefix = "$2a${0:02}$".format(log_rounds)
    salt = encode_base64(urandom(16), 16)
    return prefix+salt


def test():
    print("running doctests")
    count = 0
    for tv in test_vectors:
        cost = int(tv[1][4:6])
        salt = decode_base64(tv[1][7:], 22)
        key = bytes(tv[0]+'\x00', "utf-8")
        expected = tv[2]
        h = bcrypt(salt, key, cost, debug=False, generate_tv_files=False)
        try:
            assert(h == expected)
            count += 1
        except AssertionError:
            print("got\n%s\nexpected\n%s" % (h, expected))
    print("%d tests succeeded" % count)


def gen_tv(encoded_salt, key):
    cost = 0  # int(encoded_salt[4:6])
    salt = b"\xce\x33\x5f\xbf\x78\x49\x59\xc7\x81\x33\x2a\x5d\x8d\xcd\x25\x35"
      # decode_base64(encoded_salt[7:], 22)
    key = bytes(key + '\x00', "utf-8")
    cycledKey = cycleKey(key)
    print("generating test vector files for VHDL testbench")
    print("encoded salt: %s" % encoded_salt)
    print("cost: %d" % cost)
    print("salt: 0x%x" % int.from_bytes(salt, byteorder='big'))
    print("key: 0x%x" % int.from_bytes(cycledKey, byteorder='big'))
    print("...")
    result = bcrypt(salt, key, cost, debug=True, generate_tv_files=True)
    print("%s" % result)
    print("hash: 0x%0.47xXX" % bytestring2int(decode_base64(result[29:], 32)))
    print("finished")


def main():
    #test()
    #salt = "$2a$02$dnQY/8g/fqXHs8qIjyBD2."
    gen_tv(gensalt(1), "\x62")
    #salt = bcrypt.gensalt(2)
    #crypted = bcrypt.hashpw('', salt)
    #crypted2 = bcrypt.hashpw('', crypted)
    #self.assertEqual(crypted, crypted2)


p = []
s0 = []
s1 = []
s2 = []
s3 = []

test_vectors = [
    ['', '$2a$06$DCq7YPn5Rq63x1Lad4cll.',
     '$2a$06$DCq7YPn5Rq63x1Lad4cll.TV4S6ytwfsfvkgY8jIucDrjc8deX1s.'],
    ['', '$2a$08$HqWuK6/Ng6sg9gQzbLrgb.',
     '$2a$08$HqWuK6/Ng6sg9gQzbLrgb.Tl.ZHfXLhvt/SgVyWhQqgqcZ7ZuUtye'],
    ['', '$2a$10$k1wbIrmNyFAPwPVPSVa/ze',
     '$2a$10$k1wbIrmNyFAPwPVPSVa/zecw2BCEnBwVS2GbrmgzxFUOqW9dk4TCW'],
    ['', '$2a$12$k42ZFHFWqBp3vWli.nIn8u',
     '$2a$12$k42ZFHFWqBp3vWli.nIn8uYyIkbvYRvodzbfbK18SSsY.CsIQPlxO'],
    ['a', '$2a$06$m0CrhHm10qJ3lXRY.5zDGO',
     '$2a$06$m0CrhHm10qJ3lXRY.5zDGO3rS2KdeeWLuGmsfGlMfOxih58VYVfxe'],
    ['a', '$2a$08$cfcvVd2aQ8CMvoMpP2EBfe',
     '$2a$08$cfcvVd2aQ8CMvoMpP2EBfeodLEkkFJ9umNEfPD18.hUF62qqlC/V.'],
    ['a', '$2a$10$k87L/MF28Q673VKh8/cPi.',
     '$2a$10$k87L/MF28Q673VKh8/cPi.SUl7MU/rWuSiIDDFayrKk/1tBsSQu4u'],
    ['a', '$2a$12$8NJH3LsPrANStV6XtBakCe',
     '$2a$12$8NJH3LsPrANStV6XtBakCez0cKHXVxmvxIlcz785vxAIZrihHZpeS'],
    ['abc', '$2a$06$If6bvum7DFjUnE9p2uDeDu',
     '$2a$06$If6bvum7DFjUnE9p2uDeDu0YHzrHM6tf.iqN8.yx.jNN1ILEf7h0i'],
    ['abc', '$2a$08$Ro0CUfOqk6cXEKf3dyaM7O',
     '$2a$08$Ro0CUfOqk6cXEKf3dyaM7OhSCvnwM9s4wIX9JeLapehKK5YdLxKcm'],
    ['abc', '$2a$10$WvvTPHKwdBJ3uk0Z37EMR.',
     '$2a$10$WvvTPHKwdBJ3uk0Z37EMR.hLA2W6N9AEBhEgrAOljy2Ae5MtaSIUi'],
    ['abc', '$2a$12$EXRkfkdmXn2gzds2SSitu.',
     '$2a$12$EXRkfkdmXn2gzds2SSitu.MW9.gAVqa9eLS1//RYtYCmB1eLHg.9q'],
    ['abcdefghijklmnopqrstuvwxyz', '$2a$06$.rCVZVOThsIa97pEDOxvGu',
     '$2a$06$.rCVZVOThsIa97pEDOxvGuRRgzG64bvtJ0938xuqzv18d3ZpQhstC'],
    ['abcdefghijklmnopqrstuvwxyz', '$2a$08$aTsUwsyowQuzRrDqFflhge',
     '$2a$08$aTsUwsyowQuzRrDqFflhgekJ8d9/7Z3GV3UcgvzQW3J5zMyrTvlz.'],
    ['abcdefghijklmnopqrstuvwxyz', '$2a$10$fVH8e28OQRj9tqiDXs1e1u',
     '$2a$10$fVH8e28OQRj9tqiDXs1e1uxpsjN0c7II7YPKXua2NAKYvM6iQk7dq'],
    ['abcdefghijklmnopqrstuvwxyz', '$2a$12$D4G5f18o7aMMfwasBL7Gpu',
     '$2a$12$D4G5f18o7aMMfwasBL7GpuQWuP3pkrZrOAnqP.bmezbMng.QwJ/pG'],
    ['~!@#$%^&*()      ~!@#$%^&*()PNBFRD', '$2a$06$fPIsBO8qRqkjj273rfaOI.',
     '$2a$06$fPIsBO8qRqkjj273rfaOI.HtSV9jLDpTbZn782DC6/t7qT67P6FfO'],
    ['~!@#$%^&*()      ~!@#$%^&*()PNBFRD', '$2a$08$Eq2r4G/76Wv39MzSX262hu',
     '$2a$08$Eq2r4G/76Wv39MzSX262huzPz612MZiYHVUJe/OcOql2jo4.9UxTW'],
    ['~!@#$%^&*()      ~!@#$%^&*()PNBFRD', '$2a$10$LgfYWkbzEvQ4JakH7rOvHe',
     '$2a$10$LgfYWkbzEvQ4JakH7rOvHe0y8pHKF9OaFgwUZ2q7W2FFZmZzJYlfS'],
    ['~!@#$%^&*()      ~!@#$%^&*()PNBFRD', '$2a$12$WApznUOJfkEGSmYRfnkrPO',
     '$2a$12$WApznUOJfkEGSmYRfnkrPOr466oFDCaj4b6HY3EXGvfxm43seyhgC']
]


if __name__ == "__main__":
    main()
