library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 

--
-- This package contains both constants and data types
--
package CustomDataTypes is
--
-- Define parameter data types
--
constant PARAM_WIDTH        :   natural :=  32;
subtype t_param_reg is std_logic_vector(PARAM_WIDTH-1 downto 0);
type t_param_reg_array is array(natural range <>) of t_param_reg;
--
-- Define ADC data types
--
constant ADC_ACTUAL_WIDTH   :   natural :=  14;
constant ADC_WIDTH          :   natural :=  16;
constant NUM_ADCS           :   natural :=  2;
subtype t_adc is signed(ADC_WIDTH-1 downto 0);
type t_adc_array is array(natural range <>) of t_adc;
--
-- Define DAC data types
--
constant DAC_ACTUAL_WIDTH   :   natural :=  14;
constant DAC_WIDTH          :   natural :=  16;
constant NUM_DACS           :   natural :=  2;
subtype t_dac is signed(DAC_WIDTH-1 downto 0);
type t_dac_array is array(natural range <>) of t_dac;
--
-- Define PWM types
--
constant PWM_DATA_WIDTH     :   natural :=  10;
constant PWM_EXP_WIDTH  :   natural :=  PWM_DATA_WIDTH + 1;

subtype t_pwm is unsigned(PWM_DATA_WIDTH - 1 downto 0);
type t_pwm_array is array(natural range <>) of t_pwm;
subtype t_pwm_exp is signed(PWM_EXP_WIDTH - 1 downto 0);
type t_pwm_exp_array is array(natural range <>) of t_pwm_exp;
type t_pwm_signed_array is array(natural range <>) of signed(PWM_DATA_WIDTH - 1 downto 0);

--
-- Defines PID gain types
--
constant PID_WIDTH          :   natural :=  8;
--
-- Defines DDS-related types
--
constant DDS_PHASE_WIDTH    :   natural :=  32;
subtype t_phase is unsigned(DDS_PHASE_WIDTH - 1 downto 0);
type t_phase_array is array(natural range <>) of t_phase;
--
-- Defines filter related types
--
subtype t_meas is signed(23 downto 0);
type t_meas_array is array(natural range <>) of t_meas;
--
-- Defines AXI address and data widths
--
constant MEM_ADDR_WIDTH :   natural :=  12;
constant MEM_DATA_WIDTH :   natural :=  32;
--
-- Defines MEM address and data signals
--
subtype t_mem_addr is unsigned(MEM_ADDR_WIDTH-1 downto 0);
subtype t_mem_data is std_logic_vector(MEM_DATA_WIDTH-1 downto 0);
--
-- Defines a generic status type
--
type t_status is (idle,waiting,reading,writing,processing,running,finishing);
--
-- Defines data buses for handling block memories
--
type t_mem_bus_master is record
    addr    :   t_mem_addr;
    trig    :   std_logic;
    reset   :   std_logic;
    status  :   t_status;
end record t_mem_bus_master;

type t_mem_bus_slave is record
    data    :   t_mem_data;
    valid   :   std_logic;
    last    :   t_mem_addr;
    status  :   t_status;
end record t_mem_bus_slave;

type t_mem_bus is record
    m   :   t_mem_bus_master;
    s   :   t_mem_bus_slave;
end record t_mem_bus;

type t_mem_bus_master_array is array(natural range <>) of t_mem_bus_master;
type t_mem_bus_slave_array is array(natural range <>) of t_mem_bus_slave;
type t_mem_bus_array is array(natural range <>) of t_mem_bus;

--
-- Define initial values
--
constant INIT_MEM_BUS_MASTER    :  t_mem_bus_master :=  (addr   =>  (others => '0'),
                                                         trig   =>  '0',
                                                         reset  =>  '0',
                                                         status =>  idle);
constant INIT_MEM_BUS_SLAVE     :   t_mem_bus_slave :=  (data   =>  (others => '0'),
                                                         valid  =>  '0',
                                                         last   =>  (others => '0'),
                                                         status =>  idle);
constant INIT_MEM_BUS           :   t_mem_bus       :=  (m  =>  INIT_MEM_BUS_MASTER,
                                                         s  =>  INIT_MEM_BUS_SLAVE);
--
-- Define FIFO data types
--
constant FIFO_WIDTH         :   natural :=  32;
constant FIFO_TIMEOUT       :   unsigned(27 downto 0)   :=  to_unsigned(125000000,28);

type t_fifo_bus_master is record
    status  :   t_status;
    rd_en   :   std_logic;
    count   :   unsigned(27 downto 0);
end record t_fifo_bus_master;

type t_fifo_bus_slave is record
    data    :   std_logic_vector(FIFO_WIDTH-1 downto 0);
    valid   :   std_logic;
    empty   :   std_logic;
    full    :   std_logic;
end record t_fifo_bus_slave;

type t_fifo_bus is record
    m   :   t_fifo_bus_master;
    s   :   t_fifo_bus_slave;
end record t_fifo_bus;

type t_fifo_bus_array is array(natural range <>) of t_fifo_bus;

constant INIT_FIFO_BUS_MASTER    :  t_fifo_bus_master :=(rd_en  =>  '0',
                                                        status =>  idle,
                                                        count  =>  (others => '0'));
constant INIT_FIFO_BUS_SLAVE     :   t_fifo_bus_slave :=(data   =>  (others => '0'),
                                                        empty  =>  '0',
                                                        full   =>  '0',
                                                        valid  =>  '0');
constant INIT_FIFO_BUS           :   t_FIFO_bus       :=(m  =>  INIT_FIFO_BUS_MASTER,
                                                        s  =>  INIT_FIFO_BUS_SLAVE);

--
-- Define SPI types
--
type t_spi_master is record
	SCLK	:	std_logic;
	SD		:	std_logic;
	SYNC	:	std_logic;
	ASYNC	:	std_logic;
end record t_spi_master;

type t_spi_slave is record
	SD		:	std_logic;
	READY	:	std_logic;
end record t_spi_slave;

constant INIT_SPI_MASTER	:	t_spi_master	:=	(
	SCLK	=> '0',
	SD		=>	'0',
	SYNC	=>	'0',
	ASYNC	=>	'0'
);

constant INIT_SPI_SLAVE		:	t_spi_slave		:=	(
	SD		=>	'0',
	READY	=>	'0'
);

function conv_std_logic_vector(
	signal spi_i	:	in	t_spi_master
) return std_logic_vector;


function to_slv_u(ARG   :   integer; SZ :   natural) return std_logic_vector;
function to_slv_s(ARG   :   integer; SZ :   natural) return std_logic_vector;

procedure signal_sync(
    signal clk_i   :   in       std_logic;
    signal aresetn :   in       std_logic;
    signal trig_i  :   in       std_logic;
    signal trig_o  :   inout    std_logic_vector(1 downto 0));

end CustomDataTypes;

--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
package body CustomDataTypes is

function to_slv_u(ARG : integer; SZ : natural) return std_logic_vector is
    variable RESULT :   std_logic_vector(SZ - 1 downto 0);
begin
    RESULT  :=  std_logic_vector(to_unsigned(ARG,SZ));
    return RESULT;
end to_slv_u;
        
function to_slv_s(ARG : integer; SZ : natural) return std_logic_vector is
    variable RESULT :   std_logic_vector(SZ - 1 downto 0);
begin
    RESULT  :=  std_logic_vector(to_signed(ARG,SZ));
    return RESULT;
end to_slv_s;  

procedure signal_sync(
    signal clk_i   :   in       std_logic;
    signal aresetn :   in       std_logic;
    signal trig_i  :   in       std_logic;
    signal trig_o  :   inout    std_logic_vector(1 downto 0)) is
begin
    if aresetn = '0' then
        trig_o <= (others => trig_i);
    elsif rising_edge(clk_i) then
        trig_o <= trig_o(0) & trig_i;
    end if;
end signal_sync; 

end CustomDataTypes;
