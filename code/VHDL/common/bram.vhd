-------------------------------------------------------------------------------
-- Title      : Inferrable Block Memory
-- Project    : Common Modules
-------------------------------------------------------------------------------
-- File       : bram.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2011-08-04
-- Last update: 2013-10-16
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    This module implements an inferrable Xilinx BlockRAM. The size of the
--    memory must be defined by the generics
--        DATA_WIDTH
--        ADDRESS_WIDTH
--
--    Optionally, the following generics can customize the behavior:
--        RW_MODE     - Defines the read/write mode of the memory. Valid
--                      settings are:
--                         "RW" (read before write) *default*
--                         "WR" (write before read)
--                         "NO" (no change on write)
--
--        INIT_MEMORY - Defines if the memory is pre-initialized once.
--                      This options is false by *default*.
--
--    In case of INIT_MEMORY = true, the following options may be set:
--                          
--        INIT_FROM_FILE  - If set to true, the memory initialization vectors
--                          are read from a file, which is set by INIT_FILE.
--                          Otherwise, the generic INIT_VECTOR is used for
--                          initialization.
--                          This option is false by *default*.
--
--        INIT_REVERSED   - If set to true (and INIT_FROM_FILE is true), the
--                          memory content is initialized Bottom-Up instead
--                          of Top-Down. (TODO: is this correct?)
--                          This option is false by *default*
--
--        INIT_FORMAT_HEX - If set to true (and INIT_FROM_FILE is true), the
--                          content of INIT_FILE is assumed to be in base 16.
--                          Otherwise, the content is assumed to be in base 2.
--                          This option is false by *default*.
--
--        INIT_FILE       - This option contains a string to the content
--                          filename. It is only used if INIT_FROM_FILE is
--                          true.
--
--                          FORMAT: Each line of the file must contain the content
--                          of one memory address, >>starting from address 0<<.
--                          The content is read using read/hread, using MSB
--                          first.
--                          
--                          This option is "" by *default*.
--
--        INIT_VECTOR     - This option contains an unrestricted
--                          std_logic_vector to initialize the memory, if
--                          INIT_FROM_FILE is false.
--
--                          FORMAT: The vector is interpreted as MSB-first.
--                          The left-most sub-vector will move to the lowest
--                          position (0 if all bits are initialized), while the
--                          right-most sub-vector will be at the highest
--                          memory-address.
--                          
--                          This option is "" by *default*.
--
--    Known Issues:
--      - Init from file may assume full file content (2**ADDRESS_WIDTH entries)
--
--    Currently missing features:
--      - Enable ports
--      - Additional output buffers
--      - Different read/write width
--
--    Nice-to-have features:
--      - initialize using little/big endian
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2013 Ruhr-University Bochum
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-08-04  1.0      rzi     Created
-- 2011-08-05  1.1      rzi     Added different write modes
-- 2012-08-30  1.1a     rzi     Added assert to check for write modes
-- 2013-01-12  1.2      rzi     Added support for memory initialization
-- 2013-01-15  1.2a     rzi     Added asserts to check initialization options
-- 2013-03-28  1.3      rzi     Added INIT_FILL_ZEROES generic, useful for simulations
-- 2013-05-06  1.3a     rzi     Added "impure" keyword as VHDL'93 requires
-- 2013-10-16  1.4      ivm     Fixed RW_MODE priority, tested w/ V6, S3, S6 device families
-- 2013-10-16  1.5      rzi     Added rst for output register
-- 2013-10-16  1.5a     ivm     Added INIT_REVERSED generic
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- file i/o for initialization from file
use std.textio.all;
use IEEE.std_logic_textio.all;

entity bram is
	generic (
		DATA_WIDTH       : positive;                             -- width of the data input and data output for both ports
		ADDRESS_WIDTH    : positive;                             -- width of the address bus, defines the depth of the memory
		RW_MODE          : string           := "RW";             -- "RW" (read before write), "WR" (write before read), "NO" (no change)
		INIT_MEMORY      : boolean          := false;            -- initialize rom at all? (default: false)
		INIT_FILL_ZEROES : boolean          := true;             -- fill with zeroes if not fully initialized
		INIT_FROM_FILE   : boolean          := false;            -- if init_memory, do this from a file (init_file generic)? (default : false)
		INIT_REVERSED    : boolean          := false;            -- if init_from_file, assume memory content reversed?
		INIT_FORMAT_HEX  : boolean          := false;            -- is the init file radix 16 [else 2]? (default: false)
		INIT_FILE        : string           := "";               -- provides filename in case init_from_file is true
		INIT_VECTOR      : std_logic_vector := ""                -- provides content in case init_from_file is false
	);
	port (
		clkA  : in  std_logic;                                   -- port A: clock input
		weA   : in  std_logic;                                   -- port A: write enable (active high)
		rstA  : in  std_logic;                                   -- port A: reset output (active high)
		addrA : in  std_logic_vector(ADDRESS_WIDTH-1 downto 0);  -- port A: address bus
		dinA  : in  std_logic_vector(DATA_WIDTH-1 downto 0);     -- port A: data input
		doutA : out std_logic_vector(DATA_WIDTH-1 downto 0);     -- port A: data output

		clkB  : in  std_logic;                                   -- port B: clock input
		weB   : in  std_logic;                                   -- port B: write enable (active high)
		rstB  : in  std_logic;                                   -- port B: reset output (active high)
		addrB : in  std_logic_vector(ADDRESS_WIDTH-1 downto 0);  -- port B: address bus
		dinB  : in  std_logic_vector(DATA_WIDTH-1 downto 0);     -- port B: data input
		doutB : out std_logic_vector(DATA_WIDTH-1 downto 0)      -- port B: data output
	);
end bram;

architecture Behavioral of bram is
	-----------------------------------------------------------------------------
	--                                Types
	-----------------------------------------------------------------------------
	-- 2^ADDRESS_WIDTH x DATA_WIDTH memory
	type ram_content is array ((2**ADDRESS_WIDTH)-1 downto 0)
	of std_logic_vector(DATA_WIDTH-1 downto 0);

	-----------------------------------------------------------------------------
	--                               Functions
	-----------------------------------------------------------------------------
	impure function InitializeMemory (init : boolean) return ram_content is
	file vector_file      : text;
	variable lineIn       : line;
	variable count        : integer;
	variable memory_line  : std_logic_vector(DATA_WIDTH-1 downto 0);
	variable padded_init  : std_logic_vector(((2**ADDRESS_WIDTH)*DATA_WIDTH)-1 downto 0);
	variable input_vector : std_logic_vector(INIT_VECTOR'length-1 downto 0);
	variable memory       : ram_content;
	variable msg          : line;
begin
	if init then
		-- if "fill with zeroes" is selected, clear padded_init
		if INIT_FILL_ZEROES then
			padded_init := (others => '0');
		end if;

		-- initialize padded_init from file
		if INIT_FROM_FILE then
			-- reset count
			count := 0;

			-- open file
			file_open(vector_file, INIT_FILE);

			read_loop : while not endfile(vector_file) loop
				-- read new line
				readline(vector_file, lineIn);
				-- skip comments
				next when (lineIn(lineIn'left) = '-');

				-- read into memory_line
				if INIT_FORMAT_HEX then
					hread(lineIn, memory_line);
				else
					read(lineIn, memory_line);
				end if;

				-- store line in memory iff in range of ram_content
				if count < 2**ADDRESS_WIDTH then
					padded_init((count+1)*DATA_WIDTH-1 downto count*DATA_WIDTH) := memory_line;
				end if;

				-- adjust counter
				count := count + 1;
			end loop read_loop;

		-- initialize padded_init from vector
		else
			-- beware: unconstrained std_logic_vector is 0 to n
			input_vector := INIT_VECTOR;
			for i in input_vector'range loop
				padded_init(i) := input_vector(i);
			end loop;
		end if;  -- initialize from file or vector?

		-- fill the memory reversed to match the addressing from file initialization
		for i in 0 to 2**ADDRESS_WIDTH-1 loop
			-- reverse the reverse process and initialize from bottom up
			if INIT_REVERSED then
				memory(i) := padded_init((i+1)*DATA_WIDTH -1 downto i*DATA_WIDTH);
			else
				memory(2**ADDRESS_WIDTH-1-i) := padded_init((i+1)*DATA_WIDTH -1 downto i*DATA_WIDTH);
			end if;
		end loop;

	end if;  -- initialize memory ?

	-- return the initialized memory
	return memory;
end;

-----------------------------------------------------------------------------
--                           Shared Variables
-----------------------------------------------------------------------------
shared variable ram : ram_content := InitializeMemory (INIT_MEMORY);  -- shared memory for dual port mode

-----------------------------------------------------------------------------
--                               Signals
-----------------------------------------------------------------------------
signal portA_out : std_logic_vector(DATA_WIDTH-1 downto 0);  -- output of port A
signal portB_out : std_logic_vector(DATA_WIDTH-1 downto 0);  -- output of port B

begin
	-- assert correct use of generics
	assert RW_MODE = "WR" or RW_MODE = "RW" or RW_MODE = "NO"
	report "BRAM module: Invalid configuration of generic RW_MODE!" severity failure;
	assert (not INIT_MEMORY) or (not INIT_FROM_FILE) or (INIT_FROM_FILE and INIT_FILE'length > 0)
	report "BRAM module: Invalid configuration; INIT_FILE must contain a filename if (INIT_MEMORY and INIT_FROM_FILE)." severity failure;
	assert (not INIT_MEMORY) or (INIT_FROM_FILE) or (not INIT_FROM_FILE and INIT_VECTOR'length > 0)
	report "BRAM module: Invalid configuration; INIT_VECTOR must contain data if (INIT_MEMORY and !INIT_FROM_FILE)." severity failure;

	-- port A read/write process
	portA : process (clkA)
	begin
		if rising_edge(clkA) then
			-- mode: read before write
			if RW_MODE = "RW" then
				-- reset or assign output
				if rstA = '1' then
					portA_out <= (others => '0');
				else 
					portA_out <= ram(to_integer(unsigned(addrA)));
				end if; -- reset

				-- check write flag
				if weA = '1' then
					ram(to_integer(unsigned(addrA))) := dinA;
				end if; -- write enable

			-- mode: write before read
			elsif RW_MODE = "WR" then
				-- check write flag
				if weA = '1' then
					ram(to_integer(unsigned(addrA))) := dinA;
				end if; -- write enable

				-- reset or assign output
				if rstA = '1' then
					portA_out <= (others => '0');
				else
					portA_out <= ram(to_integer(unsigned(addrA)));
				end if; -- reset

			-- mode: no change
			elsif RW_MODE = "NO" then
				-- check write mode
				if weA = '1' then
					ram(to_integer(unsigned(addrA))) := dinA;

					-- check reset flag
					if rstA = '1' then
						portA_out <= (others => '0');
					end if; -- reset
				else
					-- reset or assign output
					if rstA = '1' then
						portA_out <= (others => '0');
					else
						portA_out <= ram(to_integer(unsigned(addrA)));
					end if; -- reset
				end if; -- write enable
			end if; -- mode
		end if; -- rising edge
	end process;

	-- assign portA output
	doutA <= portA_out;

	-- port B read/write process
	portB : process (clkB)
	begin
		if rising_edge(clkB) then
			-- mode: read before write
			if RW_MODE = "RW" then
				-- reset or assign output
				if rstB = '1' then
					portB_out <= (others => '0');
				else 
					portB_out <= ram(to_integer(unsigned(addrB)));
				end if; -- reset

				-- check write flag
				if weB = '1' then
					ram(to_integer(unsigned(addrB))) := dinB;
				end if; -- write enable

			-- mode: write before read
			elsif RW_MODE = "WR" then
				-- check write flag
				if weB = '1' then
					ram(to_integer(unsigned(addrB))) := dinB;
				end if; -- write enable

				-- reset or assign output
				if rstB = '1' then
					portB_out <= (others => '0');
				else
					portB_out <= ram(to_integer(unsigned(addrB)));
				end if; -- reset

			-- mode: no change
			elsif RW_MODE = "NO" then
				-- check write mode
				if weB = '1' then
					ram(to_integer(unsigned(addrB))) := dinB;

					-- check reset flag
					if rstB = '1' then
						portB_out <= (others => '0');
					end if; -- reset
				else
					-- reset or assign output
					if rstB = '1' then
						portB_out <= (others => '0');
					else
						portB_out <= ram(to_integer(unsigned(addrB)));
					end if; -- reset
				end if; -- write enable
			end if; -- mode
		end if; -- rising edge
	end process;

	-- assign portB output
	doutB <= portB_out;

end Behavioral;
