-------------------------------------------------------------------------------
-- Title      : bcrypt - Testbench
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : bcrypt_tb.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
--              Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2013-12-02
-- Last update: 2014-03-24
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description: This module provides a testbench for the bcytp key derivation
--              module with a simulater, i.e., ISIM or ModelSim.
-- ----------------------------------------------------------------------------
-- Copyright (c) 2012-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-12-02  1.0      rzi     Created
-- 2014-03-24  1.01     fwi     updated uut instantiation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;

library work;
use work.pkg_bcrypt.all;
use work.rzi_helper.all;

entity bcrypt_tb is
end bcrypt_tb;

architecture Behavioral of bcrypt_tb is

    -- --------------------------------------------------------------------- --
    --                              Constants
    -- --------------------------------------------------------------------- --
    constant CLK_PERIOD : time := 10 ns;

    -- --------------------------------------------------------------------- --
    --                               Signals
    -- --------------------------------------------------------------------- --
    signal clk        : std_logic;       -- clock signal
    signal rst        : std_logic;       -- reset signal (enable high)
    signal rst_a      : std_logic;       -- reset signal (enable high) aligned
    signal key        : std_logic_vector ( KEY_LENGTH-1 downto 0) := (others => '1');
    signal key_a      : std_logic_vector ( KEY_LENGTH-1 downto 0) := (others => '0');
    signal salt       : std_logic_vector (SALT_LENGTH-1 downto 0) := (others => '1');
    signal salt_a     : std_logic_vector (SALT_LENGTH-1 downto 0) := (others => '0');
    signal dout       : std_logic_vector (191 downto 0);
    signal dout_valid : std_logic;
    signal debug_sig  : debug_signals_t;

    -- sbox init out signals
    signal sbox0_init_dout : std_logic_vector(31 downto 0);
    signal sbox1_init_dout : std_logic_vector(31 downto 0);
    signal sbox2_init_dout : std_logic_vector(31 downto 0);
    signal sbox3_init_dout : std_logic_vector(31 downto 0);
    -- sbox init controll signals
    signal sbox_init_addr  : std_logic_vector (7 downto 0);
    signal sbox0_init_addr : std_logic_vector (8 downto 0);
    signal sbox1_init_addr : std_logic_vector (8 downto 0);
    signal sbox2_init_addr : std_logic_vector (8 downto 0);
    signal sbox3_init_addr : std_logic_vector (8 downto 0);
begin

    -- --------------------------------------------------------------------- --
    -- Instantiation    UUT
    -- --------------------------------------------------------------------- --
    uut : entity work.bcrypt
    port map (
        clk             => clk,       -- clock signal
        rst             => rst_a,     -- reset signal
        key             => key_a,
        salt            => salt_a,
        sbox0_init_dout => sbox0_init_dout,
        sbox1_init_dout => sbox1_init_dout,
        sbox2_init_dout => sbox2_init_dout,
        sbox3_init_dout => sbox3_init_dout,
        dout_valid      => dout_valid,
        dout            => dout,
        sbox_init_addr  => sbox_init_addr
    );
    sbox0_init_addr <= '0' & sbox_init_addr;
    sbox1_init_addr <= '1' & sbox_init_addr;
    sbox2_init_addr <= '0' & sbox_init_addr;
    sbox3_init_addr <= '1' & sbox_init_addr;

    -- --------------------------------------------------------------------- --
    -- Instantiation    Initial SBox
    -- --------------------------------------------------------------------- --
    sbox01_init : entity work.bram
        generic map (
            DATA_WIDTH       => 32,
            ADDRESS_WIDTH    => 9,
            RW_MODE          => "RW",
            INIT_MEMORY      => true,
            INIT_FILL_ZEROES => true,
            INIT_FROM_FILE   => true,
            INIT_REVERSED    => true,
            INIT_FORMAT_HEX  => true,
            INIT_FILE        => "sbox01_init.mif",
            INIT_VECTOR      => "0"
        )
        port map (
            clkA  => clk,
            weA   => '0',
            rstA  => '0',
            addrA => sbox0_init_addr,
            dinA  => (others => '0'),
            doutA => sbox0_init_dout,
            clkB  => clk,
            weB   => '0',
            rstB  => '0',
            addrB => sbox1_init_addr,
            dinB  => (others => '0'),
            doutB => sbox1_init_dout
        );

    -- Initial Values of Sbox 2 and 3 in one BRAM core
    sbox23_init : entity work.bram
        generic map (
            DATA_WIDTH       => 32,
            ADDRESS_WIDTH    => 9,
            RW_MODE          => "RW",
            INIT_MEMORY      => true,
            INIT_FILL_ZEROES => true,
            INIT_FROM_FILE   => true,
            INIT_REVERSED    => true,
            INIT_FORMAT_HEX  => true,
            INIT_FILE        => "sbox23_init.mif",
            INIT_VECTOR      => "0"
        )
        port map (
            clkA  => clk,
            weA   => '0',
            rstA  => '0',
            addrA => sbox2_init_addr,
            dinA  => (others => '0'),
            doutA => sbox2_init_dout,
            clkB  => clk,
            weB   => '0',
            rstB  => '0',
            addrB => sbox3_init_addr,
            dinB  => (others => '0'),
            doutB => sbox3_init_dout
        );

    -- --------------------------------------------------------------------- --
    -- Testbench Processes
    -- --------------------------------------------------------------------- --

    -- align
    align_proc : process(clk)
    begin
        if rising_edge(clk) then
            rst_a  <= rst;
            key_a  <= key;
            salt_a <= salt;
        end if;
    end process align_proc;

    -- clock
    clk_proc : process
    begin
        clk <= '1';
        wait for 0.5*CLK_PERIOD;
        clk <= '0';
        wait for 0.5*CLK_PERIOD;
    end process clk_proc;

    -- stimulus
    stim_proc : process
        file conf_f : text open read_mode is "tv_conf.txt";

        variable confLine       : line;
        variable lineOut        : line;
        variable good           : boolean;
        variable salt_var       : std_logic_vector(SALT_LENGTH-1 downto 0);
        variable key_var        : std_logic_vector( KEY_LENGTH-1 downto 0);

        variable enc_count      : integer := 0;
        variable enc_succeed    : integer := 0;

        variable endnote        : line;

        function check(val,val_tv : std_logic_vector; test_number : integer)
         return integer is
            variable msg        : line;
            variable errorvar   : boolean;
         begin
            deallocate(msg);
            write(msg,string'("Test "));
            write(msg,test_number);
            if (val=val_tv) then
                write(msg,string'(" OK"));
                errorvar := false;
            else
                write (msg,string'(" FAILED "));
                hwrite(msg,val);
                write (msg, string'(" should be "));
                hwrite(msg,val_tv);
                errorvar := true;
            end if;
            if errorvar then
                report msg.all
                severity error;
                return 0;
            else
                report msg.all
                severity note;
                return 1;
            end if;
        end function check;

        procedure run_check(
            tv_f_name   : in    string;
            count       : inout integer;
            succeed     : inout integer
            ) is
            file tv_f : text open read_mode is tv_f_name;

            variable lineIn : line;
            variable good   : boolean;
            variable tv     : std_logic_vector(191 downto 0);
         begin
            wait for 3*CLK_PERIOD;

            report "-------------- Use " & tv_f_name & " for checks --------------"
            severity note;

            count := 0;
            succeed := 0;
            read_loop_tv : while not endfile(tv_f) loop
                readline(tv_f, lineIn);
                next when (lineIn(lineIn'left) = '-');
                count := count + 1;
                hread(lineIn, tv, good => good);

                assert (good)
                report "Invalid test vector format"
                severity error;

                -- compare resulte with testvector
                succeed := succeed + check(dout,tv,count);
                wait for CLK_PERIOD;
            end loop read_loop_tv;

            report "--------------- End of " & tv_f_name & " file ---------------"
            severity note;
        end procedure run_check;
    begin
    -- --------------------------------------------------------------------- --
    -- Setup: read config for salt/key from file
    -- --------------------------------------------------------------------- --
        report "reset core, setup salt and key";
        rst <= '1';

        read_loop_conf : while not endfile(conf_f) loop
            readline(conf_f, confLine);
            hread(confLine, salt_var, good => good);
            assert (good)
            report "Invalid format for salt value"
            severity error;
            readline(conf_f, confLine);
            hread(confLine, key_var, good => good);
            assert (good)
            report "Invalid format for key value"
            severity error;
            salt <= salt_var;
            key  <=  key_var;
        end loop read_loop_conf;

        wait for 2*CLK_PERIOD;

        deallocate(lineOut);
        write(lineOut, string'("using salt "));
        hwrite(lineOut, salt_var);
        write(lineOut, string'(" and key "));
        hwrite(lineOut, key_var);
        report lineOut.all severity note;

        report "begin tests" severity note;
        rst <= '0';
    -- --------------------------------------------------------------------- --
    -- Test:    check hash output
    -- --------------------------------------------------------------------- --
        wait until dout_valid = '1';
        report "finished hashing, check output"
        severity note;
        run_check("tv_enc.txt", enc_count, enc_succeed);

    -- --------------------------------------------------------------------- --
    -- Report
    -- --------------------------------------------------------------------- --
        wait for CLK_PERIOD;
        report "----------------------- Test Report -----------------------"
        severity note;
        report "Test succeeded: "
               & integer'image(enc_succeed)
               & " of "
               & integer'image(enc_count)
        severity note;

        report "---------------------- End of Report ----------------------" severity note;
        assert false report "End of Testbench" severity failure;
    end process stim_proc;

end Behavioral;
