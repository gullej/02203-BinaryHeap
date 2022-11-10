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

architecture rtl of MinHeap is 
------------------------------------------------------------------------------------------------------------
-- Function for calculating pointer
------------------------------------------------------------------------------------------------------------
function pointer_calculator_1 (pointer : integer) return integer is
variable child1 : integer;
begin

    child1 := pointer*2 + 1;

return child1;
end function pointer_calculator_1;

function pointer_calculator_2 (pointer : integer) return integer is
variable child2 : integer;
begin

    child2 := pointer*2 + 2;

return child2;
end function pointer_calculator_2;
------------------------------------------------------------------------------------------------------------
-- Define signals
------------------------------------------------------------------------------------------------------------
type state_machine is (setup, idle, read, check_root, insert_root, get_child_value, check_children, one, two, done);
signal state     : state_machine := setup;
signal current   : std_logic_vector(16 - 1 downto 0);   -- current value
signal child1    : integer;                             -- location of child 1
signal child2    : integer;                             -- location of child 2
signal v_child1  : std_logic_vector(16 - 1 downto 0);   -- value of child 1
signal v_child2  : std_logic_vector(16 - 1 downto 0);   -- value of child 2
signal pointer   : integer := 0;                        -- pointer
signal flag      : std_logic;                           -- signal to indicate start & end

type reg_type is array (15 - 1 downto 0) of std_logic_vector (16 - 1 downto 0); -- 16*15 bits
signal ram : reg_type := (others => x"0000"); 

begin

process (all)
begin
    if (reset = '1') then
        state <= setup;
    elsif(rising_edge(clk)) then 

        case state is
		when setup => -- prefilling
            ReadyIn <= '0';     -- no data from outside
            ram(pointer) <= x"8000";
            pointer <= pointer + 1;
            if pointer = 14 then -- prefilling is done
                state <= idle;
            else
                state <= setup;
            end if;
        when idle =>
            if ValidIn(2) = '1' then 
                state <= read;
                ReadyIn <= '1';
            else
                ReadyIn <= '0';
            end if;
        when read =>
            ReadyIn <= '0';
            current <= DataIn;
            flag <= ValidIn(0);
            if flag = '1' then -- it's the last value
                state <= done;
            else
                state <= check_root;
            end if;
        when check_root =>
            if signed(current) > signed(ram(0)) then
                state <= insert_root;
            else
                current <= current;
                state <= idle;
            end if;
        when insert_root =>
            ram(0) <= current; -- current is bigger, perform swap
            pointer <= 0;
            child1 <= 1;
            child2 <= 2;
            state <= get_child_value;
        when get_child_value =>
            v_child1 <= ram(child1);
            v_child2 <= ram(child2);
            state <= check_children;
        when check_children =>
            if signed(v_child1) < signed(current) then -- the left is smaller
                state <= one;
            else
                if signed(v_child2) < signed(current) then 
                    state <= two;
                else
                    ReadyIn <= '1';
                    state <= read;
                end if;
            end if;    
        when one =>
            current <= current;
            ram(child1) <= current;
            ram(pointer) <= v_child1;
            if child1 < 7 then
                pointer <= child1;
                child1 <= pointer_calculator_1(child1);
                child2 <= pointer_calculator_2(child1);
                state <= get_child_value;
            else
                ReadyIn <= '1';
                state <= read;
            end if;
        when two =>
            current <= current;
            ram(child2) <= current;
            ram(pointer) <= v_child2;
            if child2 < 8 then
                pointer <= child2;
                child1 <= pointer_calculator_1(child2);
                child2 <= pointer_calculator_2(child2);
                state <= get_child_value;
            else
                ReadyIn <= '1';
                state <= read;
            end if;
        when done=>
            ReadyOut = '1';

		end if;

    end if;
end process;
end architecture;