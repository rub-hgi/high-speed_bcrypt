-------------------------------------------------------------------------------
-- Title      : bcrypt quad core Topmodule
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : bcrypt_quad_core.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-04-16
-- Last update: 2014-04-09
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description:
--    instantiates four bcrypt cores and one pwd_generation core
--    pwd_gen generates 4 pwd's and hashes them, using the bcrypt cores
--    it repeats the process, until it's search space is exhausted
--    or the correct key was found
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-04-16  1.0      fwi     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.pkg_bcrypt.all;
use work.rzi_helper.all;

entity bcrypt_quad_core is
    generic (
        OVERALL_NUMBER : integer;
        INDEX : integer;
        NUMBER_OF_CRACKS : integer := 1
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        t_salt  : in  std_logic_vector (SALT_LENGTH-1 downto 0);
        t_hash  : in  std_logic_vector (HASH_LENGTH-1 downto 0);
        memory_init     : out std_logic;
        pipeline_full   : in  std_logic;
        sbox0_init_dout : in  std_logic_vector (31 downto 0);
        sbox1_init_dout : in  std_logic_vector (31 downto 0);
        sbox2_init_dout : in  std_logic_vector (31 downto 0);
        sbox3_init_dout : in  std_logic_vector (31 downto 0);
        skinit_dout     : in  std_logic_vector (31 downto 0);
        sbox_init_addr  : in  std_logic_vector ( 8 downto 0);
        done    : out std_logic;
        success : out std_logic;
        dout_we : out std_logic;
        dout    : out std_logic_vector (31 downto 0)
    );
end bcrypt_quad_core;

architecture behavioral of bcrypt_quad_core is

    -- --------------------------------------------------------------------- --
    --                               Constants
    -- --------------------------------------------------------------------- --
    constant NUMBER_OF_CORES : integer := 4;

    -- --------------------------------------------------------------------- --
    --                                 Types
    -- --------------------------------------------------------------------- --
    type states_t is (
		RESET,
		INIT, BRAM_CORES_A, BRAM_CORES_B, FINISHED_COMPUTATION,
		OUTPUT_PASSWORD, RESTART,
		TERMINATE
	);

    -- --------------------------------------------------------------------- --
    --                                Signals
    -- --------------------------------------------------------------------- --
    -- FSM
    signal current_state : states_t;
    signal next_state    : states_t;

    signal pwd_mem_addrA : std_logic_vector ( 8 downto 0);
    signal pwd_mem_doutA : std_logic_vector (31 downto 0);
    signal pwd_mem_addrB : std_logic_vector ( 8 downto 0);
    signal pwd_mem_doutB : std_logic_vector (31 downto 0);

    signal pwd_gen_rst      : std_logic;
    signal pwd_gen_continue : std_logic;
    signal pwd_gen_done     : std_logic;
    signal pwd_gen_weA      : std_logic;
    signal pwd_gen_addrA    : std_logic_vector ( 4 downto 0);
    signal pwd_gen_dinA     : std_logic_vector (31 downto 0);
    signal pwd_gen_weB      : std_logic;
    signal pwd_gen_addrB    : std_logic_vector ( 4 downto 0);
    signal pwd_gen_dinB     : std_logic_vector (31 downto 0);

    signal snd_iteration_ce : std_logic;
    signal snd_iteration_sr : std_logic;
    signal snd_iteration    : std_logic;

    signal bcrypt_core_rst        : std_logic_vector (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_dout_valid : std_logic_vector (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_dout_valid_d : std_logic_vector (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_start_e    : std_logic_vector (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_mem_init   : std_logic_vector (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_key_addr   : slv5_ary_t  (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_key_dout   : slv32_ary_t (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_key_done   : std_logic_vector (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_dout       : slv64_ary_t (NUMBER_OF_CORES-1 downto 0);
    signal bcrypt_core_dout_d     : slv64_ary_t (NUMBER_OF_CORES-1 downto 0);

    signal mem_access   : std_logic_vector(3 downto 0);
    alias  mem_access_pwd_gen : std_logic is mem_access(0);
    alias  mem_access_cores01 : std_logic is mem_access(1);
    alias  mem_access_cores23 : std_logic is mem_access(2);
    alias  mem_access_pwd_cnt : std_logic is mem_access(3);

    signal cracks_cnt_ce    : std_logic;
    signal cracks_cnt_sr    : std_logic;
    signal cracks_cnt_dout  : std_logic_vector (31 downto 0);

    signal pwd_addr_cnt_ce  : std_logic;
    signal pwd_addr_cnt_sr  : std_logic;
    signal pwd_addr_cnt_dout: std_logic_vector (4 downto 0);

	-- target hash, split into 64 bits, multiplex via result hash counter
	signal hashDword : std_logic_vector(63 downto 0);
	-- hash output counter
	signal hashcnt    : std_logic_vector(1 downto 0);
	signal hashcnt_ce : std_logic;
	signal hashcnt_sr : std_logic;

	-- success flag
	signal bcrypt_core_success : std_logic_vector(NUMBER_OF_CORES-1 downto 0);
	signal bcrypt_core_success_in : std_logic_vector(NUMBER_OF_CORES-1 downto 0);

	-- determine success state
    signal successful_core  : std_logic_vector (1 downto 0);
	signal success_int : std_logic;
	signal finished : std_logic;
begin

    -- ------------------------------------------------------------------------
    -- Instantiation    bram for password storage
    -- ------------------------------------------------------------------------
    pwd_mem : entity work.bram
        generic map (
            DATA_WIDTH       => 32,
            ADDRESS_WIDTH    => 9,
            RW_MODE          => "WR", -- write before read
            INIT_MEMORY      => true,
            INIT_VECTOR      => x"00000000"
        )
        port map (
            clkA  => clk,
            weA   => pwd_gen_weA,
            rstA  => '0',
            addrA => pwd_mem_addrA,
            dinA  => pwd_gen_dinA,
            doutA => pwd_mem_doutA,
            clkB  => clk,
            weB   => pwd_gen_weB,
            rstB  => '0',
            addrB => pwd_mem_addrB,
            dinB  => pwd_gen_dinB,
            doutB => pwd_mem_doutB
        );

    -- ------------------------------------------------------------------------
    -- Instantiation    pwd_generator
    -- ------------------------------------------------------------------------
    pwd_generator : entity work.pwd_gen
        generic map (
            INIT   => generate_init_vector(INDEX),--.counter_init,
            LENGTH => generate_init_length(INDEX)--.initial_length
        )
        port map (
            clk     => clk,
            rst     => pwd_gen_rst,
            continue=> pwd_gen_continue,
            done    => pwd_gen_done,
            weA     => pwd_gen_weA,
            addrA   => pwd_gen_addrA,
            dinA    => pwd_gen_dinA,
            weB     => pwd_gen_weB,
            addrB   => pwd_gen_addrB,
            dinB    => pwd_gen_dinB
        );
    snd_iter_ff : entity work.dff
        port map (
            clk     => clk,
            sr      => snd_iteration_sr,
            srinit  => '0',
            ce      => snd_iteration_ce,
            D       => '1',
            Q       => snd_iteration
        );

    -- --------------------------------------------------------------------- --
	-- Instantiation    hash result counter
	--                  count the number of hash blocks received from the cores (0, 1, 2)
    -- --------------------------------------------------------------------- --
    hash_count : entity work.nBitCounter
        generic map (
            ASYNC       => false,
            BIT_WIDTH   => 2
		)
        port map (
            clk         => clk,
            sr          => hashcnt_sr,
            ce          => hashcnt_ce,
            srinit      => const_slv(0, 2),
            count_up    => '1',
            dout        => hashcnt
        );
	hashcnt_sr <= rst;
	hashcnt_ce <= bcrypt_core_dout_valid_d(NUMBER_OF_CORES-1);

	-- multiplex 192-bit hash into 64-bit chunks according to the hash count
	hashDword <= t_hash(127 downto  64) when hashcnt(0) = '1' else  -- 01
				 t_hash( 63 downto   0) when hashcnt(1) = '1' else  -- 10
				 t_hash(191 downto 128);                            -- 00

    -- --------------------------------------------------------------------- --
    -- Instantiation    bcrypt cores
    -- --------------------------------------------------------------------- --
    bcrypt_gen : for i in 0 to NUMBER_OF_CORES-1 generate
        -- ----------------------------------------------------------------- --
        -- Instantiation    bcrypt core
        -- ----------------------------------------------------------------- --
        bcrypt : entity work.bcrypt
            port map (
                clk             => clk,
                rst             => bcrypt_core_rst(i),
                salt            => t_salt,
                start_expand_key=> bcrypt_core_start_e(i),
                memory_init     => bcrypt_core_mem_init(i),
                pipeline_full   => pipeline_full,
                sbox_init_addr  => sbox_init_addr,
                sbox0_init_dout => sbox0_init_dout,
                sbox1_init_dout => sbox1_init_dout,
                sbox2_init_dout => sbox2_init_dout,
                sbox3_init_dout => sbox3_init_dout,
                skinit_dout     => skinit_dout,
                key_addr        => bcrypt_core_key_addr(i),
                key_dout        => bcrypt_core_key_dout(i),
                key_done        => bcrypt_core_key_done(i),
                dout_valid      => bcrypt_core_dout_valid(i),
                dout            => bcrypt_core_dout(i)
            );

		-- buffer the bcrypt core output bus and output valid flag
		delay_stuff_proc : process( clk )
		begin
			if( rising_edge(clk) ) then
				bcrypt_core_dout_valid_d(i)	<= bcrypt_core_dout_valid(i);
				bcrypt_core_dout_d(i)		<= bcrypt_core_dout(i);
			end if ;
		end process ; -- delay_stuff_proc

		-- TODO: check critical path --> we can buffer the success and dout and compare it later
		-- store success flag: reset to '1' (true)
		-- update to '0' or keep its value --> never return to '1' once a check failed
		core_success_dff : entity work.dff
			generic map (
				ASYNC => false
			)
			port map (
				clk    => clk,
				sr     => rst,
				srinit => '1',
				ce     => bcrypt_core_dout_valid_d(i),
				D      => bcrypt_core_success_in(i),
				Q      => bcrypt_core_success(i)
			);
        bcrypt_core_success_in(i) <= bcrypt_core_success(i) when bcrypt_core_dout_d(i) = hashDword else '0';
    end generate bcrypt_gen;

	-- core specific control signals
    bcrypt_core_start_e(0) <= mem_access_cores01;
    bcrypt_core_start_e(1) <= mem_access_cores01;
    bcrypt_core_start_e(2) <= mem_access_cores23;
    bcrypt_core_start_e(3) <= mem_access_cores23;

	-- map output signals from password memory
    bcrypt_core_key_dout(0) <= pwd_mem_doutA;
    bcrypt_core_key_dout(1) <= pwd_mem_doutB;
    bcrypt_core_key_dout(2) <= pwd_mem_doutA;
    bcrypt_core_key_dout(3) <= pwd_mem_doutB;

	-- we only care about the first core's init flag, as it determines the init state for all 4 cores
    memory_init <= bcrypt_core_mem_init(0);

	-- all cores finished when we incremented the hash counter 4 times
	finished <= hashcnt(0) and hashcnt(1);

	-- output a core-number, from the success-flag
    successful_core <= "00" when bcrypt_core_success(0) = '1' else
                       "01" when bcrypt_core_success(1) = '1' else
                       "10" when bcrypt_core_success(2) = '1' else
                       "11";

	-- combine the 4 success bits into an internal success flag
	success_int <= bcrypt_core_success(0) or bcrypt_core_success(1) or bcrypt_core_success(2) or bcrypt_core_success(3);

    -- --------------------------------------------------------------------- --
    -- Muxing pwd memory addresses
    -- --------------------------------------------------------------------- --

    with mem_access select pwd_mem_addrA <=
        "000"  & snd_iteration   & pwd_gen_addrA     when "0001", -- pwd_gen
        "0000" & bcrypt_core_key_addr(0)             when "0010", -- cores01
        "0010" & bcrypt_core_key_addr(2)             when "0100", -- cores23
        "00"   & successful_core & pwd_addr_cnt_dout when "1000", -- pwd_cnt
        (others => '0')                              when others;

    with mem_access select pwd_mem_addrB <=
        "001" & snd_iteration & pwd_gen_addrB when "0001", -- pwd_gen access
        "0001" & bcrypt_core_key_addr(1)      when "0010", -- cores01 access
        "0011" & bcrypt_core_key_addr(3)      when "0100", -- cores02 access
        (others => '0')                       when others;

    -- --------------------------------------------------------------------- --
    -- Instantiation    counts cracked pwds
    --                  gets enabled by bcrypt_core_dout_valid(3)
    --                  i.e. it counts up everytime the last
    --                  two cores finish a hash-computation
    -- --------------------------------------------------------------------- --
    cracks_cnt : entity work.nBitCounter
        generic map (
            ASYNC       => false,
            BIT_WIDTH   => 32)
        port map (
            clk         => clk,
            sr          => cracks_cnt_sr,
            ce          => cracks_cnt_ce,
            srinit      => const_slv(0, 32),
            count_up    => '1',
            dout        => cracks_cnt_dout
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    pwd addr counter
    -- --------------------------------------------------------------------- --
    pwd_addr_cnt : entity work.nBitCounter
        generic map (
            ASYNC       => false,
            BIT_WIDTH   => 5)
        port map (
            clk         => clk,
            sr          => pwd_addr_cnt_sr,
            ce          => pwd_addr_cnt_ce,
            srinit      => const_slv(0, 5),
            count_up    => '1',
            dout        => pwd_addr_cnt_dout
        );

    -- --------------------------------------------------------------------- --
    -- FSM      controlls the pwd_gen and 4 cores
    --          init: let pwd_gen generate 4 passwords and initialize cores
    --                change to next state when pwd_gen and cores done
    --          BRAM_A: let core0 and core1 run expand_key(..., key)
    --          BRAM_B: let core2 and core3 run expand_key(..., key)
    --                change to next state when key is not needed anymore
    --                (aka cores are done)
    --          IDLE: change to init state, if not finished yet.
    -- --------------------------------------------------------------------- --
    -- FSM: state change
    fsm_state : process(clk, rst)
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
			current_state, pwd_gen_done, snd_iteration, finished, bcrypt_core_key_done, pwd_addr_cnt_dout, success_int
		)
    begin
        -- default values
        pwd_gen_rst <= '0';
        pwd_gen_continue    <= '0';
        bcrypt_core_rst     <= (others => '0');
        snd_iteration_ce    <= '0';
        snd_iteration_sr    <= '0';

        mem_access_pwd_gen  <= '0';
        mem_access_cores01  <= '0';
        mem_access_cores23  <= '0';
        mem_access_pwd_cnt  <= '0';

        cracks_cnt_ce <= '0';
        cracks_cnt_sr <= '0';

        pwd_addr_cnt_ce <= '1';
        pwd_addr_cnt_sr <= '1';

        done <= '0';
        dout_we <= '0';

        next_state <= current_state;

        -- FSM states
        case current_state is
            -- startup
            when RESET =>
                pwd_gen_rst <= '1';
                bcrypt_core_rst <= (others => '1');

                snd_iteration_sr    <= '1';

                cracks_cnt_sr <= '1';

                next_state <= INIT;

			-- wait for password generator to generate 4 passwords (two iterations)
            when INIT =>
                mem_access_pwd_gen <= '1';

                if pwd_gen_done = '1' then
					-- generated all passwords?
                    if snd_iteration = '1' then
                        snd_iteration_sr    <= '1';
                        next_state <= BRAM_CORES_A;
                    else
                        snd_iteration_ce <= '1';
                        pwd_gen_continue <= '1';
                    end if; -- snd_iteration
                end if; -- pwd_gen_done

			-- TODO: we can combine the two states BRAM_CORES_A and BRAM_CORES_B
			-- grant memory access to core 1 and 2
            when BRAM_CORES_A =>
                mem_access_cores01 <= '1';

				-- all cores finished?
                if finished = '1' then
					-- once all cores finish, we increase the #(tested passwords) counter
					cracks_cnt_ce <= '1';
                    next_state <= FINISHED_COMPUTATION;
				else
					-- if not, check if core 1 and 2 finished memory access
					if bcrypt_core_key_done(0) = '1' then
	                    next_state <= BRAM_CORES_B;
					end if;
                end if;

			-- grant memory access to core 3 and 4
            when BRAM_CORES_B =>
                mem_access_cores23 <= '1';

				-- check if core 3 and 4 finished memory access
                if bcrypt_core_key_done(2) = '1' then
                    next_state <= BRAM_CORES_A;
                end if;

			-- finished computing hashes, check if we finished completely or found a correct password
            when FINISHED_COMPUTATION =>

				-- did a password match?
				if success_int <= '1' then
                	mem_access_pwd_cnt  <= '1';
					next_state <= OUTPUT_PASSWORD;
				else
					-- no match found, check if we have passwords left
					if unsigned(cracks_cnt_dout) = NUMBER_OF_CRACKS-1 then
						next_state <= TERMINATE;
					else
						-- restart computation
						next_state <= RESTART;
					end if;
				end if;


			-- start next passwords
			when RESTART =>
				bcrypt_core_rst  <= (others => '1');
				pwd_gen_continue <= '1';
				cracks_cnt_ce <= '1';

				next_state <= INIT;

			-- output password
			when OUTPUT_PASSWORD =>
                pwd_addr_cnt_sr <= '0';

				dout_we <= '1';

				-- output all
				if pwd_addr_cnt_dout(2) = '1' then
					next_state <= TERMINATE;
				end if;


			-- finished completely
			when TERMINATE =>
				done <= '1';

				-- end of password search
				next_state <= TERMINATE;

        end case; -- state
    end process fsm_ctrl;

	-- output generation
	dout <= pwd_mem_doutA;  -- only valid while dout_we = '1'
	success <= success_int;

end behavioral;
