-------------------------------------------------------------------------------
-- Title      : n-bit Adder
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : nBitAdder.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2011-07-28
-- Last update: 2011-07-28
-- Platform   : any
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    This module describes a basic n-bit Adder without any buffer registers.
--    The purpose is only to generate correct code with NUMERIC_STD library.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-07-28  1.0      rzi     Created
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity nBitAdder is
  generic (
    BIT_WIDTH : positive := 4
    );
  port (
    inA : in  std_logic_vector(BIT_WIDTH-1 downto 0);
    inB : in  std_logic_vector(BIT_WIDTH-1 downto 0);
    res : out std_logic_vector(BIT_WIDTH-1 downto 0)
    );
end nBitAdder;

architecture Behavioral of nBitAdder is
begin
  res <= std_logic_vector(unsigned(inA) + unsigned(inB));
end Behavioral;

