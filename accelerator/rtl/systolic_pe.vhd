library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity systolic_pe is
    port (
        a_in        : in  signed (DATA_WIDTH-1 downto 0);
        w_in        : in  signed (DATA_WIDTH-1 downto 0);
        clear_i     : in  std_logic;
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;
        a_out       : out  signed (DATA_WIDTH-1 downto 0);
        w_out       : out  signed (DATA_WIDTH-1 downto 0);
        p_sum_out   : out  signed (ACC_WIDTH-1 downto 0)
    );
end systolic_pe;

architecture Behavioral of systolic_pe is
    signal a_reg : signed (DATA_WIDTH-1 downto 0) := (others => '0');
    signal w_reg : signed (DATA_WIDTH-1 downto 0) := (others => '0');
    signal p_sum : signed(ACC_WIDTH-1 downto 0) := (others => '0');
begin
    process(clk_i, rst_i)
    begin
        -- normal reset behavior
        if rst_i = '1' then
            p_sum <= (others => '0');
            a_reg <= (others => '0');
            w_reg <= (others => '0');

        elsif rising_edge(clk_i) then
            -- synchronous clear behavior
            if clear_i = '1' then
                p_sum <= (others => '0');
                a_reg <= (others => '0');
                w_reg <= (others => '0');
            else
                a_reg <= a_in;
                w_reg <= w_in;
                p_sum <= p_sum + resize(a_in * w_in, ACC_WIDTH);
            end if;
        end if;
    end process;

    a_out <= a_reg;
    w_out <= w_reg;
    p_sum_out <= p_sum;
end Behavioral;