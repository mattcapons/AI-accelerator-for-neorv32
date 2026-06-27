library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity systolic_pe is
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
end systolic_pe;

architecture Behavioral of systolic_pe is
    signal a_reg : std_logic_vector (7 downto 0) := (others => '0');
    signal w_reg : std_logic_vector (7 downto 0) := (others => '0');
    signal p_sum : std_logic_vector (31 downto 0) := (others => '0');

begin
    process(clk_i, rst_i)
    begin
        -- normal reset behavior
        if rst_i = '1' then
            p_sum <= (others => '0');
            a_reg <= (others => '0');
            w_reg <= (others => '0');

        elsif rising_edge(clk_i) then
            -- synchronous reset behavior
            if clear_i = '1' then
                p_sum <= (others => '0');
                a_reg <= (others => '0');
                w_reg <= (others => '0');
            else
                p_sum <= std_logic_vector(signed(p_sum) + resize(signed(a_in) * signed(w_in), 32));
                a_reg <= a_in;
                w_reg <= w_in;
            end if;
        end if;
    end process;

    a_out <= a_reg;
    w_out <= w_reg;
    p_sum_out <= p_sum;

end Behavioral;