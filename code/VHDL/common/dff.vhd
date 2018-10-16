-------------------------------------------------------------------------------
-- Title      : D-FlipFlop w/ (a)synchronous reset
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : dff.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2010-10-05
-- Last update: 2012-11-21
-- Platform   : any
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    This module describes a basic D-FlipFlop. It features an enable signal
--    (CE) and uses a reset high (SR = '1'), which resets to SRINIT.
--
--    Using the generic "ASYNC" it is possible to create an asynchronously
--    reset DFF instead of an synchronously reset DFF.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2010-10-05  1.0      rzi     Created
-- 2012-11-21  1.1      rzi     Merged SSR and ASR
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- D-FlipFlop with (a)synchronous reset
entity DFF is
  generic (
    ASYNC : boolean := false            -- asynchronous reset
    );
  port (
    clk    : in  std_logic;             -- input clock
    sr     : in  std_logic;             -- set/reset (high)
    srinit : in  std_logic;             -- reset value
    ce     : in  std_logic;             -- enable signal
    D      : in  std_logic;             -- input bit
    Q      : out std_logic              -- output bit
    );
end DFF;

architecture Behavioral of DFF is
begin

  FlipFlop : process(clk, sr, srinit)
  begin
    -- evaluate generic
    if ASYNC and sr = '1' then
      Q <= srinit;
    elsif rising_edge(clk) then
      if not ASYNC and sr = '1' then
        Q <= srinit;
      else
        if ce = '1' then
          Q <= D;
        end if;  -- enable
      end if;  -- reset
    end if;  -- sr or clk, depending on generic
  end process FlipFlop;

end Behavioral;
