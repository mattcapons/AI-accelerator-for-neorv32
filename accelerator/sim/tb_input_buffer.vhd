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
    signal data_i          : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0) := (others => '0');
    signal en_i            : std_logic := '0';
    signal vld_i           : std_logic := '0';
    signal rdy_i           : std_logic := '0';
    signal clk_i           : std_logic := '0';
    signal rst_i           : std_logic := '0';

    signal rdy_o           : std_logic;
    signal vld_o           : std_logic;
    signal a_data_o        : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal w_data_o        : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);


    ------------------------------------------------------------------------
    -- Clock period
    ------------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;


    ------------------------------------------------------------------------
    -- Conversion functions
    ------------------------------------------------------------------------
    function int_to_vect(num : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(num, NUM_PE*DATA_WIDTH));
    end function;

    function vect_to_int(num : std_logic_vector) return integer is
    begin
        return to_integer(signed(num));
    end function;


begin

    ------------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------------
    dut_inst : entity work.input_buffer
        port map (
            data_i          => data_i,
            en_i            => en_i,
            vld_i           => vld_i,
            rdy_i           => rdy_i,
            clk_i           => clk_i,
            rst_i           => rst_i,
            rdy_o           => rdy_o,
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

        ------------------------------------------------------------------------
        -- Write one SLINK word
        ------------------------------------------------------------------------
        procedure write_word(data : integer) is
        begin
            data_i <= int_to_vect(data);
            vld_i <= '1';

            if rdy_o /= '1' then
                wait until rdy_o = '1';
            end if;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            vld_i <= '0';

            wait for 1 ns;
        end procedure;


        ------------------------------------------------------------------------
        -- Write one complete A/W tile
        ------------------------------------------------------------------------
        procedure write_tile(a_start : integer; w_start : integer) is
        begin
            -- A words
            for i in 0 to NUM_PE-1 loop
                write_word(a_start + i);
            end loop;

            -- W words
            for i in 0 to NUM_PE-1 loop
                write_word(w_start + i);
            end loop;
        end procedure;


        ------------------------------------------------------------------------
        -- Read one A/W pair
        ------------------------------------------------------------------------
        procedure read(
            variable a_o : out integer;
            variable w_o : out integer
        ) is
        begin
            assert vld_o = '1'
                report "Buffer not ready for read"
                severity failure;

            rdy_i <= '1';

            wait for 1 ns;

            -- Capture the data BEFORE the handshake edge.
            -- The asynchronous memory output changes after rd_addr advances.
            a_o := vect_to_int(a_data_o);
            w_o := vect_to_int(w_data_o);

            wait until rising_edge(clk_i);
            wait for 1 ns;

            rdy_i <= '0';

            wait for 1 ns;
        end procedure;


        variable a_output : integer;
        variable w_output : integer;

    begin

        ------------------------------------------------------------------------
        -- Test reset
        ------------------------------------------------------------------------
        rst_i <= '1';
        wait for 1 ns;
        rst_i <= '0';

        assert rdy_o = '0' and vld_o = '0'
            report "Error in valid/ready signals after reset"
            severity failure;


        ------------------------------------------------------------------------
        -- Test disabled input
        ------------------------------------------------------------------------
        en_i <= '0';

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert rdy_o = '0'
            report "Buffer ready while input is disabled"
            severity failure;


        ------------------------------------------------------------------------
        -- Test enable
        ------------------------------------------------------------------------
        en_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert rdy_o = '1' and vld_o = '0'
            report "Error in valid/ready after enable"
            severity failure;


        ------------------------------------------------------------------------
        -- Test that A alone does not make the block valid
        ------------------------------------------------------------------------
        for i in 0 to NUM_PE-1 loop
            write_word(i + 1);
        end loop;

        assert vld_o = '0'
            report "Block became valid after A only"
            severity failure;


        ------------------------------------------------------------------------
        -- Test that incomplete W does not make the block valid
        ------------------------------------------------------------------------
        for i in 0 to NUM_PE-2 loop
            write_word(i + 2);
        end loop;

        assert vld_o = '0'
            report "Block became valid before all W words arrived"
            severity failure;


        ------------------------------------------------------------------------
        -- Final W word completes the block
        ------------------------------------------------------------------------
        write_word(NUM_PE + 1);

        assert vld_o = '1'
            report "Block not valid after complete A/W write"
            severity failure;


        ------------------------------------------------------------------------
        -- Test full read for one block
        ------------------------------------------------------------------------
        for i in 0 to NUM_PE-1 loop
            read(a_output, w_output);

            assert a_output = i + 1 and w_output = i + 2
                report "Read after first write incorrect"
                severity failure;
        end loop;

        assert vld_o = '0'
            report "Error in valid after first read"
            severity failure;


        ------------------------------------------------------------------------
        -- Test two blocks written
        ------------------------------------------------------------------------
        write_tile(1, 2);
        write_tile(2, 3);

        assert rdy_o = '0'
            report "Error in ready after two blocks are written"
            severity failure;


        ------------------------------------------------------------------------
        -- Read first block
        ------------------------------------------------------------------------
        for i in 0 to NUM_PE-1 loop
            read(a_output, w_output);

            assert a_output = i + 1 and w_output = i + 2
                report "First read is out of order"
                severity failure;
        end loop;


        ------------------------------------------------------------------------
        -- Writer needs one clock to observe that the block became EMPTY
        -- and leave IDLE
        ------------------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert rdy_o = '1'
            report "Buffer did not become ready after one block was freed"
            severity failure;


        ------------------------------------------------------------------------
        -- Read second block
        ------------------------------------------------------------------------
        for i in 0 to NUM_PE-1 loop
            read(a_output, w_output);

            assert a_output = i + 2 and w_output = i + 3
                report "Second read is out of order"
                severity failure;
        end loop;


        ------------------------------------------------------------------------
        -- Test input stall: valid = 0 must not advance write position
        ------------------------------------------------------------------------
        write_word(10);
        write_word(11);

        vld_i <= '0';

        for i in 0 to 2 loop
            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert rdy_o = '1'
                report "Ready dropped during input valid stall"
                severity failure;
        end loop;

        -- Remaining A words
        write_word(12);
        write_word(13);

        -- W words
        write_word(20);
        write_word(21);
        write_word(22);
        write_word(23);


        ------------------------------------------------------------------------
        -- Test consumer not ready: output must remain unchanged
        ------------------------------------------------------------------------
        rdy_i <= '0';
        wait for 1 ns;

        assert vld_o = '1'
            report "Valid not asserted for completed block"
            severity failure;

        assert vect_to_int(a_data_o) = 10 and
               vect_to_int(w_data_o) = 20
            report "Incorrect first output before stall"
            severity failure;

        wait for 40 ns;

        assert vld_o = '1'
            report "Valid dropped while consumer remained not ready"
            severity failure;

        assert vect_to_int(a_data_o) = 10 and
               vect_to_int(w_data_o) = 20
            report "Output moved while ready = 0"
            severity failure;


        ------------------------------------------------------------------------
        -- Test en_i going low during an active tile
        ------------------------------------------------------------------------
        -- First consume the current tile.
        for i in 0 to NUM_PE-1 loop
            read(a_output, w_output);
        end loop;

        -- Allow the writer to start the next tile.
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert rdy_o = '1'
            report "Buffer not ready before enable test"
            severity failure;

        -- Begin a tile while enabled.
        write_word(30);
        write_word(31);

        -- Disable reception of NEW tiles.
        -- Current tile should still be completed.
        en_i <= '0';

        write_word(32);
        write_word(33);

        write_word(40);
        write_word(41);
        write_word(42);
        write_word(43);

        assert vld_o = '1'
            report "Current tile did not complete after enable went low"
            severity failure;

        assert rdy_o = '0'
            report "Buffer started a new tile while enable was low"
            severity failure;


        ------------------------------------------------------------------------
        -- Final result
        ------------------------------------------------------------------------
        assert false
            report "TEST PASSED: input_buffer behaves correctly"
            severity note;

        stop;
    end process;

end architecture;
