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


-- Note: s_waitrequest asserted by default

-- Read procedure
-- 1. When s_read is high, cache reads s_addr and locates associated block (direct-mapped)
-- 2. Cache checks if block is valid and tag matches. if not (miss), c_fetch correct one
-- 3. Cache sets s_readdata to requested word
-- 4. Cache deasserts s_waitrequest for an entire clock cycle, then reasserts it

-- Write procedure
-- 1. When s_write is high, cache reads s_addr and locates associated block (direct-mapped)
-- 2. Cache checks if block is valid and tag matches. If not (miss), c_fetch correct one
-- 3. Caches writes word to correct offset in block, dirty bit set to 1
-- 4. Cache deasserts s_waitrequest for an entire clock cycle, then reasserts it

-- Block c_fetching procedure
-- 1. If block to replace in cache is valid and dirty, first perform write_back
-- 2. Cache sets m_addr to first word in block and asserts s_read
--	3. Cache waits for next rising edge of m_waitrequest, then copies m_readdata to word in block
--	4. Above two steps repeated for other three words in block
--	5. Cache sets block's valid bit to 1 and dirty bit to 0

-- write_back procedure
--	1. Cache sets m_addr to address of word of block and m_writedata to first word of block, then asserts m_write
--	2. Caches waits for next rising edge of m_waitrequest
--	3. Above two steps repeated for other three words in block


architecture arch of cache is

--cache states
type cache_state is (c_idle, c_fetch, write_back, read_write);
signal state: cache_state;

-- types

-- | V  |  TAG   |  D  |  DATA |
-- 1bit + 25bit + 1bit + 128bits
type cache_struct is
	record
		valid: std_logic;
		tag : std_logic_vector (22 downto 0);
		dirty: std_logic;
		data : std_logic_vector (127 downto 0);
	end record;
type cache_struct_array is array (31 downto 0) of cache_struct;

-- constants
constant init_block : cache_struct := (valid => '0',tag => (others => '0'),dirty => '0',data => (others => '0'));

-- signals
signal cache_storage : cache_struct_array := (others => init_block);



--type cache_storage_def is array (0 to 31) of std_logic_vector (154 downto 0);
--signal cache_storage: cache_storage_def;

signal s_waitrequest_reg : std_logic := '1';
signal s_addr_reg : std_logic_vector (31 downto 0) := (others => '0');
signal s_readdata_reg : std_logic_vector (31 downto 0) := (others => '0');
signal m_addr_reg : integer := 0;
signal m_read_reg : std_logic := '0';
signal m_write_reg : std_logic := '0';
signal m_writedata_reg : std_logic_vector (7 downto 0) := (others => '0');

signal tag : std_logic_vector (22 downto 0);
signal index, offset, addr_int, wb_addr_int : integer;

signal byte_count : integer := 0;


begin
	
	-- Output to processor
	s_waitrequest <= s_waitrequest_reg;
	s_readdata <= s_readdata_reg;
		
	-- Output to cache_storageory
	m_addr <= m_addr_reg;
	m_read <= m_read_reg;
	m_write <= m_write_reg;
	m_writedata <= m_writedata_reg;

	

	-- clock and reset sensitive process
	process (clock, reset, state, tag, index, offset, addr_int, wb_addr_int, s_addr)
	

	variable index_v : integer;
	
	begin
		
		index_v := to_integer(unsigned('0' & s_addr(8 downto 4)));
		index <= index_v;
		offset <= to_integer(unsigned('0' & s_addr(3 downto 2)));
		addr_int <= to_integer(unsigned('0' & s_addr(31 downto 4) & "0000"));
		wb_addr_int <= to_integer(unsigned('0' & cache_storage(index_v).tag & s_addr(8 downto 4) & "0000"));
		
		
		if (reset = '1') then
			state <= c_idle;
			s_waitrequest_reg <= '0';	-- wait_request set to 0 to prevent master from waiting forever if reset during request
		else
			if (clock'event and clock = '1') then
				case state is
					when c_idle =>
						if (s_read = '1' or s_write = '1') then
							s_addr_reg <= s_addr;
							if (cache_storage(index).valid = '1' and cache_storage(index).tag = s_addr(31 downto 9)) then
								state <= read_write;
							elsif (cache_storage(index).valid = '1' and cache_storage(index).dirty = '1') then
								state <= write_back;
								byte_count <= 0;
								m_addr_reg <= wb_addr_int;
								m_writedata_reg <= cache_storage(index).data (7 downto 0);
								m_write_reg <= '1';
							else
								state <= c_fetch;
								byte_count <= 0;
								m_addr_reg <= addr_int;
								m_read_reg <= '1';
							end if;
						end if;
						
					when write_back =>
						if (m_waitrequest = '0') then
							m_write_reg <= '0';
							if (byte_count = 15) then
								state <= c_fetch;
								byte_count <= 0;
								m_addr_reg <= addr_int;
								m_read_reg <= '1';
							end if;
						elsif (m_write_reg = '0') then
							byte_count <= byte_count + 1;
							m_addr_reg <= m_addr_reg + 1;
							m_writedata_reg <= cache_storage(index).data ((byte_count + 1) * 8 + 7 downto (byte_count + 1) * 8);
							m_write_reg <= '1';
						end if;
						
					when c_fetch =>
						if (m_waitrequest = '0') then
							cache_storage(index).data (byte_count * 8 + 7 downto byte_count * 8) <= m_readdata;
							m_read_reg <= '0';
							if (byte_count = 15) then
								state <= read_write;
								cache_storage(index).tag <= tag;
								cache_storage(index).valid <= '1';
								cache_storage(index).dirty <= '0';
							end if;
						elsif (m_read_reg = '0') then
							byte_count <= byte_count + 1;
							m_addr_reg <= m_addr_reg + 1;
							m_read_reg <= '1';
						end if;
						
					when read_write =>
						if (s_waitrequest_reg = '1') then
							if (s_read = '1') then
								s_readdata_reg <= cache_storage(index).data (offset * 32 + 31 downto offset * 32);
							elsif (s_write = '1') then
								cache_storage(index).data (offset * 32 + 31 downto offset * 32) <= s_writedata;
								cache_storage(index).dirty <= '1';
							end if;
							s_waitrequest_reg <= '0';
						else
							state <= c_idle;
							s_waitrequest_reg <= '1';
						end if;
						
				end case;
			end if;
		end if;
	end process;
	
end arch;