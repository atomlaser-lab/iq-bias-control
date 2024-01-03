library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

--
-- Example top-level module for parsing simple AXI instructions
--
entity topmod is
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
end topmod;


architecture Behavioural of topmod is

ATTRIBUTE X_INTERFACE_INFO : STRING;
ATTRIBUTE X_INTERFACE_INFO of m_axis_tdata: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TDATA";
ATTRIBUTE X_INTERFACE_INFO of m_axis_tvalid: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TVALID";
ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
ATTRIBUTE X_INTERFACE_PARAMETER of m_axis_tdata: SIGNAL is "CLK_DOMAIN system_AXIS_Red_Pitaya_ADC_0_0_adc_clk,FREQ_HZ 125000000";
ATTRIBUTE X_INTERFACE_PARAMETER of m_axis_tvalid: SIGNAL is "CLK_DOMAIN system_AXIS_Red_Pitaya_ADC_0_0_adc_clk,FREQ_HZ 125000000";

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
        valid_o         :   out std_logic
    );
end component;

component FIFOHandler is
    port(
        wr_clk      :   in  std_logic;
        rd_clk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        valid_i     :   in  std_logic;
        
        fifoReset   :   in  std_logic;
        bus_m       :   in  t_fifo_bus_master;
        bus_s       :   out t_fifo_bus_slave
    );
end component;

component SaveADCData is
    port(
        readClk     :   in  std_logic;          --Clock for reading data
        writeClk    :   in  std_logic;          --Clock for writing data
        aresetn     :   in  std_logic;          --Asynchronous reset
        
        data_i      :   in  std_logic_vector;   --Input data, maximum length of 32 bits
        valid_i     :   in  std_logic;          --High for one clock cycle when data_i is valid
        
        trigEdge    :   in  std_logic;          --'0' for falling edge, '1' for rising edge
        delay       :   in  unsigned;           --Acquisition delay
        numSamples  :   in  t_mem_addr;         --Number of samples to save
        trig_i      :   in  std_logic;          --Start trigger
        
        bus_m       :   in  t_mem_bus_master;   --Master memory bus
        bus_s       :   out t_mem_bus_slave     --Slave memory bus
    );
end component;

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
-- AXI communication signals
--
signal comState             :   t_status                        :=  idle;
signal bus_m                :   t_axi_bus_master                :=  INIT_AXI_BUS_MASTER;
signal bus_s                :   t_axi_bus_slave                 :=  INIT_AXI_BUS_SLAVE;
signal reset                :   std_logic;
--
-- Registers
--
signal triggers             :   t_param_reg;
signal outputReg            :   t_param_reg;
signal filterReg            :   t_param_reg;
-- DDS registers
signal dds_phase_inc_reg    :   t_param_reg;
signal dds_phase_off_reg    :   t_param_reg;
signal dds2_phase_off_reg   :   t_param_reg;
signal dds_regs             :   t_param_reg_array(2 downto 0);
-- PWM register
signal pwmReg               :   t_param_reg;
-- FIFO register
signal fifoReg              :   t_param_reg;

--
-- DDS signals
--
signal dac_o                :   t_dac_array(1 downto 0);
signal filtered_data        :   t_meas_array(3 downto 0);
signal filter_valid         :   std_logic;
--
-- ADC signals
--
signal adc                  :   signed(ADC_ACTUAL_WIDTH - 1 downto 0);

--
-- FIFO signals
--
constant NUM_FIFOS          :   natural :=  filtered_data'length;
type t_fifo_data_array is array(natural range <>) of std_logic_vector(FIFO_WIDTH - 1 downto 0);

signal fifoData             :   t_fifo_data_array(NUM_FIFOS - 1 downto 0);
signal fifoValid            :   std_logic_vector(NUM_FIFOS - 1 downto 0);
signal fifo_bus             :   t_fifo_bus_array(NUM_FIFOS - 1 downto 0)  :=  (others => INIT_FIFO_BUS);
signal enableFIFO           :   std_logic;
signal fifoReset            :   std_logic;
--
-- Memory signals
--
signal delay        :   unsigned(3 downto 0);
signal numSamples   :   t_mem_addr;
signal mem_bus      :   t_mem_bus;
signal mem_bus_m    :   t_mem_bus_master;
signal mem_bus_s    :   t_mem_bus_slave;
signal memTrig      :   std_logic;
--
-- PID signals
--
signal enable, polarity, valid_i        : std_logic;
signal control, measurement    : signed(15 downto 0);
signal pidvalid_o              : std_logic;
signal pid_o                   : signed(15 downto 0);
--
-- PWM signals
--
signal pwm_data     : t_pwm_array(3 downto 0);
begin

--
-- DAC Outputs
--
m_axis_tdata <= std_logic_vector(dac_o(1)) & std_logic_vector(dac_o(0));
m_axis_tvalid <= '1';
--
-- PWM outputs
--
pwm_data(0) <= unsigned(pwmReg(7 downto 0));
pwm_data(1) <= unsigned(pwmReg(15 downto 8));
pwm_data(2) <= unsigned(pwmReg(23 downto 16));
pwm_data(3) <= unsigned(pwmReg(31 downto 24));
PWM1: PWM_Generator
port map(
  clk     =>  adcClkx2,
  aresetn =>  aresetn,
  data_i  =>  pwm_data,
  pwm_o   =>  pwm_o
);
-- 
-- Digital outputs
--
ext_o <= outputReg(7 downto 0);
led_o <= outputReg(15 downto 8);

--
-- Modulator/demodulator component
--
adc <= resize(signed(adcData_i(15 downto 0)), adc'length);
dds_regs <= (0 => dds_phase_inc_reg, 1 => dds_phase_off_reg, 2 => dds2_phase_off_reg);
Main_Demodulator: Demodulator
generic map(
    NUM_DEMOD_SIGNALS   =>  filtered_data'length
)
port map(
    clk             =>  adcClk,
    aresetn         =>  aresetn,
    filter_reg_i    =>  filterReg,
    dds_regs_i      =>  dds_regs,
    data_i          =>  adc,
    dac_o           =>  dac_o,
    filtered_data_o =>  filtered_data,
    valid_o         =>  filter_valid
);

--
-- Collect demodulated data at lower sampling rate in FIFO buffers
-- to be read out continuously by CPU
--
enableFIFO <= fifoReg(0);
fifoReset <= fifoReg(1);
FIFO_GEN: for I in 0 to NUM_FIFOS - 1 generate
    fifoData(I) <= std_logic_vector(resize(filtered_data(I),FIFO_WIDTH));
    fifoValid(I) <= filter_valid and enableFIFO;
    PhaseMeas_FIFO_NORMAL_X: FIFOHandler
    port map(
        wr_clk      =>  adcClk,
        rd_clk      =>  sysClk,
        aresetn     =>  aresetn,
        data_i      =>  fifoData(I),
        valid_i     =>  fifoValid(I),
        fifoReset   =>  fifoReset,
        bus_m       =>  fifo_bus(I).m,
        bus_s       =>  fifo_bus(I).s
  );
end generate FIFO_GEN;
--
-- Save ADC data for debugging purposes
--
delay     <= (others => '0');
memTrig   <= triggers(0);
SaveData: SaveADCData
port map(
    readClk     =>  sysClk,
    writeClk    =>  adcClk,
    aresetn     =>  aresetn,
    data_i      =>  adcData_i,
    valid_i     =>  '1',
    trigEdge    =>  '1',
    delay       =>  delay,
    numSamples  =>  numSamples,
    trig_i      =>  memTrig,
    bus_m       =>  mem_bus.m,
    bus_s       =>  mem_bus.s
);
--
-- AXI communication routing - connects bus objects to std_logic signals
--
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;

Parse: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        reset <= '0';
        bus_s <= INIT_AXI_BUS_SLAVE;
        triggers <= (others => '0');
        outputReg <= (others => '0');
        filterReg <= X"0000000a";
        dds_phase_off_reg <= (others => '0');
        dds_phase_inc_reg <= std_logic_vector(to_unsigned(34359738, 32)); -- 1 MHz with 32 bit DDS and 125 MHz clk freq
        --dds2 
        dds2_phase_off_reg <= (others => '0');
        pwmReg <= (others => '0');
       -- new_register <= (others => '0'); -- dds2
        --
        -- FIFO registers
        --
        fifoReg <= (others => '0');
        fifo_bus(0).m.status <= idle;
        fifo_bus(1).m.status <= idle;
        fifo_bus(2).m.status <= idle;
        --
        -- Memory signals
        --
        numSamples <= to_unsigned(4000,numSamples'length);
        mem_bus.m <= INIT_MEM_BUS_MASTER; 

    elsif rising_edge(sysClk) then
        FSM: case(comState) is
            when idle =>
                triggers <= (others => '0');
                reset <= '0';
                bus_s.resp <= "00";
                mem_bus.m.reset <= '0';
                if bus_m.valid(0) = '1' then
                    comState <= processing;
                end if;

            when processing =>
                AddrCase: case(bus_m.addr(31 downto 24)) is
                    --
                    -- Parameter parsing
                    --
                    when X"00" =>
                        ParamCase: case(bus_m.addr(23 downto 0)) is
                            when X"000000" => rw(bus_m,bus_s,comState,triggers);
                            when X"000004" => rw(bus_m,bus_s,comState,outputReg);
                            when X"000008" => rw(bus_m,bus_s,comState,filterReg);
                            when X"00000C" => readOnly(bus_m,bus_s,comState,adcData_i);
                            when X"000010" => readOnly(bus_m,bus_s,comState,ext_i);
                            when X"000014" => rw(bus_m,bus_s,comState,dds_phase_inc_reg);
                            when X"000018" => rw(bus_m,bus_s,comState,dds_phase_off_reg);
                            when X"000020" => rw(bus_m,bus_s,comState,dds2_phase_off_reg);
                            when X"00002C" => rw(bus_m,bus_s,comState,pwmReg);

                            --
                            -- FIFO control and data retrieval
                            --
                            when X"000084" => rw(bus_m,bus_s,comState,fifoReg);
                            when X"000088" => fifoRead(bus_m,bus_s,comState,fifo_bus(0).m,fifo_bus(0).s);
                            when X"00008C" => fifoRead(bus_m,bus_s,comState,fifo_bus(1).m,fifo_bus(1).s);
                            when X"000090" => fifoRead(bus_m,bus_s,comState,fifo_bus(2).m,fifo_bus(2).s);
                            --
                            -- Memory signals
                            --
                            when X"100000" => rw(bus_m,bus_s,comState,numSamples);
                            when X"100004" =>
                                bus_s.resp <= "01";
                                comState <= finishing;
                                mem_bus.m.reset <= '1';
                           
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;

                      --
                    -- Memory reading of normal memory
                    --
                    when X"01" =>  
                      if bus_m.valid(1) = '0' then
                          bus_s.resp <= "11";
                          comState <= finishing;
                          mem_bus.m.trig <= '0';
                          mem_bus.m.status <= idle;
                      elsif mem_bus.s.valid = '1' then
                          bus_s.data <= mem_bus.s.data;
                          comState <= finishing;
                          bus_s.resp <= "01";
                          mem_bus.m.status <= idle;
                          mem_bus.m.trig <= '0';
                      elsif mem_bus.s.status = idle then
                          mem_bus.m.addr <= bus_m.addr(MEM_ADDR_WIDTH+1 downto 2);
                          mem_bus.m.status <= waiting;
                          mem_bus.m.trig <= '1';
                      else
                          mem_bus.m.trig <= '0';
                      end if;
                    
                    when others => 
                        comState <= finishing;
                        bus_s.resp <= "11";
                end case;
            when finishing =>
                comState <= idle;

            when others => comState <= idle;
        end case;
    end if;
end process;

end architecture Behavioural;