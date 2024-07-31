library IEEE;
library work;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseControl_tb is
--  Port ( );
end PhaseControl_tb;


architecture Behavioral of PhaseControl_tb is

component PhaseControl is
    port(
        --
        -- Clocking and reset
        --
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        --
        -- Input data
        --
        adc_i           :   in  t_adc;
        dds_i           :   in  t_dds_combined;
        --
        -- Registers
        --
        control_reg_i   :   in  t_param_reg;
        gain_reg_i      :   in  t_param_reg;
        --
        -- Control signals
        --
        pid_enable_i    :   in  std_logic;
        pid_hold_i      :   in  std_logic;
        --
        -- Output data
        --
        phase_o         :   out t_phase;
        valid_phase_o   :   out std_logic;
        phase_unwrap_o  :   out t_phase;
        valid_unwrap_o  :   out std_logic;
        actuator_o      :   out signed;
        valid_act_o     :   out std_logic
    );
end component;

COMPONENT DDS1
PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0) 
);
END COMPONENT;

--
-- Clocks and reset
--
signal clk_period   :   time    :=  10 ns;
signal clk          :   std_logic;
signal aresetn      :   std_logic;
--
-- Input data
--
signal adc                      :   t_adc;
signal dds                      :   t_dds_combined;
signal dds_adc_o, dds_mix_o     :   std_logic_vector(31 downto 0);
signal dds_slv                  :   t_dds_combined_slv;
signal freq                     :   t_dds_phase;
signal dds_phase_mod            :   t_dds_phase;
signal dds_phase                :   t_dds_phase;   
--
-- Parameters and registers
--
signal control_reg      :   t_param_reg;
signal gain_reg         :   t_param_reg;
signal dds_phase_adc_i, dds_phase_mix_i  :   std_logic_vector(63 downto 0);
signal pid_enable, pid_hold     :   std_logic;

--
-- Output data
--
signal phase_o, phase_unwrap        :   t_phase;
signal valid_phase                  :   std_logic;
signal valid_unwrap, valid_act      :   std_logic;
signal actuator                     :   signed(DDS_PHASE_WIDTH - 1 downto 0);


begin

clk_proc: process is
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

freq <= to_unsigned(171798692,32);
dds_phase <= unsigned(resize(signed(std_logic_vector(resize(dds_phase_mod,t_dds_phase'length + 1))) + shift_left(resize(actuator,t_dds_phase'length + 1),16),t_dds_phase'length));
dds_phase_adc_i <= std_logic_vector(dds_phase) & std_logic_vector(freq);
dds_phase_mix_i <= X"00000000" & std_logic_vector(freq);

ADC_DDS: DDS1
port map(
    aclk                     => clk,
    aresetn                  => aresetn,
    s_axis_phase_tvalid      => '1',
    s_axis_phase_tdata       => dds_phase_adc_i,
    m_axis_data_tvalid       => open,
    m_axis_data_tdata        => dds_adc_o
);

adc <= resize(signed(dds_adc_o(DDS_OUTPUT_WIDTH - 1 downto 0)),t_adc'length);

MIX_DDS: DDS1
port map(
    aclk                     => clk,
    aresetn                  => aresetn,
    s_axis_phase_tvalid      => '1',
    s_axis_phase_tdata       => dds_phase_mix_i,
    m_axis_data_tvalid       => open,
    m_axis_data_tdata        => dds_mix_o
);
dds.cos <= resize(signed(dds_mix_o(DDS_OUTPUT_WIDTH - 1 downto 0)),t_dds'length);
dds.sin <= resize(signed(dds_mix_o(DDS_OUTPUT_WIDTH - 1 + 16 downto 16)),t_dds'length);

Control_Phase: PhaseControl
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    adc_i           =>  adc,
    dds_i           =>  dds,
    control_reg_i   =>  control_reg,
    gain_reg_i      =>  gain_reg,
    pid_enable_i    =>  pid_enable,
    pid_hold_i      =>  pid_hold,
    phase_o         =>  phase_o,
    valid_phase_o   =>  valid_phase,
    phase_unwrap_o  =>  phase_unwrap,
    valid_unwrap_o  =>  valid_unwrap,
    actuator_o      =>  actuator,
    valid_act_o     =>  valid_act
);

main: process is
begin
    aresetn <= '0';
    control_reg(3 downto 0) <= X"a";
    control_reg(11 downto 4) <= X"00";
    control_reg(31) <= '0';
    control_reg(30) <= '1';
    control_reg(29) <= '0';
    control_reg(28 downto 12) <= (others => '0');
    gain_reg <= X"04000a0a";
    dds_phase_mod <= (others => '0');
    pid_enable <= '0';
    pid_hold <= '0';
    
    wait for 100 ns;
    aresetn <= '1';
    wait for 1 us;
    wait until rising_edge(clk);
    control_reg(3 downto 0) <= X"8";
    wait for 10 us;
    wait until rising_edge(clk);
    pid_enable <= '1';
    
    wait for 100 us;
    wait until rising_edge(clk);
    dds_phase_mod <= to_unsigned(536870912,32);
    wait;
end process;

end Behavioral;
