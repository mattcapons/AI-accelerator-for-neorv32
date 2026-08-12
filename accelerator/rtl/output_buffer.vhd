library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.systolic_pkg.all;

entity output_buffer is
    port(
        data_i          : in out_array_t;
        acc_num_i       : in integer range 1 to MAX_TILE_SIZE;
        vld_i           : in std_logic;
        rdy_i           : in std_logic;
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        rdy_o           : out std_logic;
        vld_o           : out std_logic;
        data_o          : out std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0)
    );
end entity output_buffer;


architecture behavioural of output_buffer is

    -- State of the two ping-pong output memory blocks.
    type block_state_t is (EMPTY, FULL);
    type block_state_array_t is array(0 to 1) of block_state_t;
    signal block_state : block_state_array_t;

    -- Temporary buffer used to accumulate complete array outputs.
    signal full_buffer : out_array_t;
    type full_buffer_state_t is (IDLE, ACCUMULATION, WRITE);
    signal full_buffer_state : full_buffer_state_t;

    -- Write data for the even and odd output memories.
    signal e_data_int : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal o_data_int : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);

    -- Asynchronous read outputs from the two memories.
    signal e_data_o : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal o_data_o : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);

    -- Pair counter used while copying the accumulated matrix to memory.
    signal wr_count : integer range 0 to 2*NUM_PE-1;

    -- Current ping-pong blocks used by the writer and transmitter.
    signal bl_wr_count : integer range 0 to 1;
    signal bl_rd_count : integer range 0 to 1;

    signal wr_addr : integer range 0 to NUM_PE*NUM_PE-1;

    signal e_rd_addr : integer range 0 to NUM_PE*NUM_PE-1;
    signal o_rd_addr : integer range 0 to NUM_PE*NUM_PE-1;

    signal wr_en : std_logic;

    -- Number of stored words available for transmission in each block.
    type available_t is array(0 to 1) of integer range 0 to NUM_PE*NUM_PE;
    signal available_count : available_t;

    -- Number of words already transmitted from the current block.
    signal tx_count : integer range 0 to NUM_PE*NUM_PE-1;

    signal vld : std_logic;


begin

    -- Even-column output memory.
    even_mem_inst : entity work.acc_mem_unit
        generic map(
            MEM_DEPTH => NUM_PE * NUM_PE
        )
        port map (
            data_i          => e_data_int,
            read_addr_i     => e_rd_addr,
            write_addr_i    => wr_addr,
            wr_en_i         => wr_en,
            clk_i           => clk_i,
            rst_i           => rst_i,
            data_o          => e_data_o
        );

    -- Odd-column output memory.
    odd_mem_inst : entity work.acc_mem_unit
        generic map(
            MEM_DEPTH => NUM_PE * NUM_PE
        )
        port map (
            data_i          => o_data_int,
            read_addr_i     => o_rd_addr,
            write_addr_i    => wr_addr,
            wr_en_i         => wr_en,
            clk_i           => clk_i,
            rst_i           => rst_i,
            data_o          => o_data_o
        );

    vld_o <= vld;


    sync_proc : process(clk_i, rst_i) is
        variable acc_count      : integer range 0 to MAX_TILE_SIZE-1;
        variable next_available : integer range 0 to NUM_PE*NUM_PE;
    begin
        if rst_i = '1' then
            block_state       <= (others => EMPTY);
            bl_wr_count       <= 0;
            bl_rd_count       <= 0;
            full_buffer       <= (others => (others => (others => '0')));
            full_buffer_state <= IDLE;
            acc_count         := 0;
            wr_count          <= 0;
            wr_addr           <= 0;
            available_count   <= (others => 0);
            tx_count          <= 0;

        elsif rising_edge(clk_i) then

            -- Array output accumulation and memory write control.
            case full_buffer_state is

                when IDLE =>
                    -- Store the first partial result of a new output tile.
                    if vld_i = '1' then
                        wr_addr <= bl_wr_count * 2*NUM_PE;
                        full_buffer <= data_i;

                        if acc_num_i = 1 then
                            full_buffer_state <= WRITE;
                            acc_count := 0;
                        else
                            full_buffer_state <= ACCUMULATION;
                            acc_count := 1;
                        end if;
                    end if;


                when ACCUMULATION =>
                    -- Accumulate successive partial results into the buffer.
                    if vld_i = '1' then

                        for i in 0 to NUM_PE-1 loop
                            for j in 0 to NUM_PE-1 loop
                                full_buffer(i, j) <=
                                    full_buffer(i, j) + data_i(i, j);
                            end loop;
                        end loop;

                        if acc_count < acc_num_i-1 then
                            acc_count := acc_count + 1;
                        else
                            acc_count := 0;
                            full_buffer_state <= WRITE;
                        end if;
                    end if;


                when WRITE =>
                    -- Copy the completed matrix to output memory two values at a time.
                    if block_state(bl_wr_count) = EMPTY then

                        if wr_count < 2*NUM_PE-1 then
                            wr_count <= wr_count + 1;
                            wr_addr <= wr_addr + 1;

                        else
                            wr_count <= 0;
                            block_state(bl_wr_count) <= FULL;
                            bl_wr_count <= 1 - bl_wr_count;
                            full_buffer_state <= IDLE;
                        end if;

                    end if;

            end case;


            -- Advance the TX side only after a successful valid-ready transfer.
            if vld = '1' and rdy_i = '1' then

                if tx_count < NUM_PE*NUM_PE-1 then
                    tx_count <= tx_count + 1;

                else
                    tx_count <= 0;
                    block_state(bl_rd_count) <= EMPTY;
                    bl_rd_count <= 1 - bl_rd_count;
                end if;

            end if;


            -- Track words written to and consumed from each output block.
            for b in 0 to 1 loop

                next_available := available_count(b);

                if wr_en = '1' and bl_wr_count = b then
                    next_available := next_available + 2;
                end if;

                if vld = '1' and rdy_i = '1' and bl_rd_count = b then
                    next_available := next_available - 1;
                end if;

                available_count(b) <= next_available;

            end loop;

        end if;
    end process sync_proc;


    comb_proc : process(all) is
        variable row      : integer range 0 to NUM_PE-1;
        variable base_col : integer range 0 to NUM_PE-1;
        variable rd_addr  : integer range 0 to NUM_PE*NUM_PE-1;
    begin

        -- Combinational defaults.
        rdy_o      <= '0';
        vld        <= '0';
        wr_en      <= '0';

        e_data_int <= (others => '0');
        o_data_int <= (others => '0');

        e_rd_addr  <= 0;
        o_rd_addr  <= 0;

        data_o     <= (others => '0');

        row      := 0;
        base_col := 0;
        rd_addr  := 0;


        -- Write-side combinational control.
        case full_buffer_state is

            when IDLE | ACCUMULATION =>
                rdy_o <= '1';

            when WRITE =>
                -- Select the next row-major pair from the accumulated matrix.
                row      := wr_count / 2;
                base_col := (wr_count mod 2) * 2;

                e_data_int <= std_logic_vector(full_buffer(row, base_col));
                o_data_int <= std_logic_vector(full_buffer(row, base_col + 1));

                if block_state(bl_wr_count) = EMPTY then
                    wr_en <= '1';
                end if;

            when others =>
                null;

        end case;


        -- Read-side address for the current block and matrix pair.
        rd_addr := (bl_rd_count * 2*NUM_PE) + (tx_count / 2);

        e_rd_addr <= rd_addr;
        o_rd_addr <= rd_addr;

        -- Data is valid whenever at least one stored word is available.
        if available_count(bl_rd_count) > 0 then
            vld <= '1';
        end if;

        -- Alternate even and odd memories to produce row-major output.
        if (tx_count mod 2) = 0 then
            data_o <= e_data_o;
        else
            data_o <= o_data_o;
        end if;

    end process comb_proc;

end architecture behavioural;
