library IEEE;
library work;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity topmod_tb is
--  Port ( );
end topmod_tb;

architecture Behavioral of topmod_tb is

component topmod is
    port (
        sysClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        ext_i           :   in  std_logic_vector(7 downto 0);

        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0);                   --Response in
        
        ext_o           :   out std_logic_vector(7 downto 0);
        led_o           :   out std_logic_vector(7 downto 0);
        pwm_o           :   out std_logic_vector(3 downto 0);
        
        adcClk          :   in  std_logic;
        adcClkx2        :   in  std_logic;
        adcData_i       :   in  std_logic_vector(31 downto 0);
       
        m_axis_tdata    :   out std_logic_vector(31 downto 0);
        m_axis_tvalid   :   out std_logic
      
    );
end component;

component AXI_Tester is
    port (
        --
        -- Clocking and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Main AXI data to transfer
        --
        axi_addresses   :   in  t_axi_addr_array;
        axi_data        :   in  t_axi_data_array;
        start_i         :   in  std_logic;
        --
        -- Single data to transfer
        --
        axi_addr_single :   in  t_axi_addr;
        axi_data_single :   in  t_axi_data;
        start_single_i  :   in  std_logic_vector(1 downto 0);
        --
        -- Signals
        --
        bus_m           :   out t_axi_bus_master;
        bus_s           :   in  t_axi_bus_slave
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
signal clk_period   :   time    :=  8 ns;
signal sysClk,adcClk,adcClkx2:   std_logic;
signal aresetn      :   std_logic;
--
-- ADC and DAC data
--
signal adcData_i    :   std_logic_vector(31 downto 0);
signal m_axis_tdata :   std_logic_vector(31 downto 0);
signal m_axis_tvalid:   std_logic;
signal pwm_o        :   std_logic_vector(3 downto 0);
--
-- External inputs and outputs
--
signal ext_i,ext_o  :   std_logic_vector(7 downto 0);
--
-- AXI signals
--
signal addr_i                   :   unsigned(AXI_ADDR_WIDTH-1 downto 0);
signal writeData_i, readData_o  :   std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal dataValid_i, resp_o      :   std_logic_vector(1 downto 0);
signal bus_m                    :   t_axi_bus_master;
signal bus_s                    :   t_axi_bus_slave;

--
-- AXI data
--
constant axi_addresses   :   t_axi_addr_array(25 downto 0) := (0  =>  X"00000040",
                                                               1  =>  X"00000000",
                                                               2  =>  X"00000004",
                                                               3  =>  X"00000008",
                                                               4  =>  X"00000014",
                                                               5  =>  X"00000030",
                                                               6  =>  X"00000018",
                                                               7  =>  X"00000020",
                                                               8  =>  X"00100000",
                                                               9  =>  X"00000050",
                                                               10  =>  X"00000054",
                                                               11  =>  X"00000058",
                                                               12  =>  X"0000005c",
                                                               13  =>  X"00100004",
                                                               14  =>  X"00000100",
                                                               15  =>  X"00000104",
                                                               16  =>  X"00000108",
                                                               17  =>  X"0000010c",
                                                               18  =>  X"00000110",
                                                               19  =>  X"00000120",
                                                               20  =>  X"00000124",
                                                               21  =>  X"00000128",
                                                               22  =>  X"0000012c",
                                                               23  =>  X"00000060",
                                                               24  =>  X"00000200",
                                                               25  =>  X"00000204");
                                                     

constant axi_data   :   t_axi_data_array(25 downto 0) := (0  =>  X"0000001a",
                                                          1  =>  X"00000000",
                                                          2  =>  X"00000000",
                                                          3  =>  X"00ff0fdd",
                                                          4  =>  X"083126e9",
                                                          5  =>  X"00000000",
                                                          6  =>  X"6e147ae1",
                                                          7  =>  X"727d27d2",
                                                          8  =>  X"00000fa0",
                                                          9  =>  X"000000b7",
                                                          10  =>  X"00000191",
                                                          11  =>  X"0000021c",
                                                          12  =>  X"00000000",
                                                          13  =>  X"00000000",
                                                          14  =>  X"00000000",
                                                          15  =>  X"00000000",
                                                          16  =>  X"00000000",
                                                          17  =>  X"00000000",
                                                          18  =>  X"00000000",
                                                          19  =>  X"000ffc00",
                                                          20  =>  X"000ffc00",
                                                          21  =>  X"000ffc00",
                                                          22  =>  X"03bf0000",
                                                          23  =>  X"00000000",
                                                          24  =>  X"0000000a",
                                                          25  =>  X"08000000");
                                                               
signal dds_phase_inc_reg            :   t_param_reg;

--
-- AXI control signals
--
signal startAXI     :   std_logic;
signal axi_addr_single  :   t_axi_addr;
signal axi_data_single  :   t_axi_data;
signal start_single_i   :   std_logic_vector(1 downto 0);

signal dds1_o, dds2_o             : std_logic_vector(31 downto 0);
signal dds_phase_i, dds2_phase_i  :   std_logic_vector(63 downto 0);
signal dds_phase_off_test   :   unsigned(31 downto 0);
signal dds2_phase_off_test   :   unsigned(31 downto 0);

signal adc_data :   signed(15 downto 0);

begin

clk_proc: process is
begin
    sysClk <= '0';
    adcClk <= '0';
    wait for clk_period/2;
    sysClk <= '1';
    adcClk <= '1';
    wait for clk_period/2;
end process;

clkx2_proc: process is
begin
    adcClkx2 <= '0';
    wait for clk_period/4;
    adcClkx2 <= '1';
    wait for clk_period/4;
end process;

uut: topmod
port map(
    sysclk          =>  sysclk,
    adcclk          =>  adcclk,
    adcClkx2        =>  adcClkx2,
    aresetn         =>  aresetn,
    addr_i          =>  addr_i,
    writeData_i     =>  writeData_i,
    dataValid_i     =>  dataValid_i,
    readData_o      =>  readData_o,
    resp_o          =>  resp_o,
    ext_i           =>  ext_i,
    ext_o           =>  ext_o,
    pwm_o           =>  pwm_o,
    m_axis_tdata    =>  m_axis_tdata,
    m_axis_tvalid   =>  m_axis_tvalid,
    adcData_i       =>  adcData_i
);

AXI: AXI_Tester
port map(
    clk             =>  sysClk,
    aresetn         =>  aresetn,
    axi_addresses   =>  axi_addresses,
    axi_data        =>  axi_data,
    start_i         =>  startAXI,
    axi_addr_single =>  axi_addr_single,
    axi_data_single =>  axi_data_single,
    start_single_i  =>  start_single_i,
    bus_m           =>  bus_m,
    bus_s           =>  bus_s
);

DDS_inst : DDS1
  PORT MAP (
    aclk                     => adcClk,
    aresetn                  => aresetn,
    s_axis_phase_tvalid      => '1',
    s_axis_phase_tdata       => dds_phase_i,
    m_axis_data_tvalid       => open,
    m_axis_data_tdata        => dds1_o
);

DDS2_inst : DDS1
  PORT MAP (
    aclk                     => adcClk,
    aresetn                  => aresetn,
    s_axis_phase_tvalid      => '1',
    s_axis_phase_tdata       => dds2_phase_i,
    m_axis_data_tvalid       => open,
    m_axis_data_tdata        => dds2_o
);

dds_phase_inc_reg <= axi_data(4);

dds_phase_i <= std_logic_vector(dds_phase_off_test) & dds_phase_inc_reg;
dds2_phase_i <= std_logic_vector(dds2_phase_off_test) & std_logic_vector(shift_left(unsigned(dds_phase_inc_reg),1));

addr_i <= bus_m.addr;
writeData_i <= bus_m.data;
dataValid_i <= bus_m.valid;
bus_s.data <= readData_o;
bus_s.resp <= resp_o;


             
adc_data <= shift_left(resize(signed(dds1_o(9 downto 0)),16),0);-- + resize(signed(dds2_o(25 downto 16)),16);
adcData_i <= std_logic_vector(shift_left(resize(signed(dds2_o(25 downto 16)),16),0)) & std_logic_vector(adc_data);
--adcData_i <= m_axis_tdata;




main_proc: process is
begin
    --
    -- Initialize the registers and reset
    --
    aresetn <= '0';
    startAXI <= '0';
    ext_i <= (others => '0');

    dds_phase_off_test <= to_unsigned(0,dds_phase_off_test'length);
    dds2_phase_off_test <= to_unsigned(0,dds2_phase_off_test'length);
    
    axi_addr_single <= (others => '0');
    axi_data_single <= (others => '0');
    start_single_i <= "00";
    wait for 200 ns;
    aresetn <= '1';
    wait for 100 ns;
    --
    -- Start AXI transfer
    --
    wait until rising_edge(sysclk);
    startAXI <= '1';
    wait until rising_edge(sysclk);
    startAXI <= '0';
    wait for 10 us;
    --
    -- Change filter rate
    --
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0060";
--    axi_data_single <= X"0000" & "1010000000001111";
--    start_single_i <= "01";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
    --
    -- Change demodulation phase for 2x freq
    --
--    wait for 50 us;
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0028";
--    axi_data_single <= std_logic_vector(shift_left(to_unsigned(1,32),30));
--    start_single_i <= "01";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
    --
    -- Change the DDS2 phase
    --
--    wait for 50 us;
--    dds2_phase_off_test <= to_unsigned(1073741824,dds2_phase_off_test'length);
    
    --
    -- These commands test the FIFO read out
    --
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0080";
--    axi_data_single <= X"0000_0002";
--    start_single_i <= "01";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0080";
--    axi_data_single <= X"0000_0001";
--    start_single_i <= "01";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
    
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0094";
--    axi_data_single <= X"0000_0000";
--    start_single_i <= "10";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
    
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0094";
--    axi_data_single <= X"0000_0000";
--    start_single_i <= "10";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
    
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0094";
--    axi_data_single <= X"0000_0000";
--    start_single_i <= "10";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
    
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"0000_0094";
--    axi_data_single <= X"0000_0000";
--    start_single_i <= "10";
--    wait until bus_s.resp(0) = '1';
--    start_single_i <= "00";
--    wait for 500 ns;
    

    wait;
end process; 


end Behavioral;
