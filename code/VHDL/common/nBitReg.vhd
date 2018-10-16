-------------------------------------------------------------------------------
-- Title      : n-bit Register w/ (a)synchronous reset
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : nBitReg.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2011-05-10
-- Last update: 2012-11-21
-- Platform   : any
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    This module is a basic, (a)synchronously reset n-bit register.
--
--    Parameters are
--      ASYNC     : use asynchronous reset when true
--      BIT_WIDTH : register size in bits
--
--    This register uses a reset high (SR = '1') and resets to the value on
--    SRINIT.
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2012 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-05-10  0.1      rzi     Created
-- 2012-08-30  1.0      rzi     Rewrote module
-- 2012-11-21  1.2      rzi     Merged SSR and ASR
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity nBitReg is
  generic (
    ASYNC     : boolean := false;       -- asynchronous reset
    BIT_WIDTH : positive                -- size of the register
    );
  port (
    clk    : in  std_logic;             -- input clock
    sr     : in  std_logic;             -- set/reset (high)
    srinit : in  std_logic_vector(BIT_WIDTH-1 downto 0);  -- init value
    ce     : in  std_logic;             -- enable signal
    din    : in  std_logic_vector(BIT_WIDTH-1 downto 0);  -- input word
    dout   : out std_logic_vector(BIT_WIDTH-1 downto 0)   -- output word
    );
end nBitReg;

architecture Structural of nBitReg is

  -----------------------------------------------------------------------------
  --                              Components
  -----------------------------------------------------------------------------

  -- (a)synchronously reset D-FlipFlop
  component DFF is
    generic (
      ASYNC : boolean := false          -- asynchronous reset
      );
    port (
      clk    : in  std_logic;           -- input clock
      sr     : in  std_logic;           -- set/reset (high)
      srinit : in  std_logic;           -- reset value
      ce     : in  std_logic;           -- enable signal
      D      : in  std_logic;           -- input bit
      Q      : out std_logic            -- output bit
      );
  end component DFF;

begin

  -- Register, synchronous reset, reset high
  Reg : for i in 0 to BIT_WIDTH-1 generate
    FF : DFF
      generic map (
        ASYNC => ASYNC
        )
      port map (
        clk    => clk,
        sr     => sr,
        srinit => srinit(i),
        ce     => ce,
        D      => din(i),
        Q      => dout(i)
        );
  end generate;

end Structural;

