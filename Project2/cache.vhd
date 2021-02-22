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

--- V = (154) 
--- TAG = (153 down to 129)
--- D = (128) 
--- DATA = (127 downto 0)
-- | V  |  TAG   |  D  |  DATA |
-- 1bit + 25bit + 1bit + 128bits
type cache_storage_def is array (0 to 31) of std_logic_vector (154 downto 0);
signal cache_storage: cache_storage_def;

shared variable is_read: boolean := false;
shared variable cache_index: INTEGER;
shared variable data_offset: INTEGER := 0;

begin

-- make circuits here
process (clock, reset, state, s_read, s_write)

-- declare other internal variables

begin

	if (reset = '1') then
		state <= c_begin;
	elsif (rising_edge(clock)) then
	
	cache_index := to_integer(unsigned(s_addr(6 downto 2)));
	data_offset := to_integer(unsigned(s_addr(1 downto 0)));
	
	case state is
		when c_begin =>
			s_waitrequest <= '1';
			if s_read = '1' then 
				state <= c_read;
			
			elsif s_write = '1' then
				state <= c_write;
		
			else
				state <= c_begin;
			end if;

		when c_write =>
			s_waitrequest <= '1';
			if(cache_storage(cache_index)(154) = '1' and cache_storage(cache_index)(153 downto 129) = s_addr(31 downto 7) and cache_storage(cache_index)(128) /= '1') then
				cache_storage(cache_index)(127 downto 0)((data_offset*32)-1 downto 32*(data_offset-1)) <= s_writedata;
				s_waitrequest <= '0';
				state <= c_begin;
			else
				state <= write_back;
			end if;
			
		when c_read =>
		
		when write_back =>
		-- check if there is an occupant (valid = 0 or not), 
		-- if valid is 1 send to memory, change valid bit to 0, if yes send to memory and 
		-- bring back from memory reading 
		-- set valid tag to 1
		-- set dirty bit to zero
		-- switch to previous state using isread boolean
		
		when memory_read =>
		
		when others =>
		NULL;
		
	end case;
	end if;

end process;
end arch;