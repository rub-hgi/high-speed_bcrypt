#ifndef _C_INTERFACE_H_
#define _C_INTERFACE_H_

#define SALT_ADDR 0x00
#define HASH_ADDR 0x10
#define PASS_ADDR 0x28
#define SREG_ADDR 0x3f

#define SALT_LEN  16
#define HASH_LEN  24
#define PASS_LEN  20
#define SREG_LEN   1

#define SREG_RESET 0x01
#define SREG_START 0x02
#define SREG_DONE  0x10
#define SREG_SUCC  0x20

#define BCRYPT_VERSION '2'
#define BCRYPT_MAXSALT 16
#define BCRYPT_MAXHASH 24

void reset_logic();
void start_logic();
void stop_logic();
void setup_logic(u_int8_t *, u_int8_t *);

void poll_sreg(u_int8_t);
int  test_sreg(u_int8_t);

void print_pwd();

#endif /* _C_INTERFACE_H_ */
