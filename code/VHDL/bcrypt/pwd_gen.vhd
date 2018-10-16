-------------------------------------------------------------------------------
-- Title      : password generation Topmodule
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : pwd_gen.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-04-09
-- Last update: 2014-04-19
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02/08
-- ----------------------------------------------------------------------------
-- Description:
--    generates passwords for bcrypt cores
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-04-09  1.0      fwi     Created
-- 2014-04-19  1.01     fwi     Changed to BRAM-password storage
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_bcrypt.all;
use work.rzi_helper.all;

entity pwd_gen is
    generic (
        INIT    : std_logic_vector (PWD_LENGTH*getBitSize(CHARSET_LEN+1)-1 downto 0)
                    := const_slv(0,PWD_LENGTH*getBitSize(CHARSET_LEN+1));
        LENGTH  : integer := 1
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        continue: in  std_logic;  -- generate next pwd
        done    : out std_logic;  -- indicates, that new pwd was generated
        weA     : out std_logic;
        addrA   : out std_logic_vector ( 4 downto 0);
        dinA    : out std_logic_vector (31 downto 0);
        weB     : out std_logic;
        addrB   : out std_logic_vector ( 4 downto 0);
        dinB    : out std_logic_vector (31 downto 0)
    );
end pwd_gen;

architecture Behavioral of pwd_gen is

    -- --------------------------------------------------------------------- --
    -- Types
    -- --------------------------------------------------------------------- --
    type states_t is (
        RESET,
        --DELAY_A,
        COUNTER_UPDATE,
        DELAY,
        LOAD_SHIFTREG,
        WRITE_TO_BRAM,
        IDLE
    );
    type pwd_cnt_ary_t is array (integer range <>) of
        std_logic_vector(getBitSize(CHARSET_LEN+1)-1 downto 0);
    -- --------------------------------------------------------------------- --
    --                               Signals
    -- --------------------------------------------------------------------- --
    -- FSM
    signal current_state: states_t;
    signal next_state   : states_t;

    -- Signals for generating password byte counter states
    signal pwd_cnt_ceA  : std_logic_vector(PWD_LENGTH-1 downto 0);
    signal pwd_cnt_srA  : std_logic_vector(PWD_LENGTH-1 downto 0);
    signal pwd_cnt_srA_d: std_logic_vector(PWD_LENGTH-1 downto 0);
    signal pwd_cnt_srA_d_rst: std_logic;
    signal pwd_cnt_doutA: pwd_cnt_ary_t(PWD_LENGTH downto 0);

    signal pwd_cnt_ceB  : std_logic_vector(PWD_LENGTH-1 downto 0);
    signal pwd_cnt_doutB: pwd_cnt_ary_t(PWD_LENGTH   downto 0);

    signal snd_iter_ce      : std_logic;
    signal snd_iter_sr      : std_logic;
    signal second_iteration : std_logic;

    signal overflow     : std_logic_vector(PWD_LENGTH-1 downto 0);
    signal prev_overflow: std_logic_vector(PWD_LENGTH-1 downto 0);

    signal is_actual_ce     : std_logic;
    signal is_actual_sr     : std_logic;
    signal is_actual_dout   : std_logic_vector(PWD_LENGTH-1 downto 0);

    signal actual_len_cntA_sr   : std_logic;
    signal actual_len_cntA_ce   : std_logic;
    signal actual_len_cntA_dout : std_logic_vector(PWD_BITLEN-1 downto 0);

    signal actual_len_cntB_ce   : std_logic;
    signal actual_len_cntB_dout : std_logic_vector(PWD_BITLEN-1 downto 0);

    -- Signals for generate password from counter state and output
    signal int2asc_dinA : std_logic_vector(CHARSET_BIT-1 downto 0);
    signal int2asc_doutA: std_logic_vector(7 downto 0);
    signal int2asc_dinB : std_logic_vector(CHARSET_BIT-1 downto 0);
    signal int2asc_doutB: std_logic_vector(7 downto 0);

    signal mux_cntA_ce   : std_logic;
    signal mux_cntA_sr   : std_logic;
    signal mux_cntA_dout : std_logic_vector(PWD_BITLEN-1 downto 0);

    signal mux_cntB_ce   : std_logic;
    signal mux_cntB_sr   : std_logic;
    signal mux_cntB_dout : std_logic_vector(PWD_BITLEN-1 downto 0);

    signal pwd_reg_ceA  : std_logic;
    signal pwd_reg_srA  : std_logic;
    signal pwd_reg_doutA: std_logic_vector(31 downto 0);

    signal pwd_reg_ceB  : std_logic;
    signal pwd_reg_srB  : std_logic;
    signal pwd_reg_doutB: std_logic_vector(31 downto 0);

    -- Counter for State-Machine Transitions
    signal updated_cnt_ce   : std_logic;
    signal updated_cnt_sr   : std_logic;
    signal updated_cnt_dout : std_logic_vector(PWD_BITLEN-1 downto 0);

    signal loaded_bytes_cnt_ce  : std_logic;
    signal loaded_bytes_cnt_sr  : std_logic;
    signal loaded_bytes_cnt_dout: std_logic_vector(1 downto 0);

    signal written_words_cnt_ce     : std_logic;
    signal written_words_cnt_sr     : std_logic;
    signal written_words_cnt_dout   : std_logic_vector(4 downto 0);

begin

    -- --------------------------------------------------------------------- --
    -- --------------------------------------------------------------------- --
    -- Logic for updating counter
    -- --------------------------------------------------------------------- --
    -- --------------------------------------------------------------------- --
    -- Instantiation    counter for password-bytes
    -- --------------------------------------------------------------------- --
    pwd_cnter : for i in 0 to PWD_LENGTH-1 generate
        pwd_byte_cntA : entity work.nBitCounter
            generic map (
               BIT_WIDTH   => getBitSize(CHARSET_LEN+1)
		    )
            port map (
                clk         => clk,
                ce          => pwd_cnt_ceA(i),
                sr          => pwd_cnt_srA(i),
                srinit      => INIT(getBitSize(CHARSET_LEN+1)*(i+1)-1 downto getBitSize(CHARSET_LEN+1)*i),
                count_up    => '1',
                dout        => pwd_cnt_doutA(i+1)
            );

        pwd_byte_cntB : entity work.nBitReg
            generic map (
               BIT_WIDTH   => getBitSize(CHARSET_LEN+1)
		    )
            port map (
                clk         => clk,
                ce          => pwd_cnt_ceB(i),
                sr          => '0',
                srinit      => const_slv(0,getBitSize(CHARSET_LEN+1)),
                din         => pwd_cnt_doutA(i+1),
                dout        => pwd_cnt_doutB(i+1)
            );
        overflow(i)         <= '1' when pwd_cnt_doutA(i+1)
                                    = const_slv(CHARSET_LEN, getBitSize(CHARSET_LEN+1))
--									std_logic_vector(
--                                      to_unsigned(CHARSET_LEN-1,CHARSET_BIT))
                                   else
                               '0';
    end generate pwd_cnter;

	pwd_byte_rst_delay : entity work.nBitReg
		generic map (
			BIT_WIDTH   => PWD_LENGTH
		)
		port map (
			clk         => clk,
			ce          => '1',
			sr          => pwd_cnt_srA_d_rst,
			srinit      => const_slv(0, PWD_LENGTH),
			din         => pwd_cnt_srA,
			dout        => pwd_cnt_srA_d
		);
    pwd_cnt_doutA(0)<= (others => '0');
    pwd_cnt_doutB(0)<= (others => '0');

--    prev_overflow   <= overflow(PWD_LENGTH-2 downto 0) & '1';
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				prev_overflow(PWD_LENGTH-1 downto 1) <= (others => '0');
			else
				prev_overflow(PWD_LENGTH-1 downto 1) <= overflow(PWD_LENGTH-2 downto 0);
			end if;
		end if;
	end process;
    prev_overflow(0) <= is_actual_dout(0);

    snd_iter : entity work.dff
        generic map (
            ASYNC   => false
        )
        port map (
            clk     => clk,
            ce      => snd_iter_ce,
            sr      => snd_iter_sr,
            srinit  => '0',
            D       => '1',
            Q       => second_iteration
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    is_actual shift register
    --                  marks every active counter
    --                  delayed register is used for snd count up
    --                  and pwd_B load
    -- --------------------------------------------------------------------- --
    is_actual_shiftreg : entity work.nxmBitShiftReg
        generic map (
            N       => PWD_LENGTH,
            M       => 1
        )
        port map (
            clk     => clk,
            ce      => is_actual_ce,
            sr      => is_actual_sr,
            srinit  => const_slv(1, PWD_LENGTH),
            opmode  => "11", -- [Rot?, Left?] -- [rotate,left]
            din     => "0",
            dout    => open,
            dout_f  => is_actual_dout
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    counts the actual password length
    -- --------------------------------------------------------------------- --
    actual_len_cntA : entity work.nBitCounter
        generic map (
            BIT_WIDTH   => PWD_BITLEN)
        port map (
            clk         => clk,
            ce          => actual_len_cntA_ce,
            sr          => actual_len_cntA_sr,
            srinit      => const_slv(LENGTH,PWD_BITLEN),
            count_up    => '1',
            dout        => actual_len_cntA_dout
        );
    actual_len_cntB : entity work.nBitReg
        generic map (
            BIT_WIDTH   => PWD_BITLEN)
        port map (
            clk         => clk,
            ce          => actual_len_cntB_ce,
            sr          => '0',
            srinit      => const_slv(0,PWD_BITLEN),
            din         => actual_len_cntA_dout,
            dout        => actual_len_cntB_dout
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    counts updated counter
    --                  e.g. from 0 to PWD_LENGTH-1
    -- --------------------------------------------------------------------- --
    updated_cnt : entity work.nBitCounter
        generic map (
            BIT_WIDTH   => PWD_BITLEN)
        port map (
            clk         => clk,
            sr          => updated_cnt_sr,
            ce          => updated_cnt_ce,
            srinit      => const_slv(0, PWD_BITLEN),
            count_up    => '1',
            dout        => updated_cnt_dout
        );

    -- --------------------------------------------------------------------- --
    -- --------------------------------------------------------------------- --
    -- Logic for mapping password counter to ascii values
    -- --------------------------------------------------------------------- --
    -- --------------------------------------------------------------------- --
    -- Instantiation    counter for the active pwd byte counter
    --                  (used to mux the password counter)
    --                  counts from highest active pwd-byte-counter down to 0
    -- --------------------------------------------------------------------- --
    mux_cntA : entity work.nBitCounter
        generic map (
            BIT_WIDTH   => PWD_BITLEN)
        port map (
            clk         => clk,
            ce          => mux_cntA_ce,
            sr          => mux_cntA_sr,
            srinit      => actual_len_cntA_dout,
            count_up    => '0',
            dout        => mux_cntA_dout
        );
    mux_cntB : entity work.nBitCounter
        generic map (
            BIT_WIDTH   => PWD_BITLEN)
        port map (
            clk         => clk,
            ce          => mux_cntB_ce,
            sr          => mux_cntB_sr,
            srinit      => actual_len_cntB_dout,
            count_up    => '0',
            dout        => mux_cntB_dout
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    int2asc mapper
    -- --------------------------------------------------------------------- --
    int2asc_mapA : entity work.int2asc
        port map (
            din     => int2asc_dinA,
            dout    => int2asc_doutA
        );
    int2asc_mapB : entity work.int2asc
        port map (
            din     => int2asc_dinB,
            dout    => int2asc_doutB
        );

    int2asc_dinA <= pwd_cnt_doutA(to_integer(unsigned(mux_cntA_dout)))(CHARSET_BIT-1 downto 0);
    int2asc_dinB <= pwd_cnt_doutB(to_integer(unsigned(mux_cntB_dout)))(CHARSET_BIT-1 downto 0);

    -- --------------------------------------------------------------------- --
    -- --------------------------------------------------------------------- --
    -- Logic for writing password
    -- --------------------------------------------------------------------- --
    -- --------------------------------------------------------------------- --
    -- Instantiation    password shiftregs
    --                  holds one of the 18 password-words
    -- --------------------------------------------------------------------- --
    pwd_regA : entity work.nxmBitShiftReg
        generic map (
            N     => 4,
            M     => 8
        )
        port map (
            clk    => clk,
            ce     => pwd_reg_ceA,
            sr     => pwd_reg_srA,
            srinit => const_slv(0, 32),
            opmode => "01", -- [Rot?, Left?] -- [shift,right]
            din    => int2asc_doutA,
            dout   => open,
            dout_f => pwd_reg_doutA
        );
    pwd_regB : entity work.nxmBitShiftReg
        generic map (
            N     => 4,
            M     => 8
        )
        port map (
            clk    => clk,
            ce     => pwd_reg_ceB,
            sr     => pwd_reg_srB,
            srinit => const_slv(0, 32),
            opmode => "01", -- [Rot?, Left?] -- [shift,right]
            din    => int2asc_doutB,
            dout   => open,
            dout_f => pwd_reg_doutB
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    counts loaded bytes for 32bit shiftreg
    --                  e.g. from 0 to 3
    -- --------------------------------------------------------------------- --
    loaded_bytes_cnt : entity work.nBitCounter
        generic map (
            BIT_WIDTH   => 2)
        port map (
            clk         => clk,
            sr          => loaded_bytes_cnt_sr,
            ce          => loaded_bytes_cnt_ce,
            srinit      => const_slv(0, 2),
            count_up    => '1',
            dout        => loaded_bytes_cnt_dout
        );

    -- --------------------------------------------------------------------- --
    -- Instantiation    counts written words to BRAM
    --                  e.g. from 0 to 17
    -- --------------------------------------------------------------------- --
    written_words_cnt : entity work.nBitCounter
        generic map (
            BIT_WIDTH   => 5)
        port map (
            clk         => clk,
            sr          => written_words_cnt_sr,
            ce          => written_words_cnt_ce,
            srinit      => const_slv(0, 5),
            count_up    => '1',
            dout        => written_words_cnt_dout
        );

    addrA <= written_words_cnt_dout;
    addrB <= written_words_cnt_dout;
    dinA <= pwd_reg_doutA;
    dinB <= pwd_reg_doutB;

    -- --------------------------------------------------------------------- --
    -- --------------------------------------------------------------------- --
    -- FSM
    -- --------------------------------------------------------------------- --
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
        current_state, continue, rst, second_iteration,
        overflow, is_actual_dout, prev_overflow,
        updated_cnt_dout, actual_len_cntA_dout, mux_cntA_dout, mux_cntB_dout,
        loaded_bytes_cnt_dout, written_words_cnt_dout, pwd_cnt_srA_d)
    begin
        -- default values

        -- counter and control signals
        pwd_cnt_ceA <= (others => '0');
        pwd_cnt_srA <= (others => '0');
        pwd_cnt_ceB <= (others => '0');
		pwd_cnt_srA_d_rst <= '1';

        snd_iter_ce <= '0';
        snd_iter_sr <= '0';

        is_actual_ce <= '0';
        is_actual_sr <= '0';

        -- load password control signals
        mux_cntA_ce <= '1';
        mux_cntA_sr <= '1';

        mux_cntB_ce <= '1';
        mux_cntB_sr <= '1';

        actual_len_cntA_ce <= '0';
        actual_len_cntA_sr <= '0';
        actual_len_cntB_ce <= '0';

        updated_cnt_ce <= '1';
        updated_cnt_sr <= '1';

        loaded_bytes_cnt_ce <= '1';
        loaded_bytes_cnt_sr <= '1';

        pwd_reg_ceA <= '0';
        pwd_reg_srA <= '0';

        pwd_reg_ceB <= '0';
        pwd_reg_srB <= '0';

        -- write password control signals
        written_words_cnt_ce <= '0';
        written_words_cnt_sr <= '0';

        weA <= '0';
        weB <= '0';

        done <= '0';

        next_state <= current_state;

        -- FSM states
        case current_state is
            -- startup
            when RESET =>
                is_actual_sr <= '1';

                pwd_cnt_srA <= (others => '1');
                pwd_cnt_ceB <= (others => '1');

                snd_iter_sr <= '1';

                --implicitly reset mux counter

                actual_len_cntA_sr <= '1';
                actual_len_cntB_ce <= '1';

                pwd_reg_srA <= '1';
                pwd_reg_srB <= '1';

                written_words_cnt_sr <= '1';

            -- TODO: check whats better: DELAY state or IF?
            --    next_state <= DELAY_A;
            -- when DELAY_A =>
                if rst = '0' then
                    next_state <= COUNTER_UPDATE;
                end if;
            when COUNTER_UPDATE =>
                is_actual_ce <= '1';
				pwd_cnt_srA_d_rst <= '0';

                pwd_cnt_ceA <= prev_overflow or pwd_cnt_srA_d;
                pwd_cnt_srA <= overflow;

                updated_cnt_sr  <= '0';

                -- if hightest active counter overflowed,
                -- count up password length
                if overflow(to_integer(unsigned(actual_len_cntA_dout))-1)
                   = '1'
                then
                    actual_len_cntA_ce <= '1';
                end if;

                if updated_cnt_dout
                   = std_logic_vector(to_unsigned(PWD_LENGTH-1,PWD_BITLEN))
                then
                    if second_iteration = '1' then
                        next_state <= DELAY;
                    else
                        pwd_cnt_ceB     <= (others => '1');
                        is_actual_sr    <= '1';
                        updated_cnt_sr  <= '1';
                        actual_len_cntB_ce <= '1';
                        snd_iter_ce     <= '1';
                    end if;
                end if;
            when DELAY =>
                -- we have to delay the mux counter reset,
                -- because the password length could have increased

                -- implicitly reset password muxer
                -- mux_cntA_sr <= '1';
                -- mux_cntB_sr <= '1';
                next_state <= LOAD_SHIFTREG;
            when LOAD_SHIFTREG =>
                -- mux next byte counter
                if mux_cntA_dout = const_slv(0,PWD_BITLEN) then
                    mux_cntA_sr <= '1';
                else
                    mux_cntA_sr <= '0';
                end if;
                -- mux next byte counter
                if mux_cntB_dout = const_slv(0,PWD_BITLEN) then
                    mux_cntB_sr <= '1';
                else
                    mux_cntB_sr <= '0';
                end if;
                -- count up number of loaded bytes
                loaded_bytes_cnt_sr <= '0';

                -- load byte to shiftregs
                pwd_reg_ceA <= '1';
                pwd_reg_ceB <= '1';

                if loaded_bytes_cnt_dout = "11" then
                    next_state <= WRITE_TO_BRAM;
                end if;
            when WRITE_TO_BRAM =>
                mux_cntA_sr <= '0';
                mux_cntA_ce <= '0';
                mux_cntB_sr <= '0';
                mux_cntB_ce <= '0';

                weA <= '1';
                weB <= '1';

                written_words_cnt_ce <= '1';

                if written_words_cnt_dout = "10001" then
                    next_state <= IDLE;
                else
                    next_state <= LOAD_SHIFTREG;
                end if;
            when IDLE =>
                done <= '1';

                snd_iter_sr <= '1';
                is_actual_sr <= '1';

                actual_len_cntB_ce <= '1';

                pwd_reg_srA <= '1';
                pwd_reg_ceB <= '1';

                written_words_cnt_sr <= '1';

                if continue = '1' then
                    next_state <= COUNTER_UPDATE;
                end if;
        end case; -- state

    end process fsm_ctrl;

end Behavioral;
