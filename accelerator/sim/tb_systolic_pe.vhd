library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

library work;
use work.systolic_pkg.all;

entity tb_systolic_pe is
end tb_systolic_pe;

architecture sim of tb_systolic_pe is

    signal a_in      : std_logic_vector(DATA_WIDTH-1 downto 0)  := (others => '0');
    signal w_in      : std_logic_vector(DATA_WIDTH-1 downto 0)  := (others => '0');
    signal clear_i   : std_logic := '0';
    signal clk_i     : std_logic := '0';
    signal rst_i     : std_logic := '0';

    signal a_out     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal w_out     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal p_sum_out : std_logic_vector(ACC_WIDTH-1 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    function slv_data(x : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(x, DATA_WIDTH));
    end function;

    function slv_acc(x : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(x, ACC_WIDTH));
    end function;

    procedure check_outputs(
        constant expected_a   : in integer;
        constant expected_w   : in integer;
        constant expected_sum : in integer;
        constant test_name    : in string
    ) is
    begin
        assert a_out = slv_data(expected_a)
            report "FAIL: " & test_name & " a_out wrong"
            severity failure;

        assert w_out = slv_data(expected_w)
            report "FAIL: " & test_name & " w_out wrong"
            severity failure;

        assert p_sum_out = slv_acc(expected_sum)
            report "FAIL: " & test_name & " p_sum_out wrong"
            severity failure;
    end procedure;

    procedure apply_and_check(
        signal a_sig          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        signal w_sig          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        constant a_value      : in integer;
        constant w_value      : in integer;
        constant expected_sum : in integer;
        constant test_name    : in string
    ) is
    begin
        a_sig <= slv_data(a_value);
        w_sig <= slv_data(w_value);

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(a_value, w_value, expected_sum, test_name);
    end procedure;

begin

    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut : entity work.systolic_pe
        port map (
            a_in      => a_in,
            w_in      => w_in,
            clear_i   => clear_i,
            clk_i     => clk_i,
            rst_i     => rst_i,
            a_out     => a_out,
            w_out     => w_out,
            p_sum_out => p_sum_out
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
        variable expected_sum : integer := 0;
    begin

        --------------------------------------------------------------------
        -- Initial asynchronous reset check
        --------------------------------------------------------------------
        rst_i   <= '1';
        clear_i <= '0';

        -- Intentionally non-zero values to prove reset dominates the datapath.
        a_in <= slv_data(55);
        w_in <= slv_data(-12);

        wait for 2 ns;

        check_outputs(0, 0, 0, "asynchronous reset immediate check");

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(0, 0, 0, "asynchronous reset after clock edge");

        --------------------------------------------------------------------
        -- Release reset safely
        -- Important: set inputs to zero before the next active clock edge,
        -- otherwise the PE would immediately accumulate the old test values.
        --------------------------------------------------------------------
        rst_i <= '0';
        a_in  <= slv_data(0);
        w_in  <= slv_data(0);

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(0, 0, 0, "reset release with zero inputs");

        --------------------------------------------------------------------
        -- Normal accumulation with at least 3 sets of values
        -- 3*4 + (-2)*5 + 7*(-1) = 12 - 10 - 7 = -5
        --------------------------------------------------------------------
        expected_sum := 0;

        expected_sum := expected_sum + 3 * 4;
        apply_and_check(a_in, w_in, 3, 4, expected_sum, "normal compute step 1");

        expected_sum := expected_sum + (-2) * 5;
        apply_and_check(a_in, w_in, -2, 5, expected_sum, "normal compute step 2");

        expected_sum := expected_sum + 7 * (-1);
        apply_and_check(a_in, w_in, 7, -1, expected_sum, "normal compute step 3");

        --------------------------------------------------------------------
        -- Zero multiplication check
        -- Accumulator must not change, but passthrough must still update.
        --------------------------------------------------------------------
        expected_sum := expected_sum + 0 * 99;
        apply_and_check(a_in, w_in, 0, 99, expected_sum, "zero multiplication with a_in zero");

        expected_sum := expected_sum + 88 * 0;
        apply_and_check(a_in, w_in, 88, 0, expected_sum, "zero multiplication with w_in zero");

        --------------------------------------------------------------------
        -- Synchronous clear check
        -- clear_i is checked only after a rising clock edge.
        --------------------------------------------------------------------
        clear_i <= '1';

        -- Non-zero values to prove clear_i dominates computation.
        a_in <= slv_data(10);
        w_in <= slv_data(10);

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(0, 0, 0, "synchronous clear");

        clear_i <= '0';
        a_in    <= slv_data(0);
        w_in    <= slv_data(0);

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(0, 0, 0, "after clear release with zero inputs");

        --------------------------------------------------------------------
        -- Max positive signed 8-bit values
        -- 127 * 127 = 16129
        --------------------------------------------------------------------
        expected_sum := 0;

        expected_sum := expected_sum + 127 * 127;
        apply_and_check(a_in, w_in, 127, 127, expected_sum, "max positive multiplication");

        --------------------------------------------------------------------
        -- Clear before max negative tests
        --------------------------------------------------------------------
        clear_i <= '1';
        a_in    <= slv_data(0);
        w_in    <= slv_data(0);

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(0, 0, 0, "clear before max negative tests");

        clear_i <= '0';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(0, 0, 0, "after second clear release");

        --------------------------------------------------------------------
        -- Max negative signed 8-bit squared
        -- (-128) * (-128) = 16384
        --------------------------------------------------------------------
        expected_sum := 0;

        expected_sum := expected_sum + (-128) * (-128);
        apply_and_check(a_in, w_in, -128, -128, expected_sum, "max negative squared");

        --------------------------------------------------------------------
        -- Accumulate with max negative and max positive
        -- current sum = 16384
        -- add (-128) * 127 = -16256
        -- final sum = 128
        --------------------------------------------------------------------
        expected_sum := expected_sum + (-128) * 127;
        apply_and_check(a_in, w_in, -128, 127, expected_sum, "max negative times max positive");

        --------------------------------------------------------------------
        -- Normal passthrough after extreme values
        --------------------------------------------------------------------
        expected_sum := expected_sum + 5 * 6;
        apply_and_check(a_in, w_in, 5, 6, expected_sum, "passthrough after extreme values");

        --------------------------------------------------------------------
        -- Asynchronous reset after computation
        --------------------------------------------------------------------
        rst_i <= '1';

        wait for 2 ns;

        check_outputs(0, 0, 0, "asynchronous reset after computation");

        rst_i <= '0';
        a_in  <= slv_data(0);
        w_in  <= slv_data(0);

        wait until rising_edge(clk_i);
        wait for 1 ns;

        check_outputs(0, 0, 0, "final reset release");

        --------------------------------------------------------------------
        -- End simulation
        --------------------------------------------------------------------
        assert false
            report "TEST PASSED: systolic_pe behaves correctly"
            severity note;
            stop;
        wait;

    end process;

end sim;