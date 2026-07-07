library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity systolic_controller is
    port (
        p_sums_i        : in out_array_t;
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        start_i         : in std_logic;
        p_sum_o         : out signed(ACC_WIDTH-1 downto 0);
        rdy_o           : out std_logic;
        feed_idx_o      : out integer range 0 to NUM_PE-1;
        clear_o         : out std_logic;
        done_o          : out std_logic;
        feed_valid_o    : out std_logic;
        p_sum_valid_o   : out std_logic
    );
end systolic_controller;

architecture Behavioral of systolic_controller is

    type state_t is (IDLE, FEED, DRAIN, OUTPUT, DONE);
    signal state : state_t := IDLE;

    signal cycle_count : integer range 0 to NUM_PE := 0;
    signal row_count : integer range 0 to NUM_PE-1 := 0;
    signal col_count : integer range 0 to NUM_PE-1 := 0;
    
begin  

    in_fsm_sync : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            state <= IDLE;
            cycle_count <= 0;
            row_count <= 0;
            col_count <= 0;

        elsif rising_edge(clk_i) then
            case state is
                when IDLE =>
                    if start_i = '1' then
                        state <= FEED;
                        cycle_count <= 0;
                        row_count <= 0;
                        col_count <= 0;
                    end if;

                when FEED =>
                    if cycle_count = NUM_PE then
                        state <= DRAIN;
                    else
                        cycle_count <= cycle_count + 1;
                    end if;

                when DRAIN =>
                    state <= OUTPUT;

                when OUTPUT =>
                    if col_count = NUM_PE-1 then
                        if row_count = NUM_PE-1 then
                            state <= DONE;
                        else
                            col_count <= 0;
                            row_count <= row_count + 1;
                        end if;
                    else
                        col_count <= col_count + 1;
                    end if;

                when DONE =>
                    state <= IDLE;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    fsm_comb : process(all)
    begin
        rdy_o <= '0';
        feed_idx_o <= 0;
        clear_o <= '0';
        done_o <= '0';
        feed_valid_o <= '0';
        p_sum_o <= (others => '0');
        p_sum_valid_o <= '0';
        

        case state is
            when IDLE =>
                rdy_o <= '1';

            when FEED =>
                if cycle_count > 0 then
                    feed_valid_o <= '1';
                else
                    feed_valid_o <= '0';
                end if;

                if cycle_count < NUM_PE then
                    feed_idx_o <= cycle_count;
                else
                    feed_idx_o <= 0;
                end if;

            when DRAIN =>
                null;

            when OUTPUT =>
                p_sum_o <= p_sums_i(row_count, col_count);
                p_sum_valid_o <= '1';

            when DONE =>
                clear_o <= '1';
                done_o <= '1';

            when others =>
                null;

        end case;
    end process;

end Behavioral;
        