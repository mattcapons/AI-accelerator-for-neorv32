library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package systolic_pkg is

    constant NUM_PE : positive := 4; -- size of the systolic array (number of processing elements)
    
    constant DATA_WIDTH : positive := 8; -- width of the input data (activations and weights)
    constant ACC_WIDTH : positive := 32; -- width of the accumulator (output sum)

    type data_array_t is array (0 to NUM_PE-1) of signed (DATA_WIDTH-1 downto 0); -- array type for input activations and weights
    type out_array_t is array (0 to NUM_PE-1, 0 to NUM_PE-1) of signed (ACC_WIDTH-1 downto 0); -- array type for output sums

    type data_type_t is (A, W);
    
end package systolic_pkg;