-------------------------------------------------------------------------------
-- Title      : n-bit counter w/ (a)syncronous reset
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : nBitCounter.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2011-05-10
-- Last update: 2012-12-10
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    This module implements a basic n-bit up-down counter. It will infer the
--    Xilinx counter HDL macro and will be optimized accordingly.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-05-10  1.0      rzi     Created
-- 2011-11-15  1.1      rzi     Added direction support
-- 2012-08-30  1.1a     rzi     Minor change
-- 2012-12-10  1.2      rzi     Added asynchronous reset option (generic)
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity nBitCounter is
  generic (
    ASYNC     : boolean  := false;      -- asynchronous reset
    BIT_WIDTH : positive := 4           -- width of counter
    );
  port (
    clk      : in  std_logic;           -- clock signal
    sr       : in  std_logic;           -- reset (active high)
    ce       : in  std_logic;           -- enable signal
    srinit   : in  std_logic_vector(BIT_WIDTH-1 downto 0);  -- initialization value
    count_up : in  std_logic;           -- direction: '1' = up, '0' = down
    dout     : out std_logic_vector (BIT_WIDTH-1 downto 0)  -- counter value
    );
end nBitCounter;

architecture Behavioral of nBitCounter is
  signal count_intern : unsigned(BIT_WIDTH-1 downto 0);
begin

  -- counter
  counter : process (clk)
  begin
    -- async reset
    if (ASYNC and sr = '1') then
      count_intern <= unsigned(srinit);
    elsif (rising_edge(clk)) then
      -- sync reset
      if ((not ASYNC) and sr = '1') then
        count_intern <= unsigned(srinit);
      elsif (ce = '1') then
        if count_up = '1' then
          count_intern <= count_intern + 1;
        else
          count_intern <= count_intern - 1;
        end if;  -- direction
      end if;  -- rst
    end if;  -- clk
  end process counter;

  dout <= std_logic_vector(count_intern);

end Behavioral;
