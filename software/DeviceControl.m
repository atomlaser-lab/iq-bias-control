classdef DeviceControl < handle
    properties
        jumpers
    end
    
    properties(SetAccess = immutable)
        conn
       % dac
        ext_o
        adc
        ext_i
        led_o
        filterData
        phase_offset % added for DDS
        phase_inc  % added for DDS
        dds2_phase_offset % added for DDS2
        dds2_phase_inc  % added for DDS2
        dds3_phase_offset % added for DDS3
        dds3_phase_inc  % added for DDS3
       % new_signal % new signal added here for dds2

    end
    
    properties(SetAccess = protected)
        % R/W registers
        trigReg
        outputReg
        inputReg
        filterReg
       % dacReg
        adcReg
        ddsPhaseOffsetReg %  added for dds 
        ddsPhaseIncReg  % added for dds
        dds2PhaseOffsetReg %  added for dds2 
        dds2PhaseIncReg  % added for dds2
        dds3PhaseOffsetReg % added for dds3
        dds3PhaseIncReg % ------- dds3
        %new_register % new register added here for dds2
    end
    
    properties(Constant)
        CLK = 125e6;
        %HOST_ADDRESS = 'rp-f0919a.local';
        HOST_ADDRESS = 'rp-f06a54.local';
        DAC_WIDTH = 14;
        ADC_WIDTH = 14;
        DDS_WIDTH = 32;
        CONV_LV = 1.1851/2^(DeviceControl.ADC_WIDTH - 1);
        CONV_HV = 29.3570/2^(DeviceControl.ADC_WIDTH - 1);
        
    end
    
    methods
        function self = DeviceControl(varargin)
            if numel(varargin)==1
                self.conn = ConnectionClient(varargin{1});
            else
                self.conn = ConnectionClient(self.HOST_ADDRESS);
            end
            
            self.jumpers = 'lv';
            
            % R/W registers
            self.trigReg = DeviceRegister('0',self.conn);
            self.outputReg = DeviceRegister('4',self.conn);
            %self.dacReg = DeviceRegister('8',self.conn);
            self.filterReg = DeviceRegister('8',self.conn);
            self.adcReg = DeviceRegister('C',self.conn);
            self.inputReg = DeviceRegister('10',self.conn);
            self.ddsPhaseIncReg = DeviceRegister('14',self.conn);
            self.ddsPhaseOffsetReg = DeviceRegister('18',self.conn);
            self.dds2PhaseIncReg = DeviceRegister('1C',self.conn);
            self.dds2PhaseOffsetReg = DeviceRegister('20',self.conn);
            self.dds3PhaseIncReg = DeviceRegister('24',self.conn);
            self.dds3PhaseOffsetReg = DeviceRegister('28',self.conn);
            
           % self.new_register = DeviceRegister('1C',self.conn); % added this new register
            
            % self.dac = DeviceParameter([0,15],self.dacReg,'int16')...
            %     .setLimits('lower',-1,'upper',1)...
            %     .setFunctions('to',@(x) x*(2^(self.DAC_WIDTH - 1) - 1),'from',@(x) x/(2^(self.DAC_WIDTH - 1) - 1));
            % 
            % self.dac(2) = DeviceParameter([16,31],self.dacReg,'int16')...
            %     .setLimits('lower',-1,'upper',1)...
            %     .setFunctions('to',@(x) x*(2^(self.DAC_WIDTH - 1) - 1),'from',@(x) x/(2^(self.DAC_WIDTH - 1) - 1));
            % 
            self.ext_o = DeviceParameter([0,7],self.outputReg)...
                .setLimits('lower',0,'upper',255);
            self.led_o = DeviceParameter([8,15],self.outputReg)...
                .setLimits('lower',0,'upper',255);
            
            self.adc = DeviceParameter([0,15],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            
            self.adc(2) = DeviceParameter([16,31],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            
            self.ext_i = DeviceParameter([0,7],self.inputReg);
           
            self.filterData = DeviceParameter([0,15],self.filterReg,'int16')...
                 .setLimits('lower',0,'upper', 50e6)...
                 .setFunctions('to',@(x) x/self.CLK*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*self.CLK);
            self.filterData(2) = DeviceParameter([0,15],self.filterReg,'int16')...
                 .setLimits('lower',0,'upper', 50e6)...
                 .setFunctions('to',@(x) x/self.CLK*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*self.CLK);
            self.filterData(3) = DeviceParameter([0,15],self.filterReg,'int16')...
                 .setLimits('lower',0,'upper', 50e6)...
                 .setFunctions('to',@(x) x/self.CLK*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*self.CLK);

            self.phase_inc = DeviceParameter([0,31],self.ddsPhaseIncReg,'uint32')...
                 .setLimits('lower',0,'upper', 50e6)...
                 .setFunctions('to',@(x) x/self.CLK*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*self.CLK);
            
            self.phase_offset = DeviceParameter([0,31],self.ddsPhaseOffsetReg,'uint32')...
                 .setLimits('lower',-360,'upper', 360)...
                 .setFunctions('to',@(x) mod(x,360)/360*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*360);
             %% new signals for dds2
              self.dds2_phase_inc = DeviceParameter([0,31],self.dds2PhaseIncReg,'uint32')...
                 .setLimits('lower',0,'upper', 50e6)...
                 .setFunctions('to',@(x) x/self.CLK*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*self.CLK);
            
            self.dds2_phase_offset = DeviceParameter([0,31],self.dds2PhaseOffsetReg,'uint32')...
                 .setLimits('lower',-360,'upper', 360)...
                 .setFunctions('to',@(x) mod(x,360)/360*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*360);
             %% new signals for dds3
              self.dds3_phase_inc = DeviceParameter([0,31],self.dds3PhaseIncReg,'uint32')...
                 .setLimits('lower',0,'upper', 50e6)...
                 .setFunctions('to',@(x) x/self.CLK*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*self.CLK);
            
            self.dds3_phase_offset = DeviceParameter([0,31],self.dds3PhaseOffsetReg,'uint32')...
                 .setLimits('lower',-360,'upper', 360)...
                 .setFunctions('to',@(x) mod(x,360)/360*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*360);
          

        end
        
        function self = setDefaults(self,varargin)
           % self.dac(1).set(0);
            %self.dac(2).set(0);
             self.ext_o.set(0);
             self.led_o.set(0);
             self.filterData(1).set(1e6);
             self.filterData(2).set(1e6);
             self.filterData(3).set(1e6);
             self.phase_inc.set(1e6); % added for dds1 
             self.phase_offset.set(0); % added for dds1
             self.dds2_phase_inc.set(1e6); % added for dds2 
             self.dds2_phase_offset.set(0); % added for dds2
             self.dds3_phase_inc.set(1e6); % added for dds3 
             self.dds3_phase_offset.set(0); % added for dds3
             
        end
        
        function self = check(self)

        end
        
        function self = upload(self)
             self.check;
             self.outputReg.write;
             self.filterReg.write;
             self.ddsPhaseIncReg.write; % added for dds
             self.ddsPhaseOffsetReg.write; % added for dds
             self.dds2PhaseIncReg.write; % added for dds2
             self.dds2PhaseOffsetReg.write; % added for dds2
             self.dds3PhaseIncReg.write; % added for dds3
             self.dds3PhaseOffsetReg.write; % added for dds3
        end
        
        function self = fetch(self)
            %Read registers
            self.outputReg.read;
            self.inputReg.read;
            self.filterReg.read;
            self.adcReg.read;
            self.ddsPhaseIncReg.read;
            self.ddsPhaseOffsetReg.read;
            self.dds2PhaseIncReg.read; % dds2
            self.dds2PhaseOffsetReg.read; % dds2
            self.dds3PhaseIncReg.read; % dds2
            self.dds3PhaseOffsetReg.read; % dds2

            self.ext_o.get;
            self.led_o.get;
            self.ext_i.get
            
            for nn = 1:numel(self.adc)
                self.adc(nn).get;
            end
            self.phase_offset.get; % added for dds1
            self.phase_inc.get;   % added for dds1
            self.dds2_phase_offset.get; % added for dds2
            self.dds2_phase_inc.get;   % added for dds2
            self.dds3_phase_offset.get; % added for dds3
            self.dds3_phase_inc.get;   % added for dds3

            for nn = 1:numel(self.filterData)
                 self.filterData(nn).get;
            end

            
        
        end
        
        function r = convert2volts(self,x)
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_LV;
            end
            r = x*c;
        end
        
        function r = convert2int(self,x)
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_LV;
            end
            r = x/c;
        end
        
        function disp(self)
            strwidth = 20;
            fprintf(1,'DeviceControl object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.outputReg.print('outputReg',strwidth);
            self.inputReg.print('inputReg',strwidth);
            self.filterReg.print('filterReg',strwidth);
            self.adcReg.print('adcReg',strwidth);
            self.ddsPhaseIncReg.print('phaseIncReg',strwidth);
            self.ddsPhaseOffsetReg.print('phaseOffsetReg',strwidth);
            self.dds2PhaseIncReg.print('dds2phaseIncReg',strwidth);
            self.dds2PhaseOffsetReg.print('dds2phaseOffsetReg',strwidth);
            self.dds3PhaseIncReg.print('dds3phaseIncReg',strwidth);
            self.dds3PhaseOffsetReg.print('dds3phaseOffsetReg',strwidth);
           % self.new_register.print('new_register',strwidth);

            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Parameters\n');
             self.led_o.print('LEDs',strwidth,'%02x');
             self.ext_o.print('External output',strwidth,'%02x');
             self.ext_i.print('External input',strwidth,'%02x');
             %self.dac(1).print('DAC 1',strwidth,'%.3f');
             %self.dac(2).print('DAC 2',strwidth,'%.3f');
             self.adc(1).print('ADC 1',strwidth,'%.3f');
             self.adc(2).print('ADC 2',strwidth,'%.3f');
             self.phase_inc.print('Phase Increment',strwidth,'%.3e');
             self.phase_offset.print('Phase Offset',strwidth,'%.3f');
             self.dds2_phase_inc.print('dds2 Phase Increment',strwidth,'%.3e');
             self.dds2_phase_offset.print('dds2 Phase Offset',strwidth,'%.3f');
             self.dds3_phase_inc.print('dds3 Phase Increment',strwidth,'%.3e');
             self.dds3_phase_offset.print('dds3 Phase Offset',strwidth,'%.3f');
             self.filterData(1).print('filterData 1',strwidth,'%.3f');
             self.filterData(2).print('filterData 2',strwidth,'%.3f');
             self.filterData(3).print('filterData 3',strwidth,'%.3f');
        end
        
        
    end
    
end