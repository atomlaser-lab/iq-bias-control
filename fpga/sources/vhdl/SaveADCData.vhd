library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;


entity SaveADCData is
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
end SaveADCData;

architecture Behavioral of SaveADCData is

COMPONENT BlockMem_Fast
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

constant MAX_MEM_ADDR   :   t_mem_addr                      :=  (others => '1');

signal maxAddr          :   t_mem_addr                      :=  (others => '1');

signal trig             :   std_logic_vector(1 downto 0)    :=  "00";
signal wea              :   std_logic_vector(0 downto 0)    :=  "0";
signal addra            :   t_mem_addr                      :=  (others => '0');

signal state            :   natural range 0 to 3            :=  0;
signal dina             :   std_logic_vector(31 downto 0)   :=  (others => '0');

signal resetSync, trigSync        :   std_logic_vector(1 downto 0)    :=  "00";

type t_state_local is (idle,waiting,write_enabled);
signal writeState    :   t_state_local;

signal enable  :   std_logic;

signal delayCount   :   unsigned(delay'length - 1 downto 0);

begin

dina(data_i'length-1 downto 0) <= data_i;
dina(dina'length-1 downto data_i'length) <= (others => '0');

--
-- Generate writeClk-synchronous address reset signal
--
signal_sync(writeClk,aresetn,bus_m.reset,resetSync);
signal_sync(writeClk,aresetn,trig_i,trigSync);
--
-- Instantiate the block memory
--
maxAddr <= (maxAddr'range => '1');
BlockMem_inst : BlockMem_Fast
PORT MAP (
    clka => writeClk,
    wea => wea,
    addra => std_logic_vector(addra),
    dina => dina,
    clkb => readClk,
    addrb => std_logic_vector(bus_m.addr),
    doutb => bus_s.data
);

--
-- Write ADC data to memory
-- On the rising edge of 'trig' we write numSamples to memory
-- On the falling edge of 'trig' we reset the counter
--
wea(0) <= valid_i and enable;
bus_s.last <= addra;
WriteProc: process(writeClk,aresetn) is
begin
    if aresetn = '0' then
        addra <= (others => '0');
        writeState <= idle;
        delayCount <= (others => '0');
    elsif rising_edge(writeClk) then
        if resetSync = "01" then
            addra <= (others => '0');
            writeState <= idle;
        else
            WriteCase: case writeState is
                when idle =>
                    if (trigSync = "01" and trigEdge = '1') or (trigSync = "10" and trigEdge = '0') then
                        addra <= (others => '0');
                        if delay = 0 then
                            enable <= '1';
                            writeState <= write_enabled;
                        else
                            delayCount <= (0 => '1', others => '0');
                            writeState <= waiting;
                        end if;
                    else
                        enable <= '0';
                    end if;
                    
                when waiting =>
                    if delayCount < delay then
                        delayCount <= delayCount + 1;
                    else
                        writeState <= write_enabled;
                        enable <= '1';
                    end if;
                    
                when write_enabled =>
                    if valid_i = '1' and addra < numSamples then
                        addra <= addra + 1;
                    elsif addra >= numSamples then
                        enable <= '0';
                        writeState <= idle;
                    end if;
            end case;
        end if;
    end if;
end process;

--
-- Reads data from the memory address provided by the user
-- Note that we need an extra clock cycle to read data compared to writing it
--
ReadProc: process(readClk,aresetn) is
begin
    if aresetn = '0' then
        state <= 0;
        bus_s.valid <= '0';
        bus_s.status <= idle;
    elsif rising_edge(readClk) then
        if state = 0 and bus_m.trig = '1' then
            state <= 1;
            bus_s.valid <= '0';
            bus_s.status <= waiting;
        elsif state > 0 and state < 2 then
            state <= state + 1;
        elsif state = 2 then
            state <= 0;
            bus_s.valid <= '1';
            bus_s.status <= finishing;
        else
            bus_s.valid <= '0';
            bus_s.status <= idle;
        end if;
    end if;
end process;

end Behavioral;
