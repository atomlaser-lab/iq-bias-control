library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity Demodulator_tb is
--  Port ( );
end Demodulator_tb;

architecture Behavioral of Demodulator_tb is

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

component Demodulator is
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
        dds_regs_i      :   in  t_param_reg_array(2 downto 0);
        --
        -- Input and output data
        --
        data_i          :   in  t_adc;
        dac_o           :   out t_dac_array(1 downto 0);
        filtered_data_o :   out t_meas_array(NUM_DEMOD_SIGNALS - 1 downto 0);
        valid_o         :   out std_logic_vector(NUM_DEMOD_SIGNALS - 1 downto 0)
    );
end component;

constant DDS_OUTPUT_WIDTH   :   natural :=  10;
subtype t_dds_phase_slv is std_logic_vector(31 downto 0);
subtype t_dds_phase_combined_slv is std_logic_vector(63 downto 0);
subtype t_dds_o_slv is std_logic_vector(31 downto 0);
subtype t_dds is signed(DDS_OUTPUT_WIDTH - 1 downto 0);

type t_dds_phase_combined_slv_array is array(natural range <>) of t_dds_phase_combined_slv;
type t_dds_o_slv_array is array(natural range <>) of t_dds_o_slv;
type t_dds_array is array(natural range <>) of t_dds;

--
-- Clocks and reset
--
signal clk_period   :   time    :=  10 ns;
signal clk          :   std_logic;
signal aresetn      :   std_logic;

signal filterReg        :   t_param_reg;
signal modulation_freq  :   t_phase;
signal phase_offsets    :   t_phase_array(1 downto 0);
signal dds_regs         :   t_param_reg_array(2 downto 0);

signal data_i           :   t_adc;
signal dac_o            :   t_dac_array(1 downto 0);
signal filtered_data_o  :   t_meas_array(3 downto 0);
signal valid_o          :   std_logic_vector(3 downto 0);

signal dds_phase_i      :   t_dds_phase_combined_slv_array(1 downto 0);
signal dds_o            :   t_dds_o_slv_array(1 downto 0);
signal dds_cos, dds_sin :   t_dds_array(1 downto 0);

begin

clk_proc: process is
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

dds_regs <= (0 => std_logic_vector(modulation_freq), 1 => std_logic_vector(phase_offsets(0)), 2=> std_logic_vector(phase_offsets(1)));
uut: Demodulator
generic map(
    NUM_DEMOD_SIGNALS => 4
)
port map(
    clk                 =>  clk,
    aresetn             =>  aresetn,
    filter_reg_i        =>  filterReg,
    dds_regs_i          =>  dds_regs,
    data_i              =>  data_i,
    dac_o               =>  dac_o,
    filtered_data_o     =>  filtered_data_o,
    valid_o             =>  valid_o
);

dds_phase_i(0) <= X"00000000" & std_logic_vector(modulation_freq);
dds_phase_i(1) <= X"00000000" & std_logic_vector(shift_left(modulation_freq,1));

DDS_inst : DDS1
  PORT MAP (
    aclk                     => clk,
    aresetn                  => aresetn,
    s_axis_phase_tvalid      => '1',
    s_axis_phase_tdata       => dds_phase_i(0),
    m_axis_data_tvalid       => open,
    m_axis_data_tdata        => dds_o(0)
);

DDS2_inst : DDS1
  PORT MAP (
    aclk                     => clk,
    aresetn                  => aresetn,
    s_axis_phase_tvalid      => '1',
    s_axis_phase_tdata       => dds_phase_i(1),
    m_axis_data_tvalid       => open,
    m_axis_data_tdata        => dds_o(1)
);

dds_cos(0) <= signed(dds_o(0)(9 downto 0));
dds_cos(1) <= signed(dds_o(1)(9 downto 0));
dds_sin(0) <= signed(dds_o(0)(25 downto 16));
dds_sin(1) <= signed(dds_o(1)(25 downto 16));

--data_i <= resize(dds_cos(0) + dds_sin(1),data_i'length);
data_i <= resize(dds_cos(0),data_i'length) + resize(dds_sin(1),data_i'length);

main_proc: process is
begin
    --
    -- Initialize the registers and reset
    --
    aresetn <= '0';
    wait for 50 ns;
    modulation_freq <= to_unsigned(171798692,modulation_freq'length);
    phase_offsets(0) <= (others => '0');
    phase_offsets(1) <= (others => '0');
    filterReg <= X"00ff0009";
    wait for 200 ns;
    aresetn <= '1';
    wait for 10 us;
    wait until rising_edge(clk);
    filterReg <= X"00ff000a";
--    wait for 50 us;
--    phase_offsets(1) <= (30 => '1', others => '0');
    
    wait;
end process; 

end Behavioral;
