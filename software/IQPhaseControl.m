classdef IQPhaseControl < DeviceControlSubModule
    %IQPHASECONTROL Defines a class for handling the phase control module
    %in the bias control design
    
    properties(SetAccess = immutable)
        meas_switch     %Switch between phase stabilisation and Q stabilisation
        output_switch   %Output switch
        log2_rate       %Log2(CIC filter rate)
        cic_shift       %Log2(Additional digital gain after filter)
        Kp              %Proportional gain value
        Ki              %Integral gain value
        Kd              %Derivative gain value
        Dp              %Proportional divisor value
        Di              %Integral divisor value
        Dd              %Derivative divisor value
        polarity        %Polarity of PID module
        enable          %Enable/disable PID module
        hold            %Software enabled hold
        control         %Control/set-point of the module
        lower_limit     %Lower output limit for the module
        upper_limit     %Upper output limit for the module
    end

    properties(Constant)
        NUM_REGS = 3;   %Number of registers needed for PID
    end
    
    methods
        function self = IQPhaseControl(parent,top_reg,control_reg,gain_reg,divisor_reg,limit_reg)
            %IQPHASECONTROL Creates an instance of the class
            %
            %   SELF = IQPHASECONTROL(PARENT,CONTROL_REG,GAIN_REG,LIMIT_REG) Creates
            %   instance SELF with parent object PARENT and associated with
            %   registers CONTROL_REG, GAIN_REG, and LIMIT_REG
            
            self.parent = parent;

            self.log2_rate = DeviceParameter([0,3],control_reg)...
                .setLimits('lower',2,'upper',13);
            self.cic_shift = DeviceParameter([4,11],control_reg,'int8')...
                .setLimits('lower',-100,'upper',100);
            
            self.enable = DeviceParameter([31,31],control_reg)...
                .setLimits('lower',0,'upper',1);
            self.polarity = DeviceParameter([30,30],control_reg)...
                .setLimits('lower',0,'upper',1);
            self.hold = DeviceParameter([29,29],control_reg)...
                .setLimits('lower',0,'upper',1);
            self.control = DeviceParameter([12,27],control_reg,'int16')...
                .setLimits('lower',-2^15,'upper',2^15)...
                .setFunctions('to',@(x) x/self.parent.CONV_PHASE,'from',@(x) x*self.parent.CONV_PHASE);
            self.meas_switch = DeviceParameter([28,28],control_reg)...
                .setLimits('lower',0,'upper',1);
            self.output_switch = DeviceParameter([2,2],top_reg)...
                .setLimit('lower',0,'upper',1);

            self.Kp = DeviceParameter([0,7],gain_reg)...
                .setLimits('lower',0,'upper',2^8-1);
            self.Ki = DeviceParameter([8,15],gain_reg)...
                .setLimits('lower',0,'upper',2^8-1);
            self.Kd = DeviceParameter([16,23],gain_reg)...
                .setLimits('lower',0,'upper',2^8-1);
            self.Dp = DeviceParameter([0,7],divisor_reg,'int8')...
                .setLimits('lower',-2^7,'upper',2^7-1);
            self.Di = DeviceParameter([8,15],divisor_reg,'int8')...
                .setLimits('lower',-2^7,'upper',2^7-1);
            self.Dd = DeviceParameter([16,23],divisor_reg,'int8')...
                .setLimits('lower',-2^7,'upper',2^7-1);


            self.lower_limit = DeviceParameter([0,15],limit_reg,'uint32')...
                .setLimits('lower',0,'upper',1.6)...
                .setFunctions('to',@(x) x/self.parent.CONV_PWM,'from',@(x) x*self.parent.CONV_PWM);
            self.upper_limit = DeviceParameter([16,31],limit_reg,'uint32')...
                .setLimits('lower',0,'upper',1.6)...
                .setFunctions('to',@(x) x/self.parent.CONV_PWM,'from',@(x) x*self.parent.CONV_PWM);
        end
        
        function self = setDefaults(self)
            %SETDEFAULTS Sets the default values for the module
            %
            %   SELF = SETDEFAULTS(SELF) sets the default values of object
            %   SELF
            
            if numel(self) > 1
                for nn = 1:numel(self)
                    self(nn).setDefaults;
                end
            else
                self.log2_rate.set(10);
                self.cic_shift.set(0);

                self.enable.set(0);
                self.polarity.set(0);
                self.hold.set(0);
                self.control.set(0);
                self.meas_switch.set(0);
                self.output_switch.set(0);

                self.Kp.set(0);
                self.Ki.set(0);
                self.Kd.set(0);
                self.Dp.set(8);
                self.Di.set(8);
                self.Dd.set(8);
                self.lower_limit.set(0);
                self.upper_limit.set(1.5);
            end
        end
        
        function [Kp,Ki,Kd] = calculateRealGains(self)
            %CALCULATEREALGAINS Calculates the "real",
            %continuous-controller equivalent gains
            %
            %   [Kp,Ki,Kd] = CALCULATEREALGAINS(SELF) Calculates the real
            %   gains Kp, Ki, and Kd using the set DIVISOR value and the
            %   parent object's sampling interval
            
            Kp = self.Kp.value*2^(-self.Dp.value)/self.parent.CONV_PWM*self.parent.CONV_PHASE;
            Ki = self.Ki.value*2^(-self.Di.value)/self.dt()/self.parent.CONV_PWM*self.parent.CONV_PHASE;
            Kd = self.Kd.value*2^(-self.Dd.value)*self.dt()/self.parent.CONV_PWM*self.parent.CONV_PHASE;
        end

        function self = setRealGains(self,Kp,Ki,Kd)
            Kp_int = Kp*self.parent.CONV_PWM/self.parent.CONV_PHASE;
            Ki_int = Ki*self.dt*self.parent.CONV_PWM/self.parent.CONV_PHASE;
            Kd_int = Kd/self.dt*self.parent.CONV_PWM/self.parent.CONV_PHASE;

            if Kp_int ~= 0
                Dp_int = min(max(floor(self.Dp.numbits() - log2(Kp_int)),self.Dp.lowerLimit),self.Dp.upperLimit);
            else
                Dp_int = 0;
            end
            self.Dp.set(Dp_int);
            self.Kp.set(round(Kp_int*2^self.Dp.value));

            if Ki_int ~= 0
                Di_int = min(max(floor(self.Di.numbits() - log2(Ki_int)),self.Di.lowerLimit),self.Di.upperLimit);
            else
                Di_int = 0;
            end
            self.Di.set(Di_int);
            self.Ki.set(round(Ki_int*2^self.Di.value));

            if Kd_int ~= 0
                Dd_int = min(max(floor(self.Dd.numbits() - log2(Kd_int)),self.Dd.lowerLimit),self.Dd.upperLimit);
            else
                Dd_int = 0;
            end
            self.Dd.set(Dd_int);
            self.Kd.set(round(Kd_int*2^self.Dd.value));
        end

        function r = dt(self)
            r = 2^self.log2_rate.value/self.parent.CLK;
        end
        
        function ss = print(self,width)
            %PRINT Prints a string representing the object
            %
            %   S = PRINT(SELF,WIDTH) returns a string S representing the
            %   object SELF with label width WIDTH.  If S is not requested,
            %   prints it to the command line
            s{1} = self.log2_rate.print('Log2(CIC Rate)',width,'%d');
            s{2} = self.cic_shift.print('Log2(CIC shift)',width,'%d');
            s{3} = self.enable.print('Enable',width,'%d');
            s{4} = self.polarity.print('Polarity',width,'%d');
            s{5} = self.hold.print('Hold',width,'%d');
            s{6} = self.control.print('Control',width,'%.3f','rad');
            s{7} = self.meas_switch.print('Measurement switch',width,'%d');
            s{8} = self.Kp.print('Kp',width,'%d');
            s{9} = self.Ki.print('Ki',width,'%d');
            s{10} = self.Kd.print('Kd',width,'%d');
            s{11} = self.Dp.print('Dp',width,'%d');
            s{12} = self.Di.print('Di',width,'%d');
            s{13} = self.Dd.print('Dd',width,'%d');
            s{14} = self.lower_limit.print('Lower Limit',width,'%.3f','V');
            s{15} = self.upper_limit.print('Upper Limit',width,'%.3f','V');
            
            ss = '';
            for nn = 1:numel(s)
                ss = [ss,s{nn}]; %#ok<*AGROW>
            end
            if nargout == 0
                fprintf(1,ss);
            end
        end
        
        function disp(self)
            %DISP Displays the object properties
            disp('IQPhaseControl object with properties:');
            disp(self.print(25));
        end
        
        
    end
    
end