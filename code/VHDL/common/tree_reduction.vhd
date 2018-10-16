-------------------------------------------------------------------------------
-- Title      : Controlled, Buffered Result Reduction (Tree-Buffer Reduction)
-- Project    : Common Modules
-- ----------------------------------------------------------------------------
-- File       : tree_reduction.vhd
-- Author     : Ralf Zimmermann <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-07-31
-- Last update: 2014-07-31
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description:
--    Reduce the output of an n x m bit data array using a one-hot control signal.
--    If more than one control signal is set, a deterministic behavior is used.
--    
-- TODO: test and add full description including parameters
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-07-31  1.0      rzi     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.rzi_helper.all;

entity tree_buffer is

	generic (
		ASYNC   : boolean;   -- use asynchronous reset
		N       : positive;  -- number of data elements
		M       : positive;  -- bitwidth of data elements
		LUTSIZE : positive   -- number of input per LUT
	);
	port (
		clk  : in  std_logic;
		rst  : in  std_logic;
		ce   : in  std_logic; 
		din  : in  std_logic_vector(N*M-1 downto 0);
		ctrl : in  std_logic_vector(N-1 downto 0);
		dout : out std_logic_vector(M-1 downto 0);
		valid: out std_logic
	);
end tree_buffer;

architecture Behavioral of tree_buffer is
    -- --------------------------------------------------------------------- --
	--                              Functions
    -- --------------------------------------------------------------------- --
	function getRegisters(depth : integer) return integer is
		variable regs : integer; 
	begin
		regs := N;

		if depth > 0 then
			for i in 0 to depth-1 loop
				regs := getWordCount(regs, LUTSIZE);
			end loop;
		end if;

		return regs;
	end function;

	function getDepth(elements : integer) return integer is
		variable res : integer;
		variable remainder : integer;
	begin
		res := 1;
		remainder := elements;

		while remainder > 1 loop
			remainder := integer(ceil(real(remainder)/real(LUTSIZE)));
			res := res + 1;
		end loop;
		
		return res;
	end function;

    -- --------------------------------------------------------------------- --
    --                              Types
    -- --------------------------------------------------------------------- --
	type row_data is array (0 to N-1) of std_logic_vector(M-1 downto 0);
	type tree_data is array(0 to getDepth(N)-1) of row_data;
	type row_ctrl is array (0 to N-1) of std_logic; 
	type tree_ctrl is array(0 to getDepth(N)-1) of row_ctrl;

    -- --------------------------------------------------------------------- --
    --                              Signals
    -- --------------------------------------------------------------------- --
	signal tree_ctrl_in  : tree_ctrl;
	signal tree_ctrl_out : tree_ctrl;
	signal tree_data_in  : tree_data;
	signal tree_data_out : tree_data;
begin

	-- generate reduction tree
	gen_depth : for i in 0 to getDepth(N)-1 generate
		-- generate registers per tree depth
		gen_width : for j in 0 to getRegisters(i)-1 generate
			
			-- generate all registers
			data_reg : entity work.nBitReg
				generic map (
					ASYNC     => ASYNC,
					BIT_WIDTH => M
				)
				port map (
					clk    => clk,
					sr     => rst,
					srinit => const_slv(0, M),
					ce     => ce,
					din    => tree_data_in(i)(j),
					dout   => tree_data_out(i)(j)
				);

			ctrl_reg : entity work.DFF
				generic map (
					ASYNC     => ASYNC
				)
				port map (
					clk    => clk,
					sr     => rst,
					srinit => '0',
					ce     => ce,
					D      => tree_ctrl_in(i)(j),
					Q      => tree_ctrl_out(i)(j)
				);

			-- map input to tree input
			map_input : if i = 0 generate
				tree_ctrl_in(0)(j) <= ctrl(j);
				tree_data_in(0)(j) <= din( (N-j)*M-1 downto (N-j-1)*M );
			end generate; 

			-- map tree buffers
			map_reduction : if i > 0 generate
				-- reduction
				process(tree_data_out, tree_ctrl_out)
					variable data : std_logic_vector(M-1 downto 0);
					variable ctrl : std_logic; 
					variable rng : integer;
				begin
					-- how many registers do we combine?
					rng := min((getRegisters(i-1) - j*LUTSIZE), LUTSIZE);
					
					-- one hot select in LUTSIZE splits
					data := tree_data_out(i-1)(j*LUTSIZE);
					ctrl := tree_ctrl_out(i-1)(j*LUTSIZE);

					for k in 1 to rng-1 loop
						if tree_ctrl_out(i-1)(j*LUTSIZE + k) = '1' then
							data := tree_data_out(i-1)(j*LUTSIZE + k);
							ctrl := tree_ctrl_out(i-1)(j*LUTSIZE + k);
						end if;
					end loop;
				
					tree_data_in(i)(j) <= data;
					tree_ctrl_in(i)(j) <= ctrl;
				end process;

			end generate;
		end generate;
	end generate;

	dout  <= tree_data_out(getDepth(N)-1)(0);
	valid <= tree_ctrl_out(getDepth(N)-1)(0);

end architecture Behavioral;
    
