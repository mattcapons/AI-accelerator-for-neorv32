library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

use work.systolic_pkg.all;

entity tb_systolic_controller is
end entity tb_systolic_controller;

architecture sim of tb_systolic_controller is

    ----------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------
    signal p_sums_i      : out_array_t := (others => (others => (others => '0')));
    signal clk_i         : std_logic := '0';
    signal rst_i         : std_logic := '0';
    signal start_i       : std_logic := '0';

    signal p_sum_o       : signed(ACC_WIDTH-1 downto 0);
    signal rdy_o         : std_logic;
    signal feed_idx_o    : integer range 0 to NUM_PE-1;
    signal clear_o       : std_logic;
    signal done_o        : std_logic;
    signal feed_valid_o  : std_logic;
    signal p_sum_valid_o : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    ----------------------------------------------------------------
    -- Helper function
    ----------------------------------------------------------------
    function signed_acc(x : integer) return signed is
    begin
        return to_signed(x, ACC_WIDTH);
    end function;

    ----------------------------------------------------------------
    -- Wait one clock and allow combinational outputs to settle
    ----------------------------------------------------------------
    procedure tick is
    begin
        wait until rising_edge(clk_i);
        wait for 1 ns;
    end procedure;

    ----------------------------------------------------------------
    -- Generic controller-output check
    ----------------------------------------------------------------
    procedure check_ctrl(
        constant expected_rdy         : in std_logic;
        constant expected_feed_valid  : in std_logic;
        constant expected_feed_idx    : in integer;
        constant expected_p_sum_valid : in std_logic;
        constant expected_p_sum       : in integer;
        constant expected_done        : in std_logic;
        constant expected_clear       : in std_logic;
        constant test_name            : in string
    ) is
        variable actual_p_sum : integer;
    begin

        assert rdy_o = expected_rdy
            report "FAIL: " & test_name & " rdy_o wrong. Expected " &
                   std_logic'image(expected_rdy) & ", got " &
                   std_logic'image(rdy_o)
            severity failure;

        assert feed_valid_o = expected_feed_valid
            report "FAIL: " & test_name & " feed_valid_o wrong. Expected " &
                   std_logic'image(expected_feed_valid) & ", got " &
                   std_logic'image(feed_valid_o)
            severity failure;

        assert feed_idx_o = expected_feed_idx
            report "FAIL: " & test_name & " feed_idx_o wrong. Expected " &
                   integer'image(expected_feed_idx) & ", got " &
                   integer'image(feed_idx_o)
            severity failure;

        assert p_sum_valid_o = expected_p_sum_valid
            report "FAIL: " & test_name & " p_sum_valid_o wrong. Expected " &
                   std_logic'image(expected_p_sum_valid) & ", got " &
                   std_logic'image(p_sum_valid_o)
            severity failure;

        if expected_p_sum_valid = '1' then
            actual_p_sum := to_integer(p_sum_o);

            assert actual_p_sum = expected_p_sum
                report "FAIL: " & test_name & " p_sum_o wrong. Expected " &
                       integer'image(expected_p_sum) & ", got " &
                       integer'image(actual_p_sum)
                severity failure;
        end if;

        assert done_o = expected_done
            report "FAIL: " & test_name & " done_o wrong. Expected " &
                   std_logic'image(expected_done) & ", got " &
                   std_logic'image(done_o)
            severity failure;

        assert clear_o = expected_clear
            report "FAIL: " & test_name & " clear_o wrong. Expected " &
                   std_logic'image(expected_clear) & ", got " &
                   std_logic'image(clear_o)
            severity failure;

    end procedure;

begin

    ----------------------------------------------------------------
    -- DUT instantiation
    ----------------------------------------------------------------
    dut : entity work.systolic_controller
        port map (
            p_sums_i      => p_sums_i,
            clk_i         => clk_i,
            rst_i         => rst_i,
            start_i       => start_i,
            p_sum_o       => p_sum_o,
            rdy_o         => rdy_o,
            feed_idx_o    => feed_idx_o,
            clear_o       => clear_o,
            done_o        => done_o,
            feed_valid_o  => feed_valid_o,
            p_sum_valid_o => p_sum_valid_o
        );

    ----------------------------------------------------------------
    -- Clock generation
    ----------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk_i <= '0';
            wait for CLK_PERIOD / 2;
            clk_i <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Stimulus
    ----------------------------------------------------------------
    stimulus : process
        variable expected_value : integer;
    begin

        ----------------------------------------------------------------
        -- Initialize fake systolic-array outputs.
        --
        -- p_sums_i(i,j) = 10*i + j
        --
        -- So row-major output should be:
        -- 0, 1, 2, 3,
        -- 10, 11, 12, 13,
        -- 20, 21, 22, 23,
        -- 30, 31, 32, 33
        ----------------------------------------------------------------
        for i in 0 to NUM_PE-1 loop
            for j in 0 to NUM_PE-1 loop
                p_sums_i(i, j) <= signed_acc(10*i + j);
            end loop;
        end loop;

        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------
        rst_i   <= '1';
        start_i <= '0';

        wait for 2 * CLK_PERIOD;
        wait until rising_edge(clk_i);
        wait for 1 ns;

        rst_i <= '0';

        tick;

        check_ctrl(
            expected_rdy         => '1',
            expected_feed_valid  => '0',
            expected_feed_idx    => 0,
            expected_p_sum_valid => '0',
            expected_p_sum       => 0,
            expected_done        => '0',
            expected_clear       => '0',
            test_name            => "IDLE after reset"
        );

        ----------------------------------------------------------------
        -- Start pulse.
        -- After this clock, FSM is in FEED with cycle_count = 0.
        ----------------------------------------------------------------
        start_i <= '1';
        tick;
        start_i <= '0';

        check_ctrl(
            expected_rdy         => '0',
            expected_feed_valid  => '0',
            expected_feed_idx    => 0,
            expected_p_sum_valid => '0',
            expected_p_sum       => 0,
            expected_done        => '0',
            expected_clear       => '0',
            test_name            => "FEED dummy cycle"
        );

        ----------------------------------------------------------------
        -- FEED cycles.
        --
        -- This matches your current controller code:
        --
        -- cycle_count = 1 -> feed_idx_o = 1
        -- cycle_count = 2 -> feed_idx_o = 2
        -- cycle_count = 3 -> feed_idx_o = 3
        -- cycle_count = 4 -> feed_idx_o = 0
        --
        -- If you later change feed_idx_o to cycle_count - 1, then these
        -- expected values must become 0, 1, 2, 3.
        ----------------------------------------------------------------
        tick;
        check_ctrl('0', '1', 1, '0', 0, '0', '0', "FEED cycle 1");

        tick;
        check_ctrl('0', '1', 2, '0', 0, '0', '0', "FEED cycle 2");

        tick;
        check_ctrl('0', '1', 3, '0', 0, '0', '0', "FEED cycle 3");

        tick;
        check_ctrl('0', '1', 0, '0', 0, '0', '0', "FEED cycle 4");

        ----------------------------------------------------------------
        -- DRAIN cycle
        ----------------------------------------------------------------
        tick;
        check_ctrl(
            expected_rdy         => '0',
            expected_feed_valid  => '0',
            expected_feed_idx    => 0,
            expected_p_sum_valid => '0',
            expected_p_sum       => 0,
            expected_done        => '0',
            expected_clear       => '0',
            test_name            => "DRAIN"
        );

        ----------------------------------------------------------------
        -- OUTPUT cycles.
        -- Controller should serialize p_sums_i row-major.
        ----------------------------------------------------------------
        for i in 0 to NUM_PE-1 loop
            for j in 0 to NUM_PE-1 loop

                tick;

                expected_value := 10*i + j;

                check_ctrl(
                    expected_rdy         => '0',
                    expected_feed_valid  => '0',
                    expected_feed_idx    => 0,
                    expected_p_sum_valid => '1',
                    expected_p_sum       => expected_value,
                    expected_done        => '0',
                    expected_clear       => '0',
                    test_name            => "OUTPUT (" &
                                            integer'image(i) & "," &
                                            integer'image(j) & ")"
                );

            end loop;
        end loop;

        ----------------------------------------------------------------
        -- DONE
        ----------------------------------------------------------------
        tick;

        check_ctrl(
            expected_rdy         => '0',
            expected_feed_valid  => '0',
            expected_feed_idx    => 0,
            expected_p_sum_valid => '0',
            expected_p_sum       => 0,
            expected_done        => '1',
            expected_clear       => '1',
            test_name            => "DONE"
        );

        ----------------------------------------------------------------
        -- Back to IDLE
        ----------------------------------------------------------------
        tick;

        check_ctrl(
            expected_rdy         => '1',
            expected_feed_valid  => '0',
            expected_feed_idx    => 0,
            expected_p_sum_valid => '0',
            expected_p_sum       => 0,
            expected_done        => '0',
            expected_clear       => '0',
            test_name            => "IDLE after DONE"
        );

        ----------------------------------------------------------------
        -- End simulation
        ----------------------------------------------------------------
        report "TEST PASSED: systolic_controller behaves correctly" severity note;
        stop;
        wait;

    end process;

end architecture sim;