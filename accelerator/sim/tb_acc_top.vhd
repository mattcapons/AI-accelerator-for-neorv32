library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

use work.systolic_pkg.all;


entity tb_acc_top is
end entity tb_acc_top;


architecture behavioural of tb_acc_top is

    constant CLK_PERIOD : time := 10 ns;

    ----------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------
    signal start_i   : std_logic := '0';
    signal clk_i     : std_logic := '0';
    signal rstn_i    : std_logic := '0';

    signal acc_num_i : integer range 1 to MAX_TILE_SIZE := 1;

    signal tx_vld_i  : std_logic := '0';
    signal tx_data_i : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_rdy_o  : std_logic;

    signal rx_rdy_i  : std_logic := '0';
    signal rx_vld_o  : std_logic;
    signal rx_data_o : std_logic_vector(31 downto 0);

    signal rdy_o : std_logic;

    ----------------------------------------------------------------
    -- Testbench control
    ----------------------------------------------------------------
    signal active_test : integer range 0 to 3 := 0;
    signal test_done   : std_logic := '0';


    ----------------------------------------------------------------
    -- Software-side integer matrices
    ----------------------------------------------------------------
    type int_matrix_t is array(natural range <>, natural range <>) of integer;

    subtype matrix4_t is int_matrix_t(0 to 3, 0 to 3);
    subtype matrix8_t is int_matrix_t(0 to 7, 0 to 7);


    ----------------------------------------------------------------
    -- TEST 1 matrices
    ----------------------------------------------------------------
    constant A4 : matrix4_t := (
        ( 1, -2,  3,  4),
        ( 0,  5, -1,  2),
        ( 2,  1,  0, -3),
        (-1,  4,  2,  1)
    );

    constant B4 : matrix4_t := (
        (2,  0, -1,  3),
        (1, -2,  4,  0),
        (3,  1,  2, -1),
        (0,  2, -3,  1)
    );


    ----------------------------------------------------------------
    -- TEST 2: deterministic 8x8 matrices
    ----------------------------------------------------------------
    function make_a8 return matrix8_t is
        variable result : matrix8_t;
    begin
        for i in 0 to 7 loop
            for j in 0 to 7 loop
                result(i, j) := ((3*i + 2*j) mod 7) - 3;
            end loop;
        end loop;

        return result;
    end function;


    function make_b8 return matrix8_t is
        variable result : matrix8_t;
    begin
        for i in 0 to 7 loop
            for j in 0 to 7 loop
                result(i, j) := ((2*i + 4*j + 1) mod 9) - 4;
            end loop;
        end loop;

        return result;
    end function;


    constant A8 : matrix8_t := make_a8;
    constant B8 : matrix8_t := make_b8;


    ----------------------------------------------------------------
    -- TEST 3: padded 3x3 matrices
    ----------------------------------------------------------------
    constant A_PAD : matrix4_t := (
        (1, 2, 3, 0),
        (4, 5, 6, 0),
        (7, 8, 9, 0),
        (0, 0, 0, 0)
    );

    constant B_PAD : matrix4_t := (
        ( 2,  1, -1, 0),
        ( 0,  3,  2, 0),
        ( 1, -2,  4, 0),
        ( 0,  0,  0, 0)
    );


    ----------------------------------------------------------------
    -- Reference matrix multiplication
    ----------------------------------------------------------------
    function matmul4(
        a : matrix4_t;
        b : matrix4_t
    ) return matrix4_t is
        variable result : matrix4_t := (others => (others => 0));
        variable sum    : integer;
    begin
        for i in 0 to 3 loop
            for j in 0 to 3 loop
                sum := 0;

                for k in 0 to 3 loop
                    sum := sum + a(i, k) * b(k, j);
                end loop;

                result(i, j) := sum;
            end loop;
        end loop;

        return result;
    end function;


    function matmul8(
        a : matrix8_t;
        b : matrix8_t
    ) return matrix8_t is
        variable result : matrix8_t := (others => (others => 0));
        variable sum    : integer;
    begin
        for i in 0 to 7 loop
            for j in 0 to 7 loop
                sum := 0;

                for k in 0 to 7 loop
                    sum := sum + a(i, k) * b(k, j);
                end loop;

                result(i, j) := sum;
            end loop;
        end loop;

        return result;
    end function;


    constant C4    : matrix4_t := matmul4(A4, B4);
    constant C8    : matrix8_t := matmul8(A8, B8);
    constant C_PAD : matrix4_t := matmul4(A_PAD, B_PAD);


    ----------------------------------------------------------------
    -- Pack one A column into a 32-bit input word.
    -- The first matrix row is placed in the most-significant lane.
    ----------------------------------------------------------------
    function pack_a_word(
        a        : int_matrix_t;
        row_base : natural;
        col      : natural
    ) return std_logic_vector is
        variable result :
            std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    begin
        result := (others => '0');

        for lane in 0 to NUM_PE-1 loop
            result(
                (NUM_PE-lane)*DATA_WIDTH-1 downto
                (NUM_PE-lane-1)*DATA_WIDTH
            ) := std_logic_vector(
                to_signed(a(row_base + lane, col), DATA_WIDTH)
            );
        end loop;

        return result;
    end function;


    ----------------------------------------------------------------
    -- Pack one W row into a 32-bit input word.
    -- The first matrix column is placed in the most-significant lane.
    ----------------------------------------------------------------
    function pack_w_word(
        w        : int_matrix_t;
        row      : natural;
        col_base : natural
    ) return std_logic_vector is
        variable result :
            std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    begin
        result := (others => '0');

        for lane in 0 to NUM_PE-1 loop
            result(
                (NUM_PE-lane)*DATA_WIDTH-1 downto
                (NUM_PE-lane-1)*DATA_WIDTH
            ) := std_logic_vector(
                to_signed(w(row, col_base + lane), DATA_WIDTH)
            );
        end loop;

        return result;
    end function;


    ----------------------------------------------------------------
    -- Expected output word.
    -- Output tiles are transmitted in tile-major order, while each
    -- individual 4x4 tile is transmitted in row-major order.
    ----------------------------------------------------------------
    function expected_word(
        test_id  : integer;
        word_idx : integer
    ) return integer is
        variable tile_idx  : integer;
        variable tile_row  : integer;
        variable tile_col  : integer;
        variable local_idx : integer;
        variable row       : integer;
        variable col       : integer;
    begin

        case test_id is

            when 1 =>
                row := word_idx / NUM_PE;
                col := word_idx mod NUM_PE;

                return C4(row, col);


            when 2 =>
                tile_idx  := word_idx / (NUM_PE*NUM_PE);
                local_idx := word_idx mod (NUM_PE*NUM_PE);

                tile_row := tile_idx / 2;
                tile_col := tile_idx mod 2;

                row :=
                    tile_row*NUM_PE +
                    local_idx / NUM_PE;

                col :=
                    tile_col*NUM_PE +
                    local_idx mod NUM_PE;

                return C8(row, col);


            when 3 =>
                row := word_idx / NUM_PE;
                col := word_idx mod NUM_PE;

                return C_PAD(row, col);


            when others =>
                return 0;

        end case;

    end function;


    function expected_word_count(
        test_id : integer
    ) return integer is
    begin
        case test_id is
            when 1 =>
                return 16;

            when 2 =>
                return 64;

            when 3 =>
                return 16;

            when others =>
                return 0;
        end case;
    end function;


    ----------------------------------------------------------------
    -- Start one accelerator job.
    ----------------------------------------------------------------
    procedure start_job(
        signal clk_s       : in  std_logic;
        signal start_s     : out std_logic;
        signal ready_s     : in  std_logic;
        signal acc_num_s   : out integer;
        constant acc_num_c : in  integer
    ) is
    begin

        wait until falling_edge(clk_s);

        acc_num_s <= acc_num_c;
        start_s   <= '1';

        -- Software waits for the accelerator to accept START.
        loop
            wait until rising_edge(clk_s);
            exit when ready_s = '0';
        end loop;

        -- START is cleared after the accelerator becomes busy.
        wait until falling_edge(clk_s);
        start_s <= '0';

    end procedure;


    ----------------------------------------------------------------
    -- Send one 32-bit word through the input valid-ready interface.
    ----------------------------------------------------------------
    procedure send_word(
        signal clk_s      : in  std_logic;
        signal data_s     : out std_logic_vector(31 downto 0);
        signal valid_s    : out std_logic;
        signal ready_s    : in  std_logic;
        constant value    : in  std_logic_vector(31 downto 0);
        constant gap      : in  natural := 0
    ) is
    begin

        data_s  <= value;
        valid_s <= '1';

        loop
            wait until rising_edge(clk_s);
            exit when ready_s = '1';
        end loop;

        valid_s <= '0';

        -- Optional idle cycles between input transfers.
        for i in 1 to gap loop
            wait until rising_edge(clk_s);
        end loop;

    end procedure;


    ----------------------------------------------------------------
    -- Send one complete 4x4 systolic pass.
    --
    -- Input order:
    --   4 A column words
    --   4 W row words
    ----------------------------------------------------------------
    procedure send_pass(
        signal clk_s   : in  std_logic;
        signal data_s  : out std_logic_vector(31 downto 0);
        signal valid_s : out std_logic;
        signal ready_s : in  std_logic;

        constant a        : in int_matrix_t;
        constant w        : in int_matrix_t;
        constant row_base : in natural;
        constant col_base : in natural;
        constant k_base   : in natural;
        constant gap      : in natural := 0
    ) is
    begin

        -- Activation columns.
        for k in 0 to NUM_PE-1 loop
            send_word(
                clk_s,
                data_s,
                valid_s,
                ready_s,
                pack_a_word(a, row_base, k_base + k),
                gap
            );
        end loop;

        -- Weight rows.
        for k in 0 to NUM_PE-1 loop
            send_word(
                clk_s,
                data_s,
                valid_s,
                ready_s,
                pack_w_word(w, k_base + k, col_base),
                gap
            );
        end loop;

    end procedure;


begin

    ----------------------------------------------------------------
    -- Clock
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD/2;


    ----------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------
    dut : entity work.acc_top
        port map (
            start_i   => start_i,
            clk_i     => clk_i,
            rstn_i    => rstn_i,
            acc_num_i => acc_num_i,

            tx_vld_i  => tx_vld_i,
            rx_rdy_i  => rx_rdy_i,
            tx_data_i => tx_data_i,

            tx_rdy_o  => tx_rdy_o,
            rx_vld_o  => rx_vld_o,
            rdy_o     => rdy_o,
            rx_data_o => rx_data_o
        );


    ----------------------------------------------------------------
    -- Output receiver/checker
    --
    -- Runs independently from the input sender so input, computation
    -- and output can overlap just like they will in the real system.
    ----------------------------------------------------------------
    receiver_proc : process is
        variable current_test : integer := 0;
        variable recv_count   : integer := 0;
        variable cycle_count  : integer := 0;

        variable expected     : integer;
        variable held_data    : std_logic_vector(31 downto 0);
        variable holding      : boolean := false;
    begin

        rx_rdy_i <= '0';
        test_done <= '0';

        loop

            -- Wait for a test to start.
            wait until active_test /= 0;

            current_test := active_test;
            recv_count   := 0;
            cycle_count  := 0;
            holding      := false;

            while recv_count < expected_word_count(current_test) loop

                ----------------------------------------------------
                -- Generate deterministic output backpressure.
                ----------------------------------------------------
                wait until falling_edge(clk_i);

                cycle_count := cycle_count + 1;

                if current_test = 1 and
                   (cycle_count mod 7 = 3 or cycle_count mod 7 = 4) then

                    rx_rdy_i <= '0';

                elsif current_test = 2 and
                      cycle_count mod 11 = 5 then

                    rx_rdy_i <= '0';

                else
                    rx_rdy_i <= '1';
                end if;


                ----------------------------------------------------
                -- Observe the transfer on the next rising edge.
                ----------------------------------------------------
                wait until rising_edge(clk_i);

                -- Check that output remains stable while stalled.
                if rx_vld_o = '1' and rx_rdy_i = '0' then

                    if not holding then
                        held_data := rx_data_o;
                        holding := true;

                    else
                        assert rx_data_o = held_data
                            report
                                "Output data changed while RX was stalled"
                            severity error;
                    end if;

                else
                    holding := false;
                end if;


                -- Successful output transfer.
                if rx_vld_o = '1' and rx_rdy_i = '1' then

                    expected :=
                        expected_word(current_test, recv_count);

                    assert signed(rx_data_o) =
                           to_signed(expected, rx_data_o'length)
                        report
                            "TEST " &
                            integer'image(current_test) &
                            ": wrong output word " &
                            integer'image(recv_count) &
                            ". Expected " &
                            integer'image(expected) &
                            ", received " &
                            integer'image(to_integer(signed(rx_data_o)))
                        severity error;

                    recv_count := recv_count + 1;

                end if;

            end loop;


            --------------------------------------------------------
            -- All expected output words received.
            --------------------------------------------------------
            rx_rdy_i <= '0';
            test_done <= '1';

            wait until falling_edge(clk_i);

            test_done <= '0';

            -- Wait for stimulus process to clear active_test.
            wait until active_test = 0;

        end loop;

    end process receiver_proc;


    ----------------------------------------------------------------
    -- Main stimulus
    ----------------------------------------------------------------
    stimulus_proc : process is
    begin

        ------------------------------------------------------------
        -- Basic configuration check.
        ------------------------------------------------------------
        assert NUM_PE = 4
            report "This integration testbench expects NUM_PE = 4"
            severity failure;

        assert NUM_PE*DATA_WIDTH = 32
            report "This integration testbench expects a 32-bit stream word"
            severity failure;


        ------------------------------------------------------------
        -- Reset
        ------------------------------------------------------------
        start_i  <= '0';
        tx_vld_i <= '0';
        rstn_i   <= '0';

        wait for 3 * CLK_PERIOD;

        wait until falling_edge(clk_i);
        rstn_i <= '1';

        wait until rising_edge(clk_i);
        wait for 0 ns;

        assert rdy_o = '1'
            report "Accelerator is not ready after reset"
            severity error;


            --------------------------------------------------------------
        -- TEST 1
        -- Signed 4x4 multiplication.
        -- Exercises a complete acc_num = 1 job and RX backpressure.
        ------------------------------------------------------------------
        report "TEST 1: signed 4x4 multiplication";

        active_test <= 1;

        start_job(
            clk_i,
            start_i,
            rdy_o,
            acc_num_i,
            1
        );

        send_pass(
            clk_i,
            tx_data_i,
            tx_vld_i,
            tx_rdy_o,
            A4,
            B4,
            0,
            0,
            0,
            0
        );

        wait until test_done = '1';

        -- Top controller sees tx_done on the following clock.
        loop
            wait until rising_edge(clk_i);
            exit when rdy_o = '1';
        end loop;

        active_test <= 0;

        wait until rising_edge(clk_i);

        report "TEST 1 passed";


        --------------------------------------------------------------
        -- TEST 2
        -- Full 8x8 multiplication.
        --
        -- acc_num = 2:
        --   2 K passes per output tile
        --   2 x 2 = 4 output tiles
        --
        -- This exercises accumulation and both ping-pong buffers.
        --------------------------------------------------------------
        report "TEST 2: full 8x8 tiled multiplication";

        active_test <= 2;

        start_job(
            clk_i,
            start_i,
            rdy_o,
            acc_num_i,
            2
        );

        -- Output tiles are generated in row-major tile order.
        for tile_row in 0 to 1 loop
            for tile_col in 0 to 1 loop

                -- Two K passes contribute to each output tile.
                for k_tile in 0 to 1 loop

                    send_pass(
                        clk_i,
                        tx_data_i,
                        tx_vld_i,
                        tx_rdy_o,
                        A8,
                        B8,
                        tile_row * NUM_PE,
                        tile_col * NUM_PE,
                        k_tile * NUM_PE,
                        0
                    );

                end loop;

            end loop;
        end loop;

        wait until test_done = '1';

        loop
            wait until rising_edge(clk_i);
            exit when rdy_o = '1';
        end loop;

        active_test <= 0;

        wait until rising_edge(clk_i);

        report "TEST 2 passed";


        --------------------------------------------------------------
        -- TEST 3
        -- Padded 3x3 represented as 4x4.
        -- Adds one-cycle gaps between all incoming stream words.
        --------------------------------------------------------------
        report "TEST 3: padded matrix with input gaps";

        active_test <= 3;

        start_job(
            clk_i,
            start_i,
            rdy_o,
            acc_num_i,
            1
        );

        send_pass(
            clk_i,
            tx_data_i,
            tx_vld_i,
            tx_rdy_o,
            A_PAD,
            B_PAD,
            0,
            0,
            0,
            1
        );

        wait until test_done = '1';

        loop
            wait until rising_edge(clk_i);
            exit when rdy_o = '1';
        end loop;

        active_test <= 0;

        wait until rising_edge(clk_i);

        report "TEST 3 passed";


        ------------------------------------------------------------
        -- Finished
        ------------------------------------------------------------
        report "All acc_top integration tests passed."
            severity note;

        stop;
        wait;

    end process stimulus_proc;


    ----------------------------------------------------------------
    -- Watchdog
    ----------------------------------------------------------------
    watchdog_proc : process
    begin

        wait for 100 us;

        assert false
            report "Simulation timeout"
            severity failure;

        wait;

    end process watchdog_proc;


end architecture behavioural;
