library IEEE;
library work;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity FIFOHandler_tb is
--  Port ( );
end FIFOHandler_tb;

architecture Behavioral of FIFOHandler_tb is

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
-- Clocks and reset
--
signal clk_period   :   time    :=  8 ns;
signal sysClk,adcClk:   std_logic;
signal aresetn      :   std_logic;

signal fifo_data    :   std_logic_vector(FIFO_WIDTH - 1 downto 0);
signal valid_i      :   std_logic;
signal valid        :   std_logic;
signal enable       :   std_logic;
signal count,count2        :   unsigned(15 downto 0);

signal fifoReset    :   std_logic;
signal fifo_bus     :   t_fifo_bus;
signal enable_read  :   std_logic;
begin

FIFO: FIFOHandler
port map(
    wr_clk      =>  adcClk,
    rd_clk      =>  sysClk,
    aresetn     =>  aresetn,
    data_i      =>  fifo_data,
    valid_i     =>  valid,
    fifoReset   =>  fifoReset,
    bus_m       =>  fifo_bus.m,
    bus_s       =>  fifo_bus.s
);

valid <= valid_i and enable;

clk_proc: process is
begin
    sysClk <= '0';
    adcClk <= '0';
    wait for clk_period/2;
    sysClk <= '1';
    adcClk <= '1';
    wait for clk_period/2;
end process;

data_proc: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        fifo_data <= (others => '0');
        valid_i <= '0';
        count <= (others => '0');
    elsif rising_edge(adcClk) then
        if count = 0 then
            fifo_data <= std_logic_vector(unsigned(fifo_data) + 1);
            valid_i <= '1';
            count <= count + 1;
        elsif count < 10 then
            count <= count + 1;
            valid_i <= '0';
        else
            count <= (others => '0');
            valid_i <= '0';
        end if;
    end if;
end process;

read_process: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        fifo_bus.m <= INIT_FIFO_BUS_MASTER;
    elsif rising_edge(sysClk) and enable_read = '1' then
        if count2 = 0 then
            fifo_bus.m.rd_en <= '1';
            count2 <= count2 + 1;
        elsif count2 < 3 then
            count2 <= count + 1;
            fifo_bus.m.rd_en <= '0';
        else
            count2 <= (others => '0');
            fifo_bus.m.rd_en <= '0';
        end if;
    end if;
end process;

main: process is
begin
    aresetn <= '0';
    enable_read <= '0';
    fifoReset <= '0';
    enable <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 1 us;
    wait until rising_edge(sysClk);
    fifoReset <= '1';
    wait for 2*clk_period;
    wait until rising_edge(sysClk);
    fifoReset <= '0';
    wait for 1 us;
    enable <= '1';
    wait for 1 us;
    enable_read <= '1';
--    fifo_bus.m.
    wait;
end process;

end Behavioral;
