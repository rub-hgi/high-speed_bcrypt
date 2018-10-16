library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
--use ieee.std_logic_unsigned.all;
--use ieee.numeric_std.all;

library std;
use std.textio.all;

entity fake_top_tb is
end fake_top_tb;

architecture behavior of fake_top_tb is

    --Inputs
    signal reset    : std_logic := '0';
    signal start    : std_logic := '0';
    signal key_we   : std_logic := '0';
    signal key_out  : std_logic_vector(31 downto 0) := (others => '0');
    signal done     : std_logic := '0';
    signal done_out : std_logic := '0';
    --Clk
    signal clk_100      : std_logic := '0';
    signal bcrypt_clk   : std_logic := '0';

    constant clk_100_period     : time := 10 ns;
    constant bcrypt_clk_period  : time :=  6 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut : entity work.fake_top
        port map (
            clk_100     => clk_100,
            bcrypt_clk  => bcrypt_clk,
            rst         => reset,
            start       => start,
            key_we      => key_we,
            key_out     => key_out,
            done        => done,
            done_out    => done_out
        );

    -- Clock process definitions
    clk_100_process : process
    begin
        clk_100 <= '0';
        wait for clk_100_period/2;
        clk_100 <= '1';
        wait for clk_100_period/2;
    end process clk_100_process;

    bcrypt_clk_process : process
    begin
        bcrypt_clk <= '0';
        wait for bcrypt_clk_period/2;
        bcrypt_clk <= '1';
        wait for bcrypt_clk_period/2;
    end process bcrypt_clk_process;


    -- Stimulus process
    stimulus_process : process
    begin
        wait until rising_edge(clk_100);

        reset   <= '1';
        wait for clk_100_period*2;
        reset   <= '0';
        wait for clk_100_period*5;
        start   <= '1';
        wait for clk_100_period;
        wait until rising_edge(bcrypt_clk);
        key_we  <= '1';
        key_out <= x"61626364";
        wait for bcrypt_clk_period;
        key_out <= x"65666768";
        wait for bcrypt_clk_period;
        key_out <= x"696a6b6c";
        wait for bcrypt_clk_period;
        key_out <= x"6d6e6f70";
        wait for bcrypt_clk_period;
        key_out <= x"71727374";
        wait for bcrypt_clk_period;
        key_out <= x"75767778";
        wait for bcrypt_clk_period;
        key_we  <= '0';
        key_out <= x"00000000";
        start   <= '0';
        done    <= '1';
        wait until rising_edge(clk_100);
        wait until done_out = '1';

        assert false report "finished" severity failure;
    end process stimulus_process;

end architecture behavior;
