library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity Control is
    Port ( 
        clk                 :   in  std_logic;
        aresetn             :   in  std_logic;
        -- Inputs
        meas_i              :   in  t_meas_array(2 downto 0);
        control_i           :   in  t_meas_array(2 downto 0);
        valid_i             :   in  std_logic;
        --
        -- Parameters
        --
        enable_i            :   in  std_logic;
        hold_i              :   in  std_logic;
        gains_i             :   in  t_param_reg_array(2 downto 0);
        --
        -- Outputs
        --
        valid_o             :   out std_logic;
        control_signal_o    :   out t_pwm_exp_array(2 downto 0)
    );
end Control;

architecture Behavioral of Control is

COMPONENT PID_Multiplier_Signed
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(25 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(33 DOWNTO 0) 
  );
END COMPONENT; 

constant MULT_LATENCY   :   natural :=  4;
constant EXP_WIDTH      :   natural :=  26;
constant GAIN_WIDTH     :   natural :=  8;
constant MULT_WIDTH     :   natural :=  EXP_WIDTH + GAIN_WIDTH;

type t_state_local          is (idle,multiplying,dividing,summing,outputting);
subtype t_input_local       is signed(EXP_WIDTH-1 downto 0);
subtype t_gain_local        is std_logic_vector(GAIN_WIDTH-1 downto 0);
subtype t_mult_local        is signed(MULT_WIDTH-1 downto 0);
type    t_input_local_array is array(natural range <>) of t_input_local;
type    t_output_2d         is array(natural range <>,natural range <>) of std_logic_vector(MULT_WIDTH - 1 downto 0);
type    t_gain_array        is array(natural range <>,natural range <>) of t_gain_local;
type    t_mult_local_array  is array(natural range <>) of t_mult_local;
type    t_divisor_array     is array(natural range <>) of unsigned(GAIN_WIDTH - 1 downto 0);

signal gains                :   t_gain_array(2 downto 0,2 downto 0);
signal divisors             :   t_divisor_array(2 downto 0);
--
-- Signals
--
signal err, err_old             :   t_input_local_array(2 downto 0);
signal measurement, control     :   t_input_local_array(2 downto 0);
signal int_i                    :   t_input_local_array(2 downto 0);
signal int_o                    :   t_output_2d(2 downto 0,2 downto 0);
signal pidSum, pidAccumulate    :   t_mult_local_array(2 downto 0);

signal valid_p                  :   std_logic_vector(7 downto 0);

begin

Gain_Assignment: for I in 0 to 2 generate
    --
    -- Assign gains
    --
    gains(I,0)  <= gains_i(I)(7 downto 0);
    gains(I,1)  <= gains_i(I)(15 downto 8);
    gains(I,2)  <= gains_i(I)(23 downto 16);
    divisors(I) <= unsigned(gains_i(I)(31 downto 24));
    --
    -- Resize inputs
    --
    measurement(I) <= resize(meas_i(I),EXP_WIDTH);
    control(I) <= resize(control_i(I),EXP_WIDTH);
    
    
end generate Gain_Assignment;

Multiplier_Gen_Row: for row in 0 to 2 generate
    Multiplier_Gen_Col: for col in 0 to 2 generate
        Mult_XX: PID_Multiplier_Signed
        port map(
            clk =>  clk,
            A   =>  gains(row,col),
            B   =>  std_logic_vector(int_i(col)),
            P   =>  int_o(row,col)
        );
    end generate Multiplier_Gen_Col;
    --
    -- Create integral gain inputs
    --
    int_i(row) <= shift_right(err(row) + err_old(row),1);
    --
    -- Create summed outputs
    --
    pidSum(row) <= signed(int_o(row,0)) + signed(int_o(row,1)) + signed(int_o(row,2));
end generate Multiplier_Gen_Row;

PID: process(clk,aresetn) is
begin
    if aresetn = '0' then
        err <= (others => (others => '0'));
        err_old <= (others => (others => '0'));
        valid_o <= '0';
        valid_p <= (others => '0');
        pidAccumulate <= (others => (others => '0'));
        control_signal_o <= (others => (others => '0'));
    elsif rising_edge(clk) then
        if enable_i = '1' then
            --
            -- First pipeline stage
            --
            valid_p(0) <= valid_i;
            if valid_i = '1' then
                --
                -- Get new error data and store old error data
                --
                for I in 0 to 2 loop
                    err(I) <= control(I) - measurement(I);
                    err_old(I) <= err(I);
                end loop;
            end if;
            --
            -- Step through pipeline stages to account for multiplication latency
            --
            for I in 0 to MULT_LATENCY - 1 loop
                valid_p(I + 1) <= valid_p(I);
            end loop;
            --
            -- Sum new values
            --
            if valid_p(MULT_LATENCY) = '1' and hold_i = '0' then
                for I in 0 to 2 loop
                    pidAccumulate(I) <= pidAccumulate(I) + pidSum(I);
                end loop;
            end if;
            valid_p(1 + MULT_LATENCY) <= valid_p(MULT_LATENCY);
            --
            -- Produce output
            --
            if valid_p(1 + MULT_LATENCY) = '1' then
                for I in 0 to 2 loop
                    control_signal_o(I) <= resize(shift_right(pidAccumulate(I),to_integer(divisors(I))),t_pwm_exp'length);
                end loop;
                
            end if;
            valid_o <= valid_p(1 + MULT_LATENCY);
        else
            err <= (others => (others => '0'));
            err_old <= (others => (others => '0'));
            valid_p <= (others => '0');
            pidAccumulate <= (others => (others => '0'));
            control_signal_o <= (others => (others => '0'));
            valid_o <= '0';
        end if;
    end if;
end process;


end Behavioral;
