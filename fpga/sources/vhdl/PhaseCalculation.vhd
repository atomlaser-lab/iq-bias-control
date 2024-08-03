library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

--
-- This module computes a phase from I/Q demodulation of a single ADC signal
-- assuming it is at the frequency given by freq_i
--
entity PhaseCalculation is
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
        iq_o            :   out t_iq_combined;      --Output I/Q data
        valid_o         :   out std_logic           --Output phase valid signal
    );
end PhaseCalculation;

architecture Behavioral of PhaseCalculation is

--
-- Demodulation requires a mixer
--
COMPONENT Multiplier1
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;
--
-- Demodulation also requires a low-pass filter.  We use a CIC filter
-- to reduce the data rate from 125 MSPS to something more reasonable
--
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
--
-- This component computes the phase using the I and Q signals
-- using the CORDIC algorithm
--
COMPONENT PhaseCalc
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) 
  );
END COMPONENT;
--
-- Constants and types
--
constant CIC_OUTPUT_WIDTH   :   natural :=  64;
subtype t_cic_o is std_logic_vector(CIC_OUTPUT_WIDTH - 1 downto 0);
type t_cic_o_array is array(natural range <>) of t_cic_o;

--
-- Mixing signals
--
signal dds_slv          :   t_dds_combined_slv;
signal adc_slv          :   std_logic_vector(ADC_ACTUAL_WIDTH - 1 downto 0);
signal Iraw, Qraw       :   std_logic_vector(ADC_ACTUAL_WIDTH + DDS_OUTPUT_WIDTH - 1 downto 0);

--
-- Downsampling/fast averaging signals
--
signal cicLog2Rate                      :   unsigned(3 downto 0);
signal cicShift                         :   integer :=  0;
signal setShift                         :   integer :=  0;
signal filterConfig, filterConfig_old   :   std_logic_vector(15 downto 0);
signal valid_config                     :   std_logic;


signal cicI_o, cicQ_o       :   t_cic_o;
signal validIcic, validQcic :   std_logic;

signal Iphase_i, Qphase_i   :   std_logic_vector(23 downto 0);
signal validPhase_i         :   std_logic;

--
-- Phase calculation signals
--
signal tdataPhase   :   std_logic_vector(47 downto 0);
signal phase        :   std_logic_vector(CORDIC_WIDTH - 1 downto 0);
signal validPhase   :   std_logic;


begin

--
-- Parse parameters
--
cicLog2Rate <= unsigned(filter_reg_i(3 downto 0));
setShift <= to_integer(signed(filter_reg_i(11 downto 4)));
--
-- Multiply the input signal with the I and Q mixing signals
--
dds_slv.cos <= std_logic_vector(dds_i.cos);
dds_slv.sin <= std_logic_vector(dds_i.sin);
adc_slv <= std_logic_vector(resize(adc_i,adc_slv'length));
I_Mixer: Multiplier1
port map(
    CLK =>  clk,
    A   =>  adc_slv,
    B   =>  dds_slv.cos,
    P   =>  Iraw
);

Q_Mixer: Multiplier1
port map(
    CLK =>  clk,
    A   =>  adc_slv,
    B   =>  dds_slv.sin,
    P   =>  Qraw
);

--
-- Filter raw I and Q
--
cicShift <= to_integer(cicLog2Rate)+ to_integer(cicLog2Rate)+ to_integer(cicLog2Rate);
filterConfig <= std_logic_vector(shift_left(to_unsigned(1, filterConfig'length),to_integer(cicLog2Rate)));
--
-- This creates a signal that is high for a single clock cycle when the
-- filter rate changes
--
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

I_decimate: CICfilter
port map(
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_config_tdata     => filterConfig,
    s_axis_config_tvalid    => valid_config,
    s_axis_config_tready    => open,
    s_axis_data_tdata       => Iraw,
    s_axis_data_tvalid      => '1',
    s_axis_data_tready      => open,
    m_axis_data_tdata       => cicI_o,
    m_axis_data_tvalid      => validIcic
);

Q_decimate: CICfilter
port map(
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_config_tdata     => filterConfig,
    s_axis_config_tvalid    => valid_config,
    s_axis_config_tready    => open,
    s_axis_data_tdata       => Qraw,
    s_axis_data_tvalid      => '1',
    s_axis_data_tready      => open,
    m_axis_data_tdata       => cicQ_o,
    m_axis_data_tvalid      => validQcic
);

--
-- Compute phase via arctan using the CORDIC algorithm.  This version uses SCALED RADIANS for the output
-- When using CORDIC ARCTAN, there are two options for the output phase.
--
-- Option 1: Radians.  Here, the output phase is a signed value in radians in 2QN format
-- To convert the integer value to radians, compute <OUTPUT INTEGER>/2^(PHASE_WIDTH - 3).  Note the lack of a pi multiplier!
--
-- Option 2: Scaled radians.  Here, the output phase is a signed value as a fraction of a radian.
-- To convert to radians, compute <OUTPUT INTEGER>/2^(PHASE_WIDTH - 3) * PI.  Note the PI! 
--
validPhase_i <= validQcic and validIcic;
Iphase_i <= std_logic_vector(resize(shift_right(signed(cicI_o),cicShift + setShift),Iphase_i'length));
Qphase_i <= std_logic_vector(resize(shift_right(signed(cicQ_o),cicShift + setShift),Qphase_i'length));
tdataPhase <= Qphase_i & Iphase_i;
MakePhase: PhaseCalc
PORT MAP (
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_cartesian_tvalid => validPhase_i,
    s_axis_cartesian_tdata  => tdataPhase,
    m_axis_dout_tvalid      => validPhase,
    m_axis_dout_tdata       => phase
);

valid_o <= validPhase;
phase_o <= resize(signed(phase),phase_o'length);
iq_o <= (I => signed(Iphase_i), Q => signed(Qphase_i), valid => validPhase_i);

end Behavioral;
