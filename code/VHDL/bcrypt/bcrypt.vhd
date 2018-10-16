-------------------------------------------------------------------------------
-- Title      : bcrypt Topmodule
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : bcrypt.vhd
-- Author     : Ralf Zimmermann  <ralf.zimmermann@rub.de>
--              Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2013-12-02
-- Last update: 2014-05-05
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description:
--    This module implements the top-level of a bcrypt derivation module.
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-12-02  1.0      rzi     Created
-- 2014-03-06  1.01     fwi     changed module in/outs, finished initialization
-- 2014-03-24  1.02     fwi     finished first, unoptimized version
-- 2014-05-05  1.03     fwi     optimized FSM, outsources blowfish encryption
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.pkg_bcrypt.all;
use work.rzi_helper.all;

entity bcrypt is
    port (
        clk             : in  std_logic;  -- clock input
        rst             : in  std_logic;  -- rst (active high)
        salt            : in  std_logic_vector (SALT_LENGTH-1 downto 0);
        start_expand_key: in  std_logic;
        -- sbox init access
        memory_init     : out std_logic;  -- signals memory init state
        pipeline_full   : in  std_logic;
        sbox_init_addr  : in  std_logic_vector ( 8 downto 0);
        sbox0_init_dout : in  std_logic_vector (31 downto 0);
        sbox1_init_dout : in  std_logic_vector (31 downto 0);
        sbox2_init_dout : in  std_logic_vector (31 downto 0);
        sbox3_init_dout : in  std_logic_vector (31 downto 0);
        skinit_dout     : in  std_logic_vector (31 downto 0);
        -- key access
        key_addr        : out std_logic_vector ( 4 downto 0);
        key_dout        : in  std_logic_vector (31 downto 0);
        key_done        : out std_logic;
        -- valid output data
        dout_valid      : out std_logic;
        -- output data
        dout            : out std_logic_vector (63 downto 0)
    );
end bcrypt;

architecture Behavioral of bcrypt is
    -- --------------------------------------------------------------------- --
    --                                Types
    -- --------------------------------------------------------------------- --
    type states_t is (
		RESET,
		-- initialize memory and wait for start signal
		WAIT_FOR_PIPELINE, INIT_MEMORY, WAIT_FOR_MEM_ACCESS,
		-- expand key (setup and cost loop)
		EKEY_KEY_XOR, EKEY_ENC_P_PREPARE, EKEY_ENC_P, EKEY_ENC_UPDATE_SUBKEY,
		EKEY_ENC_SBOX_PREPARE_START, EKEY_ENC_SBOX_PREPARE_CONTINUE, EKEY_ENC_SBOX,
		-- encrypt magic word
		PREPARE_ENC_MAGIC_HIGH, PREPARE_ENC_MAGIC_MIDDLE, PREPARE_ENC_MAGIC_LOW,
		ENC_MAGIC_HIGH, ENC_MAGIC_MIDDLE, ENC_MAGIC_LOW,
		-- wait for reset
		FINISH
    );
    -- --------------------------------------------------------------------- --
    --                               Signals
    -- --------------------------------------------------------------------- --
    -- FSM
    signal current_state : states_t;
    signal next_state    : states_t;

    signal sbox_rst   : std_logic;
    -- sbox 0 memory
    signal sbox0_we   : std_logic;
    signal sbox0_addr : std_logic_vector( 8 downto 0);
    signal sbox0_din  : std_logic_vector(31 downto 0);
    signal sbox0_dout : std_logic_vector(31 downto 0);
    -- sbox 1 memory
    signal sbox1_we   : std_logic;
    signal sbox1_addr : std_logic_vector( 8 downto 0);
    signal sbox1_din  : std_logic_vector(31 downto 0);
    signal sbox1_dout : std_logic_vector(31 downto 0);
    -- sbox 2 memory
    signal sbox2_we   : std_logic;
    signal sbox2_addr : std_logic_vector( 8 downto 0);
    signal sbox2_din  : std_logic_vector(31 downto 0);
    signal sbox2_dout : std_logic_vector(31 downto 0);
    -- sbox 3 memory
    signal sbox3_we   : std_logic;
    signal sbox3_addr : std_logic_vector( 8 downto 0);
    signal sbox3_din  : std_logic_vector(31 downto 0);
    signal sbox3_dout : std_logic_vector(31 downto 0);

    -- subkey memory
    signal subkey_weA   : std_logic;
    signal subkey_rstA  : std_logic;
    signal subkey_addrA : std_logic_vector( 8 downto 0);
    signal subkey_dinA  : std_logic_vector(31 downto 0);
    signal subkey_doutA : std_logic_vector(31 downto 0);

    signal subkey_weB   : std_logic;
    signal subkey_rstB  : std_logic;
    signal subkey_addrB : std_logic_vector( 8 downto 0);
    signal subkey_dinB  : std_logic_vector(31 downto 0);
    signal subkey_doutB : std_logic_vector(31 downto 0);

	-- active sbox selection
	signal active_sbox_ce : std_logic;
	signal active_sbox_sr : std_logic;
	signal active_sbox_dout : std_logic_vector(3 downto 0);

    -- cost counter
    signal costcnt_ce  : std_logic;
    signal costcnt_rst : std_logic;
    signal costcnt     : std_logic_vector(COST+1 downto 0);

	-- loop counter + delay + end counter (loop counter + 1)
    signal loopcnt_ce     : std_logic;
    signal loopcnt_rst    : std_logic;
    signal loopcnt        : std_logic_vector(8 downto 0);
    signal loopcnt_d      : std_logic_vector(8 downto 0);
    signal loopendcnt     : std_logic_vector(9 downto 0);
	signal loopendcnt_ce  : std_logic;
	signal loopendcnt_rst : std_logic;

	-- salt word
	signal salt_word : std_logic_vector(31 downto 0);

	-- flag: still in first expandKey?
	signal firstExpand_flag_rst : std_logic;
	signal firstExpand_flag_ce  : std_logic;
	signal firstExpand_flag     : std_logic;
	-- flag: use low DWORD of salt?
	signal useSaltDwordLow_flag_rst : std_logic;
	signal useSaltDwordLow_flag_ce  : std_logic;
	signal useSaltDwordLow_flag_in  : std_logic;
	signal useSaltDwordLow_flag     : std_logic;
	-- flag: use salt as key parameter?
	signal useSaltAsKey_flag : std_logic;

	-- blowfish
    signal bf_start         : std_logic;
    signal bf_din           : std_logic_vector(63 downto 0);
    signal bf_done          : std_logic;
    signal bf_dout          : std_logic_vector(63 downto 0);
    signal bf_sbox0_addr    : std_logic_vector( 7 downto 0);
    signal bf_sbox1_addr    : std_logic_vector( 7 downto 0);
    signal bf_sbox2_addr    : std_logic_vector( 7 downto 0);
    signal bf_sbox3_addr    : std_logic_vector( 7 downto 0);
	signal bf_sbox_rst      : std_logic;
	signal bf_subkey_rstA   : std_logic;
    signal bf_subkey_addrA  : std_logic_vector( 4 downto 0);
	signal bf_subkey_rstB   : std_logic;
    signal bf_subkey_addrB  : std_logic_vector( 4 downto 0);
    -- buffer signal
	signal bf_dout_d        : std_logic_vector(63 downto 0);
	signal bf_dout_dd       : std_logic_vector(63 downto 0);

begin
    -- ------------------------------------------------------------------------
    -- Instantiation    working registers/memories
    -- ------------------------------------------------------------------------
    -- SBOX 0 and SBOX 1
    sbox01 : entity work.bram
        generic map (
            DATA_WIDTH       => 32,
            ADDRESS_WIDTH    => 9,
            RW_MODE          => "WR", -- write before read
            INIT_MEMORY      => false
        )
        port map (
            clkA  => clk,
            weA   => sbox0_we,
            rstA  => sbox_rst,
            addrA => sbox0_addr,
            dinA  => sbox0_din,
            doutA => sbox0_dout,
            clkB  => clk,
            weB   => sbox1_we,
            rstB  => sbox_rst,
            addrB => sbox1_addr,
            dinB  => sbox1_din,
            doutB => sbox1_dout
        );
    -- SBOX 2 and SBOX 3
    sbox23 : entity work.bram
        generic map (
            DATA_WIDTH       => 32,
            ADDRESS_WIDTH    => 9,
            RW_MODE          => "WR", -- write before read
            INIT_MEMORY      => false
        )
        port map (
            clkA  => clk,
            weA   => sbox2_we,
            rstA  => sbox_rst,
            addrA => sbox2_addr,
            dinA  => sbox2_din,
            doutA => sbox2_dout,
            clkB  => clk,
            weB   => sbox3_we,
            rstB  => sbox_rst,
            addrB => sbox3_addr,
            dinB  => sbox3_din,
            doutB => sbox3_dout
        );

    -- Subkey Memory
    subkey_memory : entity work.bram
        generic map (
            DATA_WIDTH       => 32,
            ADDRESS_WIDTH    => 9,
            RW_MODE          => "WR", -- write before read
            INIT_MEMORY      => true,
            INIT_VECTOR      => x"00000000"
        )
        port map (
            clkA  => clk,
            weA   => subkey_weA,
            rstA  => subkey_rstA,
            addrA => subkey_addrA,
            dinA  => subkey_dinA,
            doutA => subkey_doutA,
            clkB  => clk,
            weB   => subkey_weB,
            rstB  => subkey_rstB,
            addrB => subkey_addrB,
            dinB  => subkey_dinB,
            doutB => subkey_doutB
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    Active SBox Shiftreg
    --                  marks the SBox which is currently updated
    -- --------------------------------------------------------------------- --
    -- key shift register
    active_sbox_shiftreg : entity work.nxmBitShiftReg
        generic map (
            ASYNC => false,
            N     => 4,
            M     => 1
        )
        port map (
            clk    => clk,
            ce     => active_sbox_ce,
            sr     => active_sbox_sr,
            srinit => "0001",
            opmode => "11", -- [Rot?, Left?] -- [rotate,left]
            din    => const_slv(0, 1),
            dout   => open,
            dout_f => active_sbox_dout
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    cost-Counter for 2^cost expand key's
	--                  reset to 2, count up to 2^(cost+2)
    -- --------------------------------------------------------------------- --
    cost_counter : entity work.nBitCounter
        generic map (
            ASYNC       => false,
            BIT_WIDTH   => COST+2
		)
        port map (
            clk         => clk,
            sr          => costcnt_rst,
            ce          => costcnt_ce,
            srinit      => const_slv(2, COST+2),
            count_up    => '1',
            dout        => costcnt
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    loop-Counter for initialization and ECB encryptions
    -- --------------------------------------------------------------------- --
    loop_counter : entity work.nBitCounter
        generic map (
            ASYNC       => false,
            BIT_WIDTH   => 9
		)
        port map (
            clk         => clk,
            sr          => loopcnt_rst,
            ce          => loopcnt_ce,
            srinit      => (others=>'0'),
            count_up    => '1',
            dout        => loopcnt
        );

	loop_counter_delay : entity work.nBitReg
		generic map (
			ASYNC => FALSE,
			BIT_WIDTH => 9
		)
		port map (
            clk         => clk,
            sr          => '0',
            srinit      => const_slv(0, 9),
            ce          => '1',
			din         => loopcnt,
			dout        => loopcnt_d
		);

	-- we use the loop end counter as a +1 counter (reset to 1)
	-- for better logic usage
	loop_end_counter : entity work.nBitCounter
        generic map (
            ASYNC       => false,
            BIT_WIDTH   => 10
		)
        port map (
            clk         => clk,
            sr          => loopendcnt_rst,
            ce          => loopendcnt_ce,
			srinit      => const_slv(1, loopendcnt'length),
            count_up    => '1',
            dout        => loopendcnt
        );
	loopendcnt_rst <= loopcnt_rst;
	loopendcnt_ce <= loopcnt_ce;

	-- flags
	flag_firstExpandKey_dff : entity work.dff
		generic map (
			ASYNC => false
		)
		port map (
			clk    => clk,
			sr     => firstExpand_flag_rst,
			srinit => '0',
			ce     => firstExpand_flag_ce,
			D      => '1',
			Q      => firstExpand_flag
		);

	flag_useSaltDwordLow_dff : entity work.dff
		generic map (
			ASYNC => false
		)
		port map (
			clk    => clk,
			sr     => useSaltDwordLow_flag_rst,
			srinit => '0',
			ce     => useSaltDwordLow_flag_ce,
			D      => useSaltDwordLow_flag_in,
			Q      => useSaltDwordLow_flag
		);
	useSaltDwordLow_flag_in <= not useSaltDwordLow_flag;

    -- --------------------------------------------------------------------- --
    -- Instantiation    Blowfish Encryption
    -- --------------------------------------------------------------------- --
    bf_enc : entity work.blowfish_encryption
        port map (
            clk         => clk,
            start       => bf_start,
--          rst         => bf_sr,
--			din         => bf_din,
			-- memory data input
            sbox0_dout  => sbox0_dout,
            sbox1_dout  => sbox1_dout,
            sbox2_dout  => sbox2_dout,
            sbox3_dout  => sbox3_dout,
            subkey_doutA=> subkey_doutA,
            subkey_doutB=> subkey_doutB,
			-- output
			dout        => bf_dout,
            done        => bf_done,
            -- memory access control
			sbox_rst    => bf_sbox_rst,
            sbox0_addr  => bf_sbox0_addr,
            sbox1_addr  => bf_sbox1_addr,
            sbox2_addr  => bf_sbox2_addr,
            sbox3_addr  => bf_sbox3_addr,
            subkey_rstA => bf_subkey_rstA,
            subkey_addrA=> bf_subkey_addrA,
            subkey_rstB => bf_subkey_rstB,
            subkey_addrB=> bf_subkey_addrB
        );

		salt_word <= salt(127 downto 96) when loopcnt_d(1 downto 0) = "00" else
					 salt( 95 downto 64) when loopcnt_d(1 downto 0) = "01" else
					 salt( 63 downto 32) when loopcnt_d(1 downto 0) = "10" else
					 salt( 31 downto  0);

	bf_dout_delay : entity work.nBitReg
		generic map (
			ASYNC => FALSE,
			BIT_WIDTH => 64
		)
		port map (
            clk         => clk,
            sr          => '0',
            srinit      => const_slv(0, 64),
            ce          => '1',
			din         => bf_dout,
			dout        => bf_dout_d
		);

	bf_dout_delay_twice : entity work.nBitReg
		generic map (
			ASYNC => FALSE,
			BIT_WIDTH => 64
		)
		port map (
			clk         => clk,
			sr          => '0',
			srinit      => const_slv(0, 64),
			ce          => '1',
			din         => bf_dout_d,
			dout        => bf_dout_dd
		);

    fsm_state : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= RESET;
            else
                current_state <= next_state;
            end if; -- rst
        end if; -- clk
    end process fsm_state;

    -- FSM: control logic
    fsm_ctrl : process (
			current_state, pipeline_full, skinit_dout, sbox0_init_dout,
			sbox1_init_dout, sbox2_init_dout, sbox3_init_dout, sbox_init_addr,
			loopcnt, salt_word, start_expand_key, useSaltAsKey_flag,
			subkey_doutA, key_dout, firstExpand_flag, salt, bf_sbox0_addr,
			bf_sbox1_addr, bf_sbox2_addr, bf_sbox3_addr, bf_subkey_addrA,
			bf_subkey_addrB, bf_din, bf_dout_d, bf_dout_dd, bf_done,
			useSaltDwordLow_flag, active_sbox_dout, costcnt, loopcnt_d,
			bf_sbox_rst, bf_subkey_rstA, bf_subkey_rstB, loopendcnt
		)
    begin
        -- default values

		-- memory access signals
		-- blowfish manages memory access
		sbox0_addr <= '0' & bf_sbox0_addr;
		sbox1_addr <= '1' & bf_sbox1_addr;
		sbox2_addr <= '0' & bf_sbox2_addr;
		sbox3_addr <= '1' & bf_sbox3_addr;
--		subkey_addrA <= useSaltAsKey_flag & resize_slv(bf_subkey_addrA, 8);
--		subkey_addrB <= useSaltAsKey_flag & resize_slv(bf_subkey_addrB, 8);
		subkey_addrA <= '0' & resize_slv(bf_subkey_addrA, 8);
		subkey_addrB <= '0' & resize_slv(bf_subkey_addrB, 8);
		sbox0_din <= bf_dout_d(63 downto 32);
		sbox1_din <= bf_dout_d(31 downto  0);
		sbox2_din <= bf_dout_d(63 downto 32);
		sbox3_din <= bf_dout_d(31 downto  0);
		subkey_dinA <= bf_dout_d(63 downto 32);
		subkey_dinB <= bf_dout_d(31 downto  0);
		sbox0_we <= '0';
		sbox1_we <= '0';
		sbox2_we <= '0';
		sbox3_we <= '0';
		subkey_weA <= '0';
		subkey_weB <= '0';

		subkey_rstA <= '0';
		subkey_rstB <= '0';
		sbox_rst <= '0';

		-- cost counter
		costcnt_rst <= '0';
		costcnt_ce <= '0';

		-- loop counter
		loopcnt_rst <= '0';
		loopcnt_ce <= '0';

		-- flags
		firstExpand_flag_rst <= '0';
		firstExpand_flag_ce <= '0';
		useSaltDwordLow_flag_rst <= '0';
		useSaltDwordLow_flag_ce <= '0';
		useSaltAsKey_flag <= costcnt(0);

		-- key management
		key_done <= '0';
		key_addr <= loopcnt(4 downto 0);

		-- active sbox register
		active_sbox_ce <= '0';
		active_sbox_sr <= '0';

		-- blowfish
		bf_din <= (others => '0');
		bf_start <= '0';

		-- memory init
		memory_init <= '0';

		-- output flag
		dout_valid <= '0';

		-- state
		next_state <= current_state;


		case current_state is

			when RESET =>

				-- reset blowfish
--				bf_sr <= '1';

				-- reset counters
				costcnt_rst <= '1';
				loopcnt_rst <= '1';

				-- reset flags
				firstExpand_flag_ce <= '1';      -- we start in first expandKey
				useSaltDwordLow_flag_rst <= '1'; -- we start with the high dword of the salt

				-- request memory init
				memory_init <= '1';

				next_state <= WAIT_FOR_PIPELINE;

			when WAIT_FOR_PIPELINE =>
				-- reset blowfish
--				bf_sr <= '1';

				-- wait for pipeline
				if pipeline_full = '1' then
					next_state <= INIT_MEMORY;
				end if;

			when INIT_MEMORY =>
				-- reset blowfish
--				bf_sr <= '1';
				-- initialize sbox with init value
				sbox0_addr <= '0' & sbox_init_addr(7 downto 0);
				sbox0_we <= '1';
				sbox0_din <= sbox0_init_dout;

				sbox1_addr <= '1' & sbox_init_addr(7 downto 0);
				sbox1_we <= '1';
				sbox1_din <= sbox1_init_dout;

				sbox2_addr <= '0' & sbox_init_addr(7 downto 0);
				sbox2_we <= '1';
				sbox2_din <= sbox2_init_dout;

				sbox3_addr <= '1' & sbox_init_addr(7 downto 0);
				sbox3_we <= '1';
				sbox3_din <= sbox3_init_dout;

				-- initialize subkey
				subkey_addrA <= '0' & sbox_init_addr(7 downto 0);
				subkey_weA <= '1';
				subkey_dinA <= skinit_dout;

				-- use loopcount to write salt to memory
				loopcnt_ce <= '1';

				-- write salt to subkey memory
				subkey_addrB <= '1' & resize_slv(loopcnt(4 downto 0), 8);
				subkey_weB <= '1';
				subkey_dinB <= salt_word;

				-- initialize 256 positions, then wait for memory control
				if loopendcnt(8) = '1' then
--				if unsigned(sbox_init_addr) = 255 then
					-- reset loop counter for next step
					loopcnt_rst <= '1';
					next_state <= WAIT_FOR_MEM_ACCESS;
				end if;

			-- wait until start_expand_key is set
			when WAIT_FOR_MEM_ACCESS =>
				-- reset blowfish
--				bf_sr <= '1';

				-- count up when we change the state
				loopcnt_ce <= start_expand_key;

				-- fetch the first key and subkey
				subkey_addrA <= '0' & resize_slv(loopcnt(4 downto 0), 8);

				if start_expand_key = '1' then
					next_state <= EKEY_KEY_XOR;
				end if;

			-- add the key to the subkeys
			when EKEY_KEY_XOR =>

				-- reset blowfish
--				bf_sr <= '1';

				-- continue counting
				loopcnt_ce <= '1';

				-- read next key and subkey
				subkey_addrA <= '0' & resize_slv(loopcnt(4 downto 0), 8);

				-- write [key or salt] xor subkey as new subkey
				subkey_addrB <= '0' & resize_slv(loopcnt_d(4 downto 0), 8);
				subkey_weB <= '1';

				-- xor either salt or key
				if useSaltAsKey_flag = '1' then
					subkey_dinB <= salt_word xor subkey_doutA;
				else
					subkey_dinB <= key_dout xor subkey_doutA;
				end if;

				-- wait until all subkeys were updated
				if loopendcnt(4) = '1' and loopendcnt(1) = '1' and loopendcnt(0) = '1' then
--				if loopcnt(4) = '1' and loopcnt(1) = '1' then
					-- reset loop counter
					loopcnt_rst <= '1';
					-- done with key memory
					key_done <= '1';

					next_state <= EKEY_ENC_P_PREPARE;
				end if;

			-- new version of ekey prepare
			when EKEY_ENC_P_PREPARE =>
				-- encrypt either salt or nothing (?)
				if firstExpand_flag = '1' then
					if unsigned(loopcnt(3 downto 0)) = 0 then
						bf_din <= salt(127 downto 64);
					else
						if useSaltDwordLow_flag = '1' then
							bf_din <= salt(63 downto 0) xor bf_dout_dd;
						else
							bf_din <= salt(127 downto 64) xor bf_dout_dd;
						end if;
					end if;
				else
					if unsigned(loopcnt(3 downto 0)) = 0 then
						bf_din <= (others => '0');
					else
						bf_din <= bf_dout_dd;
					end if;
				end if;

				-- write blowfish input into subkey memory
				subkey_addrA <= '1' & const_slv(0, subkey_addrA'length-1);
				subkey_addrB <= '1' & const_slv(1, subkey_addrA'length-1);
				subkey_weA <= '1';
				subkey_weB <= '1';
				subkey_dinA <= bf_din(31 downto  0);
				subkey_dinB <= bf_din(63 downto 32);

				-- start blowfish
				bf_start <= '1';

				-- reset sbox output
				sbox_rst <= bf_sbox_rst;

				-- toggle dword flag for salt
				useSaltDwordLow_flag_ce <= '1';

				next_state <= EKEY_ENC_P;

			-- encrypt subkeys
			when EKEY_ENC_P =>
				-- reset active sbox signal for next step
				active_sbox_sr <= '1';

				-- use blowfish for sbox/subkey reset
				sbox_rst <= bf_sbox_rst;
				subkey_rstA <= bf_subkey_rstA;
				subkey_rstB <= bf_subkey_rstB;

				if  bf_done = '1' then
					next_state <= EKEY_ENC_UPDATE_SUBKEY;
				end if;

			when EKEY_ENC_UPDATE_SUBKEY =>

				subkey_dinA <= bf_dout_d(63 downto 32);
				subkey_dinB <= bf_dout_d(31 downto  0);

				-- write result to subkey memory
				subkey_addrA <= '0' & resize_slv(loopcnt(4 downto 0), 7) & '0';
				subkey_addrB <= '0' & resize_slv(loopcnt(4 downto 0), 7) & '1';
				subkey_weA <= '1';
				subkey_weB <= '1';

				-- increase round counter
				loopcnt_ce <= '1';

				-- wait for 9 rounds (write 2x9 = 18 subkeys)
				if loopcnt(3) = '1' then
					loopcnt_rst <= '1';
					next_state <= EKEY_ENC_SBOX_PREPARE_START;
				-- prepare next encryption of P
				else
					next_state <= EKEY_ENC_P_PREPARE;
				end if;

			-- prepare encryption of sbox
			when EKEY_ENC_SBOX_PREPARE_START =>

				-- toggle salt dword low flag
				useSaltDwordLow_flag_ce <= '1';

				-- encrypt salt xor output or output
				if firstExpand_flag = '1' then
					--bf_din <= salt(127 downto 64) xor bf_dout_dd;
					bf_din <= salt(63 downto 0) xor bf_dout_dd;
				else
					bf_din <= bf_dout_dd;
				end if;

				-- write blowfish input into subkey memory
				subkey_addrA <= '1' & const_slv(0, subkey_addrA'length-1);
				subkey_addrB <= '1' & const_slv(1, subkey_addrA'length-1);
				subkey_weA <= '1';
				subkey_weB <= '1';
				subkey_dinA <= bf_din(31 downto  0);
				subkey_dinB <= bf_din(63 downto 32);

				-- start blowfish
				bf_start <= '1';

				-- reset sbox output
				sbox_rst <= bf_sbox_rst;

				next_state <= EKEY_ENC_SBOX;


			-- prepare encryption of sbox
			when EKEY_ENC_SBOX_PREPARE_CONTINUE =>

				-- edge detection on 8th bit of loopcount to switch sboxes
				if (loopcnt(7) = '1' and loopcnt_d(7) = '0') or (loopcnt(7) = '0' and loopcnt_d(7) = '1') then
					active_sbox_ce <= '1';
				end if;

				-- toggle salt dword low flag
				useSaltDwordLow_flag_ce <= '1';

				-- encrypt salt xor output or output
				if firstExpand_flag = '1' then
					if useSaltDwordLow_flag = '1' then
						bf_din <= salt(63 downto 0) xor bf_dout_d;
					else
						bf_din <= salt(127 downto 64) xor bf_dout_d;
					end if;
				else
					bf_din <= bf_dout_d;
				end if;

				-- write blowfish input into subkey memory
				subkey_addrA <= '1' & const_slv(0, subkey_addrA'length-1);
				subkey_addrB <= '1' & const_slv(1, subkey_addrA'length-1);
				subkey_weA <= '1';
				subkey_weB <= '1';
				subkey_dinA <= bf_din(31 downto  0);
				subkey_dinB <= bf_din(63 downto 32);

				-- start blowfish
				bf_start <= '1';

				-- reset sbox output
				sbox_rst <= bf_sbox_rst;

				-- write result to sbox memory
				-- use dual ports to write in one clock cycle
				sbox0_we <= active_sbox_dout(0) or active_sbox_dout(1);
				sbox1_we <= active_sbox_dout(0) or active_sbox_dout(1);
				sbox2_we <= active_sbox_dout(2) or active_sbox_dout(3);
				sbox3_we <= active_sbox_dout(2) or active_sbox_dout(3);
				sbox0_addr <= active_sbox_dout(1) & resize_slv(loopcnt_d(6 downto 0), 7) & '0';
				sbox1_addr <= active_sbox_dout(1) & resize_slv(loopcnt_d(6 downto 0), 7) & '1';
				sbox2_addr <= active_sbox_dout(3) & resize_slv(loopcnt_d(6 downto 0), 7) & '0';
				sbox3_addr <= active_sbox_dout(3) & resize_slv(loopcnt_d(6 downto 0), 7) & '1';

				-- wait for 512 rounds (write 4x2x128 = 4x256 subkeys)
				if loopendcnt(9) = '1' and loopendcnt(0) = '1' then
--					if unsigned(loopcnt) = 511 then
					loopcnt_rst <= '1';

					-- increase cost counter if we are not inside the first expand key
					costcnt_rst <= firstExpand_flag;
					costcnt_ce <= '1';
					-- clear first expand key flag
					firstExpand_flag_rst <= '1';

					-- finished with cost loop?
					if costcnt(COST+1) = '1' and costcnt(0) = '1' then
						-- reset loop count
--						loopcnt_rst <= '1';
						next_state <= PREPARE_ENC_MAGIC_HIGH;
					else
						-- do not reset loop counter, let it increase (!)
						next_state <= WAIT_FOR_MEM_ACCESS;
					end if;
				-- prepare next encryption of the sbox
				else
					next_state <= EKEY_ENC_SBOX;
				end if;


			-- encrypt sbox
			when EKEY_ENC_SBOX =>
				-- use blowfish for sbox/subkey reset
				sbox_rst <= bf_sbox_rst;
				subkey_rstA <= bf_subkey_rstA;
				subkey_rstB <= bf_subkey_rstB;

				-- wait for blowfish to finish
				if bf_done = '1' then
					-- increase round counter
					loopcnt_ce <= '1';

					next_state <= EKEY_ENC_SBOX_PREPARE_CONTINUE;
				end if;

			when PREPARE_ENC_MAGIC_HIGH =>
				-- TODO: delay loopendcnt_rst and check if signal is 1
				if unsigned(loopendcnt) = 1 then
					bf_din <= MAGIC_VALUE(191 downto 128);
				else
					bf_din <= bf_dout_d;
				end if;

				-- write blowfish input into subkey memory
				subkey_addrA <= '1' & const_slv(0, subkey_addrA'length-1);
				subkey_addrB <= '1' & const_slv(1, subkey_addrA'length-1);
				subkey_weA <= '1';
				subkey_weB <= '1';
				subkey_dinA <= bf_din(31 downto  0);
				subkey_dinB <= bf_din(63 downto 32);

				-- start blowfish
				bf_start <= '1';

				-- reset sbox output
				sbox_rst <= bf_sbox_rst;

				next_state <= ENC_MAGIC_HIGH;


			-- encrypt 64x magic word (high)
			when ENC_MAGIC_HIGH =>
				-- use blowfish for sbox/subkey reset
				sbox_rst <= bf_sbox_rst;
				subkey_rstA <= bf_subkey_rstA;
				subkey_rstB <= bf_subkey_rstB;

				-- wait for blowfish to finish
				if bf_done = '1' then
					-- increase round counter
					loopcnt_ce <= '1';

					-- wait for 64 rounds
					if loopendcnt(6) = '1' then
--					if unsigned(loopcnt) = 63 then
						-- mark output as valid block
						dout_valid <= '1';

						-- continue with blowfish encryption
						loopcnt_rst <= '1';

						next_state <= PREPARE_ENC_MAGIC_MIDDLE;
					else
						next_state <= PREPARE_ENC_MAGIC_HIGH;
					end if;
				end if;

			when PREPARE_ENC_MAGIC_MIDDLE =>
				-- TODO: delay loopendcnt_rst and check if signal is 1
				if unsigned(loopendcnt) = 1 then
					bf_din <= MAGIC_VALUE(127 downto 64);
				else
					bf_din <= bf_dout_d;
				end if;

				-- write blowfish input into subkey memory
				subkey_addrA <= '1' & const_slv(0, subkey_addrA'length-1);
				subkey_addrB <= '1' & const_slv(1, subkey_addrA'length-1);
				subkey_weA <= '1';
				subkey_weB <= '1';
				subkey_dinA <= bf_din(31 downto  0);
				subkey_dinB <= bf_din(63 downto 32);

				-- start blowfish
				bf_start <= '1';

				-- reset sbox output
				sbox_rst <= bf_sbox_rst;

				next_state <= ENC_MAGIC_MIDDLE;


			-- encrypt 64x magic word (middle)
			when ENC_MAGIC_MIDDLE =>
				-- use blowfish for sbox/subkey reset
				sbox_rst <= bf_sbox_rst;
				subkey_rstA <= bf_subkey_rstA;
				subkey_rstB <= bf_subkey_rstB;

				-- wait for blowfish to finish
				if bf_done = '1' then
					-- increase round counter
					loopcnt_ce <= '1';

					-- wait for 64 rounds
					if loopendcnt(6) = '1' then
--					if unsigned(loopcnt) = 63 then
						-- mark output as valid block
						dout_valid <= '1';

						-- continue with blowfish encryption
						loopcnt_rst <= '1';

						next_state <= PREPARE_ENC_MAGIC_LOW;
					else
						next_state <= PREPARE_ENC_MAGIC_MIDDLE;
					end if;
				end if;

			when PREPARE_ENC_MAGIC_LOW =>
				-- TODO: delay loopendcnt_rst and check if signal is 1
				if unsigned(loopendcnt) = 1 then
					bf_din <= MAGIC_VALUE(63 downto 0);
				else
					bf_din <= bf_dout_d;
				end if;

				-- write blowfish input into subkey memory
				subkey_addrA <= '1' & const_slv(0, subkey_addrA'length-1);
				subkey_addrB <= '1' & const_slv(1, subkey_addrA'length-1);
				subkey_weA <= '1';
				subkey_weB <= '1';
				subkey_dinA <= bf_din(31 downto  0);
				subkey_dinB <= bf_din(63 downto 32);

				-- start blowfish
				bf_start <= '1';

				-- reset sbox output
				sbox_rst <= bf_sbox_rst;

				next_state <= ENC_MAGIC_LOW;


			-- encrypt 64x magic word (low)
			when ENC_MAGIC_LOW =>
				-- use blowfish for sbox/subkey reset
				sbox_rst <= bf_sbox_rst;
				subkey_rstA <= bf_subkey_rstA;
				subkey_rstB <= bf_subkey_rstB;

				-- wait for blowfish to finish
				if bf_done = '1' then
					-- increase round counter
					loopcnt_ce <= '1';

					-- wait for 64 rounds
					if loopendcnt(6) = '1' then
--					if unsigned(loopcnt) = 63 then
						-- mark output as valid block
						dout_valid <= '1';

						next_state <= FINISH;
					else
						next_state <= PREPARE_ENC_MAGIC_LOW;
					end if;
				end if;

			-- wait for reset from outside
			when FINISH =>
				null;

		end case;
	end process;

	-- output generation
	dout <= bf_dout;

end architecture Behavioral;
