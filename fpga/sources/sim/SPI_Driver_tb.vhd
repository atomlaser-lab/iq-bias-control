library IEEE;
library work;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity SPI_Driver_tb is
--  Port ( );
end SPI_Driver_tb;

architecture Behavioral of SPI_Driver_tb is

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

constant clk_period :   time    :=  10 ns;
signal clk          :   std_logic;
signal aresetn      :   std_logic;

signal spi_period   :   unsigned(7 downto 0);
signal numBits      :   unsigned(7 downto 0);
signal syncDelay    :   unsigned(7 downto 0);

signal dataToSend   :   std_logic_vector(15 downto 0);
signal trig_in      :   std_logic;
signal enable       :   std_logic;
signal busy         :   std_logic;

signal spi_o        :   t_spi_master;
signal spi_i        :   t_spi_slave;

begin

clk_proc: process is
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

uut: SPI_Driver
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    SPI_period  =>  spi_period,
    numBits     =>  numBits,
    syncDelay   =>  syncDelay,
    dataReceived=>  open,
    dataReady   =>  open,
    dataToSend  =>  dataToSend,
    trigIn      =>  trig_in,
    enable      =>  enable,
    busy        =>  busy,
    spi_o       =>  spi_o,
    spi_i       =>  spi_i
);

main: process is
begin
    aresetn <= '0';
    spi_period <= to_unsigned(10,spi_period'length);
    numBits <= to_unsigned(16,numBits'length);
    syncDelay <= to_unsigned(1,syncDelay'length);
    dataToSend <= (others => '0');
    trig_in <= '0';
    enable <= '0';
    spi_i <= INIT_SPI_SLAVE;
    
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    enable <= '1';
    dataToSend <= X"aaaa";
    trig_in <= '1';
    wait until rising_edge(clk);
    trig_in <= '0';
    wait for 2 us;
    wait until rising_edge(clk);
    trig_in <= '1';
    wait until rising_edge(clk);
    trig_in <= '0';
    wait;
    
end process;

end Behavioral;
