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
        clkx2       :   in  std_logic;
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
signal data     :   t_pwm_array(data_i'left downto 0);

begin

PWM_GEN: for I in 0 to pwm_o'left generate
    pwm_o(I) <= '1' when count < data(I) else '0';
end generate PWM_GEN;

data_process: process(clk,aresetn) is 
begin
    if aresetn = '0' then
        data <= (others => (others => '0'));
    elsif rising_edge(clk) then
        if valid_i = '1' then
            data <= data_i;
        end if;
    end if;
end process;

counting_process: process(clkx2,aresetn) is
begin
    if aresetn = '0' then
        count <= (others => '0');
    elsif rising_edge(clkx2) then
        count <= count + 1;
    end if;
end process;
   
end architecture rtl;