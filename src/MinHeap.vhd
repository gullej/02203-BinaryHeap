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
    use IEEE.std_logic_signed.all;
    
    
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
    --    function pointer_calculator_1 (pointer : integer) return std_logic_vector is
    --        variable child1 : integer;
    --        begin
    --    
    --            child1 := pointer*2 + 1;
    --
    --        return child1;
    --    end function pointer_calculator_1;
    --    
    --    function pointer_calculator_2 (pointer : integer) return std_logic_vector is
    --        variable child2 : integer;
    --        begin
    --    
    --            child2 := pointer*2 + 2;
    --    
    --        return child2;
    --    end function pointer_calculator_2;
    
    
        component rams_tdp_rf_rf is
            port(
            clka  : in  std_logic;
            clkb  : in  std_logic;
            
            ena   : in  std_logic;
            enb   : in  std_logic;
        
            wea   : in  std_logic;
            web   : in  std_logic;
        
            addra : in  std_logic_vector(3 downto 0);
            addrb : in  std_logic_vector(3 downto 0);
        
            dia   : in  std_logic_vector(24 downto 0);
            dib   : in  std_logic_vector(24 downto 0);
        
            doa   : out std_logic_vector(24 downto 0);
            dob   : out std_logic_vector(24 downto 0)
            );
        
        end component;
    
        --States----------------------------------------------------
        type state_machine is (
                                Setup           ,
                                Idle            ,
                                Read_state      ,
                                Check_root      ,
                                Insert_root     ,
                                Get_child_value ,
                                Check_children  ,
                                Update_child1   ,
                                Update_child2   ,
                                Wait_state
                                );
    
        signal state        :   state_machine;
        signal Next_state   :   state_machine;
    
        --Pointers---------------------------------------------------
        signal Pointer_parent       :   std_logic_vector(3 downto 0);
        signal Pointer_parent_next  :   std_logic_vector(3 downto 0);
    
        signal Pointer_child1       :   std_logic_vector(3 downto 0);
        signal Pointer_child1_next  :   std_logic_vector(3 downto 0);
    
        signal Pointer_child2       :   std_logic_vector(3 downto 0);
        signal Pointer_child2_next  :   std_logic_vector(3 downto 0);
        -------------------------------------------------------------
        --Data-------------------------------------------------------
        signal data_in_reg          :   std_logic_vector(DataIn'range);
        signal data_in_reg_next     :   std_logic_vector(DataIn'range);
        signal index_in_reg         :   std_logic_vector(IndexIn'range);
        signal index_in_reg_next    :   std_logic_vector(IndexIn'range);
    
        signal child1_data_reg      :   std_logic_vector(DataIn'range);
        signal child1_data_reg_next :   std_logic_vector(DataIn'range);
        signal child1_idx_reg      :   std_logic_vector(IndexIn'range);
        signal child1_idx_reg_next :   std_logic_vector(IndexIn'range);
    
        signal child2_data_reg      :   std_logic_vector(DataIn'range);
        signal child2_data_reg_next :   std_logic_vector(DataIn'range);
        signal child2_idx_reg      :   std_logic_vector(IndexIn'range);
        signal child2_idx_reg_next :   std_logic_vector(IndexIn'range);
        -------------------------------------------------------------
        --Ram signals
        signal Write_ram_a          :   std_logic;
        signal Write_ram_b          :   std_logic;
    
        signal Addr_ram_a           :   std_logic_vector(3 downto 0);
        signal Addr_ram_b           :   std_logic_vector(3 downto 0);
    
        signal data_ram_a_i         :   std_logic_vector(24 downto 0);
        signal data_ram_b_i         :   std_logic_vector(24 downto 0);
    
        signal data_ram_a_o         :   std_logic_vector(24 downto 0);
        signal data_ram_b_o         :   std_logic_vector(24 downto 0);
        --------------------------------------------------------------
        signal done_flag            :   std_logic;
        signal done_flag_next       :   std_logic;
    
    begin
    
    
        Memory  : rams_tdp_rf_rf port map(
            clka  =>    clk,
            clkb  =>    clk,
            
            ena   =>    '1',
            enb   =>    '1',
        
            wea   =>    Write_ram_a,
            web   =>    Write_ram_b,
        
            addra =>    Addr_ram_a,
            addrb =>    Addr_ram_b,
        
            dia   =>    data_ram_a_i,
            dib   =>    data_ram_b_i,
        
            doa   =>    data_ram_a_o,
            dob   =>    data_ram_b_o
        );
    
    
    
        Registers : process( clk,reset )
        begin
            if reset = '1' then
                Pointer_parent  <=  (others => '0');
                Pointer_child1  <=  (others => '0');
                Pointer_child2  <=  (others => '0');
                state <= Setup;
            elsif rising_edge(clk) then
                state           <=  Next_state;
                Pointer_parent  <=  Pointer_parent_next;
                data_in_reg     <=  data_in_reg_next;
                done_flag       <=  done_flag_next;
                index_in_reg    <=  index_in_reg_next;
                Pointer_child1  <=  Pointer_child1_next;
                Pointer_child2  <=  Pointer_child2_next;
                child1_data_reg <=  child1_data_reg_next;
                child1_idx_reg  <=  child1_idx_reg_next;
                child2_data_reg <=  child2_data_reg_next;
                child2_idx_reg  <=  child2_idx_reg_next;
            end if;
        end process ; -- Registers
        
        Next_state_logic : process( ALL )
        begin
            case state is
                when Setup =>
                    if Pointer_parent = std_logic_vector(to_unsigned(14,Pointer_parent'length)) then
                        Next_state <= Idle;
                    end if;
                when Idle =>
                    if ValidIn(2) = '1' then
                        Next_state  <= Read_state;
                    end if;
                when Read_state =>
                    if done_flag = '1' then
                        Next_state <= Idle;--Change!!
                    else
                        Next_state <= Check_root;
                    end if;
    
                when Check_root =>
                    if data_ram_a_o(15 downto 0) < data_in_reg then
                        Next_state <= Insert_root;
                    end if;
    
                when Insert_root =>
                    Next_state <= Get_child_value;
    
                when Get_child_value =>
                    Next_state  <= Check_children;
    
                when Check_children =>
                    if data_ram_a_o(15 downto 0) <= data_ram_b_o(15 downto 0) then
                        if data_ram_a_o(15 downto 0) < data_in_reg then
                            Next_state  <=  Update_child1;
                        end if;
                    else
                        if data_ram_b_o(15 downto 0) < data_in_reg then
                            Next_state  <=  Update_child2;
                        end if;
                    end if;
    
                when Update_child1 =>
                    if unsigned(Pointer_child1) > to_unsigned(6,Pointer_child1'length) 
                    or unsigned(Pointer_child2) > to_unsigned(6,Pointer_child2'length) then
                            Next_state  <= Read_state;
                    else
                        Next_state  <= Get_child_value;
                    end if;
    
                when Update_child2 =>
                    if unsigned(Pointer_child1) > to_unsigned(6,Pointer_child1'length) 
                    or unsigned(Pointer_child2) > to_unsigned(6,Pointer_child2'length) then
                        Next_state  <= Read_state;
                    else
                        Next_state  <= Get_child_value;
                    end if;
    
                when Wait_state =>
                        --Next_state <= Read_state;
    
                when others =>
                    
            
            end case;
        end process ; -- Next_state_logic
    
        Output_logic : process( ALL )
        begin
            ReadyIn     <= '0';
            Write_ram_a <= '0';
            Write_ram_b <= '0';
            data_in_reg_next        <= data_in_reg_next;
    
            child1_data_reg_next    <= child1_data_reg_next;
            child1_idx_reg_next     <= child1_idx_reg_next;
    
            child2_data_reg_next    <= child2_data_reg_next;
            child2_idx_reg_next     <= child2_idx_reg_next;
    
            Pointer_parent_next     <= Pointer_parent_next;
            done_flag_next          <= done_flag_next;
            index_in_reg_next       <= index_in_reg_next;
    
            Pointer_child1_next     <= Pointer_child1_next;
            Pointer_child2_next     <= Pointer_child2_next;
            case state is
                when Setup =>
                    Pointer_parent_next <= Pointer_parent + 1;
                    Addr_ram_a          <= Pointer_parent;
                    data_ram_a_i        <= (24 downto 16 => '0') & x"8000";
                    Write_ram_a         <= '1';
                    Pointer_child1_next <= (others => '0');
                    Pointer_child2_next <= (others => '0');
    
                when Idle =>
                    Pointer_parent_next <= (others => '0');
                    
                when Read_state =>
                    ReadyIn <= '1';
                    data_in_reg_next    <= DataIn;
                    index_in_reg_next   <= IndexIn;
                    done_flag_next      <= ValidIn(0);
                    Addr_ram_a          <= Pointer_parent;
    
                when Check_root =>
                    Pointer_child1_next <= Pointer_child1 + Pointer_child1 + 1;
                    Pointer_child2_next <= Pointer_child2 + Pointer_child2 + 2;
    
                when Insert_root =>
                    data_ram_a_i    <=  index_in_reg_next & data_in_reg;
                    Write_ram_a     <=  '1';
                    Addr_ram_a      <=  (others => '0');
    
                when Get_child_value =>
                    Addr_ram_a  <=  Pointer_child1;
                    Addr_ram_b  <=  Pointer_child2;
    
                when Check_children =>
                    child1_data_reg_next    <=  data_ram_a_o(DataIn'range);
                    child1_idx_reg_next     <=  data_ram_a_o(24 downto 16);
                    child2_data_reg_next    <=  data_ram_b_o(DataIn'range);
                    child2_idx_reg_next     <=  data_ram_b_o(24 downto 16);
    
                when Update_child1 =>
                    Write_ram_a <= '1';
                    Write_ram_b <= '1';
                    Addr_ram_a      <= Pointer_child1;
                    data_ram_a_i    <= index_in_reg & data_in_reg;
                    Addr_ram_b      <= Pointer_parent;
                    data_ram_b_i    <= child1_idx_reg & child1_data_reg;
    
                    Pointer_parent_next <= Pointer_child1;
                    Pointer_child1_next <= Pointer_child1 + Pointer_child1 + 1;
                    Pointer_child2_next <= Pointer_child1 + Pointer_child1 + 2;
    
                    if unsigned(Pointer_child1) > to_unsigned(6,Pointer_child1'length) 
                    or unsigned(Pointer_child2) > to_unsigned(6,Pointer_child2'length) then
                        Pointer_parent_next <= (others => '0');
                        Pointer_child1_next <= (others => '0');
                        Pointer_child2_next <= (others => '0');
                    end if;
    
                when Update_child2 =>
                    Write_ram_a <= '1';
                    Write_ram_b <= '1';
                    Addr_ram_a      <= Pointer_child2;
                    data_ram_a_i    <= index_in_reg & data_in_reg;
                    Addr_ram_b      <= Pointer_parent;
                    data_ram_b_i    <= child2_idx_reg & child2_data_reg;
    
                    Pointer_parent_next <= Pointer_child2;
                    Pointer_child1_next <= Pointer_child2 + Pointer_child2 + 1;
                    Pointer_child2_next <= Pointer_child2 + Pointer_child2 + 2;
    
                    if unsigned(Pointer_child1) > to_unsigned(6,Pointer_child1'length) 
                    or unsigned(Pointer_child2) > to_unsigned(6,Pointer_child2'length) then
                        Pointer_parent_next <= (others => '0');
                        Pointer_child1_next <= (others => '0');
                        Pointer_child2_next <= (others => '0');
    
                    end if;
    
                when others =>        
            end case;
        end process ; -- Output_logic
        
    
    end architecture;