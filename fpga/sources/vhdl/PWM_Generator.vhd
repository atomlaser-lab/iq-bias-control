library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PWM_Generator is
    port(
        --
        -- Clocking
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Input/outputs
        --
        data_i      :   in  t_pwm_array;
        valid_i     :   in  std_logic;
        pwm_o       :   out std_logic_vector   
    );
end PWM_Generator;

architecture rtl of PWM_Generator is

signal count    :   unsigned(t_pwm'left downto 0);
signal data     :   t_pwm_array;

begin

PWM_GEN: for I in 0 to pwm_o'left generate
    pwm_o(I) <= '1' when count < data(I) else '0';
end generate PWM_GEN;

counting_process: process(clk,aresetn) is
begin
    if aresetn = '0' then
        count <= (others => '0');
        data <= (others => (others => '0'));
    elsif rising_edge(clk) then
        count <= count + 1;
        if valid_i = '1' then
            data <= data_i;
        end if;
    end if;
end process;
   
end architecture rtl;