LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
ENTITY driver IS
	GENERIC (	resolution : integer := 128;
				curve_length : integer := 64;
				cycles_until_pi_refresh : integer := 1000;
				PWM_frequency : integer := 40000;
				microstep_resolution : integer := 127);
    PORT (
    clk   : IN std_logic;
    reset : IN std_logic;
    GPIO12    : IN std_logic; -- SS
    GPIO10  : IN std_logic;	-- MOSI
	 GPIO11  : IN std_logic; --SCLK
	 GPIO9	 : OUT std_logic; --MISO
	 dig0, dig1: OUT std_logic_vector(6 DOWNTO 0);
	 dig2, dig3 : OUT std_logic_vector(6 DOWNTO 0);
	 dig4, dig5 : OUT std_logic_vector(6 DOWNTO 0);
	 led : OUT std_logic_vector(7 DOWNTO 0);
	 X_BLK_GRN_PWM : OUT std_logic;
	 X_GRN_BLK_PWM : OUT std_logic;
	 X_RED_BLUE_PWM : OUT std_logic;
	 X_BLUE_RED_PWM : OUT std_logic;
	 Y_BLK_GRN_PWM : OUT std_logic;
	 Y_GRN_BLK_PWM : OUT std_logic;
	 Y_RED_BLUE_PWM : OUT std_logic;
	 Y_BLUE_RED_PWM : OUT std_logic
		  );		
END ENTITY driver;

ARCHITECTURE behaviour OF driver IS 
	SIGNAL inputX : signed(7 DOWNTO 0) := X"00";
	SIGNAL inputY : signed(7 DOWNTO 0) := X"00";
	SIGNAL sawtooth : integer range 0 to (microstep_resolution - 1) := 0;
	SIGNAL sawtooth_inverted : integer range 0 to (microstep_resolution - 1) := (microstep_resolution - 1);
	SIGNAL sawtooth_check : std_logic := '0';
	SIGNAL sawtooth_counter : integer range 0 to 1000 := 10;
	SIGNAL next_spi_value : std_logic := '0';
	SIGNAL next_spi_value_check : std_logic := '0';
	SIGNAL X_BLK_GRN : integer range 0 to microstep_resolution := 0;
	SIGNAL X_GRN_BLK : integer range 0 to microstep_resolution := 0;
	SIGNAL X_RED_BLUE : integer range 0 to microstep_resolution := 0;
	SIGNAL X_BLUE_RED : integer range 0 to microstep_resolution := 0;
	SIGNAL Y_BLK_GRN : integer range 0 to microstep_resolution := 0;
	SIGNAL Y_GRN_BLK : integer range 0 to microstep_resolution := 0;
	SIGNAL Y_RED_BLUE : integer range 0 to microstep_resolution := 0;
	SIGNAL Y_BLUE_RED : integer range 0 to microstep_resolution := 0;
	SIGNAL rotation_speedX : integer range -2**16-1 to 2**16-1 := 0;
	SIGNAL rotation_speedY : integer range -2**16-1 to 2**16-1 := 0;
	SIGNAL xmotor_state : std_logic_vector(1 DOWNTO 0) := "00";
	SIGNAL xmotor_progress : integer range 0 to 2**16-1 := 0;
	SIGNAL xmotor_microstep : integer range 0 to microstep_resolution := 0;
	SIGNAL xmotor_direction : integer range -1 to 1 := 1;
	SIGNAL ymotor_state : std_logic_vector(1 DOWNTO 0) := "00";
	SIGNAL ymotor_progress : integer range 0 to 2**16-1 := 0;
	SIGNAL ymotor_microstep : integer range 0 to microstep_resolution := 0;
	SIGNAL ymotor_direction : integer range -1 to 1 := 1;
	SIGNAL sawtooth_cycles_until_next_stepX : integer range 0 to 2**16-1 := 0;
	SIGNAL sawtooth_cycles_until_next_stepY : integer range 0 to 2**16-1 := 0;
	SIGNAL xmotor_progress_counter : integer range 0 to 2**16-1 := 0;
	SIGNAL ymotor_progress_counter : integer range 0 to 2**16-1 := 0;
	SHARED VARIABLE inputXintermediate : std_logic_vector(15 DOWNTO 0) := X"0000";
	SHARED VARIABLE counter : integer range 0 to 127 := 0;
	SHARED VARIABLE counterXselector : integer range 0 to 2**16-1 := 0;
	SHARED VARIABLE counterYselector : integer range 0 to 2**16-1 := 0;
	--SHARED VARIABLE progress_to_slope : integer range 0 to curve_length := 0;
	SHARED VARIABLE counter_of_rotation : integer range 0 to (2 * cycles_until_pi_refresh);
	FUNCTION hex2display (n:std_logic_vector(3 DOWNTO 0)) RETURN std_logic_vector IS	-- hex2display, copy paste from EE LAB
	VARIABLE res : std_logic_vector(6 DOWNTO 0);
	BEGIN
	CASE n IS
		 WHEN "0000" => RETURN NOT "0111111";
		 WHEN "0001" => RETURN NOT "0000110";
		 WHEN "0010" => RETURN NOT "1011011";
		 WHEN "0011" => RETURN NOT "1001111";
		 WHEN "0100" => RETURN NOT "1100110";
		 WHEN "0101" => RETURN NOT "1101101";
		 WHEN "0110" => RETURN NOT "1111101";
		 WHEN "0111" => RETURN NOT "0000111";
		 WHEN "1000" => RETURN NOT "1111111";
		 WHEN "1001" => RETURN NOT "1101111";
		 WHEN "1010" => RETURN NOT "1110111";
		 WHEN "1011" => RETURN NOT "1111100";
		 WHEN "1100" => RETURN NOT "0111001";
		 WHEN "1101" => RETURN NOT "1011110";
		 WHEN "1110" => RETURN NOT "1111001";
		 WHEN OTHERS => RETURN NOT "1110001";			
	END CASE;
	END hex2display;
BEGIN 
	PROCESS(GPIO12, GPIO11) -- SPI interface, used to get 1 byte for the X rotation, 1 byte for the Y rotation
	BEGIN
		IF reset = '0' THEN
			inputX <= X"00";
			inputY <= X"00";
			inputXintermediate := X"0000";
			dig3 <= hex2display("0000");
			dig2 <= hex2display("0000");
			dig1 <= hex2display("0000");
			dig0 <= hex2display("0000");
			next_spi_value <= '0';

		ELSIF GPIO12 = '0' AND rising_edge(GPIO11) THEN
			inputXintermediate(15 DOWNTO 0) := inputXintermediate(14 DOWNTO 0) & GPIO10;		--the newly read bit is added to the back of inputXintermediate and the front bit is removed
			counter := counter + 1;																--the counter is incremented (how many bits are read)
			IF counter = 16 THEN 																--if the counter is 16 then 16 new bits are received and thus the data is ready to be read by different processes
				dig3 <= hex2display(inputXintermediate(15 DOWNTO 12));							--display for debug purposes
				dig2 <= hex2display(inputXintermediate(11 DOWNTO 8));							--display for debug purposes
				dig1 <= hex2display(inputXintermediate(7 DOWNTO 4));							--display for debug purposes
				dig0 <= hex2display(inputXintermediate(3 DOWNTO 0));							--display for debug purposes
				inputX <= signed(inputXintermediate(15 DOWNTO 8));								--inputX is updated
				inputY <= signed(inputXintermediate(7 DOWNTO 0));								--inputY is updated
				counter := 0;																	--the counter is reset
				next_spi_value <= '1';															--for other processes to check if a new SPI value is ready to be used
			ELSIF counter > 16 THEN			--the counter shouldn't be 16, but if something goes wrong this makes sure it won't crash the FPGA
				counter := 0;
			ELSE 
				next_spi_value <= '0';
			END IF;
		END IF;
		IF GPIO12 = '1' THEN				--GPIO12 is the slave select pin, and if it is high the pi stopped sending data and the counter has to be reset, this should be not used but when one bit is missed or not send, this resets it and makes sure the pi and fpga stay sinked
			counter := 0;
		END IF;
	END PROCESS;
	PROCESS(clk) --steps2rotate, which makes sure the rotation is in the right direction
	BEGIN 
		IF reset = '0' THEN
			counter_of_rotation := 0;
			rotation_speedX <= 0;
			rotation_speedY <= 0;
		ELSIF rising_edge(clk) THEN
			IF next_spi_value = '1' AND next_spi_value_check = '0' THEN 	-- See if a new SPI input is ready
				IF to_integer(inputX) >= 1 THEN  	
					xmotor_direction <= 1;									-- if the input is positive then it rotates counter-clockwise
					rotation_speedX <= to_integer(inputX);
				ELSIF to_integer(inputX) <= -1 THEN
					xmotor_direction <= -1; 								-- if the input is negetive the abs is taken and it rotates clockwise
					rotation_speedX <= abs(to_integer(inputX));
				ELSIF to_integer(inputX) = 0 THEN
					rotation_speedX <= 0; 									-- if the input is 0 the motor maintains orientation
				END IF;
				IF to_integer(inputY) >= 1 THEN 							-- This is the same code as above but for the Y motor instead of the X
					ymotor_direction <= 1;
					rotation_speedY <= to_integer(inputY);
				ELSIF to_integer(inputY) <= -1 THEN
					ymotor_direction <= -1;
					rotation_speedY <= abs(to_integer(inputY));
				ELSIF to_integer(inputY) = 0 THEN
					rotation_speedY <= 0;
				END IF;
			END IF;
			IF sawtooth = (microstep_resolution - 1) AND sawtooth_check = '0' THEN	--Check for later if a new input can be used for the PWM signals
				sawtooth_check <= '1';
			ELSIF sawtooth /= (microstep_resolution - 1) THEN
				sawtooth_check <= '0';
			END IF;
			next_spi_value_check <= next_spi_value;
		END IF;
	END PROCESS;
	PROCESS(clk) -- sawtooth generator, which is used to generate the different PWM signals
	BEGIN 
		IF reset = '0' THEN
			sawtooth <= 0;
			sawtooth_inverted <= (microstep_resolution - 1);
		ELSIF rising_edge(clk) THEN
			IF sawtooth_counter = (1270 / microstep_resolution) THEN	--The frequency of the PWM needs to be reduced to make sure the H bridge driver keeps working.
				IF sawtooth = (microstep_resolution - 1) THEN			-- If the sawtooth is on its max value, its set back to 0
					sawtooth <= 0;
				ELSE 
					sawtooth <= sawtooth + 1;
				END IF;
				sawtooth_inverted <= ((microstep_resolution - 1) - sawtooth);	-- sawtooth inverted is the sawtooth but inverted.
				sawtooth_counter <= 0;
			ELSE 
				sawtooth_counter <= sawtooth_counter + 1;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) --Output selector X
	BEGIN 
		IF reset = '0' THEN
			xmotor_state <= "00";
			xmotor_progress <= 0;
			xmotor_progress_counter <= 0;
		ELSIF rising_edge(clk)THEN
			IF sawtooth = (microstep_resolution - 1) AND sawtooth_check = '0' THEN 	--The generated signals for the PWM are only updated when the sawtooth completed a cycle.
				IF xmotor_progress /= 0 THEN										--If progress is 0 then the microstep remains the same.
					IF xmotor_progress = xmotor_progress_counter THEN 				--A check if enough sawtooth cycles are completed, because the input is the amount of cycles between two microsteps
						IF xmotor_microstep = 0 AND xmotor_direction = -1 THEN		--When microstep is 0 and the direction is -1 then other coils are used (and thus a different motor_state)
							CASE xmotor_state IS 
								WHEN "00" => xmotor_state <= "11";
								WHEN "01" => xmotor_state <= "00";
								WHEN "10" => xmotor_state <= "01";
								WHEN OTHERS => xmotor_state <= "10";
							END CASE;
							xmotor_microstep <= microstep_resolution;
						ELSIF xmotor_microstep = microstep_resolution AND xmotor_direction = 1 THEN	-- similar as the previous if statement, but in the different direction of rotation
							CASE xmotor_state IS 
								WHEN "00" => xmotor_state <= "01";
								WHEN "01" => xmotor_state <= "10";
								WHEN "10" => xmotor_state <= "11";
								WHEN OTHERS => xmotor_state <= "00";
							END CASE;
							xmotor_microstep <= 0;
						ELSE 
							xmotor_microstep <= xmotor_microstep + xmotor_direction; --When it is not an edge case, the direction is added/subtracted to the current microstep
						END IF;
						xmotor_progress_counter <= 1;								--When a new microstep is assigned, the counter is set back to 1
						xmotor_progress <= rotation_speedX;							--The target is updated from the output of the SPI process
					ELSE 
						xmotor_progress_counter <= xmotor_progress_counter + 1;
					END IF;
				ELSE 
					xmotor_progress <= rotation_speedX;
				END IF;
			END IF;
			CASE xmotor_state IS		--This state variable is used to track which coil is the primary and which is the secondary (used to determine which sawtooth to use (normal or inverted))
				WHEN "00" => 
				X_BLK_GRN <= (microstep_resolution - xmotor_microstep); --primary is black -> green
				X_RED_BLUE <= xmotor_microstep;							--secondare is red -> blue
				X_GRN_BLK <= 0;											--green -> black is off
				X_BLUE_RED <= 0;										--blue -> red is off
				WHEN "01" =>
				X_RED_BLUE <= (microstep_resolution - xmotor_microstep);--primary is red -> blue
				X_GRN_BLK <= xmotor_microstep;							--secondary is green-> black
				X_BLK_GRN <= 0;											--black -> green is off
				X_BLUE_RED <= 0;										--blue -> red is off
				WHEN "10" => 
				X_GRN_BLK <= (microstep_resolution - xmotor_microstep);	--similar to the previous two cases
				X_BLUE_RED <= xmotor_microstep;
				X_BLK_GRN <= 0;
				X_RED_BLUE <= 0;
				WHEN OTHERS => 											--case "11" but vhdl requires when others, other than that the same as the other cases
				X_BLUE_RED <= (microstep_resolution - xmotor_microstep);
				X_BLK_GRN <= xmotor_microstep;
				X_GRN_BLK <= 0;
				X_RED_BLUE <= 0;
			END CASE;
		END IF;
	END PROCESS;
	PROCESS(clk) --Output selector Y Exactly the same as the output selector for X, but it used the Y values 
	BEGIN 
		IF reset = '0' THEN
			ymotor_state <= "00";
			ymotor_progress <= 0;
			ymotor_progress_counter <= 0;
		ELSIF rising_edge(clk)THEN
			IF sawtooth = (microstep_resolution - 1) AND sawtooth_check = '0' THEN
				IF ymotor_progress /= 0 THEN
					IF ymotor_progress = ymotor_progress_counter THEN 
						IF ymotor_microstep = 0 AND ymotor_direction = -1 THEN
							CASE ymotor_state IS 
								WHEN "00" => ymotor_state <= "11";
								WHEN "01" => ymotor_state <= "00";
								WHEN "10" => ymotor_state <= "01";
								WHEN OTHERS => ymotor_state <= "10";
							END CASE;
							ymotor_microstep <= microstep_resolution;
						ELSIF ymotor_microstep = microstep_resolution AND ymotor_direction = 1 THEN
							CASE ymotor_state IS 
								WHEN "00" => ymotor_state <= "01";
								WHEN "01" => ymotor_state <= "10";
								WHEN "10" => ymotor_state <= "11";
								WHEN OTHERS => ymotor_state <= "00";
							END CASE;
							ymotor_microstep <= 0;
						ELSE 
							ymotor_microstep <= ymotor_microstep + ymotor_direction;
						END IF;
						ymotor_progress_counter <= 1;
						ymotor_progress <= rotation_speedY;
					ELSE 
						ymotor_progress_counter <= ymotor_progress_counter + 1;
					END IF;
				ELSE 
					ymotor_progress <= rotation_speedY;
				END IF;
			END IF;
			CASE ymotor_state IS
				WHEN "00" => 
				Y_BLK_GRN <= (microstep_resolution - ymotor_microstep);
				Y_RED_BLUE <= ymotor_microstep;
				Y_GRN_BLK <= 0;
				Y_BLUE_RED <= 0;
				WHEN "01" =>
				Y_RED_BLUE <= (microstep_resolution - ymotor_microstep);
				Y_GRN_BLK <= ymotor_microstep;
				Y_BLK_GRN <= 0;
				Y_BLUE_RED <= 0;
				WHEN "10" => 
				Y_GRN_BLK <= (microstep_resolution - ymotor_microstep);
				Y_BLUE_RED <= ymotor_microstep;
				Y_BLK_GRN <= 0;
				Y_RED_BLUE <= 0;
				WHEN OTHERS => 
				Y_BLUE_RED <= (microstep_resolution - ymotor_microstep);
				Y_BLK_GRN <= ymotor_microstep;
				Y_GRN_BLK <= 0;
				Y_RED_BLUE <= 0;
			END CASE;
		END IF;
	END PROCESS;
	PROCESS(clk) -- X Black to Green PWM
	BEGIN 
		IF reset = '0' THEN
			X_BLK_GRN_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF xmotor_state = "00" THEN			--When black -> green is primary
				IF X_BLK_GRN > sawtooth THEN	--The value is compared to the sawtooth and if it is higher the output is high, otherwise it is low. Similar to how PWM is generated in actual PWM ICs
					X_BLK_GRN_PWM <= '1';
				ELSE 
					X_BLK_GRN_PWM <= '0';
				END IF;
			ELSE								--When black -> green is secondary or off (when it is off the value of X_BLK_GRN is 0 and never greater that the sawtooth)
				IF X_BLK_GRN > sawtooth_inverted THEN --same comparitor as above, but instead of sawtooth it's compared to sawtooth inverted
					X_BLK_GRN_PWM <= '1';
				ELSE 
					X_BLK_GRN_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) -- Y Black to Green PWM 	-- ALL other PWM generator processes are similar to X_BLK_GRN_PWM but the input is different and the motor_state is different
	BEGIN 
		IF reset = '0' THEN
			Y_BLK_GRN_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF ymotor_state = "00" THEN
				IF Y_BLK_GRN > sawtooth THEN
					Y_BLK_GRN_PWM <= '1';
				ELSE 
					Y_BLK_GRN_PWM <= '0';
				END IF;
			ELSE
				IF Y_BLK_GRN > sawtooth_inverted THEN
					Y_BLK_GRN_PWM <= '1';
				ELSE 
					Y_BLK_GRN_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) -- X Green to Black PWM 
	BEGIN 
		IF reset = '0' THEN
			X_GRN_BLK_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF xmotor_state = "10" THEN
				IF X_GRN_BLK > sawtooth THEN
					X_GRN_BLK_PWM <= '1';
				ELSE 
					X_GRN_BLK_PWM <= '0';
				END IF;
			ELSE 
				IF X_GRN_BLK > sawtooth_inverted THEN
					X_GRN_BLK_PWM <= '1';
				ELSE 
					X_GRN_BLK_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) -- Y Green to Black PWM 
	BEGIN 
		IF reset = '0' THEN
			Y_GRN_BLK_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF ymotor_state = "10" THEN
				IF Y_GRN_BLK > sawtooth THEN
					Y_GRN_BLK_PWM <= '1';
				ELSE 
					Y_GRN_BLK_PWM <= '0';
				END IF;
			ELSE 
				IF Y_GRN_BLK > sawtooth_inverted THEN
					Y_GRN_BLK_PWM <= '1';
				ELSE 
					Y_GRN_BLK_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) -- X Red to Blue PWM 
	BEGIN 
		IF reset = '0' THEN
			X_RED_BLUE_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF xmotor_state = "01" THEN
				IF X_RED_BLUE > sawtooth THEN
					X_RED_BLUE_PWM <= '1';
				ELSE 
					X_RED_BLUE_PWM <= '0';
				END IF;
			ELSE 
				IF X_RED_BLUE > sawtooth_inverted THEN
					X_RED_BLUE_PWM <= '1';
				ELSE 
					X_RED_BLUE_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) -- Y Red to Blue PWM 
	BEGIN 
		IF reset = '0' THEN
			Y_RED_BLUE_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF ymotor_state = "01" THEN
				IF Y_RED_BLUE > sawtooth THEN
					Y_RED_BLUE_PWM <= '1';
				ELSE 
					Y_RED_BLUE_PWM <= '0';
				END IF;
			ELSE 
				IF Y_RED_BLUE > sawtooth_inverted THEN
					Y_RED_BLUE_PWM <= '1';
				ELSE 
					Y_RED_BLUE_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) -- X Blue to Red PWM 
	BEGIN 
		IF reset = '0' THEN
			X_BLUE_RED_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF xmotor_state = "11" THEN
				IF X_BLUE_RED > sawtooth THEN
					X_BLUE_RED_PWM <= '1';
				ELSE 
					X_BLUE_RED_PWM <= '0';
				END IF;
			ELSE 
				IF X_BLUE_RED > sawtooth_inverted THEN
					X_BLUE_RED_PWM <= '1';
				ELSE 
					X_BLUE_RED_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS(clk) -- Y Blue to Red PWM 
	BEGIN 
		IF reset = '0' THEN
			Y_BLUE_RED_PWM <= '0';
		ELSIF rising_edge(clk) THEN
			IF ymotor_state = "11" THEN
				IF Y_BLUE_RED > sawtooth THEN
					Y_BLUE_RED_PWM <= '1';
				ELSE 
					Y_BLUE_RED_PWM <= '0';
				END IF;
			ELSE 
				IF Y_BLUE_RED > sawtooth_inverted THEN
					Y_BLUE_RED_PWM <= '1';
				ELSE 
					Y_BLUE_RED_PWM <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;
END behaviour;