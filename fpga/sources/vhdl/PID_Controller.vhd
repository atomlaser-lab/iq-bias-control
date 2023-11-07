library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

--
--Uses measurement and control values to implement a PID controller
--by calculating a correction to the actuator (DAC) value at each
--time step.
--
entity PID_Controller is
	port(	
		clk			:	in	std_logic;									--Clock signal
		aresetn		:	in	std_logic;									--Asynchronous, active-low reset
		--
		-- Input signals
		--
		control_i	:	in 	t_adc;										--Control signal
		measure_i	:	in	t_adc;										--Measurement signal
		measValid_i	:	in	std_logic;									--Signal that new measurement is valid.
		scan_i		:	in	t_dac;										--Input scan value
		scanValid_i	:	in	std_logic;									--Signal that a new scan value is valid
		--
		-- Parameter inputs:
		-- 0: (0 => enable, polarity => 1)
		-- 1: 8 bit values (divisor, Kd, Ki, Kp)
		-- 2: (31 downto 16 => upper limit, 15 downto 0 => lower limit)
		--
		regs_i		:	in	t_param_reg_array(2 downto 0);
		--
		-- Outputs
		--
		pid_o		:	out t_dac;										--Actuator output from PID (debugging)
		act_o		:	out t_dac;										--Output actuator signal
		valid_o		:	out std_logic									--Indicates act_o is valid
	);								
end PID_Controller;

architecture Behavioral of PID_Controller is

--
-- Define constant widths
--
constant EXP_WIDTH	    :	integer	:=	16;							--Expanded width of signals
constant MULT_WIDTH     :	integer	:=	PID_WIDTH + EXP_WIDTH;		--Width of multiplied signals
constant MULT_LATENCY	:	integer	:=	3;							--Latency of the multiplication blocks
--
-- Define new data types
--
subtype t_input_local		is	signed(EXP_WIDTH -1 downto 0);
subtype t_mult_local		is	signed(MULT_WIDTH - 1 downto 0);
subtype t_mult_slv_local	is	std_logic_vector(MULT_WIDTH - 1 downto 0);
subtype t_gain_local		is	std_logic_vector(PID_WIDTH - 1 downto 0);
type t_input_local_array	is	array(natural range <>) of t_input_local;

type t_state_local is (acquire_input, multiplying, add_scan, check_limits, outputting);
--
-- Multiplies a 16-bit signed value with an 8-bit unsigned value.
-- The widths of these signals must match the width of their appropriate parameters.
-- a'length = EXP_WIDTH, b'length = PID_WIDTH, p'length = MULT_WIDTH
--
COMPONENT K_Multiplier
PORT (
    clk : in std_logic;
    a : IN STD_LOGIC_VECTOR(EXP_WIDTH-1 DOWNTO 0);
    b : IN STD_LOGIC_VECTOR(PID_WIDTH-1 DOWNTO 0);
    p : OUT STD_LOGIC_VECTOR(MULT_WIDTH-1 DOWNTO 0)
);
END COMPONENT;
--
-- Control signals
--
constant ENABLE_DELAY   :   natural :=  1250; --1 ms
signal enable	:	std_logic;
signal polarity	:	std_logic;
signal enableDelayCount :   unsigned(16 downto 0);
signal enableSync   :   std_logic_vector(1 downto 0);
--
-- Internal measurement, control, and scan signals
--
signal measurement, control				:	t_input_local;
signal scan								:	t_mult_local;
--
-- Error signals -- need the current value and the last 2
--
signal err								:	t_input_local_array(2 downto 0);
--
-- Individual multiplier inputs and ouputs
--
signal Kp, Ki, Kd						:	t_gain_local;
signal divisor							:	integer range 0 to 2**(PID_WIDTH - 1);
signal prop_i, integral_i, derivative_i	:	t_input_local;
signal prop_o, integral_o, derivative_o	:	t_mult_slv_local;
--
-- Final values
--
signal pidSum, pidAccumulate, pidDivide, pidScan, pidFinal	:	t_mult_local;
signal lowerLimit, upperLimit					:	t_mult_local;
--
-- State and flow control
--
signal multCount	:	unsigned(3 downto 0);
signal valid_p		:	std_logic_vector(7 downto 0);


begin	
--
-- Parse parameters
--
--PSync: process(clk,aresetn) is
--begin
--    if aresetn = '0' then
--        enableSync <= "00";
--        enableDelayCount <= (others => '0');
--        enable <= '0';
--    elsif rising_edge(clk) then
--        enableSync <= enableSync(0) & regs_i(0)(0);
--        if regs_i(0)(0) = '0' then
--            enable <= '0';
--            enableDelayCount <= (others => '0');
--        elsif enableSync = "01" then
--            enableDelayCount <= (0 => '1',others => '0');
--            enable <= '0';
--        elsif enableDelayCount > 0 and enableDelayCount < ENABLE_DELAY then
--            enableDelayCount <= enableDelayCount + 1;
--            enable <= '0';
--        elsif enableDelayCount >= ENABLE_DELAY then
--            enable <= '1';
--        end if;
--    end if;
--end process;
--PSync: process(clk,aresetn,regs_i) is
--begin
--    if aresetn = '0' then
--        enableDelayCount <= (others => '0');
--        enable <= '0';
--    elsif rising_edge(regs_i(0)(0)) then
--        enableDelayCount <= (0 => '1', others => '0');
--        enable <= '0';
--    elsif rising_edge(clk) then
--        if regs_i(0)(0) = '0' then
--            enable <= '0';
--            enableDelayCount <= (others => '0');
--        elsif enableDelayCount > 0 and enableDelayCount < ENABLE_DELAY then
--            enableDelayCount <= enableDelayCount + 1;
--            enable <= '0';
--        elsif enableDelayCount >= ENABLE_DELAY then
--            enable <= '1';
--        end if;
--    end if;
--end process;

enable <= regs_i(0)(0);
polarity <= regs_i(0)(1);
--
-- Parse gains
--
Kp <= regs_i(1)(PID_WIDTH - 1 downto 0);
Ki <= regs_i(1)(2*PID_WIDTH - 1 downto PID_WIDTH);
Kd <= regs_i(1)(3*PID_WIDTH - 1 downto 2*PID_WIDTH);
divisor <= to_integer(unsigned(regs_i(1)(4*PID_WIDTH - 1 downto 3*PID_WIDTH)));
--
-- Parse limits
--
lowerLimit <= resize(signed(regs_i(2)(15 downto 0)),lowerLimit'length);
upperLimit <= resize(signed(regs_i(2)(31 downto 16)),upperLimit'length);
--
-- Resize inputs to EXP_WIDTH.
--
measurement <= resize(measure_i,measurement'length);
control <= resize(control_i,control'length);
scan <= resize(scan_i,scan'length);		
--
-- Calculate error signal
--
prop_i <= err(0) - err(1);
integral_i <= shift_right(err(0) + err(1),1);
derivative_i <= err(0) - shift_left(err(1),1) + err(2);
--
-- Calculate actuator stages
--
MultProp: K_Multiplier
port map (
	clk => clk,
	a => std_logic_vector(prop_i),
	b => Kp,
	p => prop_o);
	
MultInt: K_Multiplier
port map (
	clk => clk,
	a => std_logic_vector(integral_i),
	b => Ki,
	p => integral_o);	

MultDeriv: K_Multiplier
port map (
	clk => clk,
	a => std_logic_vector(derivative_i),
	b => Kd,
	p => derivative_o);
--
-- Sum outputs of multipliers
--
pidSum <= signed(prop_o) + signed(integral_o) + signed(derivative_o);
--
-- Divide PID output and add scan value
--
pidDivide <= shift_right(pidAccumulate,divisor);
pidScan <= pidDivide + scan;
pidFinal <= pidScan when pidScan < upperLimit and pidScan > lowerLimit else
			upperLimit when pidScan > upperLimit else
			lowerLimit when pidScan < lowerLimit;
--
-- This is the main PID process and provides parsing of the loop registers as well
-- as handling the timing.
--
PID_Process: process(clk,aresetn) is
begin
	if aresetn = '0' then
		multCount <= (others => '0');
		valid_o <= '0';
		err <= (others => (others => '0'));
		valid_p <= (others => '0');
		pidAccumulate <= (others => '0');
		pid_o <= (others => '0');
		act_o <= (others => '0');
	elsif rising_edge(clk) then
		if enable = '0' then
			multCount <= (others => '0');
			err <= (others => (others => '0'));
			valid_p <= (others => '0');
			pidAccumulate <= (others => '0');
			pid_o <= (others => '0');
			
			if scanValid_i = '1' then
				act_o <= resize(pidFinal,act_o'length);
				valid_o <= '1';
			else
			    valid_o <= '0';
			end if;
		else
			--
			-- First pipeline stage
			--
			valid_p(0) <= measValid_i;
			if measValid_i = '1' then
				--
				-- Get new data
				--
				if polarity = '0' then
					err(0) <= control - measurement;
				else
					err(0) <= measurement - control;
				end if;
				--
				-- Store previous data
				--
				err(1) <= err(0);
				err(2) <= err(1);
			end if;
			--
			-- Step through pipeline stages to account for multiplier delay
			--
			for I in 0 to MULT_LATENCY - 1 loop
				valid_p(I + 1) <= valid_p(I);
			end loop;
			--
			-- Sum new values
			--
			if valid_p(MULT_LATENCY) = '1' then
                pidAccumulate <= pidAccumulate + pidSum;
			end if;
			valid_p(MULT_LATENCY + 1) <= valid_p(MULT_LATENCY);
			--
			-- Output value
			--
			if valid_p(MULT_LATENCY + 1) = '1' then
				pid_o <= resize(pidDivide,pid_o'length);
				act_o <= resize(pidFinal,act_o'length);
			end if;
			valid_o <= valid_p(MULT_LATENCY + 1);

		end if;
	end if;
end process;


end Behavioral;

