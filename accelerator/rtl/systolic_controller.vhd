library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.systolic_pkg.all;

entity systolic_controller is
    port (
        a_buff_i : in  byte_array_t;
        w_buff_i : in  byte_array_t;
        clear_result_i : in  std_logic;
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        start_i : in  std_logic;
        a_feed_o : out  byte_array_t;
        w_feed_o : out  byte_array_t;
        pop_o : out  std_logic_vector(NUM_PE-1 downto 0);
        clear_o : out  std_logic;
        done_o : out  std_logic
    );
end systolic_controller;

architecture Behavioral of systolic_controller is

    type state_t is (IDLE, PRELOAD, FEED, DRAIN, DONE, CLEAR);
    signal state : state_t := IDLE;

    signal cycle_count : integer range 0 to 2*NUM_PE-1 := 0;
    
begin  

    sync : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            state <= IDLE;
            cycle_count <= 0;
        elsif rising_edge(clk_i) then
            case state is
                when IDLE =>
                    if start_i = '1' then
                        state <= PRELOAD;
                        cycle_count <= 0;
                    end if;

                when PRELOAD =>
                    state <= FEED;

                when FEED =>
                    if cycle_count = 2*NUM_PE-2 then
                        state <= DRAIN;
                        cycle_count <= 0;
                    else
                        cycle_count <= cycle_count + 1;
                    end if;

                when DRAIN =>
                    if cycle_count = NUM_PE-2 then
                        state <= DONE;
                        cycle_count <= 0;
                    else
                        cycle_count <= cycle_count + 1;
                    end if;

                when DONE =>
                    if clear_result_i = '1' then
                        state <= CLEAR;
                    end if;

                when CLEAR =>
                    state <= IDLE;
                    cycle_count <= 0;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    combinational_logic : process(all)
    begin
        -- Default values
        a_feed_o <= (others => (others => '0'));
        w_feed_o <= (others => (others => '0'));
        pop_o <= (others => '0');
        clear_o <= '0';
        done_o <= '0';

        case state is
            when IDLE =>
                null; -- No action in IDLE state

            when PRELOAD =>
                pop_o(0) <= '1';

            when FEED =>
                for i in 0 to NUM_PE-1 loop
                    if cycle_count+1 >= i and cycle_count+1 < i + NUM_PE then
                        pop_o(i) <= '1';
                    end if;
                    if cycle_count >= i and cycle_count < i + NUM_PE then
                        a_feed_o(i) <= a_buff_i(i);
                        w_feed_o(i) <= w_buff_i(i);
                    end if;
                end loop;

            when DRAIN =>
                null; -- No action in DRAIN state

            when DONE =>
                done_o <= '1';

            when CLEAR =>
                clear_o <= '1';
                done_o <= '1';
            
            when others =>
                null; -- No action for undefined states 

        end case;
    end process;

end Behavioral;
        