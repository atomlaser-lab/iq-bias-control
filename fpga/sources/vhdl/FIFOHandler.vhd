library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity FIFOHandler is
    port(
        wr_clk      :   in  std_logic;
        rd_clk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        sampleTime_i:   in  std_logic_vector(23 downto 0);
        enable_i    :   in  std_logic;   
        data_i      :   in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        
        fifoReset   :   in  std_logic;
        bus_m       :   in  t_fifo_bus_master;
        bus_s       :   out t_fifo_bus_slave
    );
end FIFOHandler;

architecture Behavioral of FIFOHandler is

COMPONENT FIFO_Continuous
  PORT (
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    rst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

signal rst, rst1    :   std_logic;
signal sampleTime   :   unsigned(23 downto 0);
signal count        :   unsigned(sampleTime'length - 1 downto 0);
signal startSync    :   std_logic_vector(1 downto 0);
signal start        :   std_logic;
signal valid        :   std_logic;
signal wr_en        :   std_logic;
signal rstDone      :   std_logic;
signal data         :   std_logic_vector(data_i'length - 1 downto 0);

signal rstCount     :   unsigned(3 downto 0);

type t_status_local is (idle,counting);
signal state        :   t_status_local;

begin
--
-- Parse registers
--
sampleTime <= unsigned(sampleTime_i);
--
-- Generate reset signal
--
ResetGen: process(wr_clk,aresetn) is
begin
    if aresetn = '0' then
        rstCount <= X"0";
        rst1 <= '1';
        rstDone <= '0';
    elsif rising_edge(wr_clk) then
        if fifoReset = '1' then
            rst1 <= '1';
            rstDone <= '0';
            rstCount <= X"0";
        elsif rstCount < 5 then
            rstCount <= rstCount + 1;
            rst1 <= '1';
            rstDone <= '0';
        elsif rstCount < 10 then
            rstCount <= rstCount + 1;
            rstDone <= '0';
            rst1 <= '0';
        else
            rstDone <= '1';
        end if;
    end if;
end process;
rst <= not(aresetn) or rst1;
--
-- Creates a valid output signal when rd_en is high
--
ValidDelay: process(rd_clk,aresetn) is
begin
    if aresetn = '0' then
        bus_s.valid <= '0';
    elsif rising_edge(rd_clk) then
        if bus_m.rd_en = '1' then
            bus_s.valid <= '1';
        else
            bus_s.valid <= '0';
        end if;
    end if;    
end process;
--
-- Detect rising edge of start_i
--
StartEdgeDetect: process(wr_clk,aresetn) is
begin
    if aresetn = '0' then
        startSync <= "00";
    elsif rising_edge(wr_clk) then
        startSync <= startSync(0) & enable_i;
    end if;
end process;
--
-- Start data collection
--
AcquisitionProc: process(wr_clk,aresetn) is
begin
    if aresetn = '0' then
        count <= (others => '0');
        state <= idle;
        valid <= '0';
    elsif rising_edge(wr_clk) then
        AcqCase: case(state) is
            when idle =>
                if startSync = "01" and rstDone = '1' then
                    state <= counting;
                    count <= (0 => '1',others => '0');
                    data <= data_i;
                    valid <= '1';
                else
                    valid <= '0';
                end if;
                
            when counting =>
                if enable_i = '0' or rstDone = '0' then
                    state <= idle;
                elsif count < sampleTime then
                    count <= count + 1;
                    valid <= '0';
                else
                    count <= (0 => '1', others => '0');
                    data <= data_i;
                    valid <= '1';
                end if;
                
            when others => state <= idle;
        end case;
    end if;
end process;


--
-- Instantiate FIFO part
--

FIFO: FIFO_Continuous
port map(
    wr_clk      =>  wr_clk,
    rd_clk      =>  rd_clk,
    rst         =>  rst,
    din         =>  data,
    wr_en       =>  valid,
    rd_en       =>  bus_m.rd_en,
    dout        =>  bus_s.data,
    full        =>  bus_s.full,
    empty       =>  bus_s.empty
);


end Behavioral;
