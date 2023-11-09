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
        
        data_i      :   in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        valid_i     :   in  std_logic;
        
        fifoReset   :   in  std_logic;
        bus_m       :   in  t_fifo_bus_master;
        bus_s       :   out t_fifo_bus_slave
    );
end FIFOHandler;

architecture Behavioral of FIFOHandler is

COMPONENT FIFO
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

signal rst, rst1    :   std_logic;
signal rstCount     :   unsigned(3 downto 0);
signal wr_en        :   std_logic;
signal rstDone      :   std_logic;

begin

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
            rst1 <= '0';
            rstDone <= '0';
        else
            rstDone <= '1';
        end if;
    end if;
end process;

rst <= not(aresetn) or rst1;
wr_en <= valid_i and rstDone;

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

FIFO_inst: FIFO
port map(
    wr_clk      =>  wr_clk,
    rd_clk      =>  rd_clk,
    rst         =>  rst,
    din         =>  data_i,
    wr_en       =>  wr_en,
    rd_en       =>  bus_m.rd_en,
    dout        =>  bus_s.data,
    full        =>  bus_s.full,
    empty       =>  bus_s.empty
);


end Behavioral;
