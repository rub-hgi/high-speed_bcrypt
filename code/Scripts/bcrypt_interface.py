#!/usr/bin/python
bcrypt_halt = "\x00"
bcrypt_reset = "\x01"
bcrypt_start = "\x02"
bcrypt_done = "\x10"
bcrypt_succ = "\x20"

addr_salt = 0
addr_hash = 16
addr_pass = 40
addr_sreg = 63

# 'b'
t_salt = ("\xe0\xc5\x40\x97\x0a\xeb\xbb\x49" +
          "\xc6\x86\x81\xe8\x07\x9a\x94\x7e")
t_hash = ("\x4e\xc9\xf2\x3e\x20\x91\x61\x59" +
          "\x3b\xc5\x56\x0f\xb5\x6e\xa2\xfe" +
          "\xd9\xf8\xcb\x94\x3c\xfa\x82\x5a")

# 'abcd'
# salt 91 99 46 f5 8a 4b 11 8a 75 e6 c8 99 30 3d 4a 93
# hash 59 fb 86 75 68 ac c8 da 54 83 65 4b 97 99 03 d2 2a d6 2f 9c 67 02 7d 09


def write_to_logic(fd, addr, data):
    fd.seek(addr)
    fd.write(data)


def read_from_logic(fd, addr, length):
    fd.seek(addr)
    return fd.read(length)


def setup_core(fd, target_salt, target_hash):
    write_to_logic(fd, addr_sreg, bcrypt_reset)
    write_to_logic(fd, addr_salt, target_salt)
    write_to_logic(fd, addr_hash, target_hash)


def main():
    with open('/dev/xillybus_mem_8', 'r+') as fd:
        setup_core(fd, t_salt, t_hash)
        write_to_logic(fd, addr_sreg, bcrypt_start)
        sreg = read_from_logic(fd, addr_sreg, 1)
        pwd = read_from_logic(fd, addr_pass, 10)
    print(hex(int(bytes(sreg))))
    print(pwd)

main()
