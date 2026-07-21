library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;



entity systolic_engine is
    port (
        a_mem_i         : in std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        w_mem_i         : in std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        start_i         : in std_logic;
        feed_idx_o      : out integer range 0 to NUM_PE-1;
        rdy_o           : out std_logic;
        done_o          : out std_logic;
        p_sum_out       : out signed(ACC_WIDTH-1 downto 0);
        p_sum_valid_o   : out std_logic
    );
end systolic_engine;

architecture Behavioral of systolic_engine is

    signal a_int : data_array_t := (others => (others => '0'));
    signal w_int : data_array_t := (others => (others => '0'));
    signal p_sums_int : out_array_t := (others => (others => (others => '0')));

    signal clear_int : std_logic;
    signal feed_int : std_logic;

begin

    gen_unpack : for i in 0 to NUM_PE-1 generate
        constant hi : integer := (NUM_PE - i) * DATA_WIDTH - 1;
        constant lo : integer := hi - DATA_WIDTH + 1;
    begin
        a_int(i) <= signed(a_mem_i(hi downto lo));
        w_int(i) <= signed(w_mem_i(hi downto lo));
    end generate gen_unpack;

    gen_array : entity work.systolic_array
        port map (
            a_in        => a_int,
            w_in        => w_int,
            clear_i     => clear_int,
            clk_i       => clk_i,
            rst_i       => rst_i,
            input_en_i  => feed_int,
            p_sums_out  => p_sums_int
        );

    gen_controller : entity work.systolic_controller
        port map (
            p_sums_i        => p_sums_int,
            clk_i           => clk_i,
            rst_i           => rst_i,
            start_i         => start_i,
            p_sum_o         => p_sum_out,
            rdy_o           => rdy_o,
            feed_idx_o      => feed_idx_o,
            clear_o         => clear_int,
            done_o          => done_o,
            feed_valid_o    => feed_int,
            p_sum_valid_o   => p_sum_valid_o
        );

end architecture Behavioral;
