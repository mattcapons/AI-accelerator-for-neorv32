library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

use work.systolic_pkg.all;

entity tb_systolic_controller is
end entity tb_systolic_controller;

architecture sim of tb_systolic_controller is

    ------------------------------------------------------------------------
    -- DUT signals
    ------------------------------------------------------------------------
    signal vld_i       : std_logic := '0';
    signal rdy_i       : std_logic := '0';
    signal clk_i       : std_logic := '0';
    signal rst_i       : std_logic := '0';

    signal rdy_o       : std_logic;
    signal vld_o       : std_logic;
    signal clear_o     : std_logic;
    signal input_en_o  : std_logic;
    signal comp_en_o   : std_logic;

    ------------------------------------------------------------------------
    -- Constants
    ------------------------------------------------------------------------
    constant CLK_PERIOD   : time := 10 ns;
    constant DRAIN_CYCLES : integer := (2 * NUM_PE) - 1;

begin

    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut_inst : entity work.systolic_controller
        port map (
            vld_i      => vld_i,
            rdy_i      => rdy_i,
            clk_i      => clk_i,
            rst_i      => rst_i,
            rdy_o      => rdy_o,
            vld_o      => vld_o,
            clear_o    => clear_o,
            input_en_o => input_en_o,
            comp_en_o  => comp_en_o
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
    -- Stimulus
    ------------------------------------------------------------------------
    stim_process : process

        --------------------------------------------------------------------
        -- Send one input beat
        --------------------------------------------------------------------
        procedure send_input is
        begin
            assert rdy_o = '1'
                report "Controller not ready for input"
                severity failure;

            vld_i <= '1';

            wait for 1 ns;

            assert input_en_o = '1'
                report "input_en_o not asserted during input transfer"
                severity failure;

            assert comp_en_o = '1'
                report "comp_en_o not asserted during input transfer"
                severity failure;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            vld_i <= '0';

            wait for 1 ns;
        end procedure;


        --------------------------------------------------------------------
        -- Verify drain period and arrival in OUTPUT
        --------------------------------------------------------------------
        procedure wait_for_output is
        begin

            -- We should have just entered DRAIN.
            assert rdy_o = '0'
                report "rdy_o still asserted during DRAIN"
                severity failure;

            assert comp_en_o = '1'
                report "comp_en_o not asserted at start of DRAIN"
                severity failure;

            assert vld_o = '0'
                report "vld_o asserted too early"
                severity failure;


            -- First DRAIN_CYCLES - 1 cycles must remain in DRAIN.
            for i in 1 to DRAIN_CYCLES-1 loop

                wait until rising_edge(clk_i);
                wait for 1 ns;

                assert rdy_o = '0'
                    report "rdy_o asserted during DRAIN"
                    severity failure;

                assert comp_en_o = '1'
                    report "comp_en_o dropped during DRAIN"
                    severity failure;

                assert input_en_o = '0'
                    report "input_en_o asserted during DRAIN"
                    severity failure;

                assert vld_o = '0'
                    report "OUTPUT reached too early"
                    severity failure;

                assert clear_o = '0'
                    report "Array cleared during DRAIN"
                    severity failure;

            end loop;


            -- Final drain cycle.
            wait until rising_edge(clk_i);
            wait for 1 ns;

            -- We must now be in OUTPUT.
            assert vld_o = '1'
                report "vld_o not asserted after drain completed"
                severity failure;

            assert rdy_o = '0'
                report "rdy_o asserted during OUTPUT"
                severity failure;

            assert input_en_o = '0'
                report "input_en_o asserted during OUTPUT"
                severity failure;

            assert comp_en_o = '0'
                report "comp_en_o asserted during OUTPUT"
                severity failure;

        end procedure;


    begin

        --------------------------------------------------------------------
        -- RESET TEST
        --------------------------------------------------------------------
        rst_i <= '1';

        wait for CLK_PERIOD;

        rst_i <= '0';
        wait for 1 ns;

        assert rdy_o = '1'
            report "Controller not ready after reset"
            severity failure;

        assert vld_o = '0'
            report "vld_o asserted after reset"
            severity failure;

        assert clear_o = '0'
            report "clear_o asserted after reset"
            severity failure;

        assert input_en_o = '0'
            report "input_en_o asserted without valid input"
            severity failure;

        assert comp_en_o = '0'
            report "comp_en_o asserted without valid input"
            severity failure;


        --------------------------------------------------------------------
        -- TEST 1:
        -- Normal four-word feed
        --------------------------------------------------------------------

        -- Input #1: accepted directly from IDLE.
        send_input;

        -- Input #2
        send_input;

        -- Input #3
        send_input;

        -- Input #4
        send_input;


        --------------------------------------------------------------------
        -- TEST 2:
        -- Exact drain timing
        --------------------------------------------------------------------
        wait_for_output;


        --------------------------------------------------------------------
        -- TEST 3:
        -- Output backpressure
        --------------------------------------------------------------------
        rdy_i <= '0';

        -- Stay stalled for several cycles.
        for i in 0 to 2 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert vld_o = '1'
                report "vld_o dropped while output stalled"
                severity failure;

            assert clear_o = '0'
                report "Array cleared while output was not ready"
                severity failure;

            assert comp_en_o = '0'
                report "Array computation enabled while waiting for output"
                severity failure;

        end loop;


        --------------------------------------------------------------------
        -- TEST 4:
        -- Successful output handshake
        --------------------------------------------------------------------
        rdy_i <= '1';

        wait for 1 ns;

        assert vld_o = '1'
            report "vld_o not asserted before output handshake"
            severity failure;

        assert clear_o = '1'
            report "clear_o not asserted on output handshake"
            severity failure;


        wait until rising_edge(clk_i);
        wait for 1 ns;

        rdy_i <= '0';


        -- Controller should now be back in IDLE.
        assert rdy_o = '1'
            report "Controller did not return to IDLE after output"
            severity failure;

        assert vld_o = '0'
            report "vld_o remained asserted after output handshake"
            severity failure;

        assert clear_o = '0'
            report "clear_o remained asserted after output handshake"
            severity failure;


        --------------------------------------------------------------------
        -- TEST 5:
        -- Stall input halfway through FEED
        --------------------------------------------------------------------

        -- Input #1
        send_input;

        -- Input #2
        send_input;


        -- Producer stalls.
        vld_i <= '0';

        for i in 0 to 2 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert rdy_o = '1'
                report "Controller stopped being ready during input stall"
                severity failure;

            assert input_en_o = '0'
                report "input_en_o asserted while vld_i = 0"
                severity failure;

            assert comp_en_o = '0'
                report "comp_en_o asserted while input stalled"
                severity failure;

            assert vld_o = '0'
                report "Controller advanced to OUTPUT during input stall"
                severity failure;

        end loop;


        -- Resume with input #3.
        send_input;

        -- Input #4.
        send_input;


        --------------------------------------------------------------------
        -- Must still perform the complete drain period.
        --------------------------------------------------------------------
        wait_for_output;


        --------------------------------------------------------------------
        -- Finish second operation immediately.
        --------------------------------------------------------------------
        rdy_i <= '1';

        wait for 1 ns;

        assert clear_o = '1'
            report "clear_o not asserted during second output handshake"
            severity failure;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        rdy_i <= '0';


        assert rdy_o = '1'
            report "Controller did not return to IDLE after second operation"
            severity failure;


        --------------------------------------------------------------------
        -- TEST PASSED
        --------------------------------------------------------------------
        assert false
            report "TEST PASSED: systolic_controller behaves correctly"
            severity note;

        stop;

    end process;

end architecture sim;
