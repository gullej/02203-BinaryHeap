-- Min heap circuit. 
-- Input and output ports use streaming interfaces that follow
-- an extended valid-ready protocol (Valid[2:0], Ready)
--  Valid[2:0] = 000: not valid
--               100: valid first    
--               010: valid middle   
--               001: valid last
-- Streaming of input sequence alternate with streaming of output sequence. 
-- During input sequence ValidOut <= "000". During output sequence ReadyIn <= '0'. 
-- No. of elements in input stream is unknown. Limited to 2**IndexSize-1. Default max is 512.
-- No. of elements in heap and output sequence 2**ArrayAddressSize - 1. Default is 15.


library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;


entity MinHeap is
    generic(
        ArrayAddressSize: natural :=  4;
            -- no of elements in heap/array is 2**ArrayAddressSize - 1
        DataSize:     natural := 16;
            -- Word size for data
        IndexSize:    natural := 9
            -- Word size for index. Default identifies up to 512 inputs 
    );
    port(
    -- clock and reset
        clk:   std_logic;
        reset: std_logic;      -- Reset is synchronous and active-high
        
    -- Input port. Accepts a stream of (data,index)-tuples using the extended valid-ready protocol.              
        ValidIn:  in  std_logic_vector(2 downto 0);
        ReadyIn:  out std_logic;
        DataIn:   in  std_logic_vector(DataSize-1 downto 0);  -- Data value that undergo sorting
        IndexIn:  in  std_logic_vector(IndexSize-1 downto 0); -- Corresponding index stored along with data value
        
    -- Output Port. Produces a stream of (data,index)-tuples using the extended valid-ready protocol.
        ValidOut: out std_logic_vector(2 downto 0);
        ReadyOut: in  std_logic;
        DataOut:  out std_logic_vector(DataSize-1 downto 0);
        IndexOut: out std_logic_vector(IndexSize-1 downto 0)
    );
end MinHeap;

