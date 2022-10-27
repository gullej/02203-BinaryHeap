-- -----------------------------------------------------------------------------
--
--  Title      :  Testbench for Minheap
--             :
--  Developers :  Jens Sparsoe¸ 
--             :
--  Purpose    :  
--             :
--  Revision   :  Incomplete draft. 
--
-- -----------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity MinHeap_tb is
    generic( ArrayAddressSize: natural :=  4;
               -- no of elements in heap/array is 2**ArrayAddressSize - 1
              DataSize:     natural := 16;
                -- Word size for data
              IndexSize:    natural := 9
               -- Word size for index. Default identifies up to 512 inputs 
          );
end MinHeap_tb;

architecture behaviour of MinHeap_tb is

    component MinHeap is
 --       generic(
 --             ArrayAddressSize: natural :=  4;
 --              -- no of elements in heap/array is 2**ArrayAddressSize - 1
 --             DataSize:     natural := 16;
 --               -- Word size for data
 --             IndexSize:    natural := 9
 --              -- Word size for index. Default identifies up to 512 inputs 
 --       );  
        port(
            -- clock and reset
            clk:   in std_logic;
            reset: in std_logic;      -- Reset is synchronous and active-high

            -- Stream of (data,index)-tuples to MinHeap. Uses the extended valid-ready protocol.              
            ValidIn:  in std_logic_vector(2 downto 0);
            ReadyIn:  out  std_logic;
            DataIn:   in std_logic_vector(DataSize-1 downto 0);  -- Data value that undergo sorting
            IndexIn:  in std_logic_vector(IndexSize-1 downto 0); -- Corresponding index stored along with data value

            -- Output stream from MinHeap. (data,index)-tuples. Uses the extended valid-ready protocol.
            ValidOut: out std_logic_vector(2 downto 0);
            ReadyOut: in  std_logic;
            DataOut:  out std_logic_vector(DataSize-1 downto 0);
            IndexOut: out std_logic_vector(IndexSize-1 downto 0)
        );
    end component;

    -- define signals corresponding to component/entity ports
    signal clk:      std_logic;
    signal reset:    std_logic;
    signal ValidIn:  std_logic_vector(2 downto 0);
    signal ReadyIn:  std_logic;
    signal DataIn:   std_logic_vector(DataSize-1 downto 0);
    signal IndexIn:  std_logic_vector(IndexSize-1 downto 0);
    signal ValidOut: std_logic_vector(2 downto 0);
    signal ReadyOut: std_logic;
    signal DataOut:  std_logic_vector(DataSize-1 downto 0);
    signal IndexOut: std_logic_vector(IndexSize-1 downto 0);

    -- state machine to drive input port.
    type StateType is (init, input, done);
    signal state, state_next: StateType;

    -- InputTuple
    type InputTuple is record
        Valid: std_logic_vector(2 downto 0); -- 000: not valid, 001 validFirst
        Index: natural;  -- we use  9 bits
        Data:  integer;   -- we use 16 bits
    end record;

    type InputSequenceType is array (0 to 16) of InputTuple;
    constant InputVectorArray : InputSequenceType :=  (
         0  => ("100",  0,  1),  -- 01
         1  => ("010",  1,  8),  -- o8
         2  => ("010",  2, 11),  -- 1b
         3  => ("010",  3, 16),  -- 10
         4  => ("010",  4,  9),  --  9
         5  => ("010",  5, 20),  -- 14
         6  => ("010",  6, 21),  -- 15
         7  => ("010",  7, 22),  -- 16
         8  => ("010",  8, 23),  -- 17
         9  => ("010",  9, 34),  -- 22
        10  => ("010", 10, 22),  -- 16
        11  => ("010", 11,  8),  -- 08
        12  => ("010", 12, 77),  -- 4d
        13  => ("010", 13, 43),  -- 2b
        14  => ("010", 14, 17),  -- 11
        15  => ("001", 15,  6),  -- 06
        16  => ("000",  0,  0));
 
    signal VectorIndex, VectorIndex_next: integer := 0;

begin

-- instantiate dut
dut: MinHeap port map(
        clk => clk, reset => reset,
        ValidIn  => ValidIn,  ReadyIn  => ReadyIn,  DataIn  => DataIn,  IndexIn  => IndexIn,
        ValidOut => ValidOut, ReadyOut => ReadyOut, DataOut => DataOut, IndexOut => IndexOut   );

-- clock with period of 10 ns
process
begin
    clk <= '1'; wait for 5 ns;
    clk <= '0'; wait for 5 ns;
end process;

-- reset
reset <= '1' after 0 ns, '0' after 12 ns;

-- FSM: state-register and VectorIndex
process (clk,reset)
begin
    if (reset = '1') then
        State <= init;
    elsif rising_edge(clk) then
          State <= State_next;
          VectorIndex <= VectorIndex_next;
    end if;
end process;

-- FSM: CL that drive input test vectors 
process(all)
begin
State_next <= State;
VectorIndex_next <= VectorIndex;
    case State is
        when init =>
            ValidIn  <= (others => '0');
            DataIn   <= (others => '0');
            IndexIn  <= (others => '0');
            if reset = '0' then
                State_next <= input;
            else
                State_next <= init;
            end if;
        when input =>
            ValidIn <=                              InputVectorArray(VectorIndex).valid;
            DataIn  <=   std_logic_vector(to_signed(InputVectorArray(VectorIndex).Data,16));
            IndexIn <= std_logic_vector(to_unsigned(InputVectorArray(VectorIndex).Index,9));
            if (ReadyIn = '1') then
                VectorIndex_next <= VectorIndex + 1;
            end if;
            if (ValidIn = "000") then
                State_next <= done;
            else
                State_next <= input;
            end if;
        when done =>
            ValidIn  <= (others => '0');
            DataIn   <= (others => '0');
            IndexIn  <= (others => '0');
    end case;
end process;
end architecture;
