library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.systolic_pkg.all;

entity systolic_controller is
    port (
        a_buff_i : in  byte_array_t(0 to NUM_PE-1);
        w_buff_i : in  byte_array_t(0 to NUM_PE-1);
        clear__result_i : in  std_logic;
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        start_i : in  std_logic;
        a_feed_o : out  byte_array_t(0 to NUM_PE-1);
        done_o : out  std_logic
    );
end systolic_controller;