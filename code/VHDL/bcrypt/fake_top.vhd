-------------------------------------------------------------------------------
-- Title      : bcrypt bruteforce Topmodule
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : bcrypt.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-02-18
-- Last update: 2014-04-16
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description:
--    top module, controlls everything
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-02-18  1.0      fwi     Created
-- 2014-04-16  1.01     fwi     Changed to Password-Storage in BRAMs
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.pkg_bcrypt.all;
use work.rzi_helper.all;
-- ------------------------------------------------------------------------- --
-- used for FIFO instantiation
-- ------------------------------------------------------------------------- --
    Library UNISIM;
    use UNISIM.vcomponents.all;
    Library UNIMACRO;
    use UNIMACRO.vcomponents.all;
-- ------------------------------------------------------------------------- --

entity fake_top is
	generic (
		NUMBER_OF_QUADCORES : positive := 2);
	port (
		clk_100		: in  std_logic;
		bcrypt_clk 	: in  std_logic;
		rst 		: in  std_logic;
		start 		: in  std_logic;
		key_we 		: in  std_logic;
		key_out 	: in  std_logic_vector(31 downto 0);
		done 		: in  std_logic;
		done_out	: out std_logic;
		data_out    : out std_logic_vector(31 downto 0)
	);
end fake_top;

architecture behavioral of fake_top is
    -- --------------------------------------------------------------------- --
    --                                Types
    -- --------------------------------------------------------------------- --
    type slv8_ary_t is array (integer range <>) of
        std_logic_vector (7 downto 0);
    type states_t is (RESET, CRACK, DUMP_FIFO);
    -- --------------------------------------------------------------------- --
    --                               Signals
    -- --------------------------------------------------------------------- --
    -- FSM
    signal current_state: states_t;
    signal next_state   : states_t;
    -- FIFO
    signal FIFO_dout    : std_logic_vector(31 downto 0);
    signal FIFO_empty   : std_logic;
    signal FIFO_rden    : std_logic;
    signal FIFO_valid   : std_logic;

    signal key_addr_ce  : std_logic;
    signal key_addr_sr  : std_logic;
    signal key_addr     : std_logic_vector(3 downto 0);

    signal mem  : slv8_ary_t(0 to 63)
    	:= (others => (others => '0'));
    signal ram_addr_int : integer range 0 to 63;
    signal key_addr_int : integer range 0 to  5;

    alias  bus_clk      : std_logic is clk_100;
    alias  status_reg   : std_logic_vector(7 downto 0) is mem(63);
    alias  bcrypt_reset : std_logic is rst;  --status_reg(0);
    alias  bcrypt_start : std_logic is start;--status_reg(1);
    alias  bcrypt_done  : std_logic is status_reg(4);
    alias  bcrypt_succ  : std_logic is status_reg(5);
begin
    -- ------------------------------------------------------------------------
    -- Instantiation    fifo for clock domain crossing
    -- ------------------------------------------------------------------------
    fifo_clock_domain_crossing : entity work.fifo_core
        PORT MAP (
            wr_clk  => bcrypt_clk,
            rd_clk  => bus_clk,
            din     => key_out,
            wr_en   => key_we,
            rd_en   => FIFO_rden,
            dout    => FIFO_dout,
            full    => open,
            empty   => FIFO_empty,
            valid   => FIFO_valid
        );

    done_out    <= bcrypt_done;
    data_out 	<= FIFO_dout;

    -- --------------------------------------------------------------------- --
    -- Instantiation    key_addr_counter
    -- --------------------------------------------------------------------- --
    key_addr_counter : entity work.nBitCounter
        generic map (
            ASYNC       => false,
            BIT_WIDTH   => 4)
        port map (
            clk         => bus_clk,
            sr          => key_addr_sr,
            ce          => key_addr_ce,
            srinit      => const_slv(0, 4),
            count_up    => '1',
            dout        => key_addr
        );
    key_addr_int<= conv_integer(key_addr);

    -- --------------------------------------------------------------------- --
    -- Instantiation    DMA-endpoint memory
    -- --------------------------------------------------------------------- --
    memory : process (
        bus_clk, FIFO_valid, key_addr_int, FIFO_dout, FIFO_empty, done)
        --host_write_wren, host_write_data, ram_addr_int, host_read_rden,
    begin
        if rising_edge(bus_clk) then
            -- host write
--            if (host_write_wren = '1') then
--              if (ram_addr_int <= 39) then
--                mem(ram_addr_int) <= host_write_data;
--              end if;
--              if (ram_addr_int = 63) then
--                mem(ram_addr_int)(3 downto 0) <= host_write_data(3 downto 0);
--              end if;
--            end if;
            -- fpga write
            if (FIFO_valid = '1' and key_addr_int <= 4) then
                mem(43+key_addr_int*4) <= FIFO_dout( 7 downto  0); --key_out;
                mem(42+key_addr_int*4) <= FIFO_dout(15 downto  8); --key_out;
                mem(41+key_addr_int*4) <= FIFO_dout(23 downto 16); --key_out;
                mem(40+key_addr_int*4) <= FIFO_dout(31 downto 24); --key_out;
            end if;
            -- keep status register up to date
            bcrypt_done <= done and FIFO_empty;
            -- host read
--            if (host_read_rden = '1') then
--                host_read_data <= mem(ram_addr_int);
--            end if;
        end if;
    end process memory;

    -- --------------------------------------------------------------------- --
    -- FSM      controlls bcrypt_cracker, writes fifo content to memory
    --          which can be read out by the host.
    -- --------------------------------------------------------------------- --
    -- FSM: state change
    fsm_state : process(bus_clk, bcrypt_reset)
    begin
        if rising_edge(bus_clk) then
            if bcrypt_reset = '1' then
                current_state <= RESET;
            else
                current_state <= next_state;
            end if; -- bcrypt_reset
        end if; -- clk
    end process fsm_state;

    -- FSM: control logic
    fsm_ctrl : process (
    	current_state, bcrypt_start, done, FIFO_empty, FIFO_valid)
    begin
        -- default values
        key_addr_sr <= '1';
        key_addr_ce <= '1';
        FIFO_RDEN <= '0';
        next_state  <= current_state;

        -- FSM states
        case current_state is
            -- startup
            when RESET =>
                if bcrypt_start = '1' then
                    next_state <= CRACK;
                end if;
            when CRACK =>
                if done = '1' then
                    next_state <= DUMP_FIFO;
                end if;
            when DUMP_FIFO =>
                if FIFO_EMPTY = '0' then
                    key_addr_sr <= not FIFO_valid;
                    FIFO_RDEN <= '1';
                end if;
        end case; -- state

    end process fsm_ctrl;
end behavioral;
