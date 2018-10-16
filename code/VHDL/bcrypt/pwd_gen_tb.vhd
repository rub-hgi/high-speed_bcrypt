-------------------------------------------------------------------------------
-- Title      : pwd_gen - Testbench
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : pwd_gen_tb.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-04-11
-- Last update: 2014-04-11
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02/08
-- ----------------------------------------------------------------------------
-- Description: This module provides a testbench for the pwd_generation
--              module with a simulater, i.e., ISIM or ModelSim.
-- ----------------------------------------------------------------------------
-- Copyright (c) 2012-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-04-11  1.0      fwi     Created
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

entity pwd_gen_tb is
end entity pwd_gen_tb;

architecture behavioral of pwd_gen_tb is
    -- --------------------------------------------------------------------- --
    --                              Constants
    -- --------------------------------------------------------------------- --
    constant INIT : std_logic_vector (PWD_LENGTH*CHARSET_OF_BIT-1 downto 0)
     := const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT) &
        const_slv(0,CHARSET_OF_BIT) & const_slv(0,CHARSET_OF_BIT);
    constant LENGTH : integer := 1;
    constant CLK_PERIOD : time := 10 ns;

    -- --------------------------------------------------------------------- --
    --                               Signals
    -- --------------------------------------------------------------------- --
    signal clk      : std_logic;     -- clock signal
    signal rst      : std_logic;
    signal continue : std_logic;

    signal pwd_gen_rst      : std_logic;
    signal pwd_gen_continue : std_logic;
    signal pwd_gen_done     : std_logic;
    signal pwd_gen_weA      : std_logic;
    signal pwd_gen_addrA    : std_logic_vector ( 4 downto 0);
    signal pwd_gen_dinA     : std_logic_vector (31 downto 0);
    signal pwd_gen_weB      : std_logic;
    signal pwd_gen_addrB    : std_logic_vector ( 4 downto 0);
    signal pwd_gen_dinB     : std_logic_vector (31 downto 0);

    signal pwd_doutA        : std_logic_vector (31 downto 0);
    signal pwd_doutB        : std_logic_vector (31 downto 0);
begin
    -- --------------------------------------------------------------------- --
    -- Instantiation    UUT
    -- --------------------------------------------------------------------- --
    uut : entity work.pwd_gen
        generic map (
            INIT    => INIT,
            LENGTH  => LENGTH
        )
        port map (
            clk     => clk,
            rst     => pwd_gen_rst,
            continue=> pwd_gen_continue,
            done    => pwd_gen_done,
            weA     => pwd_gen_weA,
            addrA   => pwd_gen_addrA,
            dinA    => pwd_gen_dinA,
            weB     => pwd_gen_weB,
            addrB   => pwd_gen_addrB,
            dinB    => pwd_gen_dinB
        );
    -- ------------------------------------------------------------------------
    -- Instantiation    bram for password storage
    -- ------------------------------------------------------------------------
    pwd_mem : entity work.bram
        generic map (
            DATA_WIDTH       => 32,
            ADDRESS_WIDTH    => 9,
            RW_MODE          => "WR", -- write before read
            INIT_MEMORY      => true,
            INIT_VECTOR      => x"00000000"
        )
        port map (
            clkA  => clk,
            weA   => pwd_gen_weA,
            rstA  => '0',
            addrA => "0000" & pwd_gen_addrA,
            dinA  => pwd_gen_dinA,
            doutA => pwd_doutA,
            clkB  => clk,
            weB   => pwd_gen_weB,
            rstB  => '0',
            addrB => "0010" & pwd_gen_addrB,
            dinB  => pwd_gen_dinB,
            doutB => pwd_doutB
        );
    -- --------------------------------------------------------------------- --
    -- Testbench Processes
    -- --------------------------------------------------------------------- --

    -- align
    align_proc : process(clk)
    begin
        if rising_edge(clk) then
            pwd_gen_rst      <= rst;
            pwd_gen_continue <= continue;
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
        report "reset module"
        severity note;
        rst <= '1';
        continue <= '0';

        wait for 2*CLK_PERIOD;
        report "begin tests" severity note;
        rst <= '0';
    -- --------------------------------------------------------------------- --
    -- Test:    To Be Implemented
    -- --------------------------------------------------------------------- --
        for i in 0 to 9999 loop
            wait until pwd_gen_done = '1';
            continue <= '1';
            wait for 1.5*CLK_PERIOD;
            continue <= '0';
        end loop;
        wait until pwd_gen_done = '1';
        wait for 2*CLK_PERIOD;
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

end architecture behavioral;
