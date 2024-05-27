library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

--
-- Transfers and receives data using the SPI protocol.  
-- Behaviour can be changed with generics.
--
entity SPI_Driver is
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
end SPI_Driver;

architecture Behavioral of SPI_Driver is

signal SPI_cnt	:	unsigned(SPI_period'left downto 0)	:=	(others => '0');
signal bit_cnt	:	unsigned(numBits'length - 1 downto 0)	:=	(others => '0');
signal trigSync	:	std_logic_vector(1 downto 0)	:=	"00";
signal trig	:	std_logic	:=	'0';
signal dataIn, dataOut	:	std_logic_vector(MAX_NUM_BITS - 1 downto 0)	:=	(others => '0');

signal delayCount	:	unsigned(7 downto 0)	:=	(others => '0');

type t_state_local is (idle,send_receive,sync_delay,async_pulse);
signal state	:	t_state_local	:=	idle;

begin
--
--Synchronous trigger detection
--
startAcq: process(clk,spi_i.READY) is
	begin
		if rising_edge(clk) then
			trigSync <= (trigSync(0),spi_i.READY);
		end if;
end process;
--
--Use appropriate trigger depending on options TRIG_SYNC and TRIG_EDGE
--
trig <= 	trigIn when TRIG_SYNC = '0' else
			'1' when (TRIG_EDGE = "FALLING" and trigSync = "10") or (TRIG_EDGE = "RISING" and trigSync = "01") else
			'0';
			
SPI_Process: process(clk,aresetn) is
begin
	if aresetn = '0' then
		state <= idle;
		dataOut <= (others => '0');
		dataReady <= '0';
		dataIn <= (others => '0');
		busy <= '0';
		spi_o.SCLK <= CPOL;
		spi_o.SD <= '0';
		spi_o.SYNC <= not(SYNC_POL);
		spi_o.ASYNC <= not(ASYNC_POL);
		SPI_cnt <= (others => '0');
		bit_cnt <= (others => '0');
	elsif rising_edge(clk) then
		SPI_Case: case state is
			--
			--Idle/wait for trigger state
			--
			when idle =>
				dataIn <= (others => '0');
				dataReady <= '0';
				spi_o.SCLK <= CPOL;
				spi_o.SD <= '0';
				delayCount <= (others => '0');
				spi_o.ASYNC <= not(ASYNC_POL);
				if trig = '1' and enable = '1' then
					--
					-- If a trigger is received, latch data to send
					-- signal that driver is busy
					--
					state <= send_receive;
					SPI_cnt <= to_unsigned(1,SPI_cnt'length);
					dataOut <= dataToSend;
					spi_o.SYNC <= SYNC_POL;
					busy <= '1';
					if ORDER = "LSB" then
						bit_cnt <= (others => '0');
					else
						bit_cnt <= numBits - 1;
					end if;
				else
					spi_o.SYNC <= not(SYNC_POL);
					busy <= '0';
				end if;
			--
			--Send/receive data state
			--
			when send_receive =>
				if SPI_cnt <= shift_right(SPI_period,1) then
					if CPHA = '0' then
						spi_o.SD <= dataOut(to_integer(bit_cnt));
						dataIn(to_integer(bit_cnt)) <= spi_i.SD;
					end if;
					spi_o.SCLK <= CPOL;
					SPI_cnt <= SPI_cnt + 1;
				elsif SPI_cnt < SPI_period then
					if CPHA = '1' then
						spi_o.SD <= dataOut(to_integer(bit_cnt));
						dataIn(to_integer(bit_cnt)) <= spi_i.SD;
					end if;
					spi_o.SCLK <= not(CPOL);
					SPI_cnt <= SPI_cnt + 1;
				else
					--
					-- This is for the end of transmission/reception
					--
					if ORDER = "LSB" then
						--
						-- This is for LSB first
						--
						if bit_cnt = numBits - 1 then
							bit_cnt <= (others => '0');
							SPI_cnt <= (others => '0');
							dataReceived <= dataIn;
							dataReady <= '1';
							state <= sync_delay;
						else
							bit_cnt <= bit_cnt + 1;
							SPI_cnt <= to_unsigned(1,SPI_cnt'length);
						end if;
					else
						--
						-- This is for MSB first
						--
						if bit_cnt = 0 then
							bit_cnt <= numBits - 1;
							SPI_cnt <= (others => '0');
							dataReceived <= dataIn;
							dataReady <= '1';
							state <= sync_delay;
						else
							bit_cnt <= bit_cnt - 1;
							SPI_cnt <= to_unsigned(1,SPI_cnt'length);
						end if;
					end if;
				end if;
			--
			--SYNC delay state
			--
			when sync_delay =>
				dataReady <= '0';
				spi_o.SCLK <= CPOL;
				spi_o.SD <= '0';
				if delayCount < syncDelay then
					delayCount <= delayCount + 1;
				else
					spi_o.SYNC <= not(SYNC_POL);
					delayCount <= (others => '0');
					state <= async_pulse;
				end if;
			--
			--ASYNC pulse state
			--
			when async_pulse =>
				if delayCount < ASYNC_WIDTH then
					spi_o.ASYNC <= ASYNC_POL;
					delayCount <= delayCount + 1;
				else
					state <= idle;
				end if;
				
			when others => null;
		end case;	--end SPI_case
	end if;	--end rising_edge
end process;
			

end Behavioral;

