library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.systolic_pkg.all;

entity input_buffer is
    port(
        a_data_i        : in std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        w_data_i        : in std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        en_i            : in std_logic;
        a_vld_i         : in std_logic;
        w_vld_i         : in std_logic;
        rdy_i           : in std_logic;
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        a_rdy_o         : out std_logic;
        w_rdy_o         : out std_logic;
        vld_o           : out std_logic;
        a_data_o        : out std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
        w_data_o        : out std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0)
    );
end entity input_buffer;


architecture behavioural of input_buffer is

    type block_state_t is (EMPTY, FULL);
    type state_t is array(0 to 1) of block_state_t;

    signal a_state : state_t;
    signal w_state : state_t;

    signal bl_wr_count : integer range 0 to 1;
    signal bl_rd_count : integer range 0 to 1;

    signal a_wr_addr : integer range 0 to NUM_PE*2-1;
    signal w_wr_addr : integer range 0 to NUM_PE*2-1;

    signal rd_addr : integer range 0 to NUM_PE*2-1;

    signal a_wr_en : std_logic;
    signal w_wr_en : std_logic;


    signal a_rdy : std_logic;
    signal w_rdy : std_logic;

    signal vld : std_logic;


begin

    a_mem_inst : entity work.acc_mem_unit
        generic map(
            MEM_DEPTH => 2 * NUM_PE
        )
        port map (
            data_i          => a_data_i,
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
            data_i          => w_data_i,
            read_addr_i     => rd_addr,
            write_addr_i    => w_wr_addr,
            wr_en_i         => w_wr_en,
            clk_i           => clk_i,
            rst_i           => rst_i,
            data_o          => w_data_o
        );


    sync_proc : process(clk_i, rst_i) is

        -- WRITE COUNT
        variable a_wr_count : integer range 0 to NUM_PE-1 := 0;
        variable w_wr_count : integer range 0 to NUM_PE-1 := 0;

        -- READ COUNT
        variable rd_count : integer range 0 to NUM_PE-1 := 0;
    begin

        if rst_i = '1' then

            a_state <= (others => EMPTY);
            w_state <= (others => EMPTY);

            -- WRITE SIDE
            a_wr_count := 0;
            w_wr_count := 0;
            a_wr_addr <= 0;
            w_wr_addr <= 0;
            bl_wr_count <= 0;

            -- READ SIDE
            rd_count := 0;
            rd_addr <= 0;
            bl_rd_count <= 0;

        elsif rising_edge(clk_i) then
            -- WRITE SIDE
            if a_rdy = '1' and a_vld_i = '1' then
                if a_wr_count < NUM_PE-1 then
                    a_wr_count := a_wr_count + 1;
                    a_wr_addr <= a_wr_addr + 1;
                else
                    a_state(bl_wr_count) <= FULL;
                    a_wr_count := 0;
                end if;
            end if;

            if w_rdy = '1' and w_vld_i = '1' then
                if w_wr_count < NUM_PE-1 then
                    w_wr_count := w_wr_count + 1;
                    w_wr_addr <= w_wr_addr + 1;
                else
                    w_state(bl_wr_count) <= FULL;
                    w_wr_count := 0;
                end if;
            end if;

            if a_state(bl_wr_count) = FULL and w_state(bl_wr_count) = FULL then
                bl_wr_count <= 1 - bl_wr_count;
                a_wr_addr <= (1-bl_wr_count) * NUM_PE;
                w_wr_addr <= (1-bl_wr_count) * NUM_PE;
            end if;

            -- READ SIDE
            if rdy_i = '1' and vld = '1' then
                if rd_count < NUM_PE-1 then
                    rd_count := rd_count + 1;
                    rd_addr <= rd_addr + 1;
                else
                    a_state(bl_rd_count) <= EMPTY; -- memory discarded
                    w_state(bl_rd_count) <= EMPTY; -- memory discarded
                    rd_count := 0; -- reset count
                    bl_rd_count <= 1 - bl_rd_count; -- change block
                    rd_addr <= (1-bl_rd_count) * NUM_PE; -- set address to the first element of next block
                end if;
            end if;

        end if;
    end process sync_proc;

    --WRITE COMBINATORIAL
    a_rdy <= '1' when
        en_i = '1' and a_state(bl_wr_count) = EMPTY
    else '0';

    w_rdy <= '1' when
        en_i = '1' and w_state(bl_wr_count) = EMPTY
    else '0';

    a_wr_en <= a_rdy and a_vld_i;
    w_wr_en <= w_rdy and w_vld_i;

    a_rdy_o <= a_rdy;
    w_rdy_o <= w_rdy;


    -- READ COMBINATORIAL
    vld <= '1' when
        a_state(bl_rd_count) = FULL and w_state(bl_rd_count) = FULL
    else '0';

    vld_o <= vld;

end architecture behavioural;
