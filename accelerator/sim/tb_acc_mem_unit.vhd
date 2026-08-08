library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.systolic_pkg.all;

entity tb_acc_mem_unit is
end tb_acc_mem_unit;

architecture sim of tb_acc_mem_unit is

    ------------------------------------------------------------------------
    -- DUT signals
    ------------------------------------------------------------------------
    signal data_i           : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal read_addr_i      : integer range 0 to NUM_PE-1;
    signal write_addr_i     : integer range 0 to NUM_PE-1;
    signal wr_en_i          : std_logic;
    signal clk_i            : std_logic;
    signal rst_i            : std_logic;
    signal data_o           : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);

    ------------------------------------------------------------------------
    -- Clock period
    ------------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    ------------------------------------------------------------------------
    -- Convert integer matrix column to 8-bit std_logic_vector array
    ------------------------------------------------------------------------
    procedure write(addr : integer; value : integer) is
    begin
        wr_en_i <= '1';
        write_addr_i <= addr;
        data_i <= std_logic_vector(to_unsigned(value, NUM_PE*DATA_WIDTH));

        wait until rising_edge(clk_i);
        wait for 10 ns;

        wr_en_i <= '0';
    end procedure;

    function read(addr : integer) return integer is
        variable result : integer := 0;
    begin
        read_addr_i <= addr;

        wait until rising_edge(clk_i);
        wait for 10 ns;

        result := to_integer(signed(data_o));
        return result;
    end function;

begin

    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut_inst : entity work.acc_mem_unit
        generic map(
            MEM_DEPTH => 2 * NUM_PE
        )
        port map (
            data_i          => data_i,
            read_addr_i     => read_addr_i,
            write_addr_i    => write_addr_i,
            wr_en_i         => wr_en_i,
            clk_i           => clk_i,
            rst_i           => rst_i,
            data_o          => data_o
        );

        ------------------------------------------------------------------------
        -- Clock generation
        ------------------------------------------------------------------------
        clk_process : process
        begin
            while true loop
                clk_i <= '0';
                wait for CLK_PERIOD / 2;
                clk_i <= '1';
                wait for CLK_PERIOD / 2;
            end loop;
        end process;

        ------------------------------------------------------------------------
        -- Stimulus process
        ------------------------------------------------------------------------
        stim_process : process
        begin


        end process;


end architecture;
