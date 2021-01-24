library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

-- Do not modify the port map of this structure
entity comments_fsm is
port (clk : in std_logic;
      reset : in std_logic;
      input : in std_logic_vector(7 downto 0);
      output : out std_logic
  );
end comments_fsm;

architecture behavioral of comments_fsm is

-- The ASCII value for the '/', '*' and end-of-line characters
constant SLASH_CHARACTER : std_logic_vector(7 downto 0) := "00101111";
constant STAR_CHARACTER : std_logic_vector(7 downto 0) := "00101010";
constant NEW_LINE_CHARACTER : std_logic_vector(7 downto 0) := "00001010";

type t_state is (S0,S1,S2,S3,S4,S5); --enumerate states
signal state : t_state;

begin

-- Insert your processes here
process (clk, reset)

begin
	if (rising_edge(clk)) then
		if(reset = '1') then
			output <= '0';
			state <= S0;
		else
		case state is
			when S0 =>
				if(input = SLASH_CHARACTER) then
					output <='0';
					state <= S2;
				elsif(input = STAR_CHARACTER) then
					output <= '0';
					state <= S1;
				else
					output <= '0';
					state <= S0;
				end if;
					
			when S1 =>
				if(input = NEW_LINE_CHARACTER) then
					output <= '0';
					state <= S0;
				else
					output <= '0';
					state <= S1;
				end if;
					
			when S2 =>
				if(input = SLASH_CHARACTER) then
					output <= '0';
					state <= S3;
				elsif(input = STAR_CHARACTER) then
					output <= '0';
					state <= S4;
				elsif(input = NEW_LINE_CHARACTER) then
					output <= '0';
					state <= S0;
				else
					output <= '0';
					state <= S1;
				end if;
					
			when S3 =>
				if(input = NEW_LINE_CHARACTER) then
					output <= '1';
					state <= S0;
				else
					output <= '1';
					state <= S3;
				end if;
			
			when S4 =>
				if(input = STAR_CHARACTER) then
					output <= '1';
					state <= S5;
				else
					output <= '1';
					state <= S4;
				end if;
			
			when S5 =>
				if(input = SLASH_CHARACTER) then
					output <= '1';
					state <= S0;
				else
					output <= '1';
					state <= S4;
				end if;
				
			when others => 
				NULL;
	
		end case;
	end if;
end if;
   
end process;

end behavioral;