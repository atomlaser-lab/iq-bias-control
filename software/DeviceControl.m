classdef DeviceControl < handle
    properties
        jumpers
        t
        data
    end
    
    properties(SetAccess = immutable)
        conn
        triggers
        ext_o
        adc
        ext_i
        led_o
        phase_offset % added for DDS
        phase_inc  % added for DDS
        dds2_phase_offset % added for DDS2
        dds2_phase_inc  % added for DDS2
        dds3_phase_offset % added for DDS3
        dds3_phase_inc  % added for DDS3
        log2_rate
        cic_shift
        numSamples
        pwm
       % new_signal % new signal added here for dds2

    end
    
    properties(SetAccess = protected)
        % R/W registers
        trigReg
        outputReg
        inputReg
        filterReg
        adcReg
        ddsPhaseOffsetReg %  added for dds 
        ddsPhaseIncReg  % added for dds
        dds2PhaseOffsetReg %  added for dds2 
        dds2PhaseIncReg  % added for dds2
        dds3PhaseOffsetReg % added for dds3
        dds3PhaseIncReg % ------- dds3
        numSamplesReg
        pwmReg
        auxReg
        %new_register % new register added here for dds2
    end
    
    properties(Constant)
        CLK = 125e6;
        %HOST_ADDRESS = 'rp-f0919a.local';
        HOST_ADDRESS = 'rp-f06a54.local';
        DAC_WIDTH = 14;
        ADC_WIDTH = 14;
        DDS_WIDTH = 32;
        CONV_ADC_LV = 1.1851/2^(DeviceControl.ADC_WIDTH - 1);
        CONV_ADC_HV = 29.3570/2^(DeviceControl.ADC_WIDTH - 1);
        
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
            self.pwmReg = DeviceRegister('2C',self.conn);
            self.numSamplesReg = DeviceRegister('100000',self.conn);
            self.auxReg = DeviceRegister('100004',self.conn);
            
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

            self.pwm = DeviceParameter.empty;
            for nn = 1:4
                self.pwm(nn) = DeviceParameter(8*(nn - 1) + [0,7],self.pwmReg)...
                    .setLimits('lower',0,'upper',1.62)...
                    .setFunctions('to',@(x) x/1.62*255,'from',@(x) x/255*1.62);
            end
          
            self.log2_rate = DeviceParameter([0,3],self.filterReg,'uint32')...
                .setLimits('lower',2,'upper',13);

            self.cic_shift = DeviceParameter([4,7],self.filterReg,'uint32')...
                .setLimits('lower',0,'upper',15);

            self.numSamples = DeviceParameter([0,11],self.numSamplesReg,'uint32')...
                .setLimits('lower',0,'upper',2^12);
        end
        
        function self = setDefaults(self,varargin)
           % self.dac(1).set(0);
            %self.dac(2).set(0);
             self.ext_o.set(0);
             self.led_o.set(0);
             self.phase_inc.set(1e6); % added for dds1 
             self.phase_offset.set(0); % added for dds1
             self.dds2_phase_inc.set(1e6); % added for dds2 
             self.dds2_phase_offset.set(0); % added for dds2
             self.dds3_phase_inc.set(1e6); % added for dds3 
             self.dds3_phase_offset.set(0); % added for dds3
            for nn = 1:numel(self.pwm)
                self.pwm(nn).set(0);
            end
             self.log2_rate.set(10);
             self.cic_shift.set(0);
             self.numSamples.set(4000);
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
             self.pwmReg.write;

             self.numSamplesReg.write;
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
            self.pwmReg.read;
            self.numSamplesReg.read;

            self.ext_o.get;
            self.led_o.get;
            self.ext_i.get;
            
            for nn = 1:numel(self.adc)
                self.adc(nn).get;
            end
            self.phase_offset.get; % added for dds1
            self.phase_inc.get;   % added for dds1
            self.dds2_phase_offset.get; % added for dds2
            self.dds2_phase_inc.get;   % added for dds2
            self.dds3_phase_offset.get; % added for dds3
            self.dds3_phase_inc.get;   % added for dds3

            for nn = 1:numel(self.pwm)
                self.pwm(nn).get;
            end

            self.log2_rate.get;
            self.cic_shift.get;

            self.numSamples.get;
        end

        function self = memoryReset(self)
            %MEMORYRESET Resets the two block memories
            
            self.auxReg.write;
        end
        
        function r = convert2volts(self,x)
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_ADC_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_ADC_LV;
            end
            r = x*c;
        end
        
        function r = convert2int(self,x)
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_ADC_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_ADC_LV;
            end
            r = x/c;
        end

        function self = getDemodulatedData(self,numSamples,saveType)
            %GETDEMODULATEDDATA Fetches demodulated data from the device
            %
            %   SELF = GETDEMODULATEDDATA(NUMSAMPLES) Acquires NUMSAMPLES of demodulated data
            %
            %   SELF = GETDEMODULATEDDATA(__,SAVETYPE) uses SAVETYPE for saving data.  For advanced
            %   users only: see the readme
            
            if nargin < 3
                saveType = 1;
            end
            
            self.conn.write(0,'mode','command','cmd',...
                {'./saveData','-n',sprintf('%d',round(numSamples)),'-t',sprintf('%d',saveType)},...
                'return_mode','file');
            raw = typecast(self.conn.recvMessage,'uint8');
            d = self.convertData(raw);
            self.data = d;
            self.t = 1/self.CLK*2^self.log2_rate.value*(0:(numSamples-1));
        end

        function self = getRAM(self,numSamples)
            %GETRAM Fetches recorded in block memory from the device
            %
            %   SELF = GETRAM(SELF) Retrieves current number of recorded
            %   samples from the device SELF
            %
            %   SELF = GETRAM(SELF,N) Retrieves N samples from device
            
%             if nargin < 2
%                 self.conn.keepAlive = true;
%                 self.lastSample(1).read;
%                 self.conn.keepAlive = false;
%                 numSamples = self.lastSample(1).value;
%             end
            self.numSamples.set(numSamples).write;
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[0,0]);
            
            self.conn.write(0,'mode','command','cmd',...
                {'./fetchRAM',sprintf('%d',round(numSamples))},...
                'return_mode','file');
            raw = typecast(self.conn.recvMessage,'uint8');
            if strcmpi(self.jumpers,'hv')
                c = self.CONV_ADC_HV;
            elseif strcmpi(self.jumpers,'lv')
                c = self.CONV_ADC_LV;
            end
            d = self.convertADCData(raw,c);
            self.data = d;
            dt = self.CLK^-1;
            self.t = dt*(0:(size(self.data,1)-1));
        end

        function D = getCharacterisationData(self,numVoltages,numAvgs)
            %GETCHARACTERISATIONDATA Acquires data characterising the
            %response of the system to bias voltages
            %
            %   SELF = GETCHARACTERISATIONDATA(SELF) Acquires 10 voltages
            %   for each bias by averaging 100 samples per voltage
            %
            %   SELF = GETCHARACTERISATIONDATA(__,NV) Acquires NV voltages
            %
            %   SELF = GETCHARACTERISATIONDATA(__,NA) Averages NA samples per
            %   voltage
            if nargin == 1
                numVoltages = 10;
                numAvgs = 100;
            elseif nargin == 2
                numAvgs = 100;
            end
            self.conn.write(0,'mode','command','cmd',...
                {'./analyze_biases','-n',sprintf('%d',round(numVoltages)),'-a',sprintf('%d',numAvgs)},...
                'return_mode','file');
            raw = typecast(self.conn.recvMessage,'int32');
            D = zeros([numVoltages*[1,1,1],3]);
            for nn = size(D,4)
                tmp = raw((nn - 1)*numVoltages^3 + (1:(numVoltages^3)));
                D(:,:,:,nn) = reshape(double(tmp),numVoltages*[1,1,1]);
            end
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
            self.pwmReg.print('pwmReg',strwidth);
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
             for nn = 1:numel(self.pwm)
                self.pwm(nn).print(sprintf('PWM %d',nn),strwidth,'%.3f');
             end
             self.log2_rate.print('Log2 Rate',strwidth,'%.0f');
             self.cic_shift.print('CIC shift',strwidth,'%.0f');
        end
        
        
    end

    methods(Static)
        function d = convertData(raw)
            raw = raw(:);
            Nraw = numel(raw);
            numStreams = 3;
            d = zeros(Nraw/(numStreams*4),numStreams,'int32');
            
            raw = reshape(raw,4*numStreams,Nraw/(4*numStreams));
            for nn = 1:numStreams
                d(:,nn) = typecast(uint8(reshape(raw((nn-1)*4 + (1:4),:),4*size(d,1),1)),'int32');
            end
            d = double(d);
        end

        function v = convertADCData(raw,c)
            %CONVERTADCDATA Converts raw ADC data into proper int16/double format
            %
            %   V = CONVERTADCDATA(RAW) Unpacks raw data from uint8 values to
            %   a pair of double values for each measurement
            %
            %   V = CONVERTADCDATA(RAW,C) uses conversion factor C in the
            %   conversion
            
            if nargin < 2
                c = 1;
            end
            
            Nraw = numel(raw);
            d = zeros(Nraw/4,2,'int16');
            
            mm = 1;
            for nn = 1:4:Nraw
                d(mm,1) = typecast(uint8(raw(nn + (0:1))),'int16');
                d(mm,2) = typecast(uint8(raw(nn + (2:3))),'int16');
                mm = mm + 1;
            end
            
            v = double(d)*c;
        end
    end
    
end