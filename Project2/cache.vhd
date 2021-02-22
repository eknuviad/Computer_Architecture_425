library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768
);
port(
	clock : in std_logic;
	reset : in std_logic;
	
	-- Avalon interface --
	s_addr : in std_logic_vector (31 downto 0);
	s_read : in std_logic;
	s_readdata : out std_logic_vector (31 downto 0);
	s_write : in std_logic;
	s_writedata : in std_logic_vector (31 downto 0);
	s_waitrequest : out std_logic; 
    
	m_addr : out integer range 0 to ram_size-1;
	m_read : out std_logic;
	m_readdata : in std_logic_vector (7 downto 0);
	m_write : out std_logic;
	m_writedata : out std_logic_vector (7 downto 0);
	m_waitrequest : in std_logic
);
end cache;

architecture arch of cache is

-- declare signals here

type t_state is (c_begin, c_write, c_read, write_back, memory_read);
signal state: t_state;

-- processor-cache addressing:
-- 4 words per block = 2 bits for offset
-- cache_data_storage_bit/block_bit :
-- = 4096/128 = 32 blocks = 5 bits for cache_block addressing
-- TAG = 32 - (2 + 5) = 25 bits


-- | V  |  TAG   |  D  |  DATA |
-- 1bit + 25bit + 1bit + 128bits
type cache_storage_def is array (0 to 31) of std_logic_vector (154 downto 0);
signal cache_storage: cache_storage_def;

shared variable is_read: boolean := false;

begin

-- make circuits here
process (clock, reset, state, s_read, s_write)

-- declare other internal variables

begin

	if (reset = '1') then
		state <= c_begin;
	elsif (rising_edge(clock)) then
	case state is
		when c_begin =>
		
		when c_write =>
		
		when c_read =>
		
		when write_back =>
		
		when memory_read =>
		
		when others =>
		NULL;
		
	end case;
	end if;

end process;
end arch;