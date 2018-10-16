-------------------------------------------------------------------------------
-- Title      : (n x m)-bit shift register w/ (a)synchronous reset
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : nxmBitShiftReg.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2011-05-11
-- Last update: 2013-05-29
-- Platform   : any
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--    This module is a basic n x m bit shift register with rotation support.
--
--    Parameters are
--      ASYNC : use asynchronous reset when true
--      N     : number of registers
--      M     : bits per register
--
--    Operation Mode flags
--      OPMODE(1) : rotation  - rotate (1), shift (0)
--      OPMODE(0) : direction - left (1), right (0)
--
--    This shift register has reset high (SR = '1') and resets to the value on
--    SRINIT.
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2013 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-05-11  1.0      rzi     Created
-- 2012-08-30  1.0a     rzi     Added assert check for generic
-- 2012-11-21  1.1      rzi     Merged SSR and ASR
-- 2013-05-29  1.2      rzi     Removed all restrictions for N and M
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity nxmBitShiftReg is
  generic (
    ASYNC : boolean  := false;          -- asynchronous reset
    N     : positive := 1;              -- number of registers
    M     : positive := 1               -- bits per register
    );
  port (
    clk    : in  std_logic;             -- input clock
    sr     : in  std_logic;             -- set/reset signal
    srinit : in  std_logic_vector(N*M-1 downto 0);  -- init value for reset
    ce     : in  std_logic;             -- enable signal
    opmode : in  std_logic_vector(1 downto 0);  -- operation mode: [Rot?, Left?]
    din    : in  std_logic_vector(M-1 downto 0);  -- input value when shifting
    dout   : out std_logic_vector(M-1 downto 0);  -- output: word shifted out resp. last word rotated
    dout_f : out std_logic_vector(N*M-1 downto 0)  -- output: complete register
    );
end nxmBitShiftReg;

architecture Behavioral of nxmBitShiftReg is
  -----------------------------------------------------------------------------
  --                              Components
  -----------------------------------------------------------------------------

  -- n bit register
  component nBitReg is
    generic (
      ASYNC     : boolean := false;     -- asynchronous reset
      BIT_WIDTH : positive              -- register size in bits
      );
    port (
      clk    : in  std_logic;           -- input clock
      sr     : in  std_logic;           -- set/reset (high)
      srinit : in  std_logic_vector(BIT_WIDTH-1 downto 0);  -- init value
      ce     : in  std_logic;           -- enable signal
      din    : in  std_logic_vector(BIT_WIDTH-1 downto 0);  -- input word
      dout   : out std_logic_vector(BIT_WIDTH-1 downto 0)   -- output word
      );
  end component nBitReg;

  -----------------------------------------------------------------------------
  --                               Signals
  -----------------------------------------------------------------------------
  signal din_intern  : std_logic_vector(N*M-1 downto 0);
  signal dout_intern : std_logic_vector(N*M-1 downto 0);
  signal ce_intern   : std_logic_vector(N-1 downto 0);
  alias rotate       : std_logic is opmode(1);
  alias toleft       : std_logic is opmode(0);

  -----------------------------------------------------------------------------
  -- Functions needed to circumvent if .. generate restrictions
  -----------------------------------------------------------------------------
  -- input signal multiplexer configuration concerning DIN and output index
  -- --------------------------------------
  -- left rot   i = n   i   i = 1
  -- --------------------------------------
  --  0 0   DIN     i+1   i+1
  --  0 1   i=1     i+1   i+1
  --  1 0   i-1     i-1   DIN
  --  1 1   i-1     i-1   i=n
  function muxSignalLeftMostRegister(pos : integer; din : std_logic_vector; state : std_logic_vector; rotate : std_logic; toleft : std_logic) return std_logic_vector is
    variable output : std_logic_vector(M-1 downto 0);
  begin
    -- if we have more than one register: use normal logic
    if N > 1 then
      if toleft = '0' then
        if rotate = '0' then
          output := din;
        else
          output := state(M-1 downto 0);
        end if;  -- rotate?
      else
        output := state((pos-1)*M-1 downto (pos-2)*M);
      end if;  -- left?
    -- otherwise: this function is not generated, dummy action.
    else
      output := std_logic_vector(to_unsigned(0, M));
    end if;  -- more than 1 register

    return output;
  end function muxSignalLeftMostRegister;

  impure function muxSignalMiddleRegister(pos : integer; din : std_logic_vector; state : std_logic_vector; rotate : std_logic; toleft : std_logic) return std_logic_vector is
    variable output : std_logic_vector(M-1 downto 0);
  begin
    -- if we have more than one register: use normal logic
    if N > 1 then
      if toleft = '0' then
        output := dout_intern((pos+1)*M-1 downto pos*M);
      else
        output := dout_intern((pos-1)*M-1 downto (pos-2)*M);
      end if;  -- left?
    -- otherwise: this function is not generated, dummy action.
    else
      output := std_logic_vector(to_unsigned(0, M));
    end if;  -- more than 1 register

    return output;
  end function muxSignalMiddleRegister;

  function muxSignalRightMostRegister(pos : integer; din : std_logic_vector; state : std_logic_vector; rotate : std_logic; toleft : std_logic) return std_logic_vector is
    variable output : std_logic_vector(M-1 downto 0);
  begin
    -- if we have more than one register: use normal logic
    if N > 1 then
      if toleft = '1' then
        if rotate = '0' then
          output := din;
        else
          output := state(n*M-1 downto (n-1)*M);
        end if;  -- rotate?
      else
        output := state((pos+1)*M-1 downto pos*M);
      end if;  -- left?
    -- otherwise: move in new data (rotate is done by "ce = '0'")
    else
      output := din;
    end if;  -- more than 1 register

    return output;
  end function muxSignalRightMostRegister;

  -- CE signal must be either ce (N > 1) or (ce and not rotate) [N = 1]
  function deriveRealCE(ce : std_logic; rotate : std_logic) return std_logic is
  begin
    -- if we have more than one register, use the ce signal.
    if N > 1 then
      return ce;
    -- otherwise, a rotation means also disabling the ce signal
    else
      return ((not rotate) and ce);
    end if;
  end function deriveRealCE;

begin

  -- generate shift register
  shiftReg : for i in 1 to n generate

    -- registers for the shift register
    reg : nBitReg
      generic map (
        ASYNC     => ASYNC,                            -- asynchronous reset
        BIT_WIDTH => M                                 -- register size in bits
        )
      port map (
        clk    => clk,                                 -- input clock
        sr     => sr,                                  -- set/reset (high)
        srinit => srinit((i*M)-1 downto (i-1)*M),      -- init value
        ce     => ce_intern(i-1),                      -- enable signal
        din    => din_intern((i*M)-1 downto (i-1)*M),  -- input word
        dout   => dout_intern((i*M)-1 downto (i-1)*M)  -- output word
        );
    ce_intern(i-1) <= deriveRealCE(ce, rotate);

    -- left most: choose between DIN, out(1), out(i-1)
    in_lmr : if i = n and n > 1 generate
      din_intern(i*M-1 downto (i-1)*M) <= muxSignalLeftMostRegister(i, din, dout_intern, rotate, toleft);
    end generate;

    -- middle: choose between out(i+1) and out(i-1)
    in_mr : if i > 1 and i < n generate
      din_intern(i*M-1 downto (i-1)*M) <= muxSignalMiddleRegister(i, din, dout_intern, rotate, toleft);
    end generate;

    -- right most: choose between DIN, out(n), out(i+1)
    in_rmr : if i = 1 generate
      din_intern(i*M-1 downto (i-1)*M) <= muxSignalRightMostRegister(i, din, dout_intern, rotate, toleft);
    end generate;

  end generate;

  -- map internal signals to output signals
  dout_f <= dout_intern;
  dout   <= dout_intern(M-1 downto 0) when toleft = '0' else
          dout_intern(N*M-1 downto (N-1)*M);

end Behavioral;
