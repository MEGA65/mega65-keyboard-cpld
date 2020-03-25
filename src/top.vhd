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
--    TDO         		: OUT std_logic := '1';
--    TDI         		: IN std_logic;
--    TMS         		: IN std_logic; 
--    TCK	 		    	: IN std_logic;

    KIO8 : in std_logic := '0';
    KIO9 : in std_logic := '0';
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
  signal cnt_idle: unsigned(31 downto 0) := x"00000000";
  
  signal last_KIO8 : std_logic := '0';
  signal bit_number : integer range 0 to 255 := 0;
  
  -- The data we are currently shifting in or out serially
  signal serial_data_in : unsigned(127 downto 0) := x"000000000000000000000000FF0000FF";
  signal serial_data_out : unsigned(81 downto 0) := (others => '1');

  signal scan_phase : integer range 0 to 15 := 0;
  signal scan_out_internal : std_logic_vector(9 downto 0) := "0000000001";
  -- 0 = key down, 1 = key not pressed
  signal mega65_ordered_matrix : unsigned(81 downto 0);

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

  signal loop_count : unsigned(7 downto 0) := x"00";  

  signal clock_duration : integer range 0 to 31 := 0;

  signal kio8_history : std_logic_vector(3 downto 0) := "0000";
  signal last_last_kio8 : std_logic := '0';

  signal caps_lock_hold_time : integer  range 0 to (4*1048576-1) := 0;
  
BEGIN
  
  clk <= osc_clk;
  
  OSCInst0: OSCH
                                        -- synthesis translate_off
    GENERIC MAP ( NOM_FREQ => "24.18" )
    
                                        -- synthesis translate_on
    PORT MAP (STDBY=> '0', OSC=> osc_clk, SEDSTDBY=> open);

  process(clk)
  begin
    if (rising_edge(clk)) then
      cnt <= cnt + X"00000001";
      cnt_idle <= cnt_idle + X"00000001";

      -- Initialisation doesn't seem to work on the lattices, so we have to be
      -- explicit
      if cnt = x"00000000" then
        mega65_ordered_matrix <= (others => '1');
      end if;
      
      kio8_history(0) <= kio8;
      kio8_history(3 downto 1) <= kio8_history(2 downto 0);

      last_last_kio8 <= last_kio8;
      if kio8_history(3 downto 0) = "1111" and kio8='1' and last_kio8 = '0' then
        last_kio8 <= '1';
      end if;
      if kio8_history(3 downto 0) = "0000" and kio8='0' and last_kio8 = '1' then
        last_kio8 <= '0';
      end if;
--      kio10 <= last_kio8;
--      last_KIO8 <= KIO8;

      -- Flash both leds like police lights if no signal from the computer
      if cnt_idle(31 downto 24) /= x"00" then
        mega65_control_data <= (others => '0');

        if cnt_idle(23)='1' then
          -- Red flashes
          mega65_control_data(7 downto 0) <= (others => cnt_idle(20));
          mega65_control_data(31 downto 24) <= (others => cnt_idle(20));
        else
          -- Blue flashes
          mega65_control_data(71 downto 64) <= (others => cnt_idle(20));
          mega65_control_data(95 downto 88) <= (others => cnt_idle(20));
        end if;
      end if;
      
      if KIO8='0' then
        clock_duration <= 0;
      else
        if clock_duration < 31 then
          clock_duration <= clock_duration + 1;
        end if;
      end if;
      
      if clock_duration = 31 then
        serial_data_out <= mega65_ordered_matrix;
        bit_number <= 0;
        KIO10 <= '1';
      else
        if last_last_KIO8 = '0' and last_KIO8 = '1' then
         -- Latch data on rising edge
          if bit_number /= 255 then
            bit_number <= bit_number + 1;
          end if;
          serial_data_in(127 downto 1) <= serial_data_in(126 downto 0);
          serial_data_in(0) <= KIO9;
          if bit_number = 127 then
            -- We have 128 bits of data, so latch the whole thing
            mega65_control_data(127 downto 1) <= serial_data_in(126 downto 0);
            mega65_control_data(0) <= KIO9;
            cnt_idle <= x"00000000";
          end if;

          -- And push matrix data out
          -- (And at the same time dealing with our funny time delay problem
          -- which is why we read from element 79, but have 81 in the loop.)
          serial_data_out(81 downto 1) <= serial_data_out(80 downto 0);
          serial_data_out(0) <= serial_data_out(81);
          KIO10 <= serial_data_out(79);
        end if;
      end if;

      -- Update PWM LED outputs
      if to_integer(cnt(7 downto 0)) = 0 then
        loop_count <= loop_count + 1;
        
        LED_SHIFT <= shift_lock;
        LED_CAPS <= caps_lock;
        if x"00" /= mega65_control_data(7 downto 0) then
          LED_R2 <= '0';
        else
          LED_R2 <= '1';
        end if;
        if x"00" /= mega65_control_data(15 downto 8) then
          LED_G2 <= '0';
        else
          LED_G2 <= '1';
        end if;
        if x"00" /= mega65_control_data(23 downto 16) then
          LED_B2 <= '0';
        else
          LED_B2 <= '1';
        end if;
        if x"00" /= mega65_control_data(31 downto 24) then
          LED_R3 <= '0';
        else
          LED_R3 <= '1';
        end if;
        if x"00" /= mega65_control_data(39 downto 32) then
          LED_G3 <= '0';
        else
          LED_G3 <= '1';
        end if;
        if x"00" /= mega65_control_data(47 downto 40) then
          LED_B3 <= '0';
        else
          LED_B3 <= '1';
        end if;
        if x"00" /= mega65_control_data(55 downto 48) then
          LED_R0 <= '0';
        else
          LED_R0 <= '1';
        end if;
        if x"00" /= mega65_control_data(63 downto 56) then
          LED_G0 <= '0';
        else
          LED_G0 <= '1';
        end if;
        if x"00" /= mega65_control_data(71 downto 64) then
          LED_B0 <= '0';
        else
          LED_B0 <= '1';
        end if;
        if x"00" /= mega65_control_data(79 downto 72) then
          LED_R1 <= '0';
        else
          LED_R1 <= '1';
        end if;
        if x"00" /= mega65_control_data(87 downto 80) then
          LED_G1 <= '0';
        else
          LED_G1 <= '1';
        end if;
        if x"00" /= mega65_control_data(95 downto 88) then
          LED_B1 <= '0';
        else
          LED_B1 <= '1';
        end if;
      else
        if cnt(7 downto 0) = mega65_control_data(7 downto 0) then
          LED_R2 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(15 downto 8) then
          LED_G2 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(23 downto 16) then
          LED_B2 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(31 downto 24) then
          LED_R3 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(39 downto 32) then
          LED_G3 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(47 downto 40) then
          LED_B3 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(55 downto 48) then
--        if clock_duration = 31 then
          LED_R0 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(63 downto 56) then
--        if clock_duration /= 31 then
          LED_G0 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(71 downto 64) then
          LED_B0 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(79 downto 72) then
          LED_R1 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(87 downto 80) then
          LED_G1 <= '1';
        end if;
        if cnt(7 downto 0) = mega65_control_data(95 downto 88) then
          LED_B1 <= '1';
        end if;
      end if;
      
      -- Scan keyboard
      if cnt(7 downto 0) = "00000000" then
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
      if cnt(7 downto 0) = "10000000" then
        -- Read scan row after allowing time to settle.
        -- We place the scanned keys directly into the MEGA65
        -- matrix layout, so that we can easily clock it out
        -- without further fiddling.

        mega65_ordered_matrix(81-75) <= KEY_RESTORE;

        case scan_phase is
          when 0 =>
            mega65_ordered_matrix(81-6) <= SCAN_IN(0);  -- F5
            mega65_ordered_matrix(81-32) <= SCAN_IN(1);  -- 9
            mega65_ordered_matrix(81-33) <= SCAN_IN(2);  -- I
            mega65_ordered_matrix(81-37) <= SCAN_IN(3);  -- K
            mega65_ordered_matrix(81-47) <= SCAN_IN(4);  -- <
            mega65_ordered_matrix(81-0) <= SCAN_IN(5);  -- INST/DEL
            mega65_ordered_matrix(81-76) <= SCAN_IN(5);  -- INST/DEL
            mega65_ordered_matrix(81-51) <= SCAN_IN(6);  -- CLR/HOME
            mega65_ordered_matrix(81-38) <= SCAN_IN(7);  -- O
            null;
          when 1 =>
            mega65_ordered_matrix(81-5) <= SCAN_IN(0);  -- F3
            mega65_ordered_matrix(81-27) <= SCAN_IN(1);  -- 8
            mega65_ordered_matrix(81-30) <= SCAN_IN(2);  -- U
            mega65_ordered_matrix(81-34) <= SCAN_IN(3);  -- J
            mega65_ordered_matrix(81-36) <= SCAN_IN(4);  -- M
            mega65_ordered_matrix(81-2) <= SCAN_IN(5);  -- CURSOR RIGHT
            mega65_ordered_matrix(81-48) <= SCAN_IN(6);  -- GBP
            mega65_ordered_matrix(81-53) <= SCAN_IN(7);  -- =
            null;
          when 2 =>
            mega65_ordered_matrix(81-4) <= SCAN_IN(0);  -- F1
            mega65_ordered_matrix(81-24) <= SCAN_IN(1);  -- 7
            mega65_ordered_matrix(81-25) <= SCAN_IN(2);  -- Y
            mega65_ordered_matrix(81-29) <= SCAN_IN(3);  -- H
            mega65_ordered_matrix(81-39) <= SCAN_IN(4);  -- N
            mega65_ordered_matrix(81-7) <= SCAN_IN(5);  -- CURSOR DOWN
            mega65_ordered_matrix(81-43) <= SCAN_IN(6);  -- -
            mega65_ordered_matrix(81-50) <= SCAN_IN(7);  -- ;
            null;
          when 3 =>
            mega65_ordered_matrix(81-19) <= SCAN_IN(1);  -- 6
            mega65_ordered_matrix(81-22) <= SCAN_IN(2);  -- T
            mega65_ordered_matrix(81-26) <= SCAN_IN(3);  -- G
            mega65_ordered_matrix(81-28) <= SCAN_IN(4);  -- B
            mega65_ordered_matrix(81-74) <= SCAN_IN(5);  -- CURSOR LEFT
            mega65_ordered_matrix(81-40) <= SCAN_IN(6);  -- +
            mega65_ordered_matrix(81-45) <= SCAN_IN(7);  -- :
            null;
          when 4 =>
            mega65_ordered_matrix(81-64) <= SCAN_IN(0);  -- NO SCROLL
            mega65_ordered_matrix(81-16) <= SCAN_IN(1);  -- 5
            mega65_ordered_matrix(81-17) <= SCAN_IN(2);  -- R
            mega65_ordered_matrix(81-21) <= SCAN_IN(3);  -- F
            mega65_ordered_matrix(81-31) <= SCAN_IN(4);  -- V
            mega65_ordered_matrix(81-60) <= SCAN_IN(5);  -- SPACE
            mega65_ordered_matrix(81-35) <= SCAN_IN(6);  -- 0
            mega65_ordered_matrix(81-42) <= SCAN_IN(7);  -- L
            
            null;
          when 5 =>
            last_caps_lock(0) <= SCAN_IN(0);
            last_caps_lock(7 downto 1) <= last_caps_lock(6 downto 0);
            if last_caps_lock = x"FF" then
              -- If caps lock is being held down for a long time for CPU speed
              -- control, then automatically re-invert it so that the user doesn't
              -- need to do so themselves.
              if caps_lock_hold_time < (1*1048576) then
                caps_lock_hold_time <= caps_lock_hold_time + 1;
              end if;
              if caps_lock_hold_time = (1*1048576 - 2) then
                caps_lock <= not caps_lock;
              end if;
            else
              caps_lock_hold_time <= 0;
            end if;
            if (SCAN_IN(0)='0') and (last_caps_lock=x"FF") then
              caps_lock <= not caps_lock;
            end if;
            -- Also expose CAPS LOCK key directly, so that it can be used to
            -- enable 40MHz CPU while held down.
            mega65_ordered_matrix(81-78) <= SCAN_IN(0);
            
            -- CAPS LOCK has its own separate line, so these exist in positions
            -- after the whole matrix
            mega65_ordered_matrix(81-72) <= not caps_lock;
            mega65_ordered_matrix(81-11) <= SCAN_IN(1);  -- 4
            mega65_ordered_matrix(81-14) <= SCAN_IN(2);  -- E
            mega65_ordered_matrix(81-18) <= SCAN_IN(3);  -- D
            mega65_ordered_matrix(81-20) <= SCAN_IN(4);  -- C
            mega65_ordered_matrix(81-67) <= SCAN_IN(6);  -- HELP
            mega65_ordered_matrix(81-1) <= SCAN_IN(7);  -- RETURN
            mega65_ordered_matrix(81-77) <= SCAN_IN(7);  -- RETURN

            
            null;
          when 6 =>
            mega65_ordered_matrix(81-66) <= SCAN_IN(0);  -- ALT
            mega65_ordered_matrix(81-8) <= SCAN_IN(1);  -- 3
            mega65_ordered_matrix(81-9) <= SCAN_IN(2);  -- W
            mega65_ordered_matrix(81-13) <= SCAN_IN(3);  -- S
            mega65_ordered_matrix(81-23) <= SCAN_IN(4);  -- X
            mega65_ordered_matrix(81-73) <= SCAN_IN(5);  -- CURSOR UP
            mega65_ordered_matrix(81-70) <= SCAN_IN(6);  -- F13
            mega65_ordered_matrix(81-54) <= SCAN_IN(7);  -- ^
            null;
          when 7 =>
            mega65_ordered_matrix(81-71) <= SCAN_IN(0);  -- ESC
            mega65_ordered_matrix(81-59) <= SCAN_IN(1);  -- 2
            mega65_ordered_matrix(81-62) <= SCAN_IN(2);  -- Q
            mega65_ordered_matrix(81-10) <= SCAN_IN(3);  -- A
            mega65_ordered_matrix(81-12) <= SCAN_IN(4);  -- Z
            mega65_ordered_matrix(81-52) <= SCAN_IN(5);  -- RIGHT SHIFT
            mega65_ordered_matrix(81-69) <= SCAN_IN(6);  -- F11
            mega65_ordered_matrix(81-49) <= SCAN_IN(7);  -- *
            null;
          when 8 =>
            last_shift_lock(0) <= SCAN_IN(3);
            last_shift_lock(7 downto 1) <= last_shift_lock(6 downto 0);
            if (SCAN_IN(3)='0') and (last_shift_lock=x"FF") then
              shift_lock <= not shift_lock;
            end if;
            mega65_ordered_matrix(81-56) <= SCAN_IN(1);  -- 1
            mega65_ordered_matrix(81-15) <= SCAN_IN(4) and (not shift_lock);  -- LEFT
                                                                              -- SHIFT
                                                                              -- and LOCK
            mega65_ordered_matrix(81-55) <= SCAN_IN(5);  -- /
            mega65_ordered_matrix(81-68) <= SCAN_IN(6);  -- F9
            mega65_ordered_matrix(81-46) <= SCAN_IN(7);  -- @
            null;
          when 9 =>
            mega65_ordered_matrix(81-63) <= SCAN_IN(0);  -- RUN/STOP
            mega65_ordered_matrix(81-57) <= SCAN_IN(1);  -- <-
            mega65_ordered_matrix(81-65) <= SCAN_IN(2);  -- TAB
            mega65_ordered_matrix(81-58) <= SCAN_IN(3);  -- CTRL
            mega65_ordered_matrix(81-61) <= SCAN_IN(4);  -- MEGA
            mega65_ordered_matrix(81-44) <= SCAN_IN(5);  -- >
            mega65_ordered_matrix(81-3) <= SCAN_IN(6);  -- F7
            mega65_ordered_matrix(81-41) <= SCAN_IN(7);  -- P
            null;
          when others =>
            null;
        end case;
      end if;

      
    end if;
  end process;
  


END ARCHITECTURE translated;
