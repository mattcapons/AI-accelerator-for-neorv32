library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.systolic_pkg.all;

entity tb_systolic_array is
end tb_systolic_array;

architecture sim of tb_systolic_array is

    ------------------------------------------------------------------------
    -- Integer types for testbench matrices
    ------------------------------------------------------------------------
    type input_array_t is array (0 to NUM_PE-1) of integer;
    type matrix_t is array (0 to NUM_PE-1, 0 to NUM_PE-1) of integer;

    ------------------------------------------------------------------------
    -- DUT signals
    ------------------------------------------------------------------------
    signal a_in       : data_array_t := (others => (others => '0'));
    signal w_in       : data_array_t := (others => (others => '0'));
    signal clear_i    : std_logic := '0';
    signal clk_i      : std_logic := '0';
    signal rst_i      : std_logic := '0';
    signal input_en_i : std_logic := '0';
    signal p_sums_out : out_array_t;

    ------------------------------------------------------------------------
    -- Clock period
    ------------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    ------------------------------------------------------------------------
    -- Convert integer matrix column to 8-bit std_logic_vector array
    ------------------------------------------------------------------------
    function mat_col_int_to_sign(x : matrix_t; col : integer) return data_array_t is
        variable res : data_array_t := (others => (others => '0'));
    begin
        for i in 0 to NUM_PE-1 loop
            res(i) := to_signed(x(i, col), DATA_WIDTH);
        end loop;

        return res;
    end function;

    ------------------------------------------------------------------------
    -- Convert integer matrix row to 8-bit std_logic_vector array
    ------------------------------------------------------------------------
    function mat_row_int_to_sign(x : matrix_t; row : integer) return data_array_t is
        variable res : data_array_t := (others => (others => '0'));
    begin
        for i in 0 to NUM_PE-1 loop
            res(i) := to_signed(x(row, i), DATA_WIDTH);
        end loop;

        return res;
    end function;

    ------------------------------------------------------------------------
    -- Compute expected matrix multiplication result in integers
    ------------------------------------------------------------------------
    function matrix_mult(a : matrix_t; b : matrix_t) return matrix_t is
        variable res : matrix_t := (others => (others => 0));
    begin
        for i in 0 to NUM_PE-1 loop
            for j in 0 to NUM_PE-1 loop
                res(i, j) := 0;
                for k in 0 to NUM_PE-1 loop
                    res(i, j) := res(i, j) + a(i, k) * b(k, j);
                end loop;
            end loop;
        end loop;

        return res;
    end function;

    ------------------------------------------------------------------------
    -- Clear the DUT input arrays
    ------------------------------------------------------------------------
    procedure clear_array(
        signal clear_sig : inout std_logic;
        signal en_sig    : inout std_logic;
        signal a_sig     : inout data_array_t;
        signal w_sig     : inout data_array_t
    ) is
    begin
        en_sig <= '0';
        a_sig <= (others => (others => '0'));
        w_sig <= (others => (others => '0'));
        clear_sig <= '1';
        wait until rising_edge(clk_i);
        wait for 1 ns;  
        clear_sig <= '0';
        wait until rising_edge(clk_i);
        wait for 1 ns;
    end procedure;

    ------------------------------------------------------------------------
    -- Feed one full matrix multiplication into the systolic array
    ------------------------------------------------------------------------
    procedure full_compute(
        signal a_sig     : inout data_array_t;
        signal w_sig     : inout data_array_t;
        signal en_sig    : inout std_logic;
        constant a_matrix : in matrix_t;
        constant w_matrix : in matrix_t
    ) is
    begin

        for cycle in 0 to NUM_PE-1 loop
            a_sig <= mat_col_int_to_sign(a_matrix, cycle);
            w_sig <= mat_row_int_to_sign(w_matrix, cycle);
            en_sig <= '1';

            wait until rising_edge(clk_i);
            wait for 1 ns;
        end loop;
        
        en_sig <= '0';
        a_sig <= (others => (others => '0'));
        w_sig <= (others => (others => '0'));

        -- Wait for the final values to propagate through the array
        for k in 0 to 2 * NUM_PE loop
            wait until rising_edge(clk_i);
            wait for 1 ns;
        end loop;
    end procedure;

    ------------------------------------------------------------------------
    -- Check output matrix
    ------------------------------------------------------------------------
    procedure check_outputs(
        constant expected_sums : in matrix_t;
        constant test_name     : in string
    ) is
        variable actual_int : integer;
    begin
        for i in 0 to NUM_PE-1 loop
            for j in 0 to NUM_PE-1 loop

                actual_int := to_integer(signed(p_sums_out(i, j)));

                assert actual_int = expected_sums(i, j)
                    report "Mismatch at position (" &
                           integer'image(i) & ", " &
                           integer'image(j) & ") in test: " &
                           test_name &
                           ". Expected " & integer'image(expected_sums(i, j)) &
                           ", got " & integer'image(actual_int)
                    severity failure;

            end loop;
        end loop;
    end procedure;

    ------------------------------------------------------------------------
    -- Compute expected result, run DUT computation, then check
    ------------------------------------------------------------------------
    procedure apply_and_check(
        signal a_sig       : inout data_array_t;
        signal w_sig       : inout data_array_t;
        signal en_sig      : inout std_logic;
        constant a_matrix : in matrix_t;
        constant w_matrix : in matrix_t;
        constant test_name : in string
    ) is
        variable expected_sums : matrix_t;
    begin
        expected_sums := matrix_mult(a_matrix, w_matrix);

        full_compute(a_sig, w_sig, en_sig, a_matrix, w_matrix);

        check_outputs(expected_sums, test_name);
    end procedure;

begin

    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut : entity work.systolic_array
        port map (
            a_in       => a_in,
            w_in       => w_in,
            clear_i    => clear_i,
            clk_i      => clk_i,
            rst_i      => rst_i,
            input_en_i => input_en_i,
            p_sums_out => p_sums_out
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

        constant I_MATRIX : matrix_t := (
            (1, 0, 0, 0),
            (0, 1, 0, 0),
            (0, 0, 1, 0),
            (0, 0, 0, 1)
        );

        constant ZERO_MATRIX : matrix_t := (
            (0, 0, 0, 0),
            (0, 0, 0, 0),
            (0, 0, 0, 0),
            (0, 0, 0, 0)
        );

        constant A_TEST : matrix_t := (
            (1, 2, 3, 4),
            (5, 6, 7, 8),
            (1, 0, 1, 0),
            (0, 1, 0, 1)
        );

        constant W_TEST : matrix_t := (
            (1, 0, 2, 1),
            (0, 1, 3, 2),
            (1, 0, 4, 3),
            (0, 1, 5, 4)
        );

        constant A_SIGNED : matrix_t := (
            ( 1, -2,  3, -4),
            (-1,  2, -3,  4),
            ( 5,  0, -1,  2),
            ( 0, -3,  2,  1)
        );

        constant W_SIGNED : matrix_t := (
            ( 2, -1,  0,  1),
            (-2,  3,  1,  0),
            ( 1,  1, -1,  2),
            ( 0, -2,  3, -1)
        );

    begin
        --------------------------------------------------------------------
        -- Initial reset
        --------------------------------------------------------------------
        rst_i   <= '1';
        clear_i <= '0';
        input_en_i <= '0';
        a_in    <= (others => (others => '0'));
        w_in    <= (others => (others => '0'));

        wait for 4 * CLK_PERIOD;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        rst_i <= '0';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        --------------------------------------------------------------------
        -- Tests
        --------------------------------------------------------------------


        clear_array(clear_i, input_en_i, a_in, w_in);
        apply_and_check(a_in, w_in, input_en_i, A_TEST, I_MATRIX, "A times identity");
        clear_array(clear_i, input_en_i, a_in, w_in);
        apply_and_check(a_in, w_in, input_en_i, I_MATRIX, W_TEST, "identity times W");
        clear_array(clear_i, input_en_i, a_in, w_in);
        apply_and_check(a_in, w_in, input_en_i, A_TEST, ZERO_MATRIX, "A times zero");
        clear_array(clear_i, input_en_i, a_in, w_in);
        apply_and_check(a_in, w_in, input_en_i, ZERO_MATRIX, W_TEST, "zero times W");
        clear_array(clear_i, input_en_i, a_in, w_in);
        apply_and_check(a_in, w_in, input_en_i, A_TEST, W_TEST, "positive non-trivial multiplication");
        clear_array(clear_i, input_en_i, a_in, w_in);
        apply_and_check(a_in, w_in, input_en_i, A_SIGNED, W_SIGNED, "signed multiplication");

        --------------------------------------------------------------------
        -- End simulation
        --------------------------------------------------------------------
        assert false
            report "TEST PASSED: systolic_array behaves correctly"
            severity note;
            stop;
    end process;

end sim;
