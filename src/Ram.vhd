library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity Ram is
port(
    clk_ram    	: in  std_logic;
    cs_ram      : in  std_logic;
    read_ram    : in  std_logic;
    write_ram   : in  std_logic;
    write_addr  : in  std_logic_vector(15 - 1 downto 0);
    read_addr   : in  std_logic_vector(15 - 1 downto 0);
    wrdata  	: in  std_logic_vector (7 - 1 downto 0);
    rddata  	: out std_logic_vector (7 - 1 downto 0)
	);
end Ram;

architecture rtl of Ram is

type reg_type is array (16 - 1 downto 0) of std_logic_vector (15 - 1 downto 0); -- 15*16 bits
signal reg : reg_type := (others => x"0000");

begin

process (clk_ram)
begin
    if (clk_ram'event and clk_ram = '1') then
        if (cs_ram = '0' and read_ram = '1') then -- read data out of ram
			rddata <= reg(to_integer(unsigned(read_addr)));
        end if;
        if (cs_ram = '0' and write_ram = '1') then -- write data into ram
			reg(to_integer(unsigned(write_addr))) <= wrdata;
        end if;
    end if;
end process;     
end architecture;