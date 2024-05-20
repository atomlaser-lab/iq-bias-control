classdef DeviceControl < handle
    properties
        jumpers
        t
        data
        auto_retry
    end
    
    properties(SetAccess = immutable)
        conn                    %Instance of CONNECTIONCLIENT used for communication with socket server
        %
        % All of these are DEVICEPARAMETER objects
        %
        triggers                %Triggers -- currently unused
        ext_o                   %External output signals -- currently unused
        adc_select              %Select which ADC to use
        adc                     %Read-only for getting current ADC values
        ext_i                   %Read-only for getting current digital input values
        led_o                   %LED control
        phase_inc               %Modulation frequency [Hz]
        phase_correction        %Correction to output phase to match high-frequency signal [deg]
        phase_offset            %Phase offset for demodulation of fundamental [deg]
        dds2_phase_offset       %Phase offset for demodulation at 2nd harmonic [deg]
        log2_rate               %Log2(CIC filter rate)
        cic_shift               %Log2(Additional digital gain after filter)
        numSamples              %Number of samples to collect from recording raw ADC signals
        output_scale            %Output scaling from 0 to 1
        pwm                     %Array of 4 PWM outputs
        control                 %Coupled integral control
        fifo_route              %Array of 4 FIFO routing options
    end
    
    properties(SetAccess = protected)
        % R/W registers
        topReg                  %Top-level register
        trigReg                 %Register for software trigger signals
        outputReg               %Register for external output control (digital and LED)
        inputReg                %UNUSED
        filterReg               %Register for CIC filter control
        adcReg                  %Read-only register for getting current ADC data
        ddsPhaseIncReg          %Register for modulation frequency
        ddsPhaseCorrectionReg   %Register for the output phase correction
        ddsPhaseOffsetReg       %Register for phase offset at fundamental
        dds2PhaseOffsetReg      %Register for phase offset at 2nd harmonic
        numSamplesReg           %Register for storing number of samples of ADC data to fetch
        pwmRegs                 %Registers for PWM signals
        auxReg                  %Auxiliary register
        controlRegs             %Registers for control
        gainRegs                %Registers for gain values
        pwmLimitRegs            %Registers for limiting PWM outputs
        %new_register % new register added here for dds2
    end
    
    properties(Constant)
        CLK = 125e6;
        DEFAULT_HOST = 'rp-f06a54.local';
        DAC_WIDTH = 14;
        ADC_WIDTH = 14;
        DDS_WIDTH = 32;
        PARAM_WIDTH = 32;
        PWM_WIDTH = 10;
        NUM_PWM = 3;
        NUM_MEAS = 4;
        %
        % Conversion values going from integer values to volts
        %
        CONV_ADC_LV = 1.1851/2^(DeviceControl.ADC_WIDTH - 1);
        CONV_ADC_HV = 29.3570/2^(DeviceControl.ADC_WIDTH - 1);
        CONV_PWM = 1.6/(2^DeviceControl.PWM_WIDTH - 1);
    end
    
    methods
        function self = DeviceControl(varargin)
            %DEVICECONTROL Creates an instance of a DEVICECONTROL object.  Sets
            %up the registers and parameters as instances of the correct
            %classes with the necessary
            %addressses/registers/limits/functions
            %
            %   SELF = DEVICECONTROL() creates an instance with default host
            %   and port
            %
            %   SELF = DEVICECONTROL(HOST) creates an instance with socket
            %   server host address HOST

            if numel(varargin)==1
                self.conn = ConnectionClient(varargin{1});
            else
                self.conn = ConnectionClient(self.DEFAULT_HOST);
            end
            %
            % Set jumper values
            %
            self.jumpers = 'lv';
            %
            % Registers
            %
            self.topReg = DeviceRegister('40',self.conn);
            self.trigReg = DeviceRegister('0',self.conn);
            self.outputReg = DeviceRegister('4',self.conn);
            self.filterReg = DeviceRegister('8',self.conn);
            self.adcReg = DeviceRegister('C',self.conn,true);
            self.inputReg = DeviceRegister('10',self.conn,true);
            self.ddsPhaseIncReg = DeviceRegister('14',self.conn);
            self.ddsPhaseOffsetReg = DeviceRegister('18',self.conn);
            self.dds2PhaseOffsetReg = DeviceRegister('20',self.conn);
            self.ddsPhaseCorrectionReg = DeviceRegister('30',self.conn);
            self.pwmRegs = DeviceRegister.empty;
            for nn = 1:self.NUM_PWM
                self.pwmRegs(nn) = DeviceRegister(hex2dec('50') + (nn - 1)*4,self.conn);
            end
            self.numSamplesReg = DeviceRegister('100000',self.conn);
            %
            % PID registers: there are 3 PIDs with IQBiasPID.NUM_REGS registers
            % each, starting at address 0x000100
            %
            self.controlRegs = DeviceRegister.empty;
            self.gainRegs = DeviceRegister.empty;
            self.pwmLimitRegs = DeviceRegister.empty;
            for nn = 1:IQBiasController.NUM_CONTROL_REGS
                self.controlRegs(nn,1) = DeviceRegister(hex2dec('100') + (nn - 1)*4,self.conn);
            end
            for nn = 1:IQBiasController.NUM_GAIN_REGS
                self.gainRegs(nn,1) = DeviceRegister(hex2dec('108') + (nn - 1)*4,self.conn);
            end
            for nn = 1:IQBiasController.NUM_LIMIT_REGS
                self.pwmLimitRegs(nn,1) = DeviceRegister(hex2dec('114') + (nn - 1)*4,self.conn);
            end
            %
            % Auxiliary register for all and sundry
            %
            self.auxReg = DeviceRegister('100004',self.conn);
            %
            % ADC Selector
            self.adc_select = DeviceParameter([0,0],self.topReg);
            %
            % Digital and LED input/output parameters
            %
            self.ext_o = DeviceParameter([0,7],self.outputReg)...
                .setLimits('lower',0,'upper',255);
            self.ext_i = DeviceParameter([0,7],self.inputReg);
            self.led_o = DeviceParameter([8,15],self.outputReg)...
                .setLimits('lower',0,'upper',255);
            %
            % Current ADC values
            %
            self.adc = DeviceParameter([0,15],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            self.adc(2) = DeviceParameter([16,31],self.adcReg,'int16')...
                .setFunctions('to',@(x) self.convert2int(x),'from',@(x) self.convert2volts(x));
            %
            % Modulation settings
            % 
            self.phase_inc = DeviceParameter([0,31],self.ddsPhaseIncReg,'uint32')...
                .setLimits('lower',0,'upper', 50e6)...
                .setFunctions('to',@(x) x/self.CLK*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*self.CLK);
            self.phase_offset = DeviceParameter([0,31],self.ddsPhaseOffsetReg,'uint32')...
                .setLimits('lower',-360,'upper', 360)...
                .setFunctions('to',@(x) mod(x,360)/360*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*360);
            self.dds2_phase_offset = DeviceParameter([0,31],self.dds2PhaseOffsetReg,'uint32')...
                .setLimits('lower',-360,'upper', 360)...
                .setFunctions('to',@(x) mod(x,360)/360*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*360);
            self.phase_correction = DeviceParameter([0,31],self.ddsPhaseCorrectionReg,'uint32')...
                .setLimits('lower',-360,'upper', 360)...
                .setFunctions('to',@(x) mod(x,360)/360*2^(self.DDS_WIDTH),'from',@(x) x/2^(self.DDS_WIDTH)*360);
            self.output_scale = DeviceParameter([16,23],self.filterReg,'uint32')...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x*(2^8 - 1),'from',@(x) x/(2^8 - 1));
            %
            % Filter settings
            %
            self.log2_rate = DeviceParameter([0,3],self.filterReg,'uint32')...
                .setLimits('lower',2,'upper',13);
            self.cic_shift = DeviceParameter([4,11],self.filterReg,'int8')...
                .setLimits('lower',-100,'upper',100);
            %
            % PWM settings
            %
            self.pwm = DeviceParameter.empty;
            for nn = 1:self.NUM_PWM
                self.pwm(nn) = DeviceParameter([0,self.PWM_WIDTH - 1],self.pwmRegs(nn))...
                    .setLimits('lower',0,'upper',1.62)...
                    .setFunctions('to',@(x) x/self.CONV_PWM,'from',@(x) x*self.CONV_PWM);
            end
            %
            % Number of samples for reading raw ADC data
            %
            self.numSamples = DeviceParameter([0,11],self.numSamplesReg,'uint32')...
                .setLimits('lower',0,'upper',2^12);
            %
            % PID settings
            %
            self.control = IQBiasController(self,self.controlRegs,self.gainRegs,self.pwmLimitRegs);
            %
            % FIFO routing
            %
            self.fifo_route = DeviceParameter.empty;
            for nn = 1:4
                self.fifo_route(nn) = DeviceParameter((16 + (nn - 1))*[1,1],self.outputReg,'uint32')...
                    .setLimits('lower',0,'upper',1);
            end
        end
        
        function self = setDefaults(self,varargin)
            %SETDEFAULTS Sets parameter values to their defaults
            %
            %   SELF = SETDEFAULTS(SELF) sets default values for SELF
            self.adc_select.set(0);
            self.ext_o.set(0);
            self.led_o.set(0);
            self.phase_inc.set(4e6); 
            self.phase_correction.set(0);
            self.phase_offset.set(154.8); 
            self.dds2_phase_offset.set(161);
            self.pwm.set([0.2865,0.6272,0.8446]);
            self.log2_rate.set(13);
            self.cic_shift.set(-3);
            self.output_scale.set(1);
            self.numSamples.set(4000);
            self.control.setDefaults;
            for nn = 1:numel(self.fifo_route)
                self.fifo_route(nn).set(0);
            end

            self.auto_retry = true;
        end

        function r = dt(self)
            %DT Returns the current sampling time based on the filter
            %settings
            %
            %   R = DT(SELF) returns sampling time R for DEVICECONTROL object
            %   SELF
            r = 2^(self.log2_rate.value)/self.CLK;
        end
        
        function self = check(self)

        end
        
        function self = upload(self)
            %UPLOAD Uploads register values to the device
            %
            %   SELF = UPLOAD(SELF) uploads register values associated with
            %   object SELF
            
            %
            % Check parameters first
            %
            self.check;
            %
            % Get all write data
            %
            p = properties(self);
            d = [];
            for nn = 1:numel(p)
                if isa(self.(p{nn}),'DeviceRegister')
                    R = self.(p{nn});
                    if numel(R) == 1
                        if ~R.read_only
                            d = [d;self.(p{nn}).getWriteData]; %#ok<*AGROW>
                        end
                    else
                        for row = 1:size(R,1)
                            for col = 1:size(R,2)
                                if ~R(row,col).read_only
                                    d = [d;R(row,col).getWriteData];
                                end
                            end
                        end
                    end
                end
            end

            d = d';
            d = d(:);
            %
            % Write every register using the same connection
            %
            self.conn.write(d,'mode','write');
        end
        
        function self = fetch(self)
            %FETCH Retrieves parameter values from the device
            %
            %   SELF = FETCH(SELF) retrieves values and stores them in
            %   object SELF
            
            %
            % Get addresses to read from for each register and get data
            % from device
            %
            p = properties(self);
            pread = {};
            Rread = DeviceRegister.empty;
            d = [];
            for nn = 1:numel(p)
                if isa(self.(p{nn}),'DeviceRegister')
                    R = self.(p{nn});
                    if numel(R) == 1
                        d = [d;R.getReadData];
                        Rread(end + 1) = R;
                        pread{end + 1} = p{nn};
                    else
                        pread{end + 1} = p{nn};
                        for row = 1:size(R,1)
                            for col = 1:size(R,2)
                                d = [d;R(row,col).getReadData];
                                Rread(end + 1) = R(row,col);
                            end
                        end
                    end
                    
                end
            end
            self.conn.write(d,'mode','read');
            value = self.conn.recvMessage;
            %
            % Parse the received data in the same order as the addresses
            % were written
            %
            for nn = 1:numel(value)
                Rread(nn).value = value(nn);
            end
            %
            % Read parameters from registers
            %
            p = properties(self);
            for nn = 1:numel(p)
                if isa(self.(p{nn}),'DeviceParameter') || isa(self.(p{nn}),'IQBiasController')
                    self.(p{nn}).get;
                end
            end
        end

        function self = memoryReset(self)
            %MEMORYRESET Resets the two block memories
            self.auxReg.addr = '100004';
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
        
        function correct_pwm(self)
            old_route = self.fifo_route.get;
            self.fifo_route.set(ones(size(old_route))).write;
            self.getDemodulatedData(100e-3/self.dt());
            new_pwm = mean(self.data,1)*self.CONV_PWM;
            self.pwm.set(new_pwm).write;
            self.fifo_route.set(old_route).write;
        end

        function self = getDemodulatedData(self,numSamples,saveType)
            %GETDEMODULATEDDATA Fetches demodulated data from the device
            %
            %   SELF = GETDEMODULATEDDATA(NUMSAMPLES) Acquires NUMSAMPLES of demodulated data
            %
            %   SELF = GETDEMODULATEDDATA(__,SAVETYPE) uses SAVETYPE for saving data.  For advanced
            %   users only: see the readme
            numSamples = round(numSamples);
            if nargin < 3
                saveType = 1;
            end
            write_arg = {'./saveData','-n',sprintf('%d',numSamples),'-t',sprintf('%d',saveType),'-s',sprintf('%d',DeviceControl.NUM_MEAS)};
            if self.auto_retry
                for jj = 1:10
                    try
                        self.conn.write(0,'mode','command','cmd',write_arg,'return_mode','file');
                        raw = typecast(self.conn.recvMessage,'uint8');
                        d = self.convertData(raw);
                        self.data = d;
                        self.t = self.dt()*(0:(numSamples-1));
                        break;
                    catch e
                        if jj == 10
                            rethrow(e);
                        end
                    end
                end
            else
                self.conn.write(0,'mode','command','cmd',...
                    {'./saveData','-n',sprintf('%d',numSamples),'-t',sprintf('%d',saveType),'-s',sprintf('%d',DeviceControl.NUM_MEAS)},...
                    'return_mode','file');
                raw = typecast(self.conn.recvMessage,'uint8');
                d = self.convertData(raw);
                self.data = d;
                self.t = self.dt()*(0:(numSamples-1));
            end
        end
        
        function self = getVoltageStepResponse(self,numSamples,jump_index,jump_amount)
            %GETDEMODULATEDDATA Fetches demodulated data from the device
            %
            %   SELF = GETDEMODULATEDDATA(NUMSAMPLES) Acquires NUMSAMPLES of demodulated data
            %
            %   SELF = GETDEMODULATEDDATA(__,SAVETYPE) uses SAVETYPE for saving data.  For advanced
            %   users only: see the readme
            if ischar(jump_index) || isstring(jump_index)
                if strcmpi(jump_index,'x')
                    jump_index = 1;
                elseif strcmpi(jump_index,'y')
                    jump_index = 2;
                elseif strcmpi(jump_index,'z')
                    jump_index = 3;
                else
                    error('Only allowed values of jump_index are ''x'', ''y'', and ''z''!');
                end
            elseif isnumeric(jump_index)
                jump_index = round(jump_index);
                if all(jump_index ~= [1,2,3])
                    error('Only allowed values of jump_index are 1, 2, and 3!');
                end
            end
            numSamples = round(numSamples);
            jump_amount = round(jump_amount/self.CONV_PWM);
            Vx = self.pwm(1).intValue;
            Vy = self.pwm(2).intValue;
            Vz = self.pwm(3).intValue;
            write_arg = {'./analyze_jump_response','-n',sprintf('%d',numSamples),'-j',sprintf('%d',round(jump_amount)),...
                            '-i',sprintf('%d',round(jump_index)),'-x',sprintf('%d',round(Vx)),'-s',sprintf('%d',DeviceControl.NUM_MEAS),...
                            '-y',sprintf('%d',round(Vy)),'-z',sprintf('%d',round(Vz))};
            if self.auto_retry
                for jj = 1:10
                    try
                        self.conn.write(0,'mode','command','cmd',write_arg,'return_mode','file');
                        raw = typecast(self.conn.recvMessage,'uint8');
                        d = self.convertData(raw);
                        self.data = d;
                        self.t = self.dt()*(0:(numSamples-1));
                        break;
                    catch e
                        if jj == 10
                            rethrow(e);
                        end
                    end
                end
            else
                self.conn.write(0,'mode','command','cmd',write_arg,'return_mode','file');
                raw = typecast(self.conn.recvMessage,'uint8');
                d = self.convertData(raw);
                self.data = d;
                self.t = self.dt()*(0:(numSamples-1));
            end
        end

        function self = getRAM(self,numSamples)
            %GETRAM Fetches recorded in block memory from the device
            %
            %   SELF = GETRAM(SELF) Retrieves current number of recorded
            %   samples from the device SELF
            %
            %   SELF = GETRAM(SELF,N) Retrieves N samples from device
            numSamples = round(numSamples);
            self.numSamples.set(numSamples).write;
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[0,0]);
            
            self.conn.write(0,'mode','command','cmd',...
                {'./fetchRAM',sprintf('%d',numSamples)},...
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

        function D = getCharacterisationData(self,numVoltages,numAvgs,maxVoltage)
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
                maxVoltage = 1;
            elseif nargin == 2
                numAvgs = 100;
                maxVoltage = 1;
            elseif nargin == 3
                maxVoltage = 1;
            end
            
            maxVoltageInt = round(self.pwm(1).toIntegerFunction(maxVoltage),-1);
            self.conn.write(0,'mode','command','cmd',...
                {'./analyze_biases','-n',sprintf('%d',round(numVoltages)),'-a',sprintf('%d',numAvgs),'-m',sprintf('%d',maxVoltageInt)},...
                'return_mode','file');
            raw = typecast(self.conn.recvMessage,'int32');
            D = zeros([numVoltages*[1,1,1],4]);
            for nn = 1:size(D,4)
                tmp = raw((nn - 1)*numVoltages^3 + (1:(numVoltages^3)));
                D(:,:,:,nn) = reshape(double(tmp),numVoltages*[1,1,1]);
            end
        end
        
        function disp(self)
            strwidth = 20;
            fprintf(1,'DeviceControl object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.topReg.print('topReg',strwidth);
            self.outputReg.print('outputReg',strwidth);
            self.inputReg.print('inputReg',strwidth);
            self.filterReg.print('filterReg',strwidth);
            self.adcReg.print('adcReg',strwidth);
            self.ddsPhaseIncReg.print('phaseIncReg',strwidth);
            self.ddsPhaseOffsetReg.print('phaseOffsetReg',strwidth);
            self.dds2PhaseOffsetReg.print('dds2phaseOffsetReg',strwidth);
            self.ddsPhaseCorrectionReg.print('ddsPhaseCorrectionReg',strwidth);
            self.pwmRegs.print('pwmReg',strwidth);
            self.controlRegs.print('controlRegs',strwidth);
            self.gainRegs.print('gainRegs',strwidth);
            self.pwmLimitRegs.print('pwmLimitRegs',strwidth);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Parameters\n')
            
            self.adc_select.print('ADC select',strwidth,'%.0f');
            self.led_o.print('LEDs',strwidth,'%02x');
            self.ext_o.print('External output',strwidth,'%02x');
            self.ext_i.print('External input',strwidth,'%02x');
            self.adc(1).print('ADC 1',strwidth,'%.3f');
            self.adc(2).print('ADC 2',strwidth,'%.3f');
            self.phase_inc.print('Phase Increment',strwidth,'%.3e');
            self.phase_correction.print('Phase Correction',strwidth,'%.3f');
            self.phase_offset.print('Phase Offset',strwidth,'%.3f');
            self.dds2_phase_offset.print('dds2 Phase Offset',strwidth,'%.3f');
            for nn = 1:numel(self.pwm)
                self.pwm(nn).print(sprintf('PWM %d',nn),strwidth,'%.3f');
            end
            self.log2_rate.print('Log2 Rate',strwidth,'%.0f');
            self.cic_shift.print('CIC shift',strwidth,'%.0f');
            self.output_scale.print('Output scale',strwidth,'%.3f');
            for nn = 1:numel(self.fifo_route)
                self.fifo_route(nn).print(sprintf('FIFO Route %d',nn),strwidth,'%d');
            end
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Control Parameters\n');
            self.control.print(strwidth);
        end
        
        function s = struct(self)
            %STRUCT Returns a structure representing the data
            %
            %   S = STRUCT(SLEF) Returns structure S from current object
            %   SELF
            s.conn = self.conn.struct;
            s.t = self.t;
            s.data = self.data;
            s.jumpers = self.jumpers;
            
            p = properties(self);
            for nn = 1:numel(p)
                if isa(self.(p{nn}),'DeviceParameter') || isa(self.(p{nn}),'IQBiasController')
                    s.(p{nn}) = self.(p{nn}).struct;
                end
            end
        end
        
        function s = saveobj(self)
            %SAVEOBJ Returns a structure used for saving data
            %
            %   S = SAVEOBJ(SELF) Returns structure S used for saving data
            %   representing object SELF
            s = self.struct;
        end
        
        function self = loadstruct(self,s)
            %LOADSTRUCT Loads a struct and copies properties to object
            %
            %   SELF = LOADSTRUCT(SELF,S) Copies properties from structure
            %   S to SELF
            self.t = s.t;
            self.data = s.data;
            self.jumpers = s.jumpers;
            p = properties(self);
            for nn = 1:numel(p)
                if isfield(s,p{nn})
                    if isa(self.(p{nn}),'DeviceParameter') || isa(self.(p{nn}),'IQBiasController')
                        try
                            self.(p{nn}).loadstruct(s.(p{nn}));
                        catch
                            
                        end
                    end
                end
            end
        end
        
    end

    methods(Static)
        function self = loadobj(s)
            %LOADOBJ Creates a DEVIECCONTROL object using input structure
            %
            %   SELF = LOADOBJ(S) uses structure S to create new
            %   DEVICECONTROL object SELF
            self = DeviceControl(s.conn.host,s.conn.port);
            self.setDefaults;
            self.loadstruct(s);
        end
        
        
        function d = convertData(raw)
            raw = raw(:);
            Nraw = numel(raw);
            numStreams = DeviceControl.NUM_MEAS;
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
        
        function D = load_bias_analysis_file(filename,numVoltages)
            if isempty(filename)
                filename = 'SavedData.bin';
            end
            
            %Load data
            fid = fopen(filename,'r');
            fseek(fid,0,'eof');
            fsize = ftell(fid);
            frewind(fid);
            x = fread(fid,fsize/4,'int32');
            fclose(fid);
            
            %Process data
%             raw = typecast(x,'int32');
            raw = x;
            D = zeros([numVoltages*[1,1,1],4]);
            for nn = 1:size(D,4)
                tmp = raw((nn - 1)*numVoltages^3 + (1:(numVoltages^3)));
                D(:,:,:,nn) = reshape(double(tmp),numVoltages*[1,1,1]);
            end
        end
        
        function app = get_running_app_instance
            h = findall(groot,'type','figure');
            for nn = 1:numel(h)
                if strcmpi(h(nn).Name,'IQ Bias Control')
                    app = h(nn).RunningAppInstance;
                    break;
                end
            end
        end
    end
    
end