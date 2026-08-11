library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.systolic_pkg.all;

entity input_buffer is
    port(
        data_i          : in std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        en_i            : in std_logic;
        vld_i           : in std_logic;
        rdy_i           : in std_logic;
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        rdy_o           : out std_logic;
        vld_o           : out std_logic;
        a_data_o        : out std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        w_data_o        : out std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0)
    );
end entity input_buffer;


architecture behavioural of input_buffer is

    type write_state_t is (IDLE, WRITE_A, WRITE_W);
    signal wr_state : write_state_t;

    signal wr_count : integer range 0 to NUM_PE-1;

    type block_state_t is (EMPTY, FULL);
    type block_state_array_t is array(0 to 1) of block_state_t;
    signal block_state : block_state_array_t;

    signal bl_wr_count : integer range 0 to 1;
    signal bl_rd_count : integer range 0 to 1;

    signal a_wr_addr : integer range 0 to NUM_PE*2-1;
    signal w_wr_addr : integer range 0 to NUM_PE*2-1;

    signal rd_addr : integer range 0 to NUM_PE*2-1;

    signal a_wr_en : std_logic;
    signal w_wr_en : std_logic;

    signal vld : std_logic;


begin

    a_mem_inst : entity work.acc_mem_unit
        generic map(
            MEM_DEPTH => 2 * NUM_PE
        )
        port map (
            data_i          => data_i,
            read_addr_i     => rd_addr,
            write_addr_i    => a_wr_addr,
            wr_en_i         => a_wr_en,
            clk_i           => clk_i,
            rst_i           => rst_i,
            data_o          => a_data_o
        );

    w_mem_inst : entity work.acc_mem_unit
        generic map(
            MEM_DEPTH => 2 * NUM_PE
        )
        port map (
            data_i          => data_i,
            read_addr_i     => rd_addr,
            write_addr_i    => w_wr_addr,
            wr_en_i         => w_wr_en,
            clk_i           => clk_i,
            rst_i           => rst_i,
            data_o          => w_data_o
        );

        sync_proc : process(clk_i, rst_i) is
            -- READ COUNT
            variable rd_count : integer range 0 to NUM_PE-1 := 0;
        begin

            if rst_i = '1' then
                block_state <= (others => EMPTY);

                -- WRITE SIDE
                wr_state <= IDLE;
                wr_count <= 0;
                bl_wr_count <= 0;
                a_wr_addr <= 0;
                w_wr_addr <= 0;

                -- READ SIDE
                rd_count := 0;
                rd_addr <= 0;
                bl_rd_count <= 0;

            elsif rising_edge(clk_i) then

                case wr_state is
                    when IDLE =>
                        wr_count <= 0;
                        a_wr_addr <= (bl_wr_count) * NUM_PE;
                        w_wr_addr <= (bl_wr_count) * NUM_PE;

                        if en_i = '1' and block_state(bl_wr_count) = EMPTY then
                            wr_state <= WRITE_A;
                        end if;

                    when WRITE_A =>
                        if vld_i = '1' and rdy_o = '1' then
                            if wr_count < NUM_PE-1 then
                                wr_count <= wr_count + 1;
                                a_wr_addr <= a_wr_addr + 1;
                            else
                                wr_count <= 0;
                                wr_state <= WRITE_W;
                            end if;
                        end if;

                    when WRITE_W =>
                        if vld_i = '1' and rdy_o = '1' then
                            if wr_count < NUM_PE-1 then
                                wr_count <= wr_count + 1;
                                w_wr_addr <= w_wr_addr + 1;
                            else
                                wr_count <= 0;
                                wr_state <= IDLE;
                                block_state(bl_wr_count) <= FULL;
                                bl_wr_count <= 1 - bl_wr_count;
                            end if;
                        end if;

                    when others =>
                        null;
                end case;

                -- READ SIDE
                if rdy_i = '1' and vld = '1' then
                    if rd_count < NUM_PE-1 then
                        rd_count := rd_count + 1;
                        rd_addr <= rd_addr + 1;
                    else
                        block_state(bl_rd_count) <= EMPTY; -- memory discarded
                        rd_count := 0; -- reset count
                        bl_rd_count <= 1 - bl_rd_count; -- change block
                        rd_addr <= (1-bl_rd_count) * NUM_PE; -- set address to the first element of next block
                    end if;
                end if;
            end if;
        end process sync_proc;

        comb_proc : process(all) is
        begin
            rdy_o <= '0';
            a_wr_en <= '0';
            w_wr_en <= '0';
            case wr_state is
                when IDLE =>
                    null;

                when WRITE_A =>
                    rdy_o <= '1';
                    if vld_i = '1' then
                        a_wr_en <= '1';
                    end if;

                when WRITE_W =>
                    rdy_o <= '1';
                    if vld_i = '1' then
                        w_wr_en <= '1';
                    end if;

                when others =>
                    null;
            end case;


            -- READ SIDE
            vld <= '0';
            if block_state(bl_rd_count) = FULL then
                vld <= '1';
            end if;
        end process comb_proc;

    vld_o <= vld;

end architecture behavioural;
