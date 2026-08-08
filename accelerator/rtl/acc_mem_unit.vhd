library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.systolic_pkg.all;

entity acc_mem_unit is
    generic (
        MEM_DEPTH : positive := 2*NUM_PE
    );
    port (
        data_i          : in  std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        read_addr_i     : in  integer range 0 to MEM_DEPTH-1;
        write_addr_i    : in  integer range 0 to MEM_DEPTH-1;
        wr_en_i         : in  std_logic;
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;
        data_o          : out std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0)
    );
end entity acc_mem_unit;

architecture Behavioral of acc_mem_unit is

    type mem_t is array (0 to MEM_DEPTH-1) of std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);

    signal mem_reg : mem_t;

begin

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            mem_reg <= (others => (others => '0'));
            data_o  <= (others => '0');

        elsif rising_edge(clk_i) then

            assert read_addr_i >= 0 and read_addr_i < MEM_DEPTH
                report "Read address out of range"
                severity failure;



            if wr_en_i = '1' then
                assert write_addr_i >= 0 and write_addr_i < MEM_DEPTH
                    report "Write address out of range"
                    severity failure;

                mem_reg(write_addr_i) <= data_i;
            end if;

            data_o <= mem_reg(read_addr_i);

        end if;
    end process;

end architecture Behavioral;
