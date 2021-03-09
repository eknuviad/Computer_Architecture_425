library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_tb is
end cache_tb;

architecture behavior of cache_tb is

component cache is
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
end component;

component memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    mem_delay : time := 10 ns;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    writedata: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
    address: IN INTEGER RANGE 0 TO ram_size-1;
    memwrite: IN STD_LOGIC;
    memread: IN STD_LOGIC;
    readdata: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    waitrequest: OUT STD_LOGIC
);
end component;
	
-- test signals 
signal reset : std_logic := '0';
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

signal s_addr : std_logic_vector (31 downto 0);
signal s_read : std_logic;
signal s_readdata : std_logic_vector (31 downto 0);
signal s_write : std_logic;
signal s_writedata : std_logic_vector (31 downto 0);
signal s_waitrequest : std_logic;

signal m_addr : integer range 0 to 2147483647;
signal m_read : std_logic;
signal m_readdata : std_logic_vector (7 downto 0);
signal m_write : std_logic;
signal m_writedata : std_logic_vector (7 downto 0);
signal m_waitrequest : std_logic; 

-- the following values will be used to in the following tests 
constant VAL1 : std_logic_vector (31 downto 0) := "01010101010101010101010101010101";
constant VAL2 : std_logic_vector (31 downto 0) := "00000000000000000000000000000001";
constant VAL3 : std_logic_vector (31 downto 0) := X"0F0E0D0C";	
constant VAL4 : std_logic_vector (31 downto 0) := X"FFFEFDFC"; 

begin

-- Connect the components which we instantiated above to their
-- respective signals.
dut: cache 
port map(
    clock => clk,
    reset => reset,

    s_addr => s_addr,
    s_read => s_read,
    s_readdata => s_readdata,
    s_write => s_write,
    s_writedata => s_writedata,
    s_waitrequest => s_waitrequest,

    m_addr => m_addr,
    m_read => m_read,
    m_readdata => m_readdata,
    m_write => m_write,
    m_writedata => m_writedata,
    m_waitrequest => m_waitrequest
);

MEM : memory
port map (
    clock => clk,
    writedata => m_writedata,
    address => m_addr,
    memwrite => m_write,
    memread => m_read,
    readdata => m_readdata,
    waitrequest => m_waitrequest
);
				

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
begin



-- TEST1:  

REPORT "TEST 1: Write Miss and Read Hit"; --write- clean miss invalid, read -clean hit valid

s_addr <= (others => '0'); -- address 0000...00
s_writedata <= VAL1; -- write know data to cache and main memory
s_write <= '1'; 
s_read <= '0'; -- write not read
wait until rising_edge(s_waitrequest);
s_write <= '0'; 
s_read <= '1'; -- now read
wait until rising_edge(s_waitrequest);
assert s_readdata = VAL1 report "Unsuccessful Write" severity error;

REPORT "End of Test 1";


-- Test 2
REPORT "TEST 2: Write Hit and Read Hit"; --write: clean, hit, valid, read: dirty, hit, valid

s_writedata <= VAL2; -- write know data to cache and main memory
s_write <=  '1'; 
s_read <= '0'; -- write not read
wait until rising_edge(s_waitrequest);
s_write <= '0'; 
s_read <= '1'; -- now read
wait until rising_edge(s_waitrequest);
assert s_readdata = VAL2 report "TEST 2 FAILED" severity error;

REPORT "END OF TEST 2";

----Test 3
REPORT "TEST 3: Read Miss (at offset) + Writeback"; -- read: dirty, miss, valid, read: clean, miss, valid

s_addr <= "00000000000000000000001000001111"; -- address with different tag, same index to trigger writeback
s_write <=  '0'; s_read <= '1'; -- read
wait until rising_edge(s_waitrequest);
assert s_readdata = VAL3 report "TEST 3 FAILED on READ MISS 1" severity error; -- data should be read from 0...01000001111
-- block in line 0 should be recently read block; now read from address 0 again to test writeback success
s_addr <= (others => '0');
s_write <= '0'; s_read <= '1'; -- read
wait until rising_edge(s_waitrequest);
assert s_readdata = VAL2 report "TEST 3 FAILED on READ MISS 2" severity error;	-- should read old value fetched from memory

REPORT "END OF Test3";

---- Test 4
REPORT "TEST 4: Write/Read at different index"; --read: clean, miss, invalid, write: clean, valid, hit, read: dirty, valid, miss
-- verify read is correct for different index and offset
s_addr <= "00000000000000000000001111111111";
s_write <=  '0'; s_read <= '1'; -- read
wait until rising_edge(s_waitrequest);
assert s_readdata = VAL4 report "TEST 4 FAILED on READ" severity error;
s_writedata <= VAL1;
s_write <=  '1'; s_read <= '0'; -- write
wait until rising_edge(s_waitrequest);
-- verify correctly written data at offset with read
s_write <=  '0'; s_read <= '1'; -- read
wait until rising_edge(s_waitrequest);
assert s_readdata = VAL1 report "TEST 4 FAILED on WRITE" severity error;

REPORT "END OF Test 4";


--- Test 5
REPORT "TEST 5: Write Miss (at offset) + Writeback"; --write: clean, miss, valid, write: dirty, hit, valid

s_addr <= "00000000000000000000001000001111"; -- address with different tag, same index to trigger writeback
s_writedata <= VAL3; 
s_write <=  '1'; s_read <= '0'; -- write
wait until rising_edge(s_waitrequest);
s_write <= '0'; 
s_read <= '1'; -- now read
assert s_readdata = VAL3 report "TEST 5 FAILED on READ MISS 1" severity error;
s_writedata <= VAL4; 
s_write <= '1'; s_read <= '0'; -- read
wait until rising_edge(s_waitrequest);
s_write <= '0'; 
s_read <= '1'; -- now read
assert s_readdata = VAL4 report "TEST 5 FAILED on READ MISS 2" severity error;	

REPORT "END OF Test5";

REPORT "TESTS COMPLETE" severity failure;

wait;


	
end process;
	
end;