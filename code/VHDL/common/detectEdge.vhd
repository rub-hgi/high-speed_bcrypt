-------------------------------------------------------------------------------
-- Title      : Edge Detection
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : detectEdge.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2011-05-11
-- Last update: 2013-10-02
-- Platform   : any
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    This module implements both rising and falling edge detection.
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2013 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-05-11  1.0      rzi     Created
-- 2012-08-30  1.0a     rzi     Adjusted comments
-- 2013-02-26  1.1      rzi     Updated module to DFF v1.1 upgrade
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity detectEdge is
  generic (
    ASYNC : boolean := false                     -- asynchronous reset
    );
  port (
    clk : in  std_logic;                -- input clock
    sr  : in  std_logic;                -- set/reset (high)
    D   : in  std_logic;                -- input signal
    QR  : out std_logic;                -- rising edge signal
    QF  : out std_logic                 -- falling edge signal
    );
end detectEdge;

architecture Behavioral of detectEdge is
  -----------------------------------------------------------------------------
  --                              Components
  -----------------------------------------------------------------------------
  component DFF is
    generic (
      ASYNC : boolean);                 -- asynchronous reset
    port (
      clk    : in  std_logic;           -- input clock
      sr     : in  std_logic;           -- set/reset (high)
      srinit : in  std_logic;           -- reset value
      ce     : in  std_logic;           -- enable signal
      D      : in  std_logic;           -- input bit
      Q      : out std_logic);          -- output bit
  end component DFF;

  -----------------------------------------------------------------------------
  --                               Signals
  -----------------------------------------------------------------------------
  signal last_state : std_logic;        -- last state of input signal

begin

  -- FlipFlop saving the last input state
  state_buffer : DFF
    generic map (
      ASYNC => ASYNC                    -- asynchronous reset
      )
    port map (
      clk    => clk,                    -- input clock
      sr     => sr,                     -- set/reset (high)
      srinit => '0',                    -- reset value
      ce     => '1',                    -- enable signal
      D      => D,                      -- input bit
      Q      => last_state              -- output bit
      );

  -- detect falling edge
  QF <= last_state and (not D) and not sr;

  -- detect rising edge
  QR <= (not last_state) and D and not sr;

end Behavioral;

