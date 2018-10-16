-------------------------------------------------------------------------------
-- Title      : bcrypt_cracker - Testbench
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : bcrypt_cracker_tb.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-04-01
-- Last update: 2014-04-01
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description: This module provides a testbench for the bcrypt cracker
--              module with a simulater, i.e., ISIM or ModelSim.
-- ----------------------------------------------------------------------------
-- Copyright (c) 2012-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-04-01  1.0      fwi     Created
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

entity bcrypt_cracker_tb is
end bcrypt_cracker_tb;

architecture Behavioral of bcrypt_cracker_tb is

    -- --------------------------------------------------------------------- --
    --                              Constants
    -- --------------------------------------------------------------------- --
    constant CLK_PERIOD : time := 10 ns;

    -- --------------------------------------------------------------------- --
    --                               Signals
    -- --------------------------------------------------------------------- --
    signal clk      : std_logic;     -- clock signal
    signal rst      : std_logic;     -- reset signal (enable high)
    signal rst_a    : std_logic;     -- reset signal (enable high) aligned
    signal t_salt   : std_logic_vector (SALT_LENGTH-1 downto 0);
    signal salt_a   : std_logic_vector (SALT_LENGTH-1 downto 0);
    signal t_hash   : std_logic_vector (191 downto 0);
    signal hash_a   : std_logic_vector (191 downto 0);
    signal done     : std_logic;
    signal success  : std_logic;
    signal dout_we  : std_logic;
    signal dout     : std_logic_vector (31 downto 0);
begin

    -- --------------------------------------------------------------------- --
    -- Instantiation    UUT
    -- --------------------------------------------------------------------- --
    uut : entity work.bcrypt_cracker
    port map (
        clk     => clk,       -- clock signal
        rst     => rst_a,     -- reset signal
        t_salt  => salt_a,
        t_hash  => hash_a,
        done    => done,
        success => success,
        dout_we => dout_we,
        dout    => dout
    );

    -- --------------------------------------------------------------------- --
    -- Testbench Processes
    -- --------------------------------------------------------------------- --

    -- align
    align_proc : process(clk)
    begin
        if rising_edge(clk) then
            rst_a  <= rst;
            salt_a <= t_salt;
            hash_a <= t_hash;
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
    begin
        report "Begin of Testbench"
        severity note;
    -- --------------------------------------------------------------------- --
    -- Setup
    -- --------------------------------------------------------------------- --
        wait for CLK_PERIOD;
        report "reset module, setup target salt and hash"
        severity note;
        rst <= '1';

        t_salt  <= x"ce335fbf784959c781332a5d8dcd2535";
        t_hash  <= x"8812dd7e0add41acf8c9baefd74a83f413315853242d2caa"; -- b cost 0
        --t_hash  <= x"98c5d4f1e66d8a4b80bd7eadc9f590559c9aa4ac408d0b36"; -- b cost 1
        -- cost 2 below
--        t_salt  <= x"919946f58a4b118a75e6c899303d4a93";
--        t_hash  <= x"6c5896c8a849a3bcd6e7f484999d7d078892a1b23237ade1"; -- b
        --t_hash  <= x"b1a60ec71b044eb6e35fb6e2fb4b32460e29d4756714847f"; -- f
        --t_hash  <= x"7f0587e584ec1d44e08de34b7c10cca2a5b3da765956e8ef"; -- aa
        --t_hash  <= x"a37a70b5cfd2254ff4f9ee13a35f66363c145ad4d30ec56f"; -- ab
        --t_hash  <= x"d9e230e32f460318e741a4080055b6831bc8c0ca1eee6d65"; -- ba

        wait for 2*CLK_PERIOD;
        report "begin tests" severity note;
        rst <= '0';
    -- --------------------------------------------------------------------- --
    -- Test:    To Be Implemented
    -- --------------------------------------------------------------------- --
        wait until dout_we = '1';
        wait until done = '1';
        wait for CLK_PERIOD;
        assert dout = x"62006200" report "checking dout" severity failure;
    -- --------------------------------------------------------------------- --
    -- Report
    -- --------------------------------------------------------------------- --
        wait for CLK_PERIOD;
        report "----------------------- Test Report -----------------------"
        severity note;
        -- nothing implemented here
        report "---------------------- End of Report ----------------------"
        severity note;
        assert false report "End of Testbench" severity failure;
    end process stim_proc;

end Behavioral;
