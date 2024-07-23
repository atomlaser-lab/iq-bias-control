library IEEE;
library work;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity Control_tb is
--  Port ( );
end Control_tb;

architecture Behavioral of Control_tb is

component Control is
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
end component;

--
-- Clocks and reset
--
signal clk_period   :   time    :=  10 ns;
signal clk          :   std_logic;
signal aresetn      :   std_logic;

signal filtered_data, control_i :   t_meas_array(2 downto 0);
signal valid_i, enable_i, polarity_i, hold_i, valid_o   :   std_logic;
signal gains_reg    :   t_param_reg_array(2 downto 0);
signal control_signal_o :   t_pwm_exp_array(2 downto 0);

signal meas_add : t_meas;

begin

clk_proc: process is
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

--GEN1: for I in 0 to 2 generate
--    filtered_data(I) <= resize(control_signal_o(I),t_meas'length);
--end generate GEN1;

filtered_data(0) <= meas_add + resize(control_signal_o(0) + shift_right(control_signal_o(1),2) - shift_right(control_signal_o(1),3),t_meas'length);
filtered_data(1) <= resize(control_signal_o(1) - shift_right(control_signal_o(0),1),t_meas'length);
filtered_data(2) <= resize(control_signal_o(2),t_meas'length);

Valid_proc: process is
begin
    valid_i <= '0';
    wait for 1 us;
    wait until rising_edge(clk);
    valid_i <= '1';
    wait until rising_edge(clk);
    valid_i <= '0';
end process;

--MeasGen: process is
--begin
--    if aresetn = '0' then
--        meas_add <= (others => '0');
--        wait for 1 us;
--    else
--        meas_add <= meas_add + to_signed(1000,meas_add'length);
--        wait for 1 us;
--    end if;
    
--end process;

Control_0: Control
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    meas_i          =>  filtered_data,
    control_i       =>  control_i,
    valid_i         =>  valid_i,
    enable_i        =>  enable_i,
    hold_i          =>  hold_i,
    gains_i         =>  gains_reg,
    valid_o         =>  valid_o,
    control_signal_o=>  control_signal_o
);

main: process is
begin
    aresetn <= '0';
    gains_reg(0) <= X"04" & to_slv_s(1,8) & to_slv_s(-2,8) & to_slv_s(9,8);
    gains_reg(1) <= X"04" & to_slv_s(1,8) & to_slv_s(9,8) & to_slv_s(4,8);
    gains_reg(2) <= X"04" & to_slv_s(10,8) & to_slv_s(0,8) & to_slv_s(0,8);
    control_i(0) <= to_signed(500,t_meas'length);
    control_i(1) <= to_signed(200,t_meas'length);
    control_i(2) <= to_signed(-300,t_meas'length);
    meas_add <= to_signed(0,t_meas'length);

    hold_i <= '0';
    enable_i <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    enable_i <= '1';
    wait for 10 us;
    meas_add <= to_signed(-128,meas_add'length);
    wait for 10 us;
    meas_add <= to_signed(-1024,meas_add'length);
    wait;
end process;

end Behavioral;
