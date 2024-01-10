library IEEE;
library work;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity Control_tb is
--  Port ( );
end Control_tb;

architecture Behavioral of Control_tb is

component Control is
    Port ( 
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        -- Inputs
       -- meas_i          :   in t_phase
        filtered_data    :   in t_meas;
        control_i       :   in  t_meas;
        valid_i         :   in  std_logic;
        --
        -- Parameters
        enable_i        :   in  std_logic;
        polarity_i      :   in  std_logic;
        hold_i          :   in  std_logic;
        gains           :   in  t_param_reg;
        --
        -- Outputs
        --
        valid_o         :   out std_logic;
        --data_o          : out t_phase;
        control_signal_o  : out signed(PWM_DATA_WIDTH -1 downto 0) 
    );
end component;

--
-- Clocks and reset
--
signal clk_period   :   time    :=  10 ns;
signal clk          :   std_logic;
signal aresetn      :   std_logic;

signal filtered_data, control_i :   t_meas;
signal valid_i, enable_i, polarity_i, hold_i, valid_o   :   std_logic;
signal gains_reg    :   t_param_reg;
signal control_signal_o :   signed(PWM_DATA_WIDTH - 1 downto 0);

begin

clk_proc: process is
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

filtered_data <= resize(control_signal_o,filtered_data'length);
valid_i <= '1';
Control_0: Control
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    filtered_data   =>  filtered_data,
    control_i       =>  control_i,
    valid_i         =>  valid_i,
    enable_i        =>  enable_i,
    polarity_i      =>  polarity_i,
    hold_i          =>  hold_i,
    gains           =>  gains_reg,
    valid_o         =>  valid_o,
    control_signal_o=>  control_signal_o
);

main: process is
begin
    aresetn <= '0';
    gains_reg <= X"08000a0a";
    control_i <= to_signed(500,control_i'length);
    polarity_i <= '0';
    hold_i <= '0';
    enable_i <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    enable_i <= '1';
    wait;
    
end process;

end Behavioral;
