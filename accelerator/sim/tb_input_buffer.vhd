library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.systolic_pkg.all;

entity tb_input_buffer is
end tb_input_buffer;

architecture sim of tb_input_buffer is



    ------------------------------------------------------------------------
    -- DUT signals
    ------------------------------------------------------------------------
    signal a_data_i        : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal w_data_i        : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal en_i            : std_logic;
    signal a_vld_i         : std_logic;
    signal w_vld_i         : std_logic;
    signal rdy_i           : std_logic;
    signal clk_i           : std_logic;
    signal rst_i           : std_logic;
    signal a_rdy_o         : std_logic;
    signal w_rdy_o         : std_logic;
    signal vld_o           : std_logic;
    signal a_data_o        : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal w_data_o        : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);


    ------------------------------------------------------------------------
    -- Clock period
    ------------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    -- Conversion functions
    function int_to_vect(num : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(num, NUM_PE*DATA_WIDTH));
    end function;

    function vect_to_int(num : STD_LOGIC_VECTOR) return INTEGER is
    begin
        return  to_integer(signed(num));
    end function;


begin


    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut_inst : entity work.input_buffer
        port map (
            a_data_i        => a_data_i,
            w_data_i        => w_data_i,
            en_i            => en_i,
            a_vld_i         => a_vld_i,
            w_vld_i         => w_vld_i,
            rdy_i           => rdy_i,
            clk_i           => clk_i,
            rst_i           => rst_i,
            a_rdy_o         => a_rdy_o,
            w_rdy_o         => w_rdy_o,
            vld_o           => vld_o,
            a_data_o        => a_data_o,
            w_data_o        => w_data_o
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


            procedure write(a : integer; w : integer) is
            begin
                assert a_rdy_o = '1' and w_rdy_o = '1'
                    report "Buffer not ready for write"
                    severity failure;


                a_vld_i <= '1';
                w_vld_i <= '1';

                a_data_i <= int_to_vect(a);
                w_data_i <= int_to_vect(w);

                wait until rising_edge(clk_i);
                wait for 1 ns;

                a_vld_i <= '0';
                w_vld_i <= '0';

                wait for 1 ns;
            end procedure;

            variable a_output : integer;
            variable w_output : integer;

            procedure read(variable a_o : out integer; variable w_o : out integer) is
            begin
                assert vld_o = '1'
                    report "Buffer not ready for read"
                    severity failure;

                rdy_i <= '1';

                wait until rising_edge(clk_i);
                wait for 1 ns;

                a_o := vect_to_int(a_data_o);
                w_o := vect_to_int(w_data_o);

                rdy_i <= '0';

                wait for 1 ns;
            end procedure;


        begin

            rst_i <= '1';
            wait for 1 ns;
            rst_i <= '0';

            assert a_rdy_o = '0' and w_rdy_o = '0' and vld_o = '0'
                report "Error in valid/ready signals after reset"
                severity failure;

            en_i <= '1';
            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert a_rdy_o = '1' and w_rdy_o = '1' and vld_o = '0'
                report "Error in valid/ready after enable"
                severity failure;


            for i in 0 to NUM_PE-1 loop
                write(i+1, i+2);
            end loop;

            for i in 0 to NUM_PE-1 loop
                read(a_output, w_output);
                assert a_output = i+1 and w_output = i+2
                    report "Read after first write incorrect"
                    severity failure;
            end loop;

            assert vld_o = '0'
                report "Error in valid after first read"
                severity failure;


            for i in 0 to NUM_PE-1 loop
                write(i+1, i+2);
            end loop;

            for i in 0 to NUM_PE-1 loop
                write(i+2, i+3);
            end loop;

            assert a_rdy_o = '0' and w_rdy_o = '0'
                report "Error in ready after 2 blocks are written"
                severity failure;

            for i in 0 to NUM_PE-1 loop
                read(a_output, w_output);
                assert a_output = i+1 and w_output = i+2
                    report "First read is out of order"
                    severity failure;
            end loop;

            assert a_rdy_o = '1' and w_rdy_o = '1'
                report "Error in ready after 1 block is freed"
                severity failure;

            for i in 0 to NUM_PE-1 loop
                read(a_output, w_output);
                assert a_output = i+2 and w_output = i+3
                    report "Second read is out of order"
                    severity failure;
            end loop;

            -- Manual write only for a
            assert a_rdy_o = '1'
                report "A buffer not ready for write"
                severity failure;

            a_vld_i <= '1';

            for i in 0 to NUM_PE-1 loop
                a_data_i <= int_to_vect(i+1);

                wait until rising_edge(clk_i);
                wait for 1 ns;

            end loop;

            a_vld_i <= '0';

            wait for 1 ns;

            assert a_rdy_o = '0' and w_rdy_o = '1'
                report "Error in ready after writing only A side"
                severity failure;


            -- Manual write only for w
            assert w_rdy_o = '1'
                report "W buffer not ready for write"
                severity failure;

            w_vld_i <= '1';

            for i in 0 to NUM_PE-1 loop
                w_data_i <= int_to_vect(i+1);

                wait until rising_edge(clk_i);
                wait for 1 ns;
            end loop;

            w_vld_i <= '0';

            wait for 1 ns;




            rdy_i <= '0';
            wait for 1 ns;

            assert vld_o = '1'
                report "Error in valid while ready remains 0"
                severity failure;

            assert vect_to_int(a_data_o) = 1 and vect_to_int(w_data_o) = 1
                report "Output moving with ready = 0"
                severity failure;

            wait for 40 ns;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert vld_o = '1'
                report "Error in valid while ready remains 0 after multiple cycles"
                severity failure;

            assert vect_to_int(a_data_o) = 1 and vect_to_int(w_data_o) = 1
                report "Output moving with ready = 0 after multiple cycles"
                severity failure;

            assert false
                report "TEST PASSED: input_buffer behaves correctly"
                severity note;
                stop;
        end process;

end architecture;
