classdef IQBiasPID < handle
    %IQBIASPID Defines a class for handling the PID modules in the
    %IQ bias controller
    
    properties(SetAccess = immutable)
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
        function self = IQBiasPID(parent,regs)
            %IQBIASPID Creates an instance of the class
            %
            %   SELF = IQBIASPID(PARENT,REGS) Creates instance SELF
            %   with parent object PARENT and associated with registers
            %   REGS
            
            self.parent = parent;
            
            self.enable = DeviceParameter([0,0],regs(1))...
                .setLimits('lower',0,'upper',1);
            self.polarity = DeviceParameter([1,1],regs(1))...
                .setLimits('lower',0,'upper',1);
            self.hold = DeviceParameter([2,2],regs(1))...
                .setLimits('lower',0,'upper',1);
            self.control = DeviceParameter([16,31],regs(1),'int16')...
                .setLimits('lower',-2^15,'upper',2^15);
            self.Kp = DeviceParameter([0,7],regs(2))...
                .setLimits('lower',0,'upper',2^8-1);
            self.Ki = DeviceParameter([8,15],regs(2))...
                .setLimits('lower',0,'upper',2^8-1);
            self.Kd = DeviceParameter([16,23],regs(2))...
                .setLimits('lower',0,'upper',2^8-1);
            self.divisor = DeviceParameter([24,31],regs(2))...
                .setLimits('lower',0,'upper',2^8-1);
            self.lower_limit = DeviceParameter([0,9],regs(3),'uint32')...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x/self.parent.CONV_PWM,'from',@(x) x*self.parent.CONV_PWM);
            self.upper_limit = DeviceParameter([10,19],regs(3),'uint32')...
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
                self.enable.set(0);
                self.polarity.set(0);
                self.hold.set(0);
                self.control.set(0);
                self.Kp.set(0);
                self.Ki.set(0);
                self.Kd.set(0);
                self.divisor.set(3);
                self.lower_limit.set(0);
                self.upper_limit.set(1);
            end
        end
        
        function self = get(self)
            %GET Retrieves parameter values from associated registers
            %
            %   SELF = GET(SELF) Retrieves values for parameters associated
            %   with object SELF
            
            if numel(self) > 1
                for nn = 1:numel(self)
                    self(nn).get;
                end
            else
                self.enable.get;
                self.polarity.get;
                self.hold.get;
                self.control.get;
                self.Kp.get;
                self.Ki.get;
                self.Kd.get;
                self.divisor.get;
                self.lower_limit.get;
                self.upper_limit.get;
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
            s{1} = self.enable.print('Enable',width,'%d');
            s{2} = self.polarity.print('Polarity',width,'%d');
            s{3} = self.hold.print('Hold',width,'%d');
            s{4} = self.control.print('Control',width,'%.3f','V');
            s{5} = self.Kp.print('Kp',width,'%d');
            s{6} = self.Ki.print('Ki',width,'%d');
            s{7} = self.Kd.print('Kd',width,'%d');
            s{8} = self.divisor.print('Divisor',width,'%d');
            s{9} = self.lower_limit.print('Lower Limit',width,'%.3f','V');
            s{10} = self.upper_limit.print('Upper Limit',width,'%.3f','V');
            
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
            disp('IQBiasPID object with properties:');
            disp(self.print(25));
        end
        
        function s = struct(self)
            %STRUCT Creates a struct from the object
            if numel(self) == 1
                s.Kp = self.Kp.struct;
                s.Ki = self.Ki.struct;
                s.Kd = self.Kd.struct;
                s.divisor = self.divisor.struct;
                s.polarity = self.polarity.struct;
                s.enable = self.enable.struct;
                s.hold = self.hold.struct;
                s.control = self.control.struct;
                s.lower_limit = self.lower_limit.struct;
                s.upper_limit = self.upper_limit.struct;
            else
                for nn = 1:numel(self)
                    s(nn) = self(nn).struct;
                end
            end
        end
        
        function self = loadstruct(self,s)
            %LOADSTRUCT Loads a struct into the object
            if numel(self) == 1
                self.Kp.set(s.Kp.value);
                self.Ki.set(s.Ki.value);
                self.Kd.set(s.Kd.value);
                self.divisor.set(s.divisor.value);
                self.polarity.set(s.polarity.value);
                self.enable.set(s.enable.value);
                self.hold.set(s.hold.value);
                self.control.set(s.control.value);
                self.lower_limit.set(s.lower_limit.value);
                self.upper_limit.set(s.upper_limit.value);
            else
                for nn = 1:numel(self)
                    self(nn).loadstruct(s(nn));
                end
            end
        end
        
    end
    
end