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

    function int_to_vect(num : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(num, NUM_PE*DATA_WIDTH));
    end function;

begin

    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut_inst : entity work.acc_mem_unit
        generic map(
            MEM_DEPTH => NUM_PE
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

            procedure write(addr : integer; value : integer) is
            begin
                wr_en_i <= '1';
                write_addr_i <= addr;
                data_i <= int_to_vect(value);
                wait until rising_edge(clk_i);
                wait for 1 ns;

                wr_en_i <= '0';
            end procedure;

            variable result : integer;

            procedure read(addr : integer; variable res : out integer) is
            begin
                read_addr_i <= addr;

                wait until rising_edge(clk_i);
                wait for 1 ns;

                res := to_integer(signed(data_o));
            end procedure;

        begin
            rst_i <= '1';
            wait for 2 ns;
            rst_i <= '0';

            for i in 0 to NUM_PE-1 loop
                read(i, result);
                assert result = 0
                    report "Error in reset 1"
                    severity failure;
            end loop;

            write(0, 1);
            read(0, result);
            assert result = 1
                report "Error in simple write read"
                severity failure;

            rst_i <= '1';
            wait for 2 ns;
            rst_i <= '0';

            for i in 0 to NUM_PE-1 loop
                read(i, result);
                assert result = 0
                    report "Error in reset 2"
                    severity failure;
            end loop;

            for i in 0 to NUM_PE-1 loop
                write(i, i+1);
            end loop;

            for i in NUM_PE-1 downto 0 loop
                read(i, result);
                assert result = i+1
                    report "Error in read out of order"
                    severity failure;
            end loop;

            wr_en_i <= '0';
            write_addr_i <= 0;
            data_i <= int_to_vect(10);

            wait until rising_edge(clk_i);
            wait for 1 ns;

            read(0, result);
            assert result = 1
                report "Error in write enable when 0"
                severity failure;

            wr_en_i <= '1';

            wait until rising_edge(clk_i);
            wait for 1 ns;

            wr_en_i <= '0';

            wait until rising_edge(clk_i);
            wait for 1 ns;

            read(0, result);
            assert result = 10
                report "Error in write enable when 1"
                severity failure;

            wr_en_i <= '1';
            write_addr_i <= 1;
            data_i <= int_to_vect(5);
            read_addr_i <= 0;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert to_integer(signed(data_o)) = 10
                report "Error when reading while writing"
                severity failure;

            assert false
                report "TEST PASSED: acc_mem_unit behaves correctly"
                severity note;
                stop;
        end process;


end architecture;
