-------------------------------------------------------------------------------
-- Title      : int2asc map Topmodule
-- Project    : bcrypt bruteforce
-- ----------------------------------------------------------------------------
-- File       : int2asc.vhd
-- Author     : Friedrich Wiemer <friedrich.wiemer@rub.de>
-- Company    : Ruhr-University Bochum
-- Created    : 2014-04-09
-- Last update: 2014-04-09
-- Platform   : Xilinx Toolchain
-- Standard   : VHDL'93/02
-- ----------------------------------------------------------------------------
-- Description:
--    maps input signal to ascii representation
-- ----------------------------------------------------------------------------
-- Copyright (c) 2011-2014 Ruhr-University Bochum
-- ----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-04-09  1.0      fwi     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.pkg_bcrypt.all;

entity int2asc is
    port (
        din     : in  std_logic_vector(CHARSET_BIT-1 downto 0);
        dout    : out std_logic_vector(7 downto 0)
    );
end int2asc;

architecture Behavioral of int2asc is
    -- --------------------------------------------------------------------- --
    -- Constants
    -- --------------------------------------------------------------------- --

    constant OUT_nul   : std_logic_vector(7 downto 0) := x"00";
    constant OUT_zero  : std_logic_vector(7 downto 0) := x"30";
    constant OUT_one   : std_logic_vector(7 downto 0) := x"31";
    constant OUT_two   : std_logic_vector(7 downto 0) := x"32";
    constant OUT_three : std_logic_vector(7 downto 0) := x"33";
    constant OUT_four  : std_logic_vector(7 downto 0) := x"34";
    constant OUT_five  : std_logic_vector(7 downto 0) := x"35";
    constant OUT_six   : std_logic_vector(7 downto 0) := x"36";
    constant OUT_seven : std_logic_vector(7 downto 0) := x"37";
    constant OUT_eight : std_logic_vector(7 downto 0) := x"38";
    constant OUT_nine  : std_logic_vector(7 downto 0) := x"39";

    constant OUT_A_up  : std_logic_vector(7 downto 0) := x"41";
    constant OUT_B_up  : std_logic_vector(7 downto 0) := x"42";
    constant OUT_C_up  : std_logic_vector(7 downto 0) := x"43";
    constant OUT_D_up  : std_logic_vector(7 downto 0) := x"44";
    constant OUT_E_up  : std_logic_vector(7 downto 0) := x"45";
    constant OUT_F_up  : std_logic_vector(7 downto 0) := x"46";
    constant OUT_G_up  : std_logic_vector(7 downto 0) := x"47";
    constant OUT_H_up  : std_logic_vector(7 downto 0) := x"48";
    constant OUT_I_up  : std_logic_vector(7 downto 0) := x"49";
    constant OUT_J_up  : std_logic_vector(7 downto 0) := x"4a";
    constant OUT_K_up  : std_logic_vector(7 downto 0) := x"4b";
    constant OUT_L_up  : std_logic_vector(7 downto 0) := x"4c";
    constant OUT_M_up  : std_logic_vector(7 downto 0) := x"4d";
    constant OUT_N_up  : std_logic_vector(7 downto 0) := x"4e";
    constant OUT_O_up  : std_logic_vector(7 downto 0) := x"4f";
    constant OUT_P_up  : std_logic_vector(7 downto 0) := x"50";
    constant OUT_Q_up  : std_logic_vector(7 downto 0) := x"51";
    constant OUT_R_up  : std_logic_vector(7 downto 0) := x"52";
    constant OUT_S_up  : std_logic_vector(7 downto 0) := x"53";
    constant OUT_T_up  : std_logic_vector(7 downto 0) := x"54";
    constant OUT_U_up  : std_logic_vector(7 downto 0) := x"55";
    constant OUT_V_up  : std_logic_vector(7 downto 0) := x"56";
    constant OUT_W_up  : std_logic_vector(7 downto 0) := x"57";
    constant OUT_X_up  : std_logic_vector(7 downto 0) := x"58";
    constant OUT_Y_up  : std_logic_vector(7 downto 0) := x"59";
    constant OUT_Z_up  : std_logic_vector(7 downto 0) := x"5a";

    constant OUT_a_lo  : std_logic_vector(7 downto 0) := x"61";
    constant OUT_b_lo  : std_logic_vector(7 downto 0) := x"62";
    constant OUT_c_lo  : std_logic_vector(7 downto 0) := x"63";
    constant OUT_d_lo  : std_logic_vector(7 downto 0) := x"64";
    constant OUT_e_lo  : std_logic_vector(7 downto 0) := x"65";
    constant OUT_f_lo  : std_logic_vector(7 downto 0) := x"66";
    constant OUT_g_lo  : std_logic_vector(7 downto 0) := x"67";
    constant OUT_h_lo  : std_logic_vector(7 downto 0) := x"68";
    constant OUT_i_lo  : std_logic_vector(7 downto 0) := x"69";
    constant OUT_j_lo  : std_logic_vector(7 downto 0) := x"6a";
    constant OUT_k_lo  : std_logic_vector(7 downto 0) := x"6b";
    constant OUT_l_lo  : std_logic_vector(7 downto 0) := x"6c";
    constant OUT_m_lo  : std_logic_vector(7 downto 0) := x"6d";
    constant OUT_n_lo  : std_logic_vector(7 downto 0) := x"6e";
    constant OUT_o_lo  : std_logic_vector(7 downto 0) := x"6f";
    constant OUT_p_lo  : std_logic_vector(7 downto 0) := x"70";
    constant OUT_q_lo  : std_logic_vector(7 downto 0) := x"71";
    constant OUT_r_lo  : std_logic_vector(7 downto 0) := x"72";
    constant OUT_s_lo  : std_logic_vector(7 downto 0) := x"73";
    constant OUT_t_lo  : std_logic_vector(7 downto 0) := x"74";
    constant OUT_u_lo  : std_logic_vector(7 downto 0) := x"75";
    constant OUT_v_lo  : std_logic_vector(7 downto 0) := x"76";
    constant OUT_w_lo  : std_logic_vector(7 downto 0) := x"77";
    constant OUT_x_lo  : std_logic_vector(7 downto 0) := x"78";
    constant OUT_y_lo  : std_logic_vector(7 downto 0) := x"79";
    constant OUT_z_lo  : std_logic_vector(7 downto 0) := x"7a";

begin

    dout <= OUT_nul  when din = "000000" else
            OUT_a_lo when din = "000001" else
            OUT_b_lo when din = "000010" else
            OUT_c_lo when din = "000011" else
            OUT_d_lo when din = "000100" else
            OUT_e_lo when din = "000101" else
            OUT_f_lo when din = "000110" else
            OUT_g_lo when din = "000111" else
            OUT_h_lo when din = "001000" else
            OUT_i_lo when din = "001001" else
            OUT_j_lo when din = "001010" else
            OUT_k_lo when din = "001011" else
            OUT_l_lo when din = "001100" else
            OUT_m_lo when din = "001101" else
            OUT_n_lo when din = "001110" else
            OUT_o_lo when din = "001111" else
            OUT_p_lo when din = "010000" else
            OUT_q_lo when din = "010001" else
            OUT_r_lo when din = "010010" else
            OUT_s_lo when din = "010011" else
            OUT_t_lo when din = "010100" else
            OUT_u_lo when din = "010101" else
            OUT_v_lo when din = "010110" else
            OUT_w_lo when din = "010111" else
            OUT_x_lo when din = "011000" else
            OUT_y_lo when din = "011001" else
            OUT_z_lo when din = "011010" else

            OUT_A_up when din = "011011" else
            OUT_B_up when din = "011100" else
            OUT_C_up when din = "011101" else
            OUT_D_up when din = "011110" else
            OUT_E_up when din = "011111" else
            OUT_F_up when din = "100000" else
            OUT_G_up when din = "100001" else
            OUT_H_up when din = "100010" else
            OUT_I_up when din = "100011" else
            OUT_J_up when din = "100100" else
            OUT_K_up when din = "100101" else
            OUT_L_up when din = "100110" else
            OUT_M_up when din = "100111" else
            OUT_N_up when din = "101000" else
            OUT_O_up when din = "101001" else
            OUT_P_up when din = "101010" else
            OUT_Q_up when din = "101011" else
            OUT_R_up when din = "101100" else
            OUT_S_up when din = "101101" else
            OUT_T_up when din = "101110" else
            OUT_U_up when din = "101111" else
            OUT_V_up when din = "110000" else
            OUT_W_up when din = "110001" else
            OUT_X_up when din = "110010" else
            OUT_Y_up when din = "110011" else
            OUT_Z_up when din = "110100" else

            OUT_zero  when din = "110101" else
            OUT_one   when din = "110110" else
            OUT_two   when din = "110111" else
            OUT_three when din = "111000" else
            OUT_four  when din = "111001" else
            OUT_five  when din = "111010" else
            OUT_six   when din = "111011" else
            OUT_seven when din = "111100" else
            OUT_eight when din = "111101" else
            OUT_nine  when din = "111110" else
            "XXXXXXXX";

end Behavioral;
