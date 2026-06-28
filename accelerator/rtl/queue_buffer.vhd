library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity queue_buffer is
    port (
        data_i  : in std_logic_vector(DATA_WIDTH-1 downto 0);
        clk_i   : in std_logic;
        rst_i   : in std_logic;
        clear_i : in std_logic;
        push_i  : in std_logic;
        sel_t   : in data_type_t;
        q_sel   : in integer range 0 to NUM_PE-1;
        pop_i   : in  std_logic_vector(0 to NUM_PE-1);
        a_out   : out byte_array_t;
        w_out   : out byte_array_t
    );
end entity;

architecture rtl of queue_buffer is
    signal a_push_reg : std_logic_vector(0 to NUM_PE-1) := (others => '0');
    signal w_push_reg : std_logic_vector(0 to NUM_PE-1) := (others => '0');
begin

    gen_units : for i in 0 to NUM_PE-1 generate

        a_inst : entity work.buffer_unit
            port map (
                data_i => data_i,
                clk_i => clk_i,
                rst_i => rst_i,
                push_i => a_push_reg(i),
                pop_i => pop_i(i),
                clear_i => clear_i,
                data_o => a_out(i)
            );

        w_inst : entity work.buffer_unit
            port map (
                data_i => data_i,
                clk_i => clk_i,
                rst_i => rst_i,
                push_i => w_push_reg(i),
                pop_i => pop_i(i),
                clear_i => clear_i,
                data_o => w_out(i)
            );

    end generate gen_units;
    
    -- Push behaviour
    process (all)
    begin
        a_push_reg <= (others => '0');
        w_push_reg <= (others => '0');

        if push_i = '1' then
            if sel_t = A then
                a_push_reg(q_sel) <= '1';
            else
                w_push_reg(q_sel) <= '1';
            end if;
        end if;
    end process;

end architecture;
