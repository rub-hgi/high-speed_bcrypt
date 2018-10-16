-------------------------------------------------------------------------------
-- Title       : pkg_bcrypt - behavioral
-- Project     : bcrypt bruteforce
-------------------------------------------------------------------------------
-- File        : pkg_bcrypt.vhd
-- Author      : Friedrich Wiemer  <friedrich.wiemer@rub.de>
-- Company     : Ruhr-University Bochum
-- Created     : 2014-03-05
-- Last update : 2014-04-09
-- Platform    : Xilinx Toolchain
-- Standard    : VHDL'93/02
-------------------------------------------------------------------------------
-- Description : package for bcrypt constants
-------------------------------------------------------------------------------
-- Copyright (c) 2010-2014 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions   :
-- Date         Version  Author  Description
-- 2014-03-04   0.1      fwi     created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.rzi_helper.all;

package pkg_bcrypt is
    -- --------------------------------------------------------------------- --
    -- Constants
    -- --------------------------------------------------------------------- --
    constant INIT_PIPELINE  : positive := 2;   -- needs to be bigger than 1
    constant CORE_INSTANCES : positive := 10;
    constant COST : integer := 0;
    constant COST_LENGTH : integer := 5;
    constant  PWD_LENGTH : integer := 8;--18;   -- maximal length of pwd to bf
    constant  PWD_BITLEN : integer := getBitSize(PWD_LENGTH);
    constant CHARSET_LEN : integer := 63;   -- 26 (lower case) + null byte
    constant CHARSET_BIT : integer := getBitSize(CHARSET_LEN);
    -- bitsize for charset + overflow
    constant CHARSET_OF_BIT : integer := getBitSize(CHARSET_LEN+1);

    constant SALT_LENGTH : integer := 128;  -- 16 bytes
    constant HASH_LENGTH : integer := 192;  -- 24 bytes
    constant  KEY_LENGTH : integer := 576;  -- 72 bytes
    constant MAGIC_VALUE : std_logic_vector(191 downto 0) := x"4f727068_65616e42_65686f6c" &
                                               x"64657253_63727944_6f756274";
    -- --------------------------------------------------------------------- --
    -- Types
    -- --------------------------------------------------------------------- --
    type debug_signals_t is record
        fin_init       : std_logic;
        fin_expand_key : std_logic;
        fin_cost_loop  : std_logic;
        fin_encryption : std_logic;
    end record;
    type salt_ary_t is array (integer range <>) of
        std_logic_vector(SALT_LENGTH-1 downto 0);
    type  key_ary_t is array (integer range <>) of
        std_logic_vector( KEY_LENGTH-1 downto 0);
    type hash_ary_t is array (integer range <>) of
        std_logic_vector(HASH_LENGTH-1 downto 0);
    type slv5_ary_t is array (integer range <>) of
        std_logic_vector (4 downto 0);
    type slv8_ary_t is array (integer range <>) of
        std_logic_vector (7 downto 0);
    type slv32_ary_t is array (integer range <>) of
        std_logic_vector (31 downto 0);
    type slv64_ary_t is array (integer range <>) of
        std_logic_vector (63 downto 0);
    type pwd_initial_t is record
        counter_init : std_logic_vector(PWD_LENGTH*CHARSET_OF_BIT-1 downto 0);
        initial_length : integer range 0 to PWD_LENGTH;
    end record;
    -- --------------------------------------------------------------------- --
    -- Functions
    -- --------------------------------------------------------------------- --
    function or_reduce (slv : in std_logic_vector) return std_logic;
    function and_reduce(slv : in std_logic_vector) return std_logic;
    -- reduce function takes array of keys, and's every key with
    -- appropriate success value and or reduces the keys into one key
    -- assuming one successful core, this results in returning only the
    -- successful key candidate, while masking out every other key candidate
    function reduce_slv5(ary : in slv5_ary_t; success : in std_logic_vector)
    return std_logic_vector;
    function reduce_slv32(ary : in slv32_ary_t; success : in std_logic_vector)
    return std_logic_vector;
    function generate_init_vector(index : in integer) return std_logic_vector;
    function generate_init_length(index : in integer) return integer;
    function pass_to_crack(c_len : integer) return integer;

end package pkg_bcrypt;

package body pkg_bcrypt is
    function or_reduce(slv : in std_logic_vector) return std_logic is
        variable r_or : std_logic;
    begin
        r_or := slv(0);
        for i in 1 to slv'length-1 loop
            r_or := r_or or slv(i);
        end loop;
        return r_or;
    end;

    function and_reduce(slv : in std_logic_vector) return std_logic is
        variable r_and : std_logic;
    begin
        r_and := slv(0);
        for i in 1 to slv'length-1 loop
            r_and := r_and and slv(i);
        end loop;
        return r_and;
    end;

    function reduce_slv5(ary : in slv5_ary_t; success : in std_logic_vector)
    return std_logic_vector is
        variable r_slv : std_logic_vector (4 downto 0);
    begin
        r_slv := ary(0) and (4 downto 0 => success(0));
        for i in 1 to ary'length-1 loop
            r_slv := r_slv or (ary(i) and (4 downto 0 => success(i)));
        end loop;
        return r_slv;
    end;

    function reduce_slv32(ary : in slv32_ary_t; success : in std_logic_vector)
    return std_logic_vector is
        variable r_slv : std_logic_vector (31 downto 0);
    begin
        r_slv := ary(0) and (31 downto 0 => success(0));
        for i in 1 to ary'length-1 loop
            r_slv := r_slv or (ary(i) and (31 downto 0 => success(i)));
        end loop;
        return r_slv;
    end;

    function generate_init_vector(index : in integer)
    return std_logic_vector is
        file     vectors_f  : text open read_mode is "init_vectors.txt";
        variable rLineIV    : line;
        variable good       : boolean;
        variable i          : integer := 0;
        variable rIV : std_logic_vector (PWD_LENGTH*CHARSET_OF_BIT-1 downto 0);
    begin
        i := 0;
        read_loop : while (not endfile(vectors_f) and i <= index) loop
            readline(vectors_f, rLineIV);
            if (i = index) then
                read(rLineIV, rIV, good => good);
                assert (good)
                report "Invalid iv format"
                severity failure;
            end if;
            i := i+1;
        end loop read_loop;
        return rIV;
    end;

    function generate_init_length(index : in integer)
    return integer is
        file     lengths_f  : text open read_mode is "init_lengths.txt";
        variable rLineLen   : line;
        variable good       : boolean;
        variable i          : integer := 0;
        variable rLength    : std_logic_vector(4 downto 0);
    begin
        i := 0;
        read_loop : while (not endfile(lengths_f) and i <= index) loop
            readline(lengths_f, rLineLen);
            if (i = index) then
                read(rLineLen, rLength, good => good);
                assert (good)
                report "Invalid length format"
                severity failure;
            end if;
            i := i+1;
        end loop read_loop;
        return to_integer(unsigned(rLength));
    end;

    function pass_to_crack(c_len : integer) return integer is
        variable overall_password_number : integer;
    begin
        -- compute overall number of passwords
        -- and passwords per core
        overall_password_number := 0;
        for i in 1 to PWD_LENGTH loop
            overall_password_number := overall_password_number+c_len**i;
        end loop;
        return overall_password_number;
    end;

end package body pkg_bcrypt;
