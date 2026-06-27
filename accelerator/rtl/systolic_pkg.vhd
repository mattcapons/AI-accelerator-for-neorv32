library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package systolic_pkg is
    type byte_array_t is array (natural range <>) of std_logic_vector (7 downto 0);
    type row_t is array (natural range <>) of std_logic_vector (31 downto 0);
    type out_array_t is array (natural range <>) of row_t;
end systolic_pkg;