#!/usr/bin/python
from math import ceil, log

PWD_LENGTH = 8  # 18
CHARSET_LEN = 63
CHARSET_OF_BIT = ceil(log(CHARSET_LEN+1, 2))
NUMBER_OF_QUADCORES = 10


def pwds(cores, c_len, max_len):
    overall_pwd = sum([c_len**i for i in range(1, max_len+1)])
    per_core = overall_pwd // cores
    return (overall_pwd, per_core)


def init_length(cores, pass_core, c_len):
    return [1]+[ceil(log(i*pass_core, c_len)) for i in range(1, cores)]


def init_vector_core(i_len, c_len, ppcore, max_pass, offset):
    iv = []
    rest_pwds = offset-sum([c_len**i for i in range(1, i_len)])
    for i in range(i_len-1, -1, -1):
        x = rest_pwds // (c_len**i)
        rest_pwds = rest_pwds % (c_len**i)
        iv.append(x)
    while len(iv) < max_pass:
        iv = [0]+iv
    return iv


def init_vector(cores, index, c_len, ppcore, max_pass, init_len):
    offset = index*ppcore
    iv = init_vector_core(init_len, c_len, ppcore, max_pass, offset)
    return iv


overall_pwd, pass_per_core = pwds(NUMBER_OF_QUADCORES, CHARSET_LEN, PWD_LENGTH)

init_len = init_length(NUMBER_OF_QUADCORES, pass_per_core, CHARSET_LEN)

init_vect = [init_vector(NUMBER_OF_QUADCORES, i, CHARSET_LEN,
                         pass_per_core, PWD_LENGTH, init_len[i])
             for i in range(NUMBER_OF_QUADCORES)]

print("overall passwords to crack\t{}".format(overall_pwd))
print("passwords per core to crack\t{}".format(pass_per_core))
print("initial passwords length\t{}".format(init_len))
print("initial vector for cores\t")
for i in init_vect:
    print("\t{}".format(i))
print("Bitlen of Charset+overflow\t{}".format(CHARSET_OF_BIT))
print("Overall length of init vect\t{}".format(CHARSET_OF_BIT*PWD_LENGTH))

print("\nWriting initial lengths to file")
with open("init_lengths.txt", "wb") as f:
    for i in init_len:
        out_str = "{:05b}\n".format(i)
        f.write(bytes(out_str, "UTF-8"))

print("\nWriting initial vectors to file")
with open("init_vectors.txt", "wb") as f:
    for i in init_vect:
        out_str = "\n"
        for j in i:
            fmt_str = "{{:0{}b}}".format(CHARSET_OF_BIT)
            out_str = fmt_str.format(j) + out_str
        f.write(bytes(out_str, "UTF-8"))

bleh = {0: "_", 1: "a", 2: "b",
        3: "c", 4: "d", 5: "e",
        6: "f", 7: "g", 8: "h",
        9: "i", 10: "j", 11: "k",
        12: "l", 13: "m", 14: "n",
        15: "o", 16: "p", 17: "q",
        18: "r", 19: "s", 20: "t",
        21: "u", 22: "v", 23: "w",
        24: "x", 25: "y", 26: "z"}

#print("Start with pwd:")
#for i in init_vect:
#    print("\t"+"".join([bleh[j] for j in i]))
