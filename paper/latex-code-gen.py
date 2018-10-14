import math

cycles = lambda cost: 12939+2**(cost+1)*9397
frequency = 100*10**6
coresZB = 10*4
coresV7 = 79*4

print((frequency/cycles(5))*coresZB)
print((frequency/cycles(5))*coresZB/4.2)
print((frequency/cycles(5))*coresV7)
print((frequency/cycles(5))*coresV7/20)
print((frequency/cycles(12))*coresZB)
print((frequency/cycles(12))*coresZB/4.2)
print((frequency/cycles(12))*coresV7)
print((frequency/cycles(12))*coresV7/20)

a = 62 ** 8
name = ["CPU", "GPU", "CPU+GPU", "zedboard", "Virtex7", "Epiphany", "OWzb"]
hashCost5 = [6210, 1920, 6210+1920, (frequency/cycles(5))*coresZB, (frequency/cycles(5))*coresV7, 1207, 4571]
c = [262*1.5, 120*1.5, 382*1.5, 319, 3495, 149, 319]
w = [300, 300, 300, 4.2, 20, 9.1, 6.7]
d = 60 * 60 * 24 * (365/12)
x = [int(math.ceil(a / (d * i))) for i in hashCost5]
fc = [x[i]*c[i] for i in range(len(c))]
pc = [int(math.ceil(
      ((a / (hashCost5[i] * x[i]) / 60 / 60) * (x[i]*w[i]) / 1000) * 0.1008))
      for i in range(len(c))]
bep = []
for i in range(len(c)):
    bla = []
    for j in range(len(c)):
        if i != j:
            bla += [(fc[j] - fc[i]) / (pc[i] - pc[j])]
        else:
            bla += [0]
    bep += [bla]

for i in range(len(c)):
    print("\t\t\\addplot{%d+%d*x}; %%%s" % (fc[i], pc[i], name[i]))

bp = {}
for i in range(len(bep)):
    for j in range(len(bep[i])):
            if bep[i][j] > 0:
                bp[round(bep[i][j], 2)] = round(fc[i] + bep[i][j]*pc[i], 2)

print("\t\t\\addplot+[color=black,only marks,scatter,scatter src=explicit symbolic] coordinates{")
for k in bp:
    print("\t\t\t({}, {}) [a]".format(k, bp[k]))
print("\t\t};")

latex = ""
latex += "\t\t\legend{\n"
for i in range(len(c)):
    latex += "\t\t\t%s,\n" % (name[i])
latex += "\t\t\tbreak-even-points,\n\t\t}"
print(latex)

print("needed devices for brute-force:")
print(x)
# compute values for dictionary attack

print("\n\n dict attack \n\n")

dict_attack = 4*10**9
seconds_per_hour = 60 * 60
seconds_per_day = 60 * 60 * 24 * (365/12)
hashCost12 = [50, 15, 65, (frequency/cycles(12))*coresZB, (frequency/cycles(12))*coresV7, 9.64, 64.83]
x = [int(math.ceil(dict_attack / (seconds_per_day * i))) for i in hashCost12]
fc = [x[i]*c[i] for i in range(len(x))]
pc = [int(math.ceil(
          ((dict_attack / (hashCost12[i] * x[i]) / 60 / 60)
          * (x[i]*w[i]) / 1000) * 0.1008))
      for i in range(len(x))]
bep = []
for i in range(len(x)):
    bla = []
    for j in range(len(x)):
        if i != j:
            if pc[i] - pc[j] != 0:
                bla += [(fc[j] - fc[i]) / (pc[i] - pc[j])]
            else:
                bla += [0]
        else:
            bla += [0]
    bep += [bla]

for i in range(len(x)):
    print("\t\t\\addplot{%d+%d*x}; %% %s" % (fc[i], pc[i], name[i]))

bp = {}
for i in range(len(bep)):
    for j in range(len(bep[i])):
            if bep[i][j] > 0:
                bp[round(bep[i][j], 2)] = round(fc[i] + bep[i][j]*pc[i], 2)

print("\t\t\\addplot+[color=black,only marks,scatter,scatter src=explicit symbolic] coordinates{")
for k in bp:
    print("\t\t\t({}, {}) [a]".format(k, bp[k]))
print("\t\t};")

print("needed devices for dict:")
print(x)
