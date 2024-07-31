library IEEE;
library work;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseCalculation_tb is
--  Port ( );
end PhaseCalculation_tb;

architecture Behavioral of PhaseCalculation_tb is

component PhaseCalculation is
    port(
        clk             :   in  std_logic;          --Master system clock
        aresetn         :   in  std_logic;          --Asynchronous active-low reset
        
        --
        -- Input data
        --
        adc_i           :   in  t_adc;
        dds_i           :   in  t_dds_combined;
        --
        -- Registers
        --
        filter_reg_i    :   in  t_param_reg;
        
        phase_o         :   out t_phase;            --Output phase
        valid_o         :   out std_logic           --Output phase valid signal
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
--
-- Parameters and registers
--
signal filter_reg   :   t_param_reg;
signal dds_phase_adc_i, dds_phase_mix_i  :   std_logic_vector(63 downto 0);
--
-- Output data
--
signal phase_o      :   t_phase;
signal valid_phase  :   std_logic;


begin

clk_proc: process is
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

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

PhaseCalc: PhaseCalculation
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    adc_i           =>  adc,
    dds_i           =>  dds,
    filter_reg_i    =>  filter_reg,
    phase_o         =>  phase_o,
    valid_o         =>  valid_phase
);

main: process is
begin
    aresetn <= '0';
    filter_reg(3 downto 0) <= X"8";
    filter_reg(11 downto 4) <= X"00";
    filter_reg(filter_reg'left downto 12) <= (others => '0');
    dds_phase_adc_i <= X"00000000" & std_logic_vector(to_unsigned(171798692,32));
    dds_phase_mix_i <= X"00000000" & std_logic_vector(to_unsigned(171798692,32));
    wait for 100 ns;
    aresetn <= '1';
    wait for 1 us;
    wait until rising_edge(clk);
    filter_reg(3 downto 0) <= X"a";
    wait for 20 us;
    wait until rising_edge(clk);
    dds_phase_adc_i <= std_logic_vector(to_unsigned(536870912,32)) & std_logic_vector(to_unsigned(171798692,32));
    wait;
end process;

end Behavioral;
