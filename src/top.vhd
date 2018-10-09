--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library machxo2;
use machxo2.all;


ENTITY top IS
   PORT (
        -- FTDI Channel A, used normally as JTAG/MPSSE
		--ADBUS0         		: IN std_logic;   -- ADBUS0 M_TCK
		--ADBUS1	       		: OUT std_logic;   -- ADBUS1 M_TDI
		--M_TDO         		: OUT std_logic;  -- ADBUS2
		--M_TMS         		: IN std_logic;   -- ADBUS3
	    --CLK	 		    	: IN std_logic;
		
		SCAN_OUT			: OUT std_logic_vector(9 downto 0);
		SCAN_IN		    	: IN std_logic_vector(7 downto 0);
		
		
		KEY_RESTORE	    	: IN std_logic;
		
		LED_R0           	: OUT std_logic;
		LED_G0           	: OUT std_logic;
		LED_B0           	: OUT std_logic;
		
		LED_R1           	: OUT std_logic;
		LED_G1           	: OUT std_logic;
		LED_B1           	: OUT std_logic;
		
		LED_R2           	: OUT std_logic;
		LED_G2           	: OUT std_logic;
		LED_B2           	: OUT std_logic;
		
		LED_R3           	: OUT std_logic;
		LED_G3           	: OUT std_logic;
		LED_B3           	: OUT std_logic;

		LED_SHIFT           : OUT std_logic;
		LED_CAPS            : OUT std_logic
      );
END ENTITY top;
--
ARCHITECTURE translated OF top IS

	--GENERIC (NOM_FREQ: string := "24.18");
	
COMPONENT OSCH
	-- synthesis translate_off
	GENERIC (NOM_FREQ: string := "12.09");
	-- synthesis translate_on
	PORT ( STDBY :IN std_logic;
	OSC :OUT std_logic;
	SEDSTDBY :OUT std_logic);
END COMPONENT OSCH;

attribute NOM_FREQ : string;

--attribute NOM_FREQ of OSCinst0 : label is "24.18";
attribute NOM_FREQ of OSCinst0 : label is "12.09";


signal osc_clk: std_logic;
signal clk: std_logic;
signal cnt: std_logic_vector(31 downto 0);

signal LED_Blink: std_logic;




BEGIN

	LED_SHIFT 		<= cnt(22);
	LED_CAPS  		<= cnt(23);
	SCAN_OUT 		<= "0000000000";


	LED_R0		    <= SCAN_IN(0);
	LED_G0		    <= SCAN_IN(1);
	LED_B0		    <= SCAN_IN(2);
	
	LED_R1		    <= SCAN_IN(3);
	LED_G1		    <= SCAN_IN(4);
	LED_B1		    <= SCAN_IN(5);
	
	LED_R2		    <= SCAN_IN(6);
	LED_G2		    <= SCAN_IN(7);
	LED_B2		    <= '1';

	LED_R3		    <= KEY_RESTORE;
	LED_G3		    <= KEY_RESTORE;
	LED_B3		    <= KEY_RESTORE;
		
	
	clk <= osc_clk;
	
OSCInst0: OSCH
		-- synthesis translate_off
		GENERIC MAP ( NOM_FREQ => "12.09" )
		
		-- synthesis translate_on
		PORT MAP (STDBY=> '0', OSC=> osc_clk, SEDSTDBY=> open);

process(clk)
begin
	if (rising_edge(clk)) then
			cnt <= cnt + X"00000001";
	end if;
end process;



END ARCHITECTURE translated;