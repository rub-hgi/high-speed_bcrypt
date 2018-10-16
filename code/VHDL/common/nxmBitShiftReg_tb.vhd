-------------------------------------------------------------------------------
-- Title      : (n x m)-bit shift register w/ (a)synchronous reset - Test Bench
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : nxmBitShiftReg_tb.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2012-11-21
-- Last update: 2013-05-29
-- Platform   : any
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    This module provides a test bench for the uut nxmBitShiftReg. It is
--    configured using constants to test MAXTEST random tests using ASYNC mode
--    of reset.
--
--    It will automatically verify the output according to the mode of
--    operation.
-------------------------------------------------------------------------------
-- Copyright (c) 2012-2013 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2012-11-21  1.1      rzi     Added ASYNC constant to testbench
-- 2013-05-29  1.2      rzi     Added automatic verification of the results
--                              for ASYNC = false only. Needs update for the
--                              case ASYNC = true.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.rzi_helper.all;

entity nxmBitShiftReg_tb is
end entity;

architecture behavioral of nxmBitShiftReg_tb is
  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  constant clk_period : time     := 10 ns;
  constant ASYNC      : boolean  := false;
  constant N          : positive := 3;
  constant M          : positive := 4;
  constant MAXTEST    : positive := 40;
  constant SEED1_INIT : positive := 2;
  constant SEED2_INIT : positive := 3;

  -----------------------------------------------------------------------------
  -- UUT component
  -----------------------------------------------------------------------------
  component nxmBitShiftReg is
    generic (
      ASYNC : boolean;                  -- asynchronous reset
      N     : positive;                 -- number of registers
      M     : positive);                -- bits per register
    port (
      clk    : in  std_logic;           -- input clock
      sr     : in  std_logic;           -- set/reset signal
      srinit : in  std_logic_vector(N*M-1 downto 0);   -- init value for reset
      ce     : in  std_logic;           -- enable signal
      opmode : in  std_logic_vector(1 downto 0);  -- operation mode: [Rot?, Left?]
      din    : in  std_logic_vector(M-1 downto 0);  -- input value when shifting
      dout   : out std_logic_vector(M-1 downto 0);  -- output: word shifted out resp. last word rotated
      dout_f : out std_logic_vector(N*M-1 downto 0));  -- output :  complete register
  end component nxmBitShiftReg;

  -- basic UUT signals
  signal clk    : std_logic;            -- input clock
  signal sr     : std_logic;            -- set/reset signal
  signal srinit : std_logic_vector(N*M-1 downto 0);  -- init value for reset
  signal ce     : std_logic;            -- enable signal
  signal opmode : std_logic_vector(1 downto 0);  -- operation mode: [Rot?, Left?]
  signal din    : std_logic_vector(M-1 downto 0);  -- input value when shifting
  signal dout   : std_logic_vector(M-1 downto 0);  -- output: word shifted out resp. last word rotated
  signal dout_f : std_logic_vector(N*M-1 downto 0);  -- output :  complete register

  -- aligned UUT signals
  signal sr_a     : std_logic;          -- set/reset signal
  signal srinit_a : std_logic_vector(N*M-1 downto 0);  -- init value for reset
  signal ce_a     : std_logic;          -- enable signal
  signal opmode_a : std_logic_vector(1 downto 0);  -- operation mode: [Rot?, Left?]
  signal din_a    : std_logic_vector(M-1 downto 0);  -- input value when shifting

begin

  uut : nxmBitShiftReg
    generic map (
      ASYNC => ASYNC,                   -- asynchronous reset
      N     => N,                       -- number of registers
      M     => M)                       -- bits per register
    port map (
      clk    => clk,                    -- input clock
      sr     => sr_a,                   -- set/reset signal
      srinit => srinit_a,               -- init value for reset
      ce     => ce_a,                   -- enable signal
      opmode => opmode_a,               -- operation mode: [Rot?, Left?]
      din    => din_a,                  -- input value when shifting
      dout   => dout,      -- output: word shifted out resp. last word rotated
      dout_f => dout_f);                -- output :  complete register

  -- Clock generation
  clk_gen : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process clk_gen;

  -- Signal alignment to clock
  synch_proc : process(clk)
  begin
    if (rising_edge(clk)) then
      sr_a     <= sr;
      srinit_a <= srinit;
      ce_a     <= ce;
      opmode_a <= opmode;
      din_a    <= din;
    end if;
  end process synch_proc;

  stim_proc : process
    variable vec   : std_logic_vector(N*M-1 downto 0);
    variable seed1 : integer := SEED1_INIT;
    variable seed2 : integer := SEED2_INIT;
  begin
    -- reset case
    sr     <= '1';
    srinit <= (others => '0');
    ce     <= '0';
    opmode <= "00";
    din    <= (others => '0');
    wait for 3*clk_period;

    report "Starting random test cases...";

    -- random test of MAXTEST iterations
    for i in 0 to MAXTEST-1 loop
      -- update inputs
      vec    := (others => '0');
      randomize(seed1, seed2, M, vec(M-1 downto 0));
      din    <= vec(M-1 downto 0);
      randomize(seed1, seed2, M*N, vec);
      srinit <= vec;
      randomize(seed1, seed2, 5, vec(4 downto 0));
      sr     <= vec(4) and vec(3) and vec(2) and vec(1);
      ce     <= vec(0);
      vec    := std_logic_vector(to_unsigned(i, M*N));
      opmode <= vec(2 downto 1);
      wait for clk_period;

    end loop;

    -- disable register and end test
    ce <= '0';
    sr <= '0';
    wait for 5*clk_period;
    assert false report "End of test" severity failure;
  end process;

  -- verify the test parameters
  -- TODO: add ASYNC case
  auto_test : process
    variable old_dout_f : std_logic_vector(N*M-1 downto 0);
    variable old_dout   : std_logic_vector(M-1 downto 0);
    variable old_din    : std_logic_vector(M-1 downto 0);
    variable old_sr     : std_logic;
    variable old_ce     : std_logic;
    variable old_srinit : std_logic_vector(N*M-1 downto 0);
    variable old_opmode : std_logic_vector(1 downto 0);
    variable tv_dout_f  : std_logic_vector(N*M-1 downto 0);
    variable tv_dout    : std_logic_vector(M-1 downto 0);
  begin
    wait for 3*clk_period;

    -- shift by 0.5 to get correctly updated values
    wait for 0.5*clk_period;
    -- random test 
    for i in 0 to MAXTEST-1 loop
      -- store current state
      old_dout_f := dout_f;
      old_dout   := dout;
      old_din    := din;
      old_sr     := sr;
      old_ce     := ce;
      old_srinit := srinit;
      old_opmode := opmode;
      wait for clk_period;
      -- check if update was correct
      if old_sr = '1' then
        tv_dout_f := old_srinit;
      elsif old_ce = '1' then
        case old_opmode is
          when "00" =>                  -- shr
            tv_dout_f := old_din & old_dout_f(N*M-1 downto M);
          when "01" =>                  -- shl
            tv_dout_f := old_dout_f((N-1)*M-1 downto 0) & old_din;
          when "10" =>                  -- ror
            tv_dout_f := old_dout_f(M-1 downto 0) & old_dout_f(N*M-1 downto M);
          when "11" =>                  -- rol
            tv_dout_f := old_dout_f((N-1)*M-1 downto 0) & old_dout_f(N*M-1 downto (N-1)*M);
          when others =>
            tv_dout_f := (others => '0');
        end case;
      else
        tv_dout_f := old_dout_f;
      end if;

      assertMatch(dout_f, tv_dout_f);
    end loop;
  end process auto_test;
end architecture behavioral;
