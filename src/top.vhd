--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library machxo2;
use machxo2.all;


ENTITY top IS
  PORT (
    -- JTAG / Xilinx main FPGA communications channel
    -- We can't easily figure out how to make these GPIOs safely, so we will
    -- switch instead to a 3-wire protocol on KIO8 -- KIO10.
    TDO         		: OUT std_logic := '1';
    TDI         		: IN std_logic;
    TMS         		: IN std_logic; 
    TCK	 		    	: IN std_logic;

    KIO8 : out std_logic := '0';
    KIO9 : out std_logic := '0';
    KIO10 : out std_logic := '0';
    
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
  signal cnt: unsigned(31 downto 0) := x"00000000";
  
  signal LED_Blink: std_logic;

  signal last_KIO8 : std_logic := '0';
  signal bit_number : integer range 0 to 255 := 0;
  
  -- The data we are currently shifting in or out serially
  signal serial_data_in : unsigned(127 downto 0) := x"000000000000000000000000FF0000FF";
  signal serial_data_out : std_logic_vector(71 downto 0) := (others => '1');

  signal scan_phase : integer range 0 to 15 := 0;
  signal scan_out_internal : std_logic_vector(9 downto 0) := "0000000001";
  -- 0 = key down, 1 = key not pressed
  signal mega65_ordered_matrix : std_logic_vector(71 downto 0) := (others => '1');
  -- Then the three keys that have their own dedicated lines
  -- We have enough pins to give them their own dedicated pins, so we will.
  signal key_left_internal : std_logic := '1';
  signal key_up_internal : std_logic := '1';
  signal key_restore_internal : std_logic := '1';  

  -- Track state of shift lock and caps lock keys locally
  -- (Again, 1 = not active, 0 = active)
  signal caps_lock : std_logic := '0';
  signal shift_lock  : std_logic := '0';
  signal last_caps_lock : std_logic_vector(7 downto 0);
  signal last_shift_lock  : std_logic_vector(7 downto 0);

  -- Info we read from the MEGA65.
  -- 4x RGB leds with 8-bit brightness for each channel.
  -- (With a 12MHz clock, 8 bit values = 12MHz/256 = 50KHz blink rate, which
  -- should be ok).  4x3x8=96 bits
  -- We'll make it 128 bits for simplicity, and a bit of expansion.
  -- (The caps lock and shift lock LEDs are driven locally by us, so we don't
  -- need to have data for those.)
  signal mega65_control_data : unsigned(127 downto 0);

  signal tms_count : unsigned(7 downto 0) := x"00";  
  signal loop_count : unsigned(7 downto 0) := x"00";  

BEGIN
  
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

      last_KIO8 <= KIO8;

      if KIO8='0' then
        clock_duration <= 0;
      else
        if clock_duration < 31 then
          clock_duration <= clock_duration + 1;
        end if;
      end if;
      
      if clock_duration = 31 then
        tms_count <= tms_count + 1;
        serial_data_out <= mega65_ordered_matrix;
        bit_number <= 0;
      else
        if last_KIO8 = '0' and KIO8 = '1' then
         -- Latch data on rising edge
          if bit_number /= 255 then
            bit_number <= bit_number + 1;
          end if;
          serial_data_in(127 downto 1) <= serial_data_in(126 downto 0);
          serial_data_in(0) <= KIO9;
          if bit_number = 128 then
            -- We have 128 bits of data, so latch the whole thing
            mega65_control_data <= serial_data_in;
          end if;

          -- And push matrix data out
          serial_data_out(70 downto 0) <= serial_data_out(71 downto 1);
          serial_data_out(71) <= '1';
          KIO10 <= serial_data_out(0);        
        end if;
      end if;

      -- Update PWM LED outputs
      if to_integer(cnt(7 downto 0)) = 0 then
        loop_count <= loop_count + 1;
        
        LED_SHIFT <= shift_lock;
        LED_CAPS <= caps_lock;
        LED_R0 <= '1';
        LED_G0 <= '1';
        LED_B0 <= '1';
        LED_R1 <= '1';
        LED_G1 <= '1';
        LED_B1 <= '1';
        LED_R2 <= '1';
        LED_G2 <= '1';
        LED_B2 <= '1';
        LED_R3 <= '1';
        LED_G3 <= '1';
        LED_B3 <= '1';
      else
--        if cnt(7 downto 0) = mega65_control_data(7 downto 0) then
        if cnt(7 downto 0) = tms_count then
          LED_R0 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(15 downto 8) then
          LED_G0 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(23 downto 16) then
          LED_B0 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(31 downto 24) then
          LED_R1 <= '0';
        end if;
--        if cnt(7 downto 0) = mega65_control_data(39 downto 32) then
        if cnt(7 downto 0) = loop_count then
          LED_G1 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(47 downto 40) then
          LED_B1 <= '0';
        end if;
--        if cnt(7 downto 0) = mega65_control_data(55 downto 48) then
        if clock_duration = 31 then
          LED_R2 <= '0';
        end if;
--        if cnt(7 downto 0) = mega65_control_data(63 downto 56) then
        if clock_duration /= 31 then
          LED_G2 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(71 downto 64) then
          LED_B2 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(79 downto 72) then
          LED_R3 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(87 downto 80) then
          LED_G3 <= '0';
        end if;
        if cnt(7 downto 0) = mega65_control_data(95 downto 88) then
          LED_B3 <= '0';
        end if;
      end if;
      
      -- Scan keyboard
      if cnt(4 downto 0) = "00000" then
        -- Rotate through scan sequence
        if scan_phase < 9 then
          scan_phase <= scan_phase + 1;
          SCAN_OUT(9 downto 1) <= scan_out_internal(8 downto 0);
          SCAN_OUT(0) <= scan_out_internal(9);
          scan_out_internal(9 downto 1) <= scan_out_internal(8 downto 0);
          scan_out_internal(0) <= scan_out_internal(9);
        else
          scan_phase <= 0;
          SCAN_OUT <= "1111111110";
          scan_out_internal <= "1111111110";
        end if;        
      end if;
      if cnt(4 downto 0) = "10000" then
        -- Read scan row after allowing time to settle.
        -- We place the scanned keys directly into the MEGA65
        -- matrix layout, so that we can easily clock it out
        -- without further fiddling.
--        shift_lock <= shift_lock and SCAN_IN(0);
        case scan_phase is
          when 0 =>
            mega65_ordered_matrix(7 downto 0) <= SCAN_IN;
            null;
          when 1 =>
            mega65_ordered_matrix(15 downto 8) <= SCAN_IN;
            null;
          when 2 =>
            mega65_ordered_matrix(23 downto 16) <= SCAN_IN;
            null;
          when 3 =>
            mega65_ordered_matrix(31 downto 24) <= SCAN_IN;
            null;
          when 4 =>
            mega65_ordered_matrix(39 downto 32) <= SCAN_IN;
            null;
          when 5 =>
            mega65_ordered_matrix(47 downto 40) <= SCAN_IN;

            last_caps_lock(0) <= SCAN_IN(0);
            last_caps_lock(7 downto 1) <= last_caps_lock(6 downto 0);
            if (SCAN_IN(0)='0') and (last_caps_lock=x"FF") then
              caps_lock <= not caps_lock;
            end if;
            null;
          when 6 =>
            mega65_ordered_matrix(55 downto 48) <= SCAN_IN;            
            null;
          when 7 =>
            mega65_ordered_matrix(63 downto 56) <= SCAN_IN;
            null;
          when 8 =>
            mega65_ordered_matrix(71 downto 64) <= SCAN_IN;

            
            last_shift_lock(0) <= SCAN_IN(3);
            last_shift_lock(7 downto 1) <= last_shift_lock(6 downto 0);
            if (SCAN_IN(3)='0') and (last_shift_lock=x"FF") then
              shift_lock <= not shift_lock;
            end if;
            null;
          when 9 =>
            null;
          when others =>
            null;
        end case;
      end if;

      
    end if;
  end process;
  


END ARCHITECTURE translated;
