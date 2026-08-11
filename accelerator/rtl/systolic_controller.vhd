library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity systolic_controller is
    port (
        vld_i           : in std_logic;
        rdy_i           : in std_logic;
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        rdy_o           : out std_logic;
        vld_o           : out std_logic;
        clear_o         : out std_logic;
        input_en_o      : out std_logic;
        comp_en_o       : out std_logic
    );
end systolic_controller;

architecture Behavioral of systolic_controller is

    type state_t is (IDLE, FEED, DRAIN, OUTPUT);
    signal state : state_t := IDLE;

begin

    in_fsm_sync : process(clk_i, rst_i)
        variable cycle_count : integer range 0 to (2*NUM_PE)-2 := 0;
    begin
        if rst_i = '1' then
            state <= IDLE;
            cycle_count := 0;

        elsif rising_edge(clk_i) then
            case state is
                when IDLE =>
                    if vld_i = '1' then
                        state <= FEED;
                        cycle_count := 0;
                    end if;

                when FEED =>
                    if vld_i = '1' then
                        if cycle_count < NUM_PE-2 then
                            cycle_count := cycle_count + 1;
                        else
                            state <= DRAIN;
                            cycle_count := 0;
                        end if;
                    end if;

                when DRAIN =>
                    if cycle_count < (NUM_PE*2)-2 then
                        cycle_count := cycle_count + 1;
                    else
                        cycle_count := 0;
                        state <= OUTPUT;
                    end if;

                when OUTPUT =>
                    if rdy_i = '1' then
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    fsm_comb : process(all)
    begin
        rdy_o <= '0';
        vld_o <= '0';
        clear_o <= '0';
        input_en_o <= '0';
        comp_en_o <= '0';

        case state is
            when IDLE =>
                rdy_o <= '1';
                if vld_i = '1' then
                    input_en_o <= '1';
                    comp_en_o <= '1';
                end if;

            when FEED =>
                rdy_o <= '1';
                if vld_i = '1' then
                    input_en_o <= '1';
                    comp_en_o <= '1';
                end if;

            when DRAIN =>
                comp_en_o <= '1';

            when OUTPUT =>
                vld_o <= '1';
                if rdy_i = '1' then
                    clear_o <= '1';
                end if;

            when others =>
                null;

        end case;
    end process;

end Behavioral;
