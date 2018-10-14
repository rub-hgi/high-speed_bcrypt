#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <inttypes.h>

#include "xillybus.h"
#include "c_if.h"

int fd;

int main(int argc, char *argv[]) {
    u_int8_t salt[BCRYPT_MAXSALT];
    u_int8_t hash[BCRYPT_MAXHASH];

    fd = open("/dev/xillybus_mem_8", O_RDWR);
    if (fd < 0) {
        perror("Failed to open /dev/xillybus_mem_8");
        exit(1);
    }

    if (argc < 2) {
        printf("geeeeve salt.bin\n");
        exit(1);
    }
    parseFile(salt, hash, argv[1]);

    reset_logic();
    setup_logic(salt, hash);
    start_logic();
    poll_sreg(SREG_DONE);
    if (test_sreg(SREG_SUCC)) {
        stop_logic();
        print_pwd();
    }
    if (close(fd) != 0) {
        perror("Failed to close /dev/xillybus_mem_8");
        exit(1);
    }
    return 0;
}

void reset_logic() {
    u_int8_t reg = 0x01;
    write_to_fpga(fd, SREG_ADDR, &reg, SREG_LEN);
}

void start_logic() {
    u_int8_t reg = 0x02;
    write_to_fpga(fd, SREG_ADDR, &reg, SREG_LEN);
}

void stop_logic() {
    u_int8_t reg = 0x00;
    write_to_fpga(fd, SREG_ADDR, &reg, SREG_LEN);
}

void setup_logic(u_int8_t *salt, u_int8_t *hash) {
    write_to_fpga(fd, SALT_ADDR, salt, SALT_LEN);
    write_to_fpga(fd, HASH_ADDR, hash, HASH_LEN);
}

void poll_sreg(u_int8_t sreg_bit) {
    while (1) {
        if (test_sreg(sreg_bit))
            break;
    }
}

int test_sreg(u_int8_t sreg_bit) {
    u_int8_t reg;
    read_frm_fpga(fd, SREG_ADDR, &reg, SREG_LEN);
    return reg & sreg_bit;
}

void print_pwd() {
    int i;
    u_int8_t pwd[PASS_LEN+1];
    u_int8_t pwd_r[PASS_LEN+1];

    read_frm_fpga(fd, PASS_ADDR, pwd, PASS_LEN); // read logic

    for (i=0; i<PASS_LEN; i+=4) {
        pwd_r[i+0] = pwd[i+3];
        pwd_r[i+1] = pwd[i+2];
        pwd_r[i+2] = pwd[i+1];
        pwd_r[i+3] = pwd[i+0];
    }
    printf("Found Password: %s\n", pwd_r);
}
