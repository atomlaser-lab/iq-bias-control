library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity Demodulator is
    generic(
        NUM_DEMOD_SIGNALS : natural :=  3
    );
    port(
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        --
        -- Registers
        --
        filter_reg_i    :   in  t_param_reg;
        dds_regs_i      :   in  t_param_reg_array(3 downto 0);
        --
        -- Input and output data
        --
        data_i          :   in  t_adc;
        dac_o           :   out t_dac_array(1 downto 0);
        filtered_data_o :   out t_meas_array(NUM_DEMOD_SIGNALS - 1 downto 0);
        valid_o         :   out std_logic_vector(NUM_DEMOD_SIGNALS - 1 downto 0)
    );
end Demodulator;

architecture Behavioral of Demodulator is

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

COMPONENT Multiplier1
PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(23 DOWNTO 0) 
);
END COMPONENT;

COMPONENT Output_Scaling_Multiplier
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(17 DOWNTO 0) 
  );
END COMPONENT;

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
-- DDS constants and types
-- It looks like overkill, but it's useful for procedurally generating
-- multiple blocks of code.
--
constant DDS_OUTPUT_WIDTH   :   natural :=  10;
-- Used for phase inputs to DDSs
subtype t_dds_phase_combined_slv    is std_logic_vector(63 downto 0);
type t_dds_phase_combined_slv_array is array(natural range <>) of t_dds_phase_combined_slv;
-- Used for raw (combined cos/sin) DDS outputs
subtype t_dds_o_slv                 is std_logic_vector(31 downto 0);
type t_dds_o_slv_array              is array(natural range <>) of t_dds_o_slv;
-- Used for separated DDS outputs
subtype t_dds                       is signed(DDS_OUTPUT_WIDTH - 1 downto 0);
type t_dds_array                    is array(natural range <>) of t_dds;
-- Multiplier outputs
constant MULT_OUTPUT_WIDTH  :   natural :=  ADC_ACTUAL_WIDTH + DDS_OUTPUT_WIDTH;
type t_mult_o_array is array(natural range <>) of std_logic_vector(MULT_OUTPUT_WIDTH - 1 downto 0);
-- CIC filter outputs
constant CIC_OUTPUT_WIDTH   :   natural :=  64;
type t_cic_o_array is array(natural range <>) of std_logic_vector(CIC_OUTPUT_WIDTH - 1 downto 0);

--
-- DDS signals
--
signal modulation_freq                  :   t_phase;
signal phase_offsets                    :   t_phase_array(2 downto 0);
signal dds_phase_i                      :   t_dds_phase_combined_slv_array(3 downto 0);
signal dds_o                            :   t_dds_o_slv_array(3 downto 0);
signal dds_cos, dds_sin                 :   t_dds_array(3 downto 0);
signal dds_cos_scale, dds_sin_scale     :   std_logic_vector(17 downto 0);
--
-- Multiplier signals
--
signal adc_reduced                      :   signed(ADC_ACTUAL_WIDTH - 1 downto 0);
signal mult_o                           :   t_mult_o_array(NUM_DEMOD_SIGNALS - 1 downto 0); 
--
-- Filter signals
--
signal cicLog2Rate                      :   unsigned(3 downto 0);
signal cicShift                         :   integer;
signal setShift                         :   signed(7 downto 0);
signal filterConfig, filterConfig_old   :   std_logic_vector(15 downto 0);
signal valid_config                     :   std_logic;
signal filter_o                         :   t_cic_o_array(NUM_DEMOD_SIGNALS - 1 downto 0);
signal valid_filter_o                   :   std_logic_vector(NUM_DEMOD_SIGNALS - 1 downto 0);
signal dds_output_scale                 :   std_logic_vector(7 downto 0);

begin
--
-- Parse registers
--
cicLog2Rate <= unsigned(filter_reg_i(3 downto 0));
setShift <= signed(filter_reg_i(11 downto 4));
dds_output_scale <= filter_reg_i(23 downto 16);

modulation_freq <= unsigned(dds_regs_i(0));
phase_offsets(0) <= unsigned(dds_regs_i(1));
phase_offsets(1) <= unsigned(dds_regs_i(2));
phase_offsets(2) <= unsigned(dds_regs_i(3));
--
-- Generate DDS signals.  Note dds_phase_i(2) has a doubled frequency
--
dds_phase_i(0) <= X"00000000" & std_logic_vector(modulation_freq);
dds_phase_i(1) <= std_logic_vector(phase_offsets(0)) & std_logic_vector(modulation_freq);
dds_phase_i(2) <= std_logic_vector(phase_offsets(1)) & std_logic_vector(shift_left(modulation_freq,1));
dds_phase_i(3) <= std_logic_vector(phase_offsets(2)) & std_logic_vector(modulation_freq);
-- Procedurally generate all DDS instances
DDS_GEN: for I in 0 to dds_phase_i'length - 1 generate
    DDS_X: DDS1
    PORT MAP (
        aclk                     => clk,
        aresetn                  => aresetn,
        s_axis_phase_tvalid      => '1',
        s_axis_phase_tdata       => dds_phase_i(I),
        m_axis_data_tvalid       => open,
        m_axis_data_tdata        => dds_o(I)
    );
    dds_cos(I) <= signed(dds_o(I)(DDS_OUTPUT_WIDTH - 1 downto 0));
    dds_sin(I) <= signed(dds_o(I)(16 + DDS_OUTPUT_WIDTH - 1 downto 16));
end generate DDS_GEN;

--
-- DAC outputs are scaled: these are dds_cos(0) and dds_sin(0)
--
OutputMultiplierCos : Output_Scaling_Multiplier
port map(
    clk     =>  clk,
    A       =>  std_logic_vector(dds_cos(0)),
    B       =>  dds_output_scale,
    P       =>  dds_cos_scale
);
OutputMultiplierSin : Output_Scaling_Multiplier
port map(
    clk     =>  clk,
    A       =>  std_logic_vector(dds_sin(3)),
    B       =>  dds_output_scale,
    P       =>  dds_sin_scale
);
-- Re-scale the outputs so that a scale factor of 255 gives full-scale output
dac_o(0) <= resize(shift_right(signed(dds_cos_scale),dds_cos_scale'length - DAC_ACTUAL_WIDTH),DAC_WIDTH);
dac_o(1) <= resize(shift_right(signed(dds_sin_scale),dds_sin_scale'length - DAC_ACTUAL_WIDTH),DAC_WIDTH);

--
-- Multiply DDS signals with single input signal
--
adc_reduced <= resize(data_i,adc_reduced'length);

DDSMult1 : Multiplier1
  PORT MAP (
    CLK => clk,
    A => std_logic_vector(adc_reduced),
    B => std_logic_vector(dds_sin(1)),
    P => mult_o(0)
  );
  
DDSMult2 : Multiplier1
  PORT MAP (
    CLK => clk,
    A => std_logic_vector(adc_reduced),
    B => std_logic_vector(dds_cos(1)),
    P => mult_o(1)
  );
DDSMult3 : Multiplier1
  PORT MAP (
    CLK => clk,
    A => std_logic_vector(adc_reduced),
    B => std_logic_vector(dds_sin(2)),
    P => mult_o(2)
  );
-- Only use if the quadrature phase part of the 2nd harmonic signal is to be captured
MULT_GEN: if NUM_DEMOD_SIGNALS = 4 generate
DDSMult4 : Multiplier1
  PORT MAP (
    CLK => clk,
    A => std_logic_vector(adc_reduced),
    B => std_logic_vector(dds_cos(2)),
    P => mult_o(3)
  );
  end generate MULT_GEN;

--
-- Implement filters
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
-- Procedurally generate all CIC filters
FILT_GEN: for I in 0 to NUM_DEMOD_SIGNALS - 1 generate
    Filt_X : CICfilter
    PORT MAP (
        aclk                        => clk,
        aresetn                     => aresetn,
        s_axis_config_tdata         => filterConfig,
        s_axis_config_tvalid        => valid_config,
        s_axis_config_tready        => open,
        s_axis_data_tdata           => mult_o(I),
        s_axis_data_tvalid          => '1',
        s_axis_data_tready          => open,
        m_axis_data_tdata           => filter_o(I),
        m_axis_data_tvalid          => valid_filter_o(I)
    );
    filtered_data_o(I) <= resize(shift_right(signed(filter_o(I)),cicShift + to_integer(setShift)),t_meas'length);
end generate FILT_GEN;

valid_o <= valid_filter_o;

end Behavioral;
