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
        spi_o           :   out std_logic_vector(2 downto 0);
        
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

component Control is
    Port ( 
        clk                 :   in  std_logic;
        aresetn             :   in  std_logic;
        -- Inputs
        meas_i              :   in  t_meas_array(2 downto 0);
        control_i           :   in  t_meas_array(2 downto 0);
        valid_i             :   in  std_logic;
        --
        -- Parameters
        --
        enable_i            :   in  std_logic;
        hold_i              :   in  std_logic;
        gains_i             :   in  t_param_reg_array(2 downto 0);
        --
        -- Outputs
        --
        valid_o             :   out std_logic;
        control_signal_o    :   out t_pwm_exp_array(2 downto 0)
    );
end component;

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
        dds_regs_i      :   in  t_param_reg_array(3 downto 0);
        --
        -- Input and output data
        --
        data_i          :   in  t_adc;
        dac_o           :   out t_dac_array(1 downto 0);
        filtered_data_o :   out t_meas_array(NUM_DEMOD_SIGNALS - 1 downto 0);
        valid_o         :   out std_logic_vector(NUM_DEMOD_SIGNALS - 1 downto 0)
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
        clkx2       :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Input/outputs
        --
        data_i      :   in  t_pwm_array;
        valid_i     :   in  std_logic;
        pwm_o       :   out std_logic_vector   
    );
end component;

component SPI_Driver is
	generic (
			CPOL			:	std_logic	:=	'0';		--Serial clock idle polarity
			CPHA			:	std_logic	:=	'0';		--Serial clock phase. '0': data valid on CPOL -> not(CPOL) transition. '1': data valid on not(CPOL) -> CPOL transition
			ORDER			:	STRING		:=	"MSB";		--Bit order.  "LSB" or "MSB"
			SYNC_POL		:	std_logic	:=	'0';		--Active polarity of SYNC.  '0': active low. '1': active high
			TRIG_SYNC		:	std_logic	:=	'0';		--Use synchronous detection for trigger?
			TRIG_EDGE		:	string		:=	"RISING";	--Edge of trigger to synchronize on. "RISING" or "FALLING"
			ASYNC_WIDTH		:	integer		:=	2;			--Width of asynchronous update pulse
			ASYNC_POL		:	std_logic	:=	'0';		--Active polarity of asynchronous signal
			MAX_NUM_BITS	:	integer		:=	16			--Maximum number of bits to transfer
			);					
	port( 	clk				:	in	std_logic;		--Clock signal
			aresetn			:	in	std_logic;		--Asynchronous reset
			SPI_period		:	in  unsigned(7 downto 0);		--SCLK period
			numBits			:	in 	unsigned(7 downto 0);		--Number of bits in current data
			syncDelay		:	in	unsigned(7 downto 0);

			dataReceived	:	out std_logic_vector(MAX_NUM_BITS - 1 downto 0);	--data that has been received
			dataReady		:	out	std_logic;	--Pulses high for one clock cycle to indicate new data is valid on dataReceived
			dataToSend		:	in	std_logic_vector(MAX_NUM_BITS - 1 downto 0);	--data to be sent
			trigIn			:	in	std_logic;		--Start trigger
			enable			:	in std_logic;		--Enable bit
			busy			:	out std_logic;		--Busy signal

			spi_o			:	out	t_spi_master;	--Output SPI signals
			spi_i			:	in	t_spi_slave);	--Input SPI signals
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
signal topReg               :   t_param_reg;
signal triggers             :   t_param_reg;
signal outputReg            :   t_param_reg;
signal filterReg            :   t_param_reg;
-- DDS registers
signal dds_phase_inc_reg    :   t_param_reg;
signal dds_phase_off_reg    :   t_param_reg;
signal dds2_phase_off_reg   :   t_param_reg;
signal dds_phase_corr_reg   :   t_param_reg;
signal dds_regs             :   t_param_reg_array(3 downto 0);
-- PWM register
signal pwm_regs             :   t_param_reg_array(2 downto 0);
-- FIFO register
signal fifoReg              :   t_param_reg;
-- PID registers
type t_pid_reg_array is array(natural range <>) of t_param_reg_array(2 downto 0);
signal pid_regs             :   t_param_reg_array(4 downto 0);
signal pwm_limit_regs       :   t_param_reg_array(3 downto 0);
-- Aux DAC registers
signal dac_reg              :   t_param_reg;
--
-- DDS signals
--
signal dac_o                :   t_dac_array(1 downto 0);
signal dac_gate, dac_gate_i :   std_logic;
signal link_dac_gate        :   std_logic;
signal filtered_data        :   t_meas_array(3 downto 0);
signal filter_valid         :   std_logic_vector(3 downto 0);
--
-- ADC signals
--
signal adc                  :   t_adc;
signal adc_select           :   std_logic;
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
signal fifo_route           :   std_logic_vector(3 downto 0);

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
-- Bias lock signals
--
signal bias_controls            :   t_meas_array(2 downto 0);
signal bias_enable              :   std_logic;
signal bias_soft_hold           :   std_logic;
signal bias_hold_i, bias_hold   :   std_logic;
--
-- PWM signals
--
signal pwm_data, pwm_data_i     :   t_pwm_array(3 downto 0);
signal control_signal_o         :   t_pwm_exp_array(2 downto 0);
signal pwm_data_exp             :   t_pwm_exp_array(2 downto 0);
signal pwm_sum                  :   t_pwm_exp_array(2 downto 0);
signal pwm_limit                :   t_pwm_exp_array(3 downto 0);
signal pwm_max, pwm_min         :   t_pwm_exp_array(2 downto 0);
signal control_valid            :   std_logic;
--
-- SPI signals
--
constant SPI_NUM_BITS   :   integer                 :=  16;
constant SPI_SYNC_DELAY :   unsigned(7 downto 0)    :=  to_unsigned(4,8);
signal spi              :   t_spi_master;
signal spi_trig         :   std_logic;
signal spi_period       :   unsigned(7 downto 0);
signal spi_enable       :   std_logic;
signal spi_busy         :   std_logic;
signal spi_data, spi_data_old         :   std_logic_vector(SPI_NUM_BITS - 1 downto 0);

begin

--
-- Parse registers
--
-- triggers
memTrig <= triggers(0);
spi_trig <= triggers(1);

-- topReg
adc_select <= topReg(0);
link_dac_gate <= topReg(1);
spi_period <= unsigned(topReg(15 downto 8));

-- outputReg
ext_o(7 downto 3) <= outputReg(7 downto 3);
led_o <= outputReg(15 downto 8);
fifo_route <= outputReg(19 downto 16);

-- DDS registers
dds_regs <= (0 => dds_phase_inc_reg, 1 => dds_phase_off_reg, 2 => dds2_phase_off_reg, 3 => dds_phase_corr_reg);

-- Control registers
bias_enable <= pid_regs(0)(0);
bias_soft_hold <= pid_regs(0)(1);

bias_controls(0) <= resize(signed(pid_regs(0)(31 downto 16)),t_meas'length);
bias_controls(1) <= resize(signed(pid_regs(1)(15 downto 0)),t_meas'length);
bias_controls(2) <= resize(signed(pid_regs(1)(31 downto 16)),t_meas'length);

-- Aux DAC register
spi_data <= dac_reg(SPI_NUM_BITS - 1 downto 0);

-- PWM registers
PWM_reg_gen: for I in 0 to 2 generate
    pwm_data(I) <= unsigned(pwm_regs(I)(t_pwm'left downto 0));
    -- Parse limits, expand to 11 bits as signed values
    pwm_min(I) <= signed(resize(unsigned(pwm_limit_regs(I)(PWM_DATA_WIDTH - 1 downto 0)),PWM_EXP_WIDTH));
    pwm_max(I) <= signed(resize(unsigned(pwm_limit_regs(I)(2*PWM_DATA_WIDTH - 1 downto PWM_DATA_WIDTH)),PWM_EXP_WIDTH));
end generate PWM_reg_gen;

-- FIFO registers
enableFIFO <= fifoReg(0);
fifoReset <= fifoReg(1);


--
-- Parse inputs
--
bias_hold_i <= ext_i(0);
dac_gate_i <= ext_i(1);

--
-- DAC Outputs
--
dac_gate <= dac_gate_i or (bias_hold and link_dac_gate);

m_axis_tdata <= std_logic_vector(dac_o(1)) & std_logic_vector(dac_o(0)) when dac_gate = '0' else (others => '0');
m_axis_tvalid <= '1';
--
-- PWM outputs
--
PWM_Gen: for I in 0 to 2 generate
    pwm_data_i(I) <= resize(unsigned(std_logic_vector(pwm_limit(I))),PWM_DATA_WIDTH);
end generate PWM_Gen;
 
pwm_data(3) <= (others => '0');
pwm_data_i(3) <= pwm_data(3);

PWM1: PWM_Generator
port map(
  clk     =>  adcClk,
  clkx2   =>  adcClkx2,
  aresetn =>  aresetn,
  data_i  =>  pwm_data_i,
  valid_i => '1',
  pwm_o   =>  pwm_o
);

--
-- SPI control
--
spi_o <= (0 => spi.SYNC, 1 => spi.SCLK, 2 => spi.SD);
ext_o(2 downto 0) <= (0 => spi.SYNC, 1 => spi.SCLK, 2 => spi.SD);
--SPI_data_proc: process(adcClk,aresetn) is
--begin
--    if aresetn = '0' then
--        spi_data_old <= spi_data;
--        spi_trig <= '0';
--    elsif rising_edge(adcClk) then
--        spi_data_old <= spi_data;
--        if spi_data_old /= spi_data then
--            spi_trig <= '1';
--        else
--            spi_trig <= '0';
--        end if;
--    end if;
--end process;

Aux_DAC: SPI_Driver
generic map(
    CPOL            =>  '0',
    CPHA            =>  '0',
    ORDER           =>  "MSB",
    SYNC_POL        =>  '0',
    TRIG_SYNC       =>  '0',
    ASYNC_WIDTH     =>  0,
    ASYNC_POL       =>  '0',
    MAX_NUM_BITS    =>  SPI_NUM_BITS
)
port map(
    clk             =>  adcClk,
    aresetn         =>  aresetn,
    spi_period      =>  spi_period,
    numBits         =>  to_unsigned(SPI_NUM_BITS,8),
    syncDelay       =>  SPI_SYNC_DELAY,
    dataReceived    =>  open,
    dataReady       =>  open,
    dataToSend      =>  spi_data,
    trigIn          =>  spi_trig,
    enable          =>  '1',
    busy            =>  spi_busy,
    spi_o           =>  spi,
    spi_i           =>  INIT_SPI_SLAVE
);

--
-- Modulator/demodulator component
--
adc <= resize(signed(adcData_i(15 downto 0)), adc'length) when adc_select = '0' else resize(signed(adcData_i(31 downto 16)), adc'length);

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
-- Apply feedback
--
bias_hold <= bias_soft_hold or bias_hold_i;
--
-- Control module
--
Bias_Control : Control
port map(
    clk               =>  adcClk,
    aresetn           =>  aresetn,
    meas_i            =>  filtered_data(2 downto 0),
    control_i         =>  bias_controls,
    valid_i           =>  filter_valid(0),
    enable_i          =>  bias_enable,
    hold_i            =>  bias_hold,
    gains_i           =>  pid_regs(4 downto 2),
    valid_o           =>  control_valid,
    control_signal_o  =>  control_signal_o
);


PWM_LIMIT_GEN: for I in 0 to 2 generate
    -- Expand manual data to a signed 11 bit value
    pwm_data_exp(I) <= signed(std_logic_vector(resize(pwm_data(I),PWM_EXP_WIDTH)));
    -- Sum expanded manual data and control data
    pwm_sum(I) <= pwm_data_exp(I) + resize(control_signal_o(I),PWM_EXP_WIDTH);
    -- Limit the summed manual and control values to their max/min limits
    pwm_limit(I) <= pwm_sum(I) when pwm_sum(I) < pwm_max(I) and pwm_sum(I) > pwm_min(I) else
                    pwm_max(I) when pwm_sum(I) >= pwm_max(I) else
                    pwm_min(I) when pwm_sum(I) <= pwm_min(I);

end generate PWM_LIMIT_GEN;
pwm_limit(3) <= (others => '0');

--
-- Collect demodulated data at lower sampling rate in FIFO buffers
-- to be read out continuously by CPU
--
FIFO_GEN: for I in 0 to NUM_FIFOS - 1 generate
    fifoData(I) <= std_logic_vector(resize(filtered_data(I),FIFO_WIDTH)) when fifo_route(I) = '0' else std_logic_vector(resize(pwm_limit(I),FIFO_WIDTH));
    fifoValid(I) <= ((filter_valid(I) and (not(fifo_route(I)) or not(bias_enable))) or (control_valid and fifo_route(I) and bias_enable)) and enableFIFO;
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
        pwm_regs <= (others => (others => '0'));
        
        for I in 0 to pid_regs'length - 1 loop
            pid_regs(I) <= (others => '0');
        end loop;

        for I in 0 to pwm_limit_regs'length - 1 loop
            pwm_limit_regs(I) <= (others => '0');
        end loop;
        --
        -- FIFO registers
        --
        fifoReg <= (others => '0');
        for I in 0 to NUM_FIFOS - 1 loop
            fifo_bus(I).m.status <= idle;
        end loop;
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
--                            when X"00002C" => rw(bus_m,bus_s,comState,pwmReg);
                            when X"000030" => rw(bus_m,bus_s,comState,dds_phase_corr_reg);
                            when X"000040" => rw(bus_m,bus_s,comState,topReg);
                            when X"000050" => rw(bus_m,bus_s,comState,pwm_regs(0));
                            when X"000054" => rw(bus_m,bus_s,comState,pwm_regs(1));
                            when X"000058" => rw(bus_m,bus_s,comState,pwm_regs(2));
                            when X"000060" => rw(bus_m,bus_s,comState,dac_reg,triggers(1));
                            --
                            -- PID registers
                            --
                            when X"000100" => rw(bus_m,bus_s,comState,pid_regs(0));
                            when X"000104" => rw(bus_m,bus_s,comState,pid_regs(1));
                            when X"000108" => rw(bus_m,bus_s,comState,pid_regs(2));
                            when X"00010C" => rw(bus_m,bus_s,comState,pid_regs(3));
                            when X"000110" => rw(bus_m,bus_s,comState,pid_regs(4));
                            when X"000114" => rw(bus_m,bus_s,comState,pwm_limit_regs(0));
                            when X"000118" => rw(bus_m,bus_s,comState,pwm_limit_regs(1));
                            when X"00011C" => rw(bus_m,bus_s,comState,pwm_limit_regs(2));

                            --
                            -- FIFO control and data retrieval
                            --
                            when X"000084" => rw(bus_m,bus_s,comState,fifoReg);
                            when X"000088" => fifoRead(bus_m,bus_s,comState,fifo_bus(0).m,fifo_bus(0).s);
                            when X"00008C" => fifoRead(bus_m,bus_s,comState,fifo_bus(1).m,fifo_bus(1).s);
                            when X"000090" => fifoRead(bus_m,bus_s,comState,fifo_bus(2).m,fifo_bus(2).s);
                            when X"000094" => fifoRead(bus_m,bus_s,comState,fifo_bus(3).m,fifo_bus(3).s);
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