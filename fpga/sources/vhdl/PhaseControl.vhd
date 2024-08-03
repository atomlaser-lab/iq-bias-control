library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseControl is
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
        iq_o            :   out t_iq_combined;
        valid_phase_o   :   out std_logic;
        phase_unwrap_o  :   out t_phase;
        valid_unwrap_o  :   out std_logic;
        actuator_o      :   out signed;
        valid_act_o     :   out std_logic
    );
end PhaseControl;

architecture Behavioral of PhaseControl is

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
        iq_o            :   out t_iq_combined;      --Output I/Q data
        valid_o         :   out std_logic           --Output phase valid signal
    );
end component;

component PhaseUnwrap is
    port(
        --
        -- Clocking and reset
        --
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        --
        -- Control
        --
        enable_i        :   in  std_logic;
        --
        -- Input/output data
        --
        phase_i         :   in  t_phase;
        valid_i         :   in  std_logic;
        phase_o         :   out t_phase;
        valid_o         :   out std_logic
    );
end component;

component PIDController is
    port(
        --
        -- Clocking and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Inputs
        --
        meas_i      :   in  signed;
        control_i   :   in  signed;
        valid_i     :   in  std_logic;
        --
        -- Parameters
        --
        enable_i    :   in  std_logic;
        polarity_i  :   in  std_logic;
        hold_i      :   in  std_logic;
        gains       :   in  t_param_reg;
        --
        -- Outputs
        --
        valid_o     :   out std_logic;
        data_o      :   out signed
    );
end component;

signal enable       :   std_logic;          -- PID enable
signal polarity     :   std_logic;
signal hold         :   std_logic;

constant ZERO_PHASE     :   t_phase     :=  (others => '0');

signal control          :   t_phase;
signal phase            :   t_phase;
signal valid_phase      :   std_logic;
signal unwrapped_phase  :   t_phase;
signal unwrapped_valid  :   std_logic;
signal valid_act        :   std_logic;


begin
--
-- Get software defined enable setting
--
enable <= control_reg_i(31) or pid_enable_i;
polarity <= control_reg_i(30);
hold <= control_reg_i(29) or pid_hold_i;

control <= shift_left(resize(signed(control_reg_i(27 downto 12)),control'length),control'length - 16);
--
-- Calculate phase
--
GetPhase: PhaseCalculation
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    adc_i           =>  adc_i,
    dds_i           =>  dds_i,
    filter_reg_i    =>  control_reg_i,
    phase_o         =>  phase,
    iq_o            =>  iq_o,
    valid_o         =>  valid_phase
);
phase_o <= phase;
valid_phase_o <= valid_phase;
--
-- Unwrap phase
--
Unwrap_Phase: PhaseUnwrap
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    enable_i        =>  enable,
    phase_i         =>  phase,
    valid_i         =>  valid_phase,
    phase_o         =>  unwrapped_phase,
    valid_o         =>  unwrapped_valid
);
phase_unwrap_o <= unwrapped_phase;
valid_unwrap_o <= unwrapped_valid;
--
-- Control
--
PhasePID: PIDController
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    meas_i          =>  unwrapped_phase,
    control_i       =>  control,
    valid_i         =>  unwrapped_valid,
    enable_i        =>  enable,
    polarity_i      =>  polarity,
    hold_i          =>  hold,
    gains           =>  gain_reg_i,
    valid_o         =>  valid_act,
    data_o          =>  actuator_o
);

valid_act_o <= valid_act when enable = '1' else unwrapped_valid;

end Behavioral;