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
        
        adcClk          :   in  std_logic;
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
signal triggers             :   t_param_reg                     :=  (others => '0');
signal outputReg            :   t_param_reg                     :=  (others => '0');
signal filterReg            :   t_param_reg;
-- we can add a new register 
-- signal new_register         :   t_param_reg; -- dds2 
-- DDS register
signal dds_phase_inc_reg     : t_param_reg;
signal dds_phase_off_reg     : t_param_reg;
-- DDS2 register
signal dds2_phase_inc_reg     : t_param_reg; -- dds2
signal dds2_phase_off_reg     : t_param_reg; -- dds2
-- DDS3
signal dds3_phase_inc_reg     : t_param_reg; -- dds2
signal dds3_phase_off_reg     : t_param_reg; -- dds2
-- we can add some costom signals for DDS2

-- add DDS signals
signal phase_offset       : std_logic_vector(31 downto 0);
signal phase_inc          : std_logic_vector(31 downto 0);
signal dds_phase_i        : std_logic_vector(63 downto 0);
signal dds_o              : std_logic_vector(31 downto 0);
signal dds_cos, dds_sin   : std_logic_vector(9 downto 0);
signal dac_o              : t_dac_array(1 downto 0);
-- DDS2 signals
signal dds2_phase_offset       : std_logic_vector(31 downto 0);
signal dds2_phase_inc          : std_logic_vector(31 downto 0);
signal dds2_phase_i        : std_logic_vector(63 downto 0);
signal dds2_o              : std_logic_vector(31 downto 0);
signal dds2_cos, dds2_sin   : std_logic_vector(9 downto 0);
-- DDS3 signals
signal dds3_phase_offset       : std_logic_vector(31 downto 0);
signal dds3_phase_inc          : std_logic_vector(31 downto 0);
signal dds3_phase_i        : std_logic_vector(63 downto 0);
signal dds3_o              : std_logic_vector(31 downto 0);
signal dds3_cos, dds3_sin   : std_logic_vector(9 downto 0);

signal adc1, adc2, adc3                 : signed(13 downto 0);
signal adc1_slv, adc2_slv, adc3_slv     : std_logic_vector(13 downto 0);

-- Filtering Signals
signal cicLog2Rate                      : unsigned(3 downto 0);
signal cicShift                         : natural;
signal setShift                         : unsigned(3 downto 0);
signal filterConfig, filterConfig_old  : std_logic_vector(15 downto 0);
signal Mult1_o, Mult2_o, Mult3_o        : std_logic_vector(23 downto 0);
signal filter_valid                       : std_logic;
signal filtMult1_i, filtMult2_i, filtMult3_i        : std_logic_vector(23 downto 0);
signal filtMult1_o, filtMult2_o, filtMult3_o        : std_logic_vector(63 downto 0);
signal Mult1_o_valid, Mult2_o_valid, Mult3_o_valid  : std_logic;

signal filterData   :   t_meas_array(2 downto 0);

--
-- FIFO signals
--
constant NUM_FIFOS  :   natural :=  3;
type t_fifo_data_array is array(natural range <>) of std_logic_vector(FIFO_WIDTH-1 downto 0);
signal fifoData     :   t_fifo_data_array(NUM_FIFOS-1 downto 0);
signal fifoValid    :   std_logic_vector(NUM_FIFOS-1 downto 0);
signal fifo_bus     :   t_fifo_bus_array(NUM_FIFOS-1 downto 0)  :=  (others => INIT_FIFO_BUS);
signal fifoReg      :   t_param_reg;
signal enableFIFO   :   std_logic;
signal fifoReset    :   std_logic;

-- PID signals
signal enable, polarity, valid_i        : std_logic;
signal control, measurement    : signed(15 downto 0);
signal pidvalid_o              : std_logic;
signal pid_o                   : signed(15 downto 0);

begin

--
-- DAC Outputs
--
m_axis_tdata <= std_logic_vector(dac_o(1)) & std_logic_vector(dac_o(0));
m_axis_tvalid <= '1';
-- now we can assign the new signals to the new register
-- Digital outputs
--
ext_o <= outputReg(7 downto 0);
led_o <= outputReg(15 downto 8);

adc1        <=    resize(signed(adcData_i(15 downto 0)), 14);
adc1_slv    <=    std_logic_vector(adc1);

-- 
-- DDS
DDS_inst : DDS1
  PORT MAP (
    aclk                     => adcClk,
    aresetn                  => aresetn,
    s_axis_phase_tvalid      => '1',
    s_axis_phase_tdata       => dds_phase_i,
    m_axis_data_tvalid       => open,
    m_axis_data_tdata        => dds_o
  );
DDS_inst2 : DDS1
  PORT MAP (
    aclk                      => adcClk,
    aresetn                   => aresetn,
    s_axis_phase_tvalid       => '1',
    s_axis_phase_tdata        => dds2_phase_i,
    m_axis_data_tvalid        => open,
    m_axis_data_tdata         => dds2_o
  );
  
 DDS_inst3 : DDS1
  PORT MAP (
    aclk                        => adcClk,
    aresetn                     => aresetn,
    s_axis_phase_tvalid         => '1',
    s_axis_phase_tdata          => dds3_phase_i,
    m_axis_data_tvalid          => open,
    m_axis_data_tdata           => dds3_o
  );
DDSMult1 : Multiplier1
  PORT MAP (
    CLK => adcClk,
    A => std_logic_vector(adc1),
    B => dds2_sin,
    P => Mult1_o
  );
  
DDSMult2 : Multiplier1
  PORT MAP (
    CLK => adcClk,
    A => std_logic_vector(adc1),
    B => dds2_cos,
    P => Mult2_o
  );
DDSMult3 : Multiplier1
  PORT MAP (
    CLK => adcCLK,
    A => std_logic_vector(adc1),
    B => dds3_sin,
    P => Mult3_o
  );
  --Filter
cicLog2Rate <= unsigned(filterReg(3 downto 0));
setShift <= unsigned(filterReg(7 downto 4));
cicShift <= to_integer(cicLog2Rate)+ to_integer(cicLog2Rate)+ to_integer(cicLog2Rate);
filterConfig <= std_logic_vector(shift_left(to_unsigned(1, filterConfig'length),to_integer(cicLog2Rate)));

ChangeProc: process(adcClk, aresetn) is
begin 
   if aresetn ='0' then
      filterConfig_old <= filterConfig;
      filter_valid <= '0';
   elsif rising_edge(adcClk) then 
      filterConfig_old <= filterConfig;
      if filterConfig /= filterConfig_old then
         filter_valid <= '1';
      else
         filter_valid <= '0';
      end if;
   end if;      

end process;

Filt1 : CICfilter
  PORT MAP (
    aclk => adcClk,
    aresetn => aresetn,
    s_axis_config_tdata => filterConfig,
    s_axis_config_tvalid => filter_valid,
    s_axis_config_tready => open,
    s_axis_data_tdata => Mult1_o,
    s_axis_data_tvalid => '1',
    s_axis_data_tready => open,
    m_axis_data_tdata => filtMult1_o,
    m_axis_data_tvalid => Mult1_o_valid
  );
Filt2 : CICfilter
  PORT MAP (
   aclk => adcClk,
    aresetn => aresetn,
    s_axis_config_tdata => filterConfig,
    s_axis_config_tvalid => filter_valid,
    s_axis_config_tready => open,
    s_axis_data_tdata => Mult2_o,
    s_axis_data_tvalid => '1',
    s_axis_data_tready => open,
    m_axis_data_tdata => filtMult2_o,
    m_axis_data_tvalid => Mult2_o_valid
  );
Filt3 : CICfilter
  PORT MAP (
  aclk => adcClk,
    aresetn => aresetn,
    s_axis_config_tdata => filterConfig,
    s_axis_config_tvalid => filter_valid,
    s_axis_config_tready => open,
    s_axis_data_tdata => Mult3_o,
    s_axis_data_tvalid => '1',
    s_axis_data_tready => open,
    m_axis_data_tdata => filtMult3_o,
    m_axis_data_tvalid => Mult3_o_valid
  );
  
filterData(0) <= resize(shift_right(signed(filtMult1_o),cicShift + to_integer(setShift)),t_meas'length);
filterData(1) <= resize(shift_right(signed(filtMult2_o),cicShift + to_integer(setShift)),t_meas'length);
filterData(2) <= resize(shift_right(signed(filtMult3_o),cicShift + to_integer(setShift)),t_meas'length);

-- 
phase_inc <= dds_phase_inc_reg;
phase_offset <= dds_phase_off_reg;
dds_phase_i <= phase_offset & phase_inc;
dds_cos     <= dds_o(9 downto 0);
dds_sin     <= dds_o(25 downto 16);

dac_o(0) <= shift_left(resize(signed(dds_cos),16),4);
dac_o(1) <= shift_left(resize(signed(dds_sin),16),4);
-- DDS2 
dds2_phase_inc <= dds_phase_inc_reg;
dds2_phase_offset <= dds2_phase_off_reg;
dds2_phase_i <= dds2_phase_offset & dds2_phase_inc;
dds2_cos     <= dds2_o(9 downto 0);
dds2_sin     <= dds2_o(25 downto 16);

-- DDS3 
dds3_phase_inc <= std_logic_vector(shift_left(unsigned(dds_phase_inc_reg),1));
dds3_phase_offset <= dds3_phase_off_reg;
dds3_phase_i <= dds3_phase_offset & dds3_phase_inc;
dds3_cos     <= dds3_o(9 downto 0);
dds3_sin     <= dds3_o(25 downto 16);

--
-- FIFO buffering for long data sets
--
enableFIFO <= fifoReg(0);
fifoReset <= fifoReg(1);
FIFO_GEN: for I in 0 to NUM_FIFOS-1 generate
    fifoData(I) <= std_logic_vector(resize(filterData(I),FIFO_WIDTH));
    fifoValid(I) <= Mult3_o_valid and enableFIFO;
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
        --dac_o <= (others => '0');
        dds_phase_off_reg <= (others => '0');
        dds_phase_inc_reg <= std_logic_vector(to_unsigned(34359738, 32)); -- 1 MHz with 32 bit DDS and 125 MHz clk freq
        --dds2 
        dds2_phase_off_reg <= (others => '0');
        dds2_phase_inc_reg <= std_logic_vector(to_unsigned(34359738, 32)); 
        -- DDS3
        dds3_phase_off_reg <= (others => '0');
        dds3_phase_inc_reg <= std_logic_vector(to_unsigned(34359738, 32)); 
       -- new_register <= (others => '0'); -- dds2
        --
        -- FIFO registers
        --
        fifoReg <= (others => '0');
        fifo_bus(0).m.status <= idle;
        fifo_bus(1).m.status <= idle;
        fifo_bus(2).m.status <= idle;
    elsif rising_edge(sysClk) then
        FSM: case(comState) is
            when idle =>
                triggers <= (others => '0');
                reset <= '0';
                bus_s.resp <= "00";
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
                            --when X"00001C" => rw(bus_m,bus_s,comState,new_register); -- dds2
                            when X"00001C" => rw(bus_m,bus_s,comState,dds2_phase_inc_reg);
                            when X"000020" => rw(bus_m,bus_s,comState,dds2_phase_off_reg);
                            when X"000024" => rw(bus_m,bus_s,comState,dds3_phase_inc_reg);
                            when X"000028" => rw(bus_m,bus_s,comState,dds3_phase_off_reg);

                            --
                            -- FIFO control and data retrieval
                            --
                            when X"000084" => rw(bus_m,bus_s,comState,fifoReg);
                            when X"000088" => fifoRead(bus_m,bus_s,comState,fifo_bus(0).m,fifo_bus(0).s);
                            when X"00008C" => fifoRead(bus_m,bus_s,comState,fifo_bus(1).m,fifo_bus(1).s);
                            when X"000090" => fifoRead(bus_m,bus_s,comState,fifo_bus(2).m,fifo_bus(2).s);
                           
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;
                    
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