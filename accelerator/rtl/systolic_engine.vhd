library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;



entity systolic_engine is
    port (
        a_mem_i         : in std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        w_mem_i         : in std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        vld_i           : in std_logic;
        rdy_i           : in std_logic;
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        rdy_o           : out std_logic;
        vld_o           : out std_logic;
        p_sums_out      : out out_array_t
    );
end systolic_engine;

architecture Behavioral of systolic_engine is

    signal a_int : data_array_t := (others => (others => '0'));
    signal w_int : data_array_t := (others => (others => '0'));

    signal clear_int : std_logic;
    signal input_en_int : std_logic;
    signal comp_en_int : std_logic;

begin

    gen_unpack : for i in 0 to NUM_PE-1 generate
        constant hi : integer := (NUM_PE - i) * DATA_WIDTH - 1;
        constant lo : integer := hi - DATA_WIDTH + 1;
    begin
        a_int(i) <= signed(a_mem_i(hi downto lo));
        w_int(i) <= signed(w_mem_i(hi downto lo));
    end generate gen_unpack;

    array_inst : entity work.systolic_array
        port map (
            a_in       => a_int,
            w_in       => w_int,
            clear_i    => clear_int,
            input_en_i => input_en_int,
            comp_en_i  => comp_en_int,
            clk_i      => clk_i,
            rst_i      => rst_i,
            p_sums_out => p_sums_out
        );

    controller_inst : entity work.systolic_controller
        port map (
            vld_i           => vld_i,
            rdy_i           => rdy_i,
            clk_i           => clk_i,
            rst_i           => rst_i,
            rdy_o           => rdy_o,
            vld_o           => vld_o,
            clear_o         => clear_int,
            input_en_o      => input_en_int,
            comp_en_o       => comp_en_int
        );

end architecture Behavioral;
