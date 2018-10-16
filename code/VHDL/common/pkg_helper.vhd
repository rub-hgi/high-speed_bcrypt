-------------------------------------------------------------------------------
-- Title      : Package: VHDL Helper Functions
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : pkg_helper.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2010-10-05
-- Last update: 2013-05-31
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This package defines helper functions useful for the definition
--              of constants in implementation mode for easy code reusablity.
--
--              It also includes procedures to increase the flexibility when
--              creating complex test benchs and supplying better debug output.
--
--              Please take care which functions are in the "simulation only"
--              section and which are flagged for "simulation/implementation".
-------------------------------------------------------------------------------
-- Copyright (c) 2010-2013 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2010-10-05  1.0      rzi     Created, added assertMatch() macro
-- 2013-03-26  1.1      rzi     Added hpwrite() and randomize()
-- 2013-05-14  1.2      rzi     Added helper functions
-- 2013-05-31  1.3      rzi     Added min function
--                              Merged into TestBenchMacros package
--                              (reset creation date to 2010-10-05)
-- 2013-10-01  1.4      rzi     Added xstPrintFlagDesc function
-- 2013-10-15  1.5      rzi     Added resize_slv function
-- 2013-12-02  1.6      rzi     Added const_slv function
-------------------------------------------------------------------------------
-- TODO: - format broken due to vim script bug, reformat ASAP
--       - probably add more xstPrint functions for easy output
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

library STD;
use std.textio.all;

package rzi_helper is
	-------------------------------------------------------------------------------
	-- Functions to help with definition of constants (simulation/implementation)
	-------------------------------------------------------------------------------
	-- maximum of two integers a and b
	function max (a : integer; b : integer)
		return integer;
	-- minimum of two integers a and b
	function min (a : integer; b : integer)
		return integer;
	-- bit size of integer n
	function getBitSize (n : positive)
		return positive;
	-- number of m bit words needed to store integer n
	function getWordCount (n : positive; m : positive)
		return positive;
	-- resize a standard logic vector (using unsigned conversion)
	function resize_slv(val : std_logic_vector; len : integer)
		return std_logic_vector;
	-- generate a constant standard logic vector (using unsigned conversion)
	function const_slv(val : integer; len : integer)
		return std_logic_vector;

	-----------------------------------------------------------------------------
	-- Procedures to help with test benches (simulation only)
	-----------------------------------------------------------------------------
	-- assert macro with text output
	procedure assertMatch(testResult, correctResult : in std_logic_vector; hex : boolean := true; sev_level : severity_level := error);
	procedure assertMatch(testResult, correctResult : in std_logic; sev_level : severity_level := error);

	-- write hex value to line L with padding (if necessary)  
	procedure hpwrite(L : inout line; value : in std_logic_vector);

	-- generate randomized std_logic_vector or integer
	procedure randomize(seed1, seed2 : inout integer; n : in positive; value : inout std_logic_vector);
	procedure randomize(seed1, seed2 : inout integer; max : in positive; value : inout integer);

	-- output constants in XST
	procedure xstPrintFlagDesc(desc : in string; posLow : in integer; posHigh : in integer := -1; fail : boolean := false);

end package rzi_helper;

package body rzi_helper is
	-------------------------------------------------------------------------------
	-- Functions to help with definition of constants (simulation/implementation)
	-------------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Defines a simple maximum function of two integers.
	-----------------------------------------------------------------------------
	function max(a : integer; b : integer) return integer is
	begin
		if (a > b) then
			return a;
		else
			return b;
		end if;
	end function;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Defines a simple minimum function of two integers.
	-----------------------------------------------------------------------------
	function min(a : integer; b : integer) return integer is
	begin
		if (a < b) then
			return a;
		else
			return b;
		end if;
	end function;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Derive the bitsize from a positive integer n.
	--
	-- This function supports also n = 1. With the usual ceil(log2(n)), this case
	-- maps to 0, returning an incorrect bit length of 0.
	-----------------------------------------------------------------------------
	function getBitSize(n : positive) return positive is
		variable evenInt : positive;
	begin

		-- make the value even and skip the rounding
		-- this also circumvents ceil(log2(n = 1)) = 0 instead of 1.
		if n mod 2 = 1 then
			evenInt := n + 1;
		else
			evenInt := n;
		end if;

		return integer(ceil(log2(real(evenInt))));
	end function;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Derive the number of m bit words from a positive integer n.
	--
	-- This function is useful to aquire the number of words needed for memory
	-- storage or a counter maximum value for I/O state machines.
	-----------------------------------------------------------------------------
	function getWordCount(n : positive; m : positive) return positive is
	begin
		return integer(ceil(real(n)/real(m)));
	end function;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Resize a standard logic vector using "resize" defined on type unsigned.
	--
	-- This function is useful to bloat up a std_logic_vector without type-casting
	-- every time a resize is necessary.
	-----------------------------------------------------------------------------
	function resize_slv(val : std_logic_vector; len : integer) return std_logic_vector is
	begin
		return std_logic_vector(resize(unsigned(val), len));
	end function;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Create a standard logic vector of length len from integer val.
	--
	-- This function is useful for constant mappings of generic size signals.
	-----------------------------------------------------------------------------
	function const_slv(val : integer; len : integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(natural(val), len));
	end function;
	-----------------------------------------------------------------------------
	
	
	-----------------------------------------------------------------------------
	--        Procedures to help with test benches (simulation only)
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Generate the random std_logic_vector value of n bits using the seeds seed1
	-- and seed2.
	--
	-- Note: seed1 and seed2 must not both be 0! Otherwise, uniform does not work.
	-----------------------------------------------------------------------------
	procedure randomize(seed1, seed2 : inout integer; n : in positive; value : inout std_logic_vector) is
		variable rand_bit : integer;
		variable rand     : real;
	begin
		for i in 0 to n-1 loop
			randomize(seed1, seed2, 1, rand_bit);
			if rand_bit = 0 then
				value(i) := '0';
			else
				value(i) := '1';
			end if;  -- 0 or 1 
		end loop;  -- loop over n bits
	end procedure randomize;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Generate a random integer of at most value max and store it in value using
	-- the seeds seed1 and seed2.
	--
	-- Note: seed1 and seed2 must nor both be 0! Otherwise, uniform does not work.
	-----------------------------------------------------------------------------
	procedure randomize(seed1, seed2 : inout integer; max : in positive; value : inout integer) is
		variable rand : real;
	begin
		uniform(seed1, seed2, rand);
		value := integer(round(rand * real(max)));
	end procedure randomize;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Write the std_logic_vector value to the line variable provided as L in
	-- base 16 representation.
	--
	-- The procedure pads leading zeroes if necessary to make hwrite work when 
	-- length % 4 != 0.
	-----------------------------------------------------------------------------
	procedure hpwrite(L : inout line; value : in std_logic_vector) is
		variable hex_pad : std_logic_vector(integer(ceil(real(value'length)/4.0)*4.0)-1 downto 0);
	begin
		-- zero padding (up to 3 leading zeroes)
		hex_pad                          := (others => '0');
		hex_pad(value'length-1 downto 0) := value;
		-- use normal hwrite
		hwrite(L, hex_pad);
	end procedure hpwrite;
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-- Assert with text output (false vs correct)
	--
	-- The assertMatch procedure works for std_logic and std_logic_vector in the
	-- same way (procedure overloading).
	--
	-- The optional parameters are
	--   hex       : boolean (true)         - output as hex value
	--   sev_level : SEVERITY_LEVEL (error) - severity level for assert check
	-----------------------------------------------------------------------------
	procedure assertMatch(testResult, correctResult : in std_logic_vector; hex : boolean := true; sev_level : severity_level := error) is
		variable msg : line;
	begin
		-- deallocate to clear msg in case the simulator does not do this
		deallocate(msg);

		-- if hex parameter is given, print as hex (via padded hwrite)
		if hex then
			-- pad with zeroes to ensure hwrite to work
			hpwrite(msg, testResult);
			write (msg, string'(" should be "));
			hpwrite(msg, correctResult);
		-- otherwise print using bit representation
		else
			write(msg, testResult);
			write(msg, string'(" should be "));
			write(msg, correctResult);
		end if;  -- write in base 16

		-- assert the 
		assert (testResult = correctResult) report msg.all severity sev_level;
	end procedure assertMatch;

	-- overloaded procedure for std_logic
	procedure assertMatch(testResult, correctResult : in std_logic; sev_level : severity_level := error) is
		variable test    : std_logic_vector(0 downto 0);
		variable correct : std_logic_vector(0 downto 0);
	begin
		test(0)    := testResult;
		correct(0) := correctResult;

		assertMatch(test, correct, false, sev_level);
	end procedure assertMatch;

	procedure xstPrintFlagDesc(desc : in string; posLow : in integer; posHigh : in integer := -1; fail : boolean := false) is
		variable msg : line; 
	begin
		if posHigh = -1 then
			assert false report "[" & integer'image(posLow) & ":" & integer'image(posLow) & "] - " & desc severity note;
		else	
			assert false report "[" & integer'image(posHigh) & ":" & integer'image(posLow) & "] - " & desc severity note;
		end if;

		if fail then
			assert false report "XST Print Flag Description Terminate Flag" severity failure;
		end if;
	end procedure xstPrintFlagDesc;
	-----------------------------------------------------------------------------
end package body rzi_helper;
