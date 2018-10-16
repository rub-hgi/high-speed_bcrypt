-------------------------------------------------------------------------------
-- Title      : blowfish encryption Module
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : blowfish_encryption.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
--            : Ralf Zimmerman <ralf.zimmermann@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-03-11
-- Last update: 2014-07-30
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description:
--    This module implements a normal blowfish encryption (block length 64bit)
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-03-13  1.0      fwi     Created, manually checked with key=0
-- 2014-07-30  1.0      fwi rzi rewritten, for 1 cycle per round operation
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.pkg_bcrypt.all;
use work.rzi_helper.all;

Library UNISIM;
use UNISIM.vcomponents.all;

--Library UNIMACRO;
--use UNIMACRO.vcomponents.all;

entity blowfish_encryption is
	Port (
		clk         : in  std_logic;
--		rst         : in  std_logic;
		start       : in  std_logic;
--		din         : in  std_logic_vector(63 downto 0);

		sbox0_dout  : in  std_logic_vector(31 downto 0);
		sbox1_dout  : in  std_logic_vector(31 downto 0);
		sbox2_dout  : in  std_logic_vector(31 downto 0);
		sbox3_dout  : in  std_logic_vector(31 downto 0);
		subkey_doutA: in  std_logic_vector(31 downto 0);
		subkey_doutB: in  std_logic_vector(31 downto 0);

		dout        : out std_logic_vector(63 downto 0);
		done        : out std_logic;

		sbox_rst    : out std_logic;
		sbox0_addr  : out std_logic_vector( 7 downto 0);
		sbox1_addr  : out std_logic_vector( 7 downto 0);
		sbox2_addr  : out std_logic_vector( 7 downto 0);
		sbox3_addr  : out std_logic_vector( 7 downto 0);
		subkey_rstA : out std_logic;
		subkey_addrA: out std_logic_vector( 4 downto 0);
		subkey_rstB : out std_logic;
		subkey_addrB: out std_logic_vector( 4 downto 0)
	);
end blowfish_encryption;

architecture Behavioral of blowfish_encryption is
	-- --------------------------------------------------------------------- --
	--                               Signals
	-- --------------------------------------------------------------------- --
	signal ctext_din : std_logic_vector(63 downto 0);
	signal ctext_dout : std_logic_vector(63 downto 0);

	signal left,right   : std_logic_vector(31 downto 0);
	signal outL : std_logic_vector(31 downto 0);
	signal outR : std_logic_vector(31 downto 0);

	signal f_out        : std_logic_vector(31 downto 0);

	signal roundcnt_ce : std_logic;
	signal roundcnt_sr : std_logic;
	signal roundcnt    : std_logic_vector(4 downto 0);

	signal addrcnt_ce : std_logic;
	signal addrcnt_sr : std_logic;
	signal addrcnt    : std_logic_vector(4 downto 0);

	signal rst : std_logic;

begin

	-- ctext-Register
	ctext_register : entity work.nBitReg
		generic map (
			ASYNC       => false,
			BIT_WIDTH   => 64
		)
		port map (
			clk         => clk,
			sr          => start,
			srinit      => const_slv(0, 64),
			ce          => '1',
			din         => ctext_din,
			dout        => ctext_dout
		);
	ctext_din <= outR & outL;

	-- test
	process(clk)
	begin
		if rising_edge(clk) then
			rst <= start;
		end if;
	end process;


	-- --------------------------------------------------------------------- --
	-- Instantiation    general logic, f function, round counter
	-- --------------------------------------------------------------------- --
	left  <= ctext_dout(63 downto 32);
	right <= ctext_dout(31 downto  0);

--	ctext_din <= din when rst = '1' else
--				 outR & outL;

	sbox0_addr <= ctext_din(31 downto 24);
	sbox1_addr <= ctext_din(23 downto 16);
	sbox2_addr <= ctext_din(15 downto  8);
	sbox3_addr <= ctext_din( 7 downto  0);

	-- f function
	f_out <= std_logic_vector(unsigned(std_logic_vector(unsigned(sbox0_dout) + unsigned(sbox1_dout)) xor sbox2_dout) + unsigned(sbox3_dout));

	-- round output
	outL <= subkey_doutA xor f_out xor left;
	outR <= subkey_doutB xor right;

	-- round counter
	round_counter : entity work.nBitCounter
		generic map (
			ASYNC       => false,
			BIT_WIDTH   => 5
		)
		port map (
			clk         => clk,
			ce          => roundcnt_ce,
			sr          => roundcnt_sr,
			srinit      => const_slv(0, 5),
			count_up    => '1',
			dout        => roundcnt
		);
	roundcnt_sr <= rst or start;
	roundcnt_ce <= '1';

	-- address counter, reset to 1
	address_counter : entity work.nBitCounter
		generic map (
			ASYNC       => false,
			BIT_WIDTH   => 5
		)
		port map (
			clk         => clk,
			ce          => addrcnt_ce,
			sr          => addrcnt_sr,
			srinit      => const_slv(1, 5),
			count_up    => '1',
			dout        => addrcnt
		);
	-- reset address counter on global rst or in round 17
--	addrcnt_sr <= rst or (roundcnt(4) and roundcnt(0));
	addrcnt_sr <= start;
	addrcnt_ce <= '1';

	-- choose subkeys
	subkey_addrA <= const_slv(0, subkey_addrA'length);
	subkey_rstA <= not rst;
	subkey_addrB <= addrcnt;
	subkey_rstB  <= '0';

	sbox_rst <= rst or start;

	-- output
	done <= roundcnt(4);
	dout <= outR & outL;

end architecture Behavioral;
