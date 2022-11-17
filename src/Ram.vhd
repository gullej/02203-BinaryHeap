-- Dual-Port Block RAM with Two Write Ports

-- Correct Modelization with a Shared Variable

-- File: rams_tdp_rf_rf.vhd

LIBRARY IEEE;

USE IEEE.std_logic_1164.ALL;

USE ieee.numeric_std.ALL;

ENTITY Ram IS
    generic(
        ArrayAddressSize: natural :=  4;
            -- no of elements in heap/array is 2**ArrayAddressSize - 1
        DataSize:     natural := 16;
            -- Word size for data
        IndexSize:    natural := 9
            -- Word size for index. Default identifies up to 512 inputs 
    );
    PORT (
        clka : IN STD_LOGIC;
        clkb : IN STD_LOGIC;
        ena : IN STD_LOGIC;
        enb : IN STD_LOGIC;
        wea : IN STD_LOGIC;
        web : IN STD_LOGIC;
        addra : integer;
        addrb : integer;
        dia : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        dib : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        doa : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        dob : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );

END Ram;

ARCHITECTURE syn OF Ram IS

    TYPE ram_type IS ARRAY ((ArrayAddressSize**2-1)-1 DOWNTO 0) OF STD_LOGIC_VECTOR(DataSize - 1 DOWNTO 0);

    SHARED VARIABLE RAM : ram_type;

BEGIN

    PROCESS (CLKA)
    BEGIN
        IF rising_edge(CLKA) THEN
            IF ENA = '1' THEN
                IF WEA = '1' THEN
                    RAM(ADDRA) := DIA;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    DOA <= RAM(ADDRA);

    PROCESS (CLKB)
    BEGIN
        IF rising_edge(CLKB) THEN
            IF ENB = '1' THEN
                IF WEB = '1' THEN
                    RAM(ADDRB) := DIB;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    DOB <= RAM(ADDRB);
    
END syn;