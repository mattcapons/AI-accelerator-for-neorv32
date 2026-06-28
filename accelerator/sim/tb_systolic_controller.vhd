library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

use work.systolic_pkg.all;

entity tb_systolic_controller is
end entity tb_systolic_controller;

architecture Behavioral of tb_systolic_controller is

    ----------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------
    signal a_buff       : byte_array_t := (others => (others => '0'));
    signal w_buff       : byte_array_t := (others => (others => '0'));
    signal clear_result : std_logic := '0';
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '0';
    signal start        : std_logic := '0';

    signal a_feed       : byte_array_t;
    signal w_feed       : byte_array_t;
    signal pop          : std_logic_vector(0 to NUM_PE-1);
    signal clear        : std_logic;
    signal done         : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    ----------------------------------------------------------------
    -- Helper function: convert integer to DATA_WIDTH signed
    ----------------------------------------------------------------
    function signed_data(x : integer) return signed is
    begin
        return to_signed(x, DATA_WIDTH);
    end function;

    ----------------------------------------------------------------
    -- Helper procedure: wait one clock and allow combinational outputs to settle
    ----------------------------------------------------------------
    procedure tick is
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
    end procedure;

    ----------------------------------------------------------------
    -- Helper procedure: check one controller cycle
    ----------------------------------------------------------------
    procedure check_cycle(
        constant expected_pop   : in std_logic_vector(0 to NUM_PE-1);
        constant expected_done  : in std_logic;
        constant expected_clear : in std_logic;
        constant expected_feed  : in std_logic_vector(0 to NUM_PE-1);
        constant test_name      : in string
    ) is
    begin
        assert pop = expected_pop
            report "FAIL: " & test_name & " pop wrong"
            severity failure;

        assert done = expected_done
            report "FAIL: " & test_name & " done wrong"
            severity failure;

        assert clear = expected_clear
            report "FAIL: " & test_name & " clear wrong"
            severity failure;

        for i in 0 to NUM_PE-1 loop
            if expected_feed(i) = '1' then
                assert a_feed(i) = a_buff(i)
                    report "FAIL: " & test_name & " a_feed(" & integer'image(i) & ") wrong"
                    severity failure;

                assert w_feed(i) = w_buff(i)
                    report "FAIL: " & test_name & " w_feed(" & integer'image(i) & ") wrong"
                    severity failure;
            else
                assert a_feed(i) = to_signed(0, DATA_WIDTH)
                    report "FAIL: " & test_name & " a_feed(" & integer'image(i) & ") should be zero"
                    severity failure;

                assert w_feed(i) = to_signed(0, DATA_WIDTH)
                    report "FAIL: " & test_name & " w_feed(" & integer'image(i) & ") should be zero"
                    severity failure;
            end if;
        end loop;
    end procedure;

begin

    ----------------------------------------------------------------
    -- DUT instantiation
    ----------------------------------------------------------------
    dut : entity work.systolic_controller
        port map (
            a_buff_i       => a_buff,
            w_buff_i       => w_buff,
            clear_result_i => clear_result,
            clk_i          => clk,
            rst_i          => rst,
            start_i        => start,
            a_feed_o       => a_feed,
            w_feed_o       => w_feed,
            pop_o          => pop,
            clear_o        => clear,
            done_o         => done
        );

    ----------------------------------------------------------------
    -- Clock generation
    ----------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Stimulus process
    ----------------------------------------------------------------
    stimulus : process
    begin

        ----------------------------------------------------------------
        -- Initialize fake buffer outputs
        ----------------------------------------------------------------
        for i in 0 to NUM_PE-1 loop
            a_buff(i) <= signed_data(i + 1);       -- 1, 2, 3, 4
            w_buff(i) <= signed_data(10 + i + 1);  -- 11, 12, 13, 14
        end loop;

        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------
        rst          <= '1';
        start        <= '0';
        clear_result <= '0';

        wait for 2 * CLK_PERIOD;
        rst <= '0';

        tick;

        check_cycle(
            expected_pop   => "0000",
            expected_done  => '0',
            expected_clear => '0',
            expected_feed  => "0000",
            test_name      => "IDLE after reset"
        );

        ----------------------------------------------------------------
        -- Start pulse: next state should be PRELOAD
        ----------------------------------------------------------------
        start <= '1';
        tick;
        start <= '0';

        check_cycle(
            expected_pop   => "1000",
            expected_done  => '0',
            expected_clear => '0',
            expected_feed  => "0000",
            test_name      => "PRELOAD"
        );

        ----------------------------------------------------------------
        -- FEED cycles
        --
        -- For NUM_PE = 4:
        --
        -- FEED 0:
        --   feed lane 0
        --   pop lanes 0,1
        --
        -- FEED 1:
        --   feed lanes 0,1
        --   pop lanes 0,1,2
        --
        -- FEED 2:
        --   feed lanes 0,1,2
        --   pop lanes 0,1,2,3
        --
        -- FEED 3:
        --   feed lanes 0,1,2,3
        --   pop lanes 1,2,3
        --
        -- FEED 4:
        --   feed lanes 1,2,3
        --   pop lanes 2,3
        --
        -- FEED 5:
        --   feed lanes 2,3
        --   pop lane 3
        --
        -- FEED 6:
        --   feed lane 3
        --   pop none
        ----------------------------------------------------------------

        tick;
        check_cycle("1100", '0', '0', "1000", "FEED cycle 0");

        tick;
        check_cycle("1110", '0', '0', "1100", "FEED cycle 1");

        tick;
        check_cycle("1111", '0', '0', "1110", "FEED cycle 2");

        tick;
        check_cycle("0111", '0', '0', "1111", "FEED cycle 3");

        tick;
        check_cycle("0011", '0', '0', "0111", "FEED cycle 4");

        tick;
        check_cycle("0001", '0', '0', "0011", "FEED cycle 5");

        tick;
        check_cycle("0000", '0', '0', "0001", "FEED cycle 6");

        ----------------------------------------------------------------
        -- DRAIN cycles
        --
        -- For NUM_PE = 4, DRAIN lasts NUM_PE-1 = 3 effective cycles.
        -- With your counter condition cycle_count = NUM_PE-2, we observe
        -- three DRAIN output cycles.
        ----------------------------------------------------------------

        tick;
        check_cycle("0000", '0', '0', "0000", "DRAIN cycle 0");

        tick;
        check_cycle("0000", '0', '0', "0000", "DRAIN cycle 1");

        tick;
        check_cycle("0000", '0', '0', "0000", "DRAIN cycle 2");

        ----------------------------------------------------------------
        -- DONE
        ----------------------------------------------------------------

        tick;
        check_cycle("0000", '1', '0', "0000", "DONE");

        ----------------------------------------------------------------
        -- Stay in DONE until clear_result is asserted
        ----------------------------------------------------------------

        tick;
        check_cycle("0000", '1', '0', "0000", "DONE hold");

        ----------------------------------------------------------------
        -- Request clear
        ----------------------------------------------------------------

        clear_result <= '1';
        tick;
        clear_result <= '0';

        -- Your controller keeps done high in CLEAR.
        check_cycle("0000", '1', '1', "0000", "CLEAR");

        ----------------------------------------------------------------
        -- Back to IDLE
        ----------------------------------------------------------------

        tick;
        check_cycle("0000", '0', '0', "0000", "IDLE after CLEAR");

        ----------------------------------------------------------------
        -- End simulation
        ----------------------------------------------------------------
        report "TEST PASSED: systolic_controller behaves correctly" severity note;
        stop;
        wait;

    end process;

end architecture Behavioral;
