library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseUnwrap is
    port(
        --
        -- Clocking and reset
        --
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        --
        -- Control
        --
        enable_i        :   in  std_logic;
        --
        -- Input/output data
        --
        phase_i         :   in  t_phase;
        valid_i         :   in  std_logic;
        phase_o         :   out t_phase;
        valid_o         :   out std_logic
    );
end PhaseUnwrap;

architecture Behavioral of PhaseUnwrap is

constant PHASE_POS_PI       :   t_phase     :=  shift_left(to_signed(1,PHASE_WIDTH),PHASE_WIDTH - 3);

signal phaseNew, phaseOld   :   t_phase;    -- These are used for detecting phase jumps
signal phaseDiff            :   t_phase;    -- This is used for measuring the difference between adjacent phase measurements
signal phaseSum             :   t_phase;    -- This is the reconstructed phase

type t_status_local is (idle,wrapping,summing,output);
signal state    :   t_status_local  :=  idle;

begin

phase_o <= phaseSum;

PhaseWrap: process(clk,aresetn) is
begin
    if aresetn = '0' then
        phaseDiff <= (others => '0');
        phaseNew <= (others => '0');
        phaseOld <= (others => '0');
        phaseSum <= (others => '0');
        state <= idle;
        valid_o <= '0';
    elsif rising_edge(clk) then
        PhaseCase: case(state) is
            when idle =>
                valid_o <= '0';
                if valid_i = '1' then
                    if enable_i = '0' then
                        phaseOld <= (others => '0');
                        phaseNew <= (others => '0');
                        phaseDiff <= (others => '0');
                        phaseSum <= (others => '0');
                    else
                        phaseOld <= phaseNew;
                        phaseNew <= resize(phase_i,phaseNew'length);
                    end if;
                    state <= wrapping;
                end if;
                
            when wrapping =>
                state <= summing;
                if phaseNew - phaseOld > PHASE_POS_PI then
                    phaseDiff <= phaseNew - phaseOld - shift_left(PHASE_POS_PI,1);
                elsif phaseNew - phaseOld < -PHASE_POS_PI then
                    phaseDiff <= phaseNew - phaseOld + shift_left(PHASE_POS_PI,1);
                else
                    phaseDiff <= phaseNew - phaseOld;
                end if;
                
            when summing =>
                state <= idle;
                valid_o <= '1';
                if enable_i = '1' then
                    phaseSum <= phaseSum + phaseDiff;                  
                elsif enable_i = '0' then
                    phaseSum <= (others => '0');
                end if;
            
            when others => null;
        
        end case;
    end if;
end process;


end Behavioral;
