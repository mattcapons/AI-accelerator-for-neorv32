library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.systolic_pkg.all;

entity tb_buffer_unit is
end entity tb_buffer_unit;

architecture sim of tb_buffer_unit is

    -- Clock period
    constant clk_period : time := 10 ns;

    -- DUT signals
    signal clk_i        : std_logic := '0';
    signal rst_i        : std_logic := '1';
    signal push_i       : std_logic := '0';
    signal pop_i        : std_logic := '0';
    signal clear_i      : std_logic := '0';
    signal data_i       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_o       : signed(DATA_WIDTH-1 downto 0);

    function int_to_vect(x : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(x, DATA_WIDTH));
    end function;

    function int_to_sign(x : integer) return signed is
    begin
        return to_signed(x, DATA_WIDTH);
    end function;

    procedure tick_clock is
    begin
        wait until rising_edge(clk_i);
        wait for 1 ns;
    end procedure;

    procedure push_value(
        signal data_sig : out std_logic_vector(DATA_WIDTH-1 downto 0);
        signal push_sig : out std_logic;
        constant data : in integer
    ) is
    begin
        data_sig <= int_to_vect(data);
        push_sig <= '1';
        tick_clock;
        push_sig <= '0';
    end procedure;

    procedure pop_and_check(
        signal pop_sig      : out std_logic;
        constant expected_data : in integer;
        constant test_name     : in string
    ) is
    begin
        assert data_o = int_to_sign(expected_data)
            report test_name
            severity failure;

        pop_sig <= '1';
        tick_clock;
        pop_sig <= '0';
    end procedure;

begin
    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut : entity work.buffer_unit
        port map (
            data_i      => data_i,
            clk_i       => clk_i,
            rst_i       => rst_i,
            push_i      => push_i,
            pop_i       => pop_i,
            clear_i     => clear_i,
            data_o      => data_o
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
            wait for CLK_PERIOD /  2;
        end loop;
    end process;

    ------------------------------------------------------------------------
    -- Stimulus process
    ------------------------------------------------------------------------
    stim_process : process
        constant data1 : integer := 1;
        constant data2 : integer := 2;
        constant data3 : integer := 3;
        constant data4 : integer := 4;
        variable value_before_extra_pop : signed(DATA_WIDTH-1 downto 0);
    begin
        tick_clock;

        assert data_o = int_to_sign(0)
            report "Initial data not zero"
            severity failure;

        rst_i <= '0';
        tick_clock;

        -- Fill the queue
        push_value(data_i, push_i, data1);
        push_value(data_i, push_i, data2);
        push_value(data_i, push_i, data3);
        push_value(data_i, push_i, data4);

        -- This extra push must be ignored because the queue is full.
        push_i <= '1';
        data_i <= int_to_vect(data1);
        tick_clock;
        push_i <= '0';

        -- Empty the queue. data_o is the current head before the pop edge.
        pop_and_check(pop_i, data1, "First pop incorrect");
        pop_and_check(pop_i, data2, "Second pop incorrect");
        pop_and_check(pop_i, data3, "Third pop incorrect");
        pop_and_check(pop_i, data4, "Fourth pop incorrect");

        -- The fourth valid pop advances head from the last slot back to zero.
        -- The next pop is extra/empty and must leave the visible output stable.
        value_before_extra_pop := data_o;
        pop_i <= '1';
        tick_clock;
        pop_i <= '0';

        assert data_o = value_before_extra_pop
            report "Extra pop changed output"
            severity failure;

        -- Clear must reset stored data and pointers.
        clear_i <= '1';
        tick_clock;
        clear_i <= '0';
        assert data_o = int_to_sign(0)
            report "Clear did not reset output"
            severity failure;

        -- Pop after clear must keep the cleared output stable.
        pop_i <= '1';
        tick_clock;
        pop_i <= '0';

        assert data_o = int_to_sign(0)
            report "Pop after clear changed output"
            severity failure;

        assert false
            report "TEST PASSED: buffer_unit behaves correctly"
            severity note;
        stop;

    end process;
end architecture sim;
