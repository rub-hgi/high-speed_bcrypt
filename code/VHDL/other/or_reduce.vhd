-------------------------------------------------------------------------------
-- Title      : or_reduce Topmodule
-- Project    :
-- ----------------------------------------------------------------------------
-- File       : bcrypt.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-04-06
-- Last update: 2014-04-06
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description:
--      compares synthesis results for or_reduce implementations
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-04-06  1.0      fwi     Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity or_reduce is
    generic (
        WIDTH   : positive := 128;
        USELOOP : boolean  := false
    );
    port (
        din     : in  std_logic_vector(WIDTH-1 downto 0);
        dout    : out std_logic
    );
end or_reduce;

architecture Behavioral of or_reduce is
    signal a    : std_logic_vector(21 downto 0);
    signal b    : std_logic_vector( 2 downto 0);
    signal c    : std_logic;
begin
    -- loop
    loop_gen : if USELOOP generate
        or_reduce_proc : process(din)
            variable result : std_logic;
        begin
            result := din(0);
            for i in 1 to din'length-1 loop
                result := result or din(i);
            end loop;
            dout <= result;
        end process or_reduce_proc;
    end generate loop_gen;

    -- handcrafted
    hand_gen : if not(USELOOP) generate
   a( 0)<=din(  0) or din(  1) or din(  2) or din(  3) or din(  4) or din(  5);
   a( 1)<=din(  6) or din(  7) or din(  8) or din(  9) or din( 10) or din( 11);
   a( 2)<=din( 12) or din( 13) or din( 14) or din( 15) or din( 16) or din( 17);
   a( 3)<=din( 18) or din( 19) or din( 20) or din( 21) or din( 22) or din( 23);
   a( 4)<=din( 24) or din( 25) or din( 26) or din( 27) or din( 28) or din( 29);
   a( 5)<=din( 30) or din( 31) or din( 32) or din( 33) or din( 34) or din( 35);
   a( 6)<=din( 36) or din( 37) or din( 38) or din( 39) or din( 40) or din( 41);
   a( 7)<=din( 42) or din( 43) or din( 44) or din( 45) or din( 46) or din( 47);
   a( 8)<=din( 48) or din( 49) or din( 50) or din( 51) or din( 52) or din( 53);
   a( 9)<=din( 54) or din( 55) or din( 56) or din( 57) or din( 58) or din( 59);
   a(10)<=din( 60) or din( 61) or din( 62) or din( 63) or din( 64) or din( 65);
   a(11)<=din( 66) or din( 67) or din( 68) or din( 69) or din( 70) or din( 71);
   a(12)<=din( 72) or din( 73) or din( 74) or din( 75) or din( 76) or din( 77);
   a(13)<=din( 78) or din( 79) or din( 80) or din( 81) or din( 82) or din( 83);
   a(14)<=din( 84) or din( 85) or din( 86) or din( 87) or din( 88) or din( 89);
   a(15)<=din( 90) or din( 91) or din( 92) or din( 93) or din( 94) or din( 95);
   a(16)<=din( 96) or din( 97) or din( 98) or din( 99) or din(100) or din(101);
   a(17)<=din(102) or din(103) or din(104) or din(105) or din(106) or din(107);
   a(18)<=din(108) or din(109) or din(110) or din(111) or din(112) or din(113);
   a(19)<=din(114) or din(115) or din(116) or din(117) or din(118) or din(119);
   a(20)<=din(120) or din(121) or din(122) or din(123) or din(124) or din(125);
   b( 0)<=  a(  0) or   a(  1) or   a(  2) or   a(  3) or   a(  4) or   a(  5);
   b( 1)<=  a(  6) or   a(  7) or   a(  8) or   a(  9) or   a( 10) or   a( 11);
   b( 2)<=  a( 12) or   a( 13) or   a( 14) or   a( 15) or   a( 16) or   a( 17);
   c    <=din(126) or din(127) or   a( 18) or   a( 19) or   a( 20) or   b(  0);
   dout <=  b(  1) or   b(  2) or   c;
    end generate hand_gen;

end architecture Behavioral;
