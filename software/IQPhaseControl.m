classdef IQPhaseControl < DeviceControlSubModule
    %IQPHASECONTROL Defines a class for handling the phase control module
    %in the bias control design
    
    properties(SetAccess = immutable)
        log2_rate       %Log2(CIC filter rate)
        cic_shift       %Log2(Additional digital gain after filter)
        Kp              %Proportional gain value
        Ki              %Integral gain value
        Kd              %Derivative gain value
        divisor         %Overall divisor for gain values to convert to fractions
        polarity        %Polarity of PID module
        enable          %Enable/disable PID module
        hold            %Software enabled hold
        control         %Control/set-point of the module
        lower_limit     %Lower output limit for the module
        upper_limit     %Upper output limit for the module
    end
    
    properties(SetAccess = protected)
        parent          %Parent object
    end

    properties(Constant)
        NUM_REGS = 3;   %Number of registers needed for PID
    end
    
    methods
        function self = IQPhaseControl(parent,control_reg,gain_reg,limit_reg)
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

            self.Kp = DeviceParameter([0,7],gain_reg)...
                .setLimits('lower',0,'upper',2^8-1);
            self.Ki = DeviceParameter([8,15],gain_reg)...
                .setLimits('lower',0,'upper',2^8-1);
            self.Kd = DeviceParameter([16,23],gain_reg)...
                .setLimits('lower',0,'upper',2^8-1);
            self.divisor = DeviceParameter([24,31],gain_reg)...
                .setLimits('lower',0,'upper',2^8-1);

            self.lower_limit = DeviceParameter([0,15],limit_reg,'uint32')...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x/self.parent.CONV_PWM,'from',@(x) x*self.parent.CONV_PWM);
            self.upper_limit = DeviceParameter([16,31],limit_reg,'uint32')...
                .setLimits('lower',0,'upper',1)...
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

                self.Kp.set(0);
                self.Ki.set(0);
                self.Kd.set(0);
                self.divisor.set(8);
                self.lower_limit.set(0);
                self.upper_limit.set(1.6);
            end
        end
        
        function [Kp,Ki,Kd] = calculateRealGains(self)
            %CALCULATEREALGAINS Calculates the "real",
            %continuous-controller equivalent gains
            %
            %   [Kp,Ki,Kd] = CALCULATEREALGAINS(SELF) Calculates the real
            %   gains Kp, Ki, and Kd using the set DIVISOR value and the
            %   parent object's sampling interval
            
            Kp = self.Kp.value*2^(-self.divisor.value);
            Ki = self.Ki.value*2^(-self.divisor.value)/self.parent.dt();
            Kd = self.Kd.value*2^(-self.divisor.value)*self.parent.dt();
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
            s{6} = self.control.print('Control',width,'%.3f','V');
            s{7} = self.Kp.print('Kp',width,'%d');
            s{8} = self.Ki.print('Ki',width,'%d');
            s{9} = self.Kd.print('Kd',width,'%d');
            s{10} = self.divisor.print('Divisor',width,'%d');
            s{11} = self.lower_limit.print('Lower Limit',width,'%.3f','V');
            s{12} = self.upper_limit.print('Upper Limit',width,'%.3f','V');
            
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