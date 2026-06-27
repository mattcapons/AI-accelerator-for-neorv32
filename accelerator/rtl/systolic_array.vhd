library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;  

entity systolic_array is
    generic (
        NUM_PE : integer := 4
    );
    port (
        a_in : in byte_array_t(0 to NUM_PE-1);
        w_in : in byte_array_t(0 to NUM_PE-1);
        clear_i : in  std_logic;
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        p_sums_out : out  out_array_t(0 to NUM_PE-1)(0 to NUM_PE-1)
    );
end systolic_array;

architecture Behavioral of systolic_array is
    component systolic_pe is
        port (
            a_in : in  std_logic_vector (7 downto 0);
            w_in : in  std_logic_vector (7 downto 0);
            clear_i : in  std_logic;
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            a_out : out  std_logic_vector (7 downto 0);
            w_out : out  std_logic_vector (7 downto 0);
            p_sum_out : out  std_logic_vector (31 downto 0)
        );
    end component;

    type grid_t is array (natural range <>) of byte_array_t;
    signal a_regs : grid_t(0 to NUM_PE-1)(0 to NUM_PE) := (others => (others => (others => '0')));
    signal w_regs : grid_t(0 to NUM_PE)(0 to NUM_PE-1) := (others => (others => (others => '0')));

begin

    -- connect external inputs into the "column 0" / "row 0" edge of the grid
    gen_a_boundary: for r in 0 to NUM_PE-1 generate
        a_regs(r)(0) <= a_in(r);
    end generate;

    gen_w_boundary: for c in 0 to NUM_PE-1 generate
        w_regs(0)(c) <= w_in(c);
    end generate;

    gen_pe_row : for i in 0 to NUM_PE-1 generate
        gen_pe_col : for j in 0 to NUM_PE-1 generate
            pe_inst : systolic_pe
                port map (
                    a_in => a_regs(i)(j),
                    w_in => w_regs(i)(j),
                    clear_i => clear_i,
                    clk_i => clk_i,
                    rst_i => rst_i,
                    a_out => a_regs(i)(j+1),
                    w_out => w_regs(i+1)(j),
                    p_sum_out => p_sums_out(i)(j)
                );
        end generate gen_pe_col;
    end generate gen_pe_row;
    
end Behavioral;