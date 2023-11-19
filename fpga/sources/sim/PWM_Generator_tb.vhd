library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PWM_Generator_tb is
--  Port ( );
end PWM_Generator_tb;

architecture Behavioral of PWM_Generator_tb is

COMPONENT CICfilter
PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tready : OUT STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC 
);
END COMPONENT;

component PWM_Generator is
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
        pwm_o       :   out std_logic_vector   
    );
end component;

--
-- Clocks and reset
--
signal clk_period   :   time    :=  10 ns;
signal clk          :   std_logic;
signal aresetn      :   std_logic;

signal log2_rate    :   unsigned(3 downto 0);
signal cic_shift    :   unsigned(3 downto 0);
signal filter_slv_o :   std_logic_vector(63 downto 0);
signal valid_o      :   std_logic;
signal filterConfig, filterConfig_old   :   std_logic_vector(15 downto 0);
signal valid_config :   std_logic;
signal filter_o     :   signed(23 downto 0);
signal filter_i     :   std_logic_vector(23 downto 0);

signal data_i       :   t_pwm_array(3 downto 0);
signal pwm_o        :   std_logic_vector(3 downto 0);




begin

clk_proc: process is
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

uut: PWM_Generator
port map(
    clk                 =>  clk,
    aresetn             =>  aresetn,
    data_i              =>  data_i,
    pwm_o               =>  pwm_o
);

filter_i <= (0 => pwm_o(0), others => '0');
cic_shift <= log2_rate + log2_rate + log2_rate;
filterConfig <= std_logic_vector(shift_left(to_unsigned(1,filterConfig'length),to_integer(log2_rate)));

ChangeProc: process(clk, aresetn) is
begin 
   if aresetn ='0' then
      filterConfig_old <= filterConfig;
      valid_config <= '0';
   elsif rising_edge(clk) then 
      filterConfig_old <= filterConfig;
      if filterConfig /= filterConfig_old then
        valid_config <= '1';
      else
        valid_config <= '0';
      end if;
   end if;      
end process;

Filt_X : CICfilter
PORT MAP (
    aclk                        => clk,
    aresetn                     => aresetn,
    s_axis_config_tdata         => filterConfig,
    s_axis_config_tvalid        => valid_config,
    s_axis_config_tready        => open,
    s_axis_data_tdata           => filter_i,
    s_axis_data_tvalid          => '1',
    s_axis_data_tready          => open,
    m_axis_data_tdata           => filter_slv_o,
    m_axis_data_tvalid          => valid_o
);

filter_o <= resize(shift_right(signed(filter_slv_o),to_integer(cic_shift)),filter_o'length);

main_proc: process is
begin
    --
    -- Initialize the registers and reset
    --
    aresetn <= '0';
    wait for 50 ns;
    log2_rate <= X"a";
    data_i <= (others => (others => '0'));
    wait for 200 ns;
    aresetn <= '1';
    wait for 1 us;
    data_i(0) <= "01000000";
    
    wait;
end process; 

end Behavioral;
