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
-- 2 bits for block offset
-- 5 bits for cache_block addressing
-- 25 bits for TAG. 
-- (Review Report for details)

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
process (clock, reset, state, s_read, s_write, m_waitrequest)

-- declare other internal variables
variable block_count: INTEGER := 0;
variable c_address: std_logic_vector (14 downto 0); 

begin

	if (reset = '1') then
		state <= c_begin;
	elsif (rising_edge(clock)) then
	
	cache_index := to_integer(unsigned(s_addr(6 downto 2)));
	data_offset := to_integer(unsigned(s_addr(1 downto 0))); --+1 ??
	
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
			-- only write if V = 1 and tag /= address requested and dirty bit is 0
			if(cache_storage(cache_index)(154) = '1' and cache_storage(cache_index)(153 downto 129) = s_addr(31 downto 7) and cache_storage(cache_index)(128) /= '1') then
				cache_storage(cache_index)(127 downto 0)((data_offset*32)-1 downto 32*(data_offset-1)) <= s_writedata;
				s_waitrequest <= '0';
				state <= c_begin;
			else
				is_read := false;
				state <= write_back;
			end if;
			
		when c_read =>
--			if(.....) then
--				s_readdata <= cache_structure(block_index)(127 downto 0)((word_offset * 32) - 1 downto 32*(word_offset - 1));
--				m_read <= '0';
--				m_write <= '0';
--				s_waitrequest <= '0';
--				-- Reset the word counter
--				block_count := 0;
--				-- Move back to the initial state to wait for the next operation
--				state <= c_begin;
--			
--			elsif(....) then
--			
--			else
--				is_read := true;
--			
		when write_back =>
		if(cache_storage(cache_index)(154) = '1') then --  write to memory if there is an occupant
			if(m_waitrequest = '1' and block_count < 4) then
				c_address := cache_storage(cache_index)(136 downto 129) & s_addr (6 downto 0);
				m_addr <= to_integer(unsigned (c_address)) + block_count;
				m_write <= '1';
				m_read <= '0';
				-- write to memory
				m_writedata <= cache_storage(cache_index)(127 downto 0)((data_offset * 8) + 7 + 32*(data_offset - 1) downto (data_offset * 8) + 32*(data_offset - 1));
				block_count := block_count + 1;
				state <= write_back;
			elsif(block_count = 4) then
				block_count :=0;
				cache_storage(cache_index)(154) <= '0';
				cache_storage(cache_index)(128) <= '0';
				state <= write_back;	
			else
				m_write <= '0';
				state <= write_back; --wait due to m_waitrequest
			end if;	
		else
			m_addr <= to_integer(unsigned(s_addr(14 downto 0))) + block_count;
			m_read <= '1';
			m_write <= '0';
			state <= memory_read;	
		end if;
		
		when memory_read =>
			if (m_waitrequest = '0' and block_count < 4) then
				-- Read in data to cache
				cache_storage(cache_index)(127 downto 0)((data_offset * 8) + 7 + 32*(data_offset - 1) downto (data_offset * 8) + 32*(data_offset - 1)) <= m_readdata;
				block_count := block_count + 1;
				m_read <= '0';
				state <= memory_read;	
			elsif(is_read = false and block_count = 4) then
				-- Set valid bit to 1, dirty bit to 0
				cache_storage(cache_index)(154) <= '1';
				cache_storage(cache_index)(152 downto 128) <= s_addr (31 downto 7);
				cache_storage(cache_index)(128) <= '0';
				state <= c_write;
			elsif(is_read = true and block_count = 4) then
				-- Set valid bit to 1, dirty bit to 0
				cache_storage(cache_index)(154) <= '1';
				cache_storage(cache_index)(152 downto 128) <= s_addr (31 downto 7);
				cache_storage(cache_index)(128) <= '0';
				state <= c_read;
			else
				state <= memory_read; --wait due to m_waitrequest
			end if;
		
		when others =>
		NULL;
		
	end case;
	end if;

end process;
end arch;