library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.systolic_pkg.all;

entity output_buffer is
    port(
        data_i          : in out_array_t;
        acc_num_i       : in integer range 0 to MAX_TILE_SIZE-1;
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

    type block_state_t is (EMPTY, FULL);
    type block_state_array_t is array(0 to 1) of block_state_t;
    signal block_state : block_state_array_t;

    signal full_buffer : out_array_t;
    type full_buffer_state_t is (IDLE, ACCUMULATION, WRITE);
    signal full_buffer_state : full_buffer_state_t;

    signal e_data_int : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal o_data_int : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);

    signal e_data_o : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal o_data_o : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);

    type write_state_t is (IDLE, WRITE_A, WRITE_W);
    signal wr_state : write_state_t;

    signal wr_count : integer range 0 to NUM_PE-1;

    signal bl_wr_count : integer range 0 to 1;
    signal bl_rd_count : integer range 0 to 1;

    signal wr_addr : integer range 0 to NUM_PE*NUM_PE-1;

    signal e_rd_addr : integer range 0 to NUM_PE*NUM_PE-1;
    signal o_rd_addr : integer range 0 to NUM_PE*NUM_PE-1;

    signal wr_en : std_logic;

    signal vld : std_logic;


begin

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

        sync_proc : process(clk_i, rst_i) is
            variable acc_count : integer range 0 to MAX_TILE_SIZE-1;
            variable wr_count : integer range 0 to 2*NUM_PE-1;
        begin
            if rst_i = '1' then

            elsif rising_edge(clk_i) then
                case full_buffer_state is
                    when IDLE =>
                        acc_count := 0;
                        wr_count := 0;
                        wr_addr <= (bl_wr_count) * 2*NUM_PE;
                        if vld_i = '1' then
                            full_buffer <= data_i;
                            full_buffer_state <= ACCUMULATION;
                        end if;

                    when ACCUMULATION =>
                        if vld_i = '1' then
                            for i in 0 to NUM_PE-1 loop
                                for j in 0 to NUM_PE-1 loop
                                    full_buffer(i, j) <= full_buffer(i, j) + data_i(i, j);
                                end loop;
                            end loop;
                        end if;
                        if acc_count < acc_num_i-1 then
                            acc_count := acc_count + 1;
                        else
                            acc_count := 0;
                            full_buffer_state <= WRITE;
                        end if;

                    when WRITE =>
                        if block_state(bl_wr_count) = EMPTY then
                            if wr_count < 2*NUM_PE-1 then
                                wr_count := wr_count + 1;
                                wr_addr <= wr_addr + 1;
                            else
                                wr_count := 0;
                                block_state(bl_wr_count) <= FULL;
                                bl_wr_count <= 1 - bl_wr_count;
                                full_buffer_state <= IDLE;
                            end if;
                        end if;
                end case;

            end if;
        end process sync_proc;

        comb_proc : process(all) is
        begin

        end process comb_proc;

end architecture behavioural;
