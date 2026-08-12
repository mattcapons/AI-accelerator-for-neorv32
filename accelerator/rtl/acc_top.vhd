library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.systolic_pkg.all;

entity acc_top is
    port (
        start_i     : in std_logic;
        clk_i       : in std_logic;
        rstn_i      : in std_logic;
        acc_num_i   : in integer range 1 to MAX_TILE_SIZE;
        tx_vld_i    : in std_logic;
        rx_rdy_i    : in std_logic;
        tx_data_i   : in std_logic_vector(31 downto 0);
        tx_rdy_o    : out std_logic;
        rx_vld_o    : out std_logic;
        rdy_o       : out std_logic;
        rx_data_o   : out std_logic_vector(31 downto 0)
    );

end entity acc_top;


architecture behavioural of acc_top is
    type acc_state_t is (IDLE, COMPUTE);
    signal acc_state : acc_state_t;

    signal enable : std_logic;
    signal tx_done : std_logic;

    signal rst : std_logic;

    signal in_to_arr_vld : std_logic;
    signal in_to_arr_rdy : std_logic;
    signal in_to_arr_a_data : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);
    signal in_to_arr_w_data : std_logic_vector(NUM_PE*DATA_WIDTH-1 downto 0);

    signal arr_to_out_vld : std_logic;
    signal arr_to_out_rdy : std_logic;
    signal arr_to_out_data : out_array_t;

begin



    input_buffer_inst : entity work.input_buffer
        port map(
            data_i          => tx_data_i,
            en_i            => enable,
            vld_i           => tx_vld_i,
            rdy_i           => in_to_arr_rdy,
            clk_i           => clk_i,
            rst_i           => rst,
            rdy_o           => tx_rdy_o,
            vld_o           => in_to_arr_vld,
            a_data_o        => in_to_arr_a_data,
            w_data_o        => in_to_arr_w_data
        );

    systolic_inst : entity work.systolic_engine
        port map(
            a_mem_i         => in_to_arr_a_data,
            w_mem_i         => in_to_arr_w_data,
            vld_i           => in_to_arr_vld,
            rdy_i           => arr_to_out_rdy,
            clk_i           => clk_i,
            rst_i           => rst,
            rdy_o           => in_to_arr_rdy,
            vld_o           => arr_to_out_vld,
            p_sums_out      => arr_to_out_data
        );

    output_buffer_inst : entity work.output_buffer
        port map(
            data_i          => arr_to_out_data,
            acc_num_i       => acc_num_i,
            vld_i           => arr_to_out_vld,
            rdy_i           => rx_rdy_i,
            clk_i           => clk_i,
            rst_i           => rst,
            rdy_o           => arr_to_out_rdy,
            vld_o           => rx_vld_o,
            tx_done_o       => tx_done,
            data_o          => rx_data_o
        );

    sync_proc : process(clk_i, rst) is
        variable tx_count : integer range 0 to MAX_TILE_SIZE*MAX_TILE_SIZE-1;
    begin
        if rst = '1' then
            acc_state <= IDLE;

            tx_count := 0;

        elsif rising_edge(clk_i) then
            case acc_state is

                when IDLE =>
                    if start_i = '1' then
                        acc_state <= COMPUTE;
                        tx_count := 0;
                    end if;

                when COMPUTE =>
                    if tx_done = '1' then
                        if tx_count < acc_num_i*acc_num_i-1 then
                            tx_count := tx_count + 1;
                        else
                            tx_count := 0;
                            acc_state <= IDLE;
                        end if;
                    end if;
            end case;

        end if;

    end process sync_proc;


    comb_proc : process(all)
    begin
        rdy_o <= '0';
        enable <= '0';

        case acc_state is
            when IDLE =>
                rdy_o <= '1';

            when COMPUTE =>
                enable <= '1';
        end case;

    end process comb_proc;


    rst <= not rstn_i;

end architecture behavioural;
