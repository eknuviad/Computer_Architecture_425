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
--cache states
type cache_state is (c_idle, c_read, c_write, m_fetch, write_back);
signal state: cache_state;

-- | V  |  TAG   |  D  |  DATA |
-- 1bit + 25bit + 1bit + 128bits = 155
type cache_struct is
	record
		valid: std_logic;
		tag : std_logic_vector (24 downto 0);
		dirty: std_logic;
		data : std_logic_vector (127 downto 0);
	end record;
type cache_struct_array is array (31 downto 0) of cache_struct;

-- constants
constant init_block : cache_struct := (valid => '0',tag => (others => '0'),dirty => '0',data => (others => '0'));

-- signals
signal cache_storage : cache_struct_array := (others => init_block);
signal s_waitrequest_signal: std_logic := '1';
signal s_addr_signal: std_logic_vector (31 downto 0) := (others => '0');
signal s_readdata_signal: std_logic_vector (31 downto 0) := (others => '0');
signal m_addr_signal: integer := 0;
signal m_read_signal: std_logic := '0';
signal m_write_signal : std_logic := '0';
signal m_writedata_signal : std_logic_vector (7 downto 0) := (others => '0');
signal tag : std_logic_vector (24 downto 0);
signal index, offset, address, wb_address : integer;
signal byte_count : integer := 0;


begin
	-- Output to processor from cache
	s_waitrequest <= s_waitrequest_signal;
	s_readdata <= s_readdata_signal;
		
	-- Output to memory from cache
	m_addr <= m_addr_signal;
	m_read <= m_read_signal;
	m_write <= m_write_signal;
	m_writedata <= m_writedata_signal;

	process (clock, reset, state, tag, wb_address, index, offset, address, s_addr)
	
	variable cache_index : integer;
	
	begin
		cache_index := to_integer(unsigned('0' & s_addr(8 downto 4))); -- 5 bits for index
		index <= cache_index;
		offset <= to_integer(unsigned('0' & s_addr(3 downto 2))); --2 bits offset
		address <= to_integer(unsigned('0' & s_addr(31 downto 4) & "0000"));
		wb_address <= to_integer(unsigned('0' & cache_storage(cache_index).tag & s_addr(8 downto 4) & "0000"));
		
		if (reset = '1') then
			state <= c_idle;
			s_waitrequest_signal<= '0';	-- s_waitrequest is high by default, set to 0 to avoid infinite wait
		else
			if (rising_edge(clock)) then
				case state is
					when c_idle =>
						if (s_read = '1' and cache_storage(index).valid = '1' and cache_storage(index).tag = s_addr(31 downto 9)) then
							s_addr_signal<= s_addr;
							state <= c_read;
						elsif(s_write = '1' and cache_storage(index).valid = '1' and cache_storage(index).tag = s_addr(31 downto 9)) then
							s_addr_signal<= s_addr;
							state <= c_write;
						elsif (cache_storage(index).valid = '1' and cache_storage(index).dirty = '1') then
							state <= write_back;
							byte_count <= 0;
							m_addr_signal<= wb_address;
							m_writedata_signal <= cache_storage(index).data (7 downto 0);
							m_write_signal <= '1';
						else
							state <= m_fetch;
							byte_count <= 0;
							m_addr_signal<= address;
							m_read_signal<= '1';
						end if;
					
					when c_read =>
						if (s_waitrequest_signal= '1') then
							if (s_read = '1') then
								s_readdata_signal<= cache_storage(index).data (offset * 32 + 31 downto offset * 32);
							end if;
							s_waitrequest_signal<= '0';
						else
							state <= c_idle;
							s_waitrequest_signal<= '1';
						end if;
						
					when c_write =>
						if (s_waitrequest_signal= '1') then
							if(s_write = '1') then
								cache_storage(index).data (offset * 32 + 31 downto offset * 32) <= s_writedata;
								cache_storage(index).dirty <= '1';
							end if;
							s_waitrequest_signal<= '0';
						else
							state <= c_idle;
							s_waitrequest_signal<= '1';
						end if;
					
					when write_back =>
						if (m_waitrequest = '0') then
							m_write_signal <= '0';
							if (byte_count = 15) then
								state <= m_fetch;
								byte_count <= 0;
								m_addr_signal<= address;
								m_read_signal<= '1';
							end if;
						elsif (m_write_signal = '0') then
							byte_count <= byte_count + 1;
							m_addr_signal<= m_addr_signal+ 1;
							m_writedata_signal <= cache_storage(index).data ((byte_count + 1) * 8 + 7 downto (byte_count + 1) * 8);
							m_write_signal <= '1';
						end if;
						
					when m_fetch =>
						if (m_waitrequest = '0') then
							cache_storage(index).data (byte_count * 8 + 7 downto byte_count * 8) <= m_readdata;
							m_read_signal<= '0';
							if(byte_count = 15) then
								cache_storage(index).tag <= tag;
								cache_storage(index).valid <= '1';
								cache_storage(index).dirty <= '0';
								if(s_read = '1') then
									state <= c_read;
								else
									state <= c_write;
								end if;	
							end if;
						elsif (m_read_signal= '0') then
							byte_count <= byte_count + 1;
							m_addr_signal<= m_addr_signal+ 1;
							m_read_signal<= '1';
						end if;
				end case;
			end if;
		end if;
	end process;
	
end arch;