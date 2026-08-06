library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity systolic_pe is
    port (
        a_in        : in signed (DATA_WIDTH-1 downto 0); -- input activation
        w_in        : in signed (DATA_WIDTH-1 downto 0); -- input weight
        clear_i     : in std_logic; -- synchronous clear signal
        en_i        : in std_logic; -- enable signal
        clk_i       : in std_logic;
        rst_i       : in std_logic;
        a_out       : out signed (DATA_WIDTH-1 downto 0); -- output activation
        w_out       : out signed (DATA_WIDTH-1 downto 0); -- output weight
        p_sum_out   : out signed (ACC_WIDTH-1 downto 0) -- output sum
    );
end systolic_pe;

architecture Behavioral of systolic_pe is
    signal acc_reg : signed(ACC_WIDTH-1 downto 0) := (others => '0');
begin
    process(clk_i, rst_i)
    begin
        -- asynchronous reset
        if rst_i = '1' then
            acc_reg <= (others => '0');
            a_out <= (others => '0');
            w_out <= (others => '0');

        elsif rising_edge(clk_i) then
            -- synchronous clear behavior
            if clear_i = '1' then
                acc_reg <= (others => '0');
                a_out <= (others => '0');
                w_out <= (others => '0');
            else
                if en_i = '1' then
                    a_out <= a_in;
                    w_out <= w_in;
                    acc_reg <= acc_reg + resize(a_in * w_in, ACC_WIDTH); -- accumulate the product of a_in and w_in into p_sum
                end if;
            end if;
        end if;
    end process;

    p_sum_out <= acc_reg;
end Behavioral;
