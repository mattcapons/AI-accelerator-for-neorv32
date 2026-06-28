library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity buffer_unit is
    port (
        data_i : in  std_logic_vector (DATA_WIDTH-1 downto 0);
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        push_i : in  std_logic;
        pop_i : in  std_logic;
        clear_i : in  std_logic;
        data_o : out signed (DATA_WIDTH-1 downto 0)
    );
end entity buffer_unit;

architecture Behavioral of buffer_unit is
    type data_buffer_t is array (0 to NUM_PE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal data_buffer : data_buffer_t := (others => (others => '0'));
    signal head : integer range 0 to NUM_PE-1 := 0;
    signal tail : integer range 0 to NUM_PE-1 := 0;
    signal count : integer range 0 to NUM_PE := 0;
begin
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            data_buffer <= (others => (others => '0'));
            head <= 0;
            tail <= 0;
            count <= 0;
        elsif rising_edge(clk_i) then
            if clear_i = '1' then
                data_buffer <= (others => (others => '0'));
                head <= 0;
                tail <= 0;
                count <= 0;
            else
                if push_i = '1' and count < NUM_PE then
                    data_buffer(tail) <= data_i;
                    tail <= (tail + 1) mod NUM_PE;
                    count <= count + 1;
                end if;
                if pop_i = '1' and count > 0 then
                    head <= (head + 1) mod NUM_PE;
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;
    data_o <= signed(data_buffer(head));
end architecture Behavioral;
