library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.systolic_pkg.all;

entity systolic_engine is
    port (
        a_buff_i : in  byte_array_t;
        w_buff_i : in  byte_array_t;
        clear_result_i : in  std_logic;
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        start_i : in  std_logic;
        pop_o : out  std_logic_vector(NUM_PE-1 downto 0);
        done_o : out  std_logic;
        p_sums_out : out out_array_t
    );
end systolic_engine;

architecture Behavioral of systolic_engine is

    signal a_feed : byte_array_t := (others => (others => '0'));
    signal w_feed : byte_array_t := (others => (others => '0'));
    signal clear_internal : std_logic := '0';

begin

    gen_array : entity work.systolic_array
        port map (
            a_in       => a_feed,
            w_in       => w_feed,
            clear_i    => clear_internal,
            clk_i      => clk_i,
            rst_i      => rst_i,
            p_sums_out => p_sums_out
        );

    gen_controller : entity work.systolic_controller
        port map (
            a_buff_i => a_buff_i,
            w_buff_i => w_buff_i,
            clear_result_i => clear_result_i,
            clk_i => clk_i,
            rst_i => rst_i,
            start_i => start_i,
            a_feed_o => a_feed,
            w_feed_o => w_feed,
            pop_o => pop_o,
            clear_o => clear_internal,
            done_o => done_o
        );
end architecture Behavioral;