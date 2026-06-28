library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity systolic_array is
    port (
        a_in       : in  byte_array_t;
        w_in       : in  byte_array_t;
        clear_i    : in  std_logic;
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        p_sums_out : out out_array_t
    );
end entity systolic_array;

architecture Behavioral of systolic_array is

    type a_grid_t is array (0 to NUM_PE-1, 0 to NUM_PE) of signed(DATA_WIDTH-1 downto 0);
    type w_grid_t is array (0 to NUM_PE, 0 to NUM_PE-1) of signed(DATA_WIDTH-1 downto 0);

    signal a_regs : a_grid_t := (others => (others => (others => '0')));
    signal w_regs : w_grid_t := (others => (others => (others => '0')));

begin

    gen_a_boundary : for r in 0 to NUM_PE-1 generate
        a_regs(r, 0) <= a_in(r);
    end generate;

    gen_w_boundary : for c in 0 to NUM_PE-1 generate
        w_regs(0, c) <= w_in(c);
    end generate;

    gen_pe_row : for i in 0 to NUM_PE-1 generate
        gen_pe_col : for j in 0 to NUM_PE-1 generate

            pe_inst : entity work.systolic_pe
                port map (
                    a_in      => a_regs(i, j),
                    w_in      => w_regs(i, j),
                    clear_i   => clear_i,
                    clk_i     => clk_i,
                    rst_i     => rst_i,
                    a_out     => a_regs(i, j+1),
                    w_out     => w_regs(i+1, j),
                    p_sum_out => p_sums_out(i, j)
                );

        end generate gen_pe_col;
    end generate gen_pe_row;

end architecture Behavioral;