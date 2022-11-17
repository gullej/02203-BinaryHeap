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

    component RAM IS
    --generic(
    --    ArrayAddressSize: natural;
    --        -- no of elements in heap/array is 2**ArrayAddressSize - 1
    --    DataSize:     natural;
    --        -- Word size for data
    --    IndexSize:    natural
    --        -- Word size for index. Default identifies up to 512 inputs 
    --);
    PORT (
        clka : IN STD_LOGIC;
        clkb : IN STD_LOGIC;
        ena : IN STD_LOGIC;
        enb : IN STD_LOGIC;
        wea : IN STD_LOGIC;
        web : IN STD_LOGIC;
        addra : IN integer;
        addrb : IN integer;
        dia : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        dib : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        doa : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        dob : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
    end component;
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
type state_machine is (setup, idle, read, check_root, insert_root, 
                        get_child_value, check_children, one, two, done);
signal state, next_state             : state_machine;
signal root, next_root               : std_logic_vector(DataSize - 1 downto 0);
signal current, next_current         : std_logic_vector(DataSize - 1 downto 0); -- current value
signal child1, next_child1           : integer;                                 -- location of child 1
signal child2, next_child2           : integer;                                 -- location of child 2
signal v_child1, next_v_child1       : std_logic_vector(DataSize - 1 downto 0); -- value of child 1
signal v_child2, next_v_child2       : std_logic_vector(DataSize - 1 downto 0); -- value of child 2
signal pointer, next_pointer         : integer := 0;                            -- pointer
signal flag, next_flag, next_ReadyIn : std_logic;                               -- signal to indicate start & end
signal next_ValidOut                 : std_logic_vector(2 downto 0);

signal ena, next_ena, enb, next_enb  : STD_LOGIC;
signal wea, next_wea, web, next_web  : STD_LOGIC;
signal addra, next_addra             : integer;
signal addrb, next_addrb             : integer;
signal dia, next_dia, dib, next_dib  : STD_LOGIC_VECTOR(15 DOWNTO 0);
signal doa, next_doa, dob, next_dob  : STD_LOGIC_VECTOR(15 DOWNTO 0);

--type reg_type is array ((2**ArrayAddressSize - 1) - 1 downto 0) of std_logic_vector (DataSize - 1 downto 0); -- 16*15 bits
--signal ram : reg_type := (others => x"0000"); 

begin

    memory : Ram PORT MAP(clka => clk,
                                  clkb => clk,
                                  ena => ena,
                                  enb => enb,
                                  wea => wea,
                                  web => web,
                                  addra => addra,
                                  addrb => addrb,
                                  dia => dia,
                                  dib => dib,
                                  doa => doa,
                                  dob => dob);

process(all)
begin
    if (reset = '1') then
        state <= setup;
        root <= (others => '0');
        pointer <= 0;
        child1 <= 0;
        child2 <= 0;
        next_v_child1 <= (others => '0');
        next_v_child2 <= (others => '0');
        current <= (others => '0');
        ReadyIn <= '0';
        ena <= '0';
        enb <= '0';
        wea <= '0';
        web <= '0';
        addra <=  0;   
        addrb <=  0;   
        dia <= (others => '0');
        dib <= (others => '0');
        doa <= (others => '0');
        dob <= (others => '0');
    elsif(rising_edge(clk)) then 
        state <= next_state;
        root <= next_root;
        pointer <= next_pointer;
        child1 <= next_child1;
        child2 <= next_child2;
        next_v_child1 <= v_child1;
        next_v_child2 <= v_child2;
        current <= next_current;
        ReadyIn <= next_ReadyIn;
        ValidOut <= next_ValidOut;
        ena <= next_ena;
        enb <= next_enb;
        wea <= next_wea;
        web <= next_web;
        addra <= next_addra;          
        addrb <= next_addrb;          
        dia <= next_dia;
        dib <= next_dib;
        doa <= next_doa;
        dob <= next_dob;
    end if;
end process;

process (all)
begin
    next_addra <= 0;
    next_dia <= (others => '0');
    next_ena <= '0';
    next_wea <= '0';
    next_addrb <= 0;
    next_dib <= (others => '0');
    next_enb <= '0';
    next_web <= '0';
    case state is
		when setup => -- prefilling
            next_ReadyIn <= '0';     -- no data from outside
            next_addra <= pointer;
            next_dia <= x"8000";
            next_ena <= '1';
            next_wea <= '1';
            next_pointer <= pointer + 1;
            if pointer = 14 then -- prefilling is done
                next_state <= idle;
            else
                next_state <= setup;
            end if;
        when idle =>
            if ValidIn(2) = '1' then 
                next_state <= read;
                next_ReadyIn <= '1';
            else
                next_ReadyIn <= '0';
            end if;
        when read =>
            next_ReadyIn <= '0';
            next_current <= DataIn;
            next_flag <= ValidIn(0);
            next_root <= doa;
            next_addra <= 0;
            next_ena <= '1';
            next_wea <= '0';
            if flag = '1' then -- it's the last value
                next_state <= done;
            else
                next_state <= check_root;
            end if;
        when check_root =>
            if signed(current) > signed(root) then
                next_state <= insert_root;
            else
                next_current <= current;
                next_state <= read;
            end if;
        when insert_root =>
            next_addra <= 0;
            next_dia <= current;
            next_ena <= '1';
            next_wea <= '1';
            next_pointer <= 0;
            next_child1 <= 1;
            next_child2 <= 2;
            next_state <= get_child_value;
        when get_child_value =>
            next_v_child1 <= doa;
            next_addra <= child1;
            next_ena <= '1';
            next_wea <= '0';
            next_v_child2 <= dob;
            next_addra <= child2;
            next_ena <= '1';
            next_wea <= '0';
            next_state <= check_children;
        when check_children =>
            if signed(v_child1) <= signed(v_child2) then -- the left is smaller
                if signed(v_child1) < signed(current) then 
                    next_state <= one;
                else
                    next_ReadyIn <= '1';
                    next_state <= read;
                end if;
            else
                if signed(v_child2) < signed(current) then 
                    next_state <= two;
                else
                    next_ReadyIn <= '1';
                    next_state <= read;
                end if;
            end if;    
        when one =>
            next_current <= current;
            --ram(child1) <= current;
            next_addra <= child1;
            next_dia <= current;
            next_ena <= '1';
            next_wea <= '1';
            --ram(pointer) <= v_child1;
            next_addrb <= pointer;
            next_dib <= v_child1;
            next_enb <= '1';
            next_web <= '1';
            if child1 < 7 then
                next_pointer <= child1;
                next_child1 <= pointer_calculator_1(child1);
                next_child2 <= pointer_calculator_2(child1);
                next_state <= get_child_value;
            else
                next_ReadyIn <= '1';
                next_state <= read;
            end if;
        when two =>
            next_current <= current;
            --ram(child2) <= current;
            next_addra <= child2;
            next_dia <= current;
            next_ena <= '1';
            next_wea <= '1';
            --ram(pointer) <= v_child2;
            next_addrb <= pointer;
            next_dib <= current;
            next_enb <= '1';
            next_web <= '1';
            if child2 < 8 then
                next_pointer <= child2;
                next_child1 <= pointer_calculator_1(child2);
                next_child2 <= pointer_calculator_2(child2);
                next_state <= get_child_value;
            else
                next_ReadyIn <= '1';
                next_state <= read;
            end if;
        when done =>
            next_ValidOut <= "100";
        end case;
		
end process;
end architecture;