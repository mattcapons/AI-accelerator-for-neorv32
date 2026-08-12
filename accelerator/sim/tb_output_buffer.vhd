library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

use work.systolic_pkg.all;


entity tb_output_buffer is
end entity tb_output_buffer;


architecture behavioural of tb_output_buffer is

    constant CLK_PERIOD : time := 10 ns;

    signal data_i    : out_array_t := (others => (others => (others => '0')));
    signal acc_num_i : integer range 1 to MAX_TILE_SIZE := 1;
    signal vld_i     : std_logic := '0';
    signal rdy_i     : std_logic := '0';

    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '1';

    signal rdy_o  : std_logic;
    signal vld_o  : std_logic;
    signal data_o : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);


    ----------------------------------------------------------------
    -- Generate a matrix with consecutive values starting from base.
    ----------------------------------------------------------------
    function make_matrix(base : integer) return out_array_t is
        variable result : out_array_t;
    begin
        for i in 0 to NUM_PE-1 loop
            for j in 0 to NUM_PE-1 loop
                result(i, j) :=
                    to_signed(base + i*NUM_PE + j, ACC_WIDTH);
            end loop;
        end loop;

        return result;
    end function;


    ----------------------------------------------------------------
    -- Sum three matrices for accumulation tests.
    ----------------------------------------------------------------
    function sum_three(
        a : out_array_t;
        b : out_array_t;
        c : out_array_t
    ) return out_array_t is
        variable result : out_array_t;
    begin
        for i in 0 to NUM_PE-1 loop
            for j in 0 to NUM_PE-1 loop
                result(i, j) :=
                    a(i, j) + b(i, j) + c(i, j);
            end loop;
        end loop;

        return result;
    end function;


    ----------------------------------------------------------------
    -- Send one complete array result using the valid-ready protocol.
    ----------------------------------------------------------------
    procedure send_array(
        signal clk_s  : in  std_logic;
        signal data_s : out out_array_t;
        signal vld_s  : out std_logic;
        signal rdy_s  : in  std_logic;
        constant value : in out_array_t
    ) is
    begin
        data_s <= value;
        vld_s  <= '1';

        loop
            wait until rising_edge(clk_s);
            exit when rdy_s = '1';
        end loop;

        vld_s <= '0';
    end procedure;


    ----------------------------------------------------------------
    -- Receive and check one complete 4x4 tile in row-major order.
    ----------------------------------------------------------------
    procedure check_tile(
        signal clk_s   : in  std_logic;
        signal data_s  : in  std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        signal vld_s   : in  std_logic;
        signal rdy_s   : out std_logic;
        constant expected : in out_array_t;
        constant test_name : in string
    ) is
        variable row : integer;
        variable col : integer;
    begin
        rdy_s <= '1';

        for word_idx in 0 to NUM_PE*NUM_PE-1 loop

            loop
                wait until rising_edge(clk_s);
                exit when vld_s = '1';
            end loop;

            row := word_idx / NUM_PE;
            col := word_idx mod NUM_PE;

            assert signed(data_s) =
                   resize(expected(row, col), data_s'length)
                report test_name &
                       ": wrong value at output word " &
                       integer'image(word_idx)
                severity error;

        end loop;

        rdy_s <= '0';
    end procedure;


begin

    ----------------------------------------------------------------
    -- Clock generation.
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD/2;


    ----------------------------------------------------------------
    -- DUT.
    ----------------------------------------------------------------
    dut : entity work.output_buffer
        port map (
            data_i    => data_i,
            acc_num_i => acc_num_i,
            vld_i     => vld_i,
            rdy_i     => rdy_i,

            clk_i     => clk_i,
            rst_i     => rst_i,

            rdy_o     => rdy_o,
            vld_o     => vld_o,
            data_o    => data_o
        );


    ----------------------------------------------------------------
    -- Main stimulus.
    ----------------------------------------------------------------
    stimulus_proc : process is

        variable matrix_1 : out_array_t;
        variable matrix_2 : out_array_t;
        variable matrix_3 : out_array_t;

        variable expected : out_array_t;

        variable tile_0 : out_array_t;
        variable tile_1 : out_array_t;

        variable held_data : std_logic_vector(
            NUM_PE*DATA_WIDTH-1 downto 0
        );

    begin

        ------------------------------------------------------------
        -- Reset.
        ------------------------------------------------------------
        rst_i <= '1';
        vld_i <= '0';
        rdy_i <= '0';

        wait for 3 * CLK_PERIOD;

        wait until falling_edge(clk_i);
        rst_i <= '0';

        wait until rising_edge(clk_i);

        assert rdy_o = '1'
            report "Output buffer is not ready after reset"
            severity error;

        assert vld_o = '0'
            report "Output valid unexpectedly high after reset"
            severity error;


        ------------------------------------------------------------
        -- TEST 1:
        -- Single array result, no accumulation.
        -- Also verify output stability while TX is stalled.
        ------------------------------------------------------------
        report "TEST 1: single accumulation";

        matrix_1 := make_matrix(1);
        acc_num_i <= 1;

        send_array(
            clk_i,
            data_i,
            vld_i,
            rdy_o,
            matrix_1
        );

        -- Keep the receiver stalled until the first word is ready.
        rdy_i <= '0';

        wait until vld_o = '1';

        held_data := data_o;

        -- Valid and data must remain stable under backpressure.
        for i in 0 to 2 loop
            wait until rising_edge(clk_i);

            assert vld_o = '1'
                report "vld_o dropped while rdy_i was low"
                severity error;

            assert data_o = held_data
                report "data_o changed while output was stalled"
                severity error;
        end loop;

        -- Drain and verify the complete tile.
        check_tile(
            clk_i,
            data_o,
            vld_o,
            rdy_i,
            matrix_1,
            "TEST 1"
        );

        wait until rising_edge(clk_i);


        ------------------------------------------------------------
        -- TEST 2:
        -- Three partial results accumulated into one output tile.
        -- Gaps are deliberately inserted between valid inputs.
        ------------------------------------------------------------
        report "TEST 2: multiple accumulations";

        matrix_1 := make_matrix(1);
        matrix_2 := make_matrix(20);
        matrix_3 := make_matrix(-5);

        expected := sum_three(
            matrix_1,
            matrix_2,
            matrix_3
        );

        acc_num_i <= 3;
        rdy_i <= '1';

        send_array(
            clk_i,
            data_i,
            vld_i,
            rdy_o,
            matrix_1
        );

        -- Make sure accumulation advances only on valid inputs.
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        send_array(
            clk_i,
            data_i,
            vld_i,
            rdy_o,
            matrix_2
        );

        wait until rising_edge(clk_i);

        send_array(
            clk_i,
            data_i,
            vld_i,
            rdy_o,
            matrix_3
        );

        check_tile(
            clk_i,
            data_o,
            vld_o,
            rdy_i,
            expected,
            "TEST 2"
        );

        wait until rising_edge(clk_i);


        ------------------------------------------------------------
        -- TEST 3:
        -- Fill both ping-pong output blocks while TX is stalled,
        -- then verify that both tiles are transmitted in order.
        ------------------------------------------------------------
        report "TEST 3: ping-pong output blocks";

        tile_0 := make_matrix(100);
        tile_1 := make_matrix(200);

        acc_num_i <= 1;
        rdy_i <= '0';

        -- Fill the first output block.
        send_array(
            clk_i,
            data_i,
            vld_i,
            rdy_o,
            tile_0
        );

        -- The next input waits until the full buffer has been copied
        -- and the writer has switched to the second block.
        send_array(
            clk_i,
            data_i,
            vld_i,
            rdy_o,
            tile_1
        );

        -- Wait until the second tile has also finished writing.
        loop
            wait until rising_edge(clk_i);
            exit when rdy_o = '1';
        end loop;

        -- Drain block 0.
        check_tile(
            clk_i,
            data_o,
            vld_o,
            rdy_i,
            tile_0,
            "TEST 3 - block 0"
        );

        -- Drain block 1.
        check_tile(
            clk_i,
            data_o,
            vld_o,
            rdy_i,
            tile_1,
            "TEST 3 - block 1"
        );


        ------------------------------------------------------------
        -- Finished.
        ------------------------------------------------------------
        wait until rising_edge(clk_i);

        assert vld_o = '0'
            report "vld_o remains asserted after all data was consumed"
            severity error;

        report "All output_buffer tests passed."
            severity note;

        stop;
        wait;

    end process stimulus_proc;


    ----------------------------------------------------------------
    -- Simulation timeout.
    ----------------------------------------------------------------
    watchdog_proc : process
    begin
        wait for 20 us;

        assert false
            report "Simulation timeout"
            severity failure;

        wait;
    end process watchdog_proc;

end architecture behavioural;
