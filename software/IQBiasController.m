classdef IQBiasController < handle
    %IQBIASCONTROLLER Defines a class for handling the PID modules in the
    %IQ bias controller
    
    properties(SetAccess = immutable)
        gains           %3x3 integral gain matrix
        divisors        %3x1 overall divisors to enable fractional scaling
        enable          %Enable/disable control
        hold            %Software enabled hold
        controls        %Controls/set-points of the module for each signal (3x1)
        lower_limits    %Lower output limits for the module outputs (3x1)
        upper_limits    %Upper output limits for the module outputs (3x1)
    end
    
    properties(SetAccess = protected)
        parent          %Parent object
    end

    properties(Constant)
        NUM_CONTROL_REGS = 2;   %Number of registers needed for control
        NUM_GAIN_REGS = 3;      %Number of registers needed for gain values
        NUM_LIMIT_REGS = 3;     %Number of registers needed for limiting PWM outputs
    end
    
    methods
        function self = IQBiasController(parent,control_regs,gain_regs,pwm_limit_regs)
            %IQBIASCONTROLLER Creates an instance of the class
            %
            %   SELF = IQBIASCONTROLLER(PARENT,REGS) Creates instance SELF
            %   with parent object PARENT and associated with registers
            %   REGS
            
            self.parent = parent;
            
            self.enable = DeviceParameter([0,0],control_regs(1))...
                .setLimits('lower',0,'upper',1);
            self.hold = DeviceParameter([1,1],control_regs(1))...
                .setLimits('lower',0,'upper',1);

            self.controls = DeviceParameter.empty;
            
            self.controls(1) = DeviceParameter([16,31],control_regs(1),'int16')...
                .setLimits('lower',-2^15,'upper',2^15);
            self.controls(2) = DeviceParameter([0,15],control_regs(2),'int16')...
                .setLimits('lower',-2^15,'upper',2^15);
            self.controls(3) = DeviceParameter([16,31],control_regs(2),'int16')...
                .setLimits('lower',-2^15,'upper',2^15);

            self.gains = DeviceParameter.empty;
            self.divisors = DeviceParameter.empty;
            for row = 1:3
                for col = 1:3
                    self.gains(row,col) = DeviceParameter;
                    self.gains(row,col) = DeviceParameter((col - 1)*8 + [0,7],gain_regs(row),'int8')...
                        .setLimits(-2^7,2^7 - 1);
                end
                self.divisors(row) = DeviceParameter([24,31],gain_regs(row),'uint32')...
                    .setLimits('lower',0,'upper',2^8 - 1);
            end

            self.lower_limits = DeviceParameter.empty;
            self.upper_limits = DeviceParameter.empty;
            for nn = 1:3
                self.lower_limits(nn) = DeviceParameter([0,DeviceControl.PWM_WIDTH - 1],pwm_limit_regs(nn),'uint32')...
                    .setLimits('lower',0,'upper',1.6)...
                    .setFunctions('to',@(x) x/self.parent.CONV_PWM,'from',@(x) x*self.parent.CONV_PWM);
                self.upper_limits(nn) = DeviceParameter(DeviceControl.PWM_WIDTH + [0,DeviceControl.PWM_WIDTH - 1],pwm_limit_regs(nn),'uint32')...
                    .setLimits('lower',0,'upper',1.6)...
                    .setFunctions('to',@(x) x/self.parent.CONV_PWM,'from',@(x) x*self.parent.CONV_PWM);
            end

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
                self.hold.set(0);
                self.controls.set(0);
                self.gains.set(0);
                self.divisors.set(0);
                self.lower_limits.set(0);
                self.upper_limits.set(1.6);
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
                self.hold.get;
                self.controls.get;
                self.gains.get;
                self.divisors.get;
                self.lower_limits.get;
                self.upper_limits.get;
            end
        end
        
        function K = calculateRealGains(self)
            %CALCULATEREALGAINS Calculates the "real",
            %continuous-controller equivalent gains
            %
            %   [Kp,Ki,Kd] = CALCULATEREALGAINS(SELF) Calculates the real
            %   gains Kp, Ki, and Kd using the set DIVISOR value and the
            %   parent object's sampling interval
            
            K = zeros(3,3);
            for row = 1:size(K,1)
                for col = 1:size(K,2)
                    K(row,col) = self.gains(row,col).get()/self.divisors(row).get()*self.parent.dt();
                end
            end
        end
        
        function ss = print(self,width)
            %PRINT Prints a string representing the object
            %
            %   S = PRINT(SELF,WIDTH) returns a string S representing the
            %   object SELF with label width WIDTH.  If S is not requested,
            %   prints it to the command line
            s{1} = self.enable.print('Enable',width,'%d');
            s{2} = self.hold.print('Hold',width,'%d');
            s{3} = sprintf(['% ',num2str(width),'s: %.3f, %.3f, %.3f\n'],'Controls',self.controls(1).value,self.controls(2).value,self.controls(3).value);
            s{4} = sprintf(['% ',num2str(width),'s= %+ 3d, %+ 3d, %+ 3d\n'],'K',self.gains(1,1).value,self.gains(1,2).value,self.gains(1,3).value);
            s{5} = sprintf(['% ',num2str(width),'s= %+ 3d, %+ 3d, %+ 3d\n'],' ',self.gains(2,1).value,self.gains(2,2).value,self.gains(2,3).value);
            s{6} = sprintf(['% ',num2str(width),'s= %+ 3d, %+ 3d, %+ 3d\n'],' ',self.gains(3,1).value,self.gains(3,2).value,self.gains(3,3).value);
            s{7} = sprintf(['% ',num2str(width),'s: % 2d, % 2d, % 2d\n'],'Divisors',self.divisors(1).value,self.divisors(2).value,self.divisors(3).value);
            s{8} = sprintf(['% ',num2str(width),'s: %.3f, %.3f, %.3f\n'],'Lower limits',self.lower_limits(1).value,self.lower_limits(2).value,self.lower_limits(3).value);
            s{9} = sprintf(['% ',num2str(width),'s: %.3f, %.3f, %.3f\n'],'Upper limits',self.upper_limits(1).value,self.upper_limits(2).value,self.upper_limits(3).value);
            
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
                s.gains = self.gains.struct;
                s.divisors = self.divisors.struct;
                s.enable = self.enable.struct;
                s.hold = self.hold.struct;
                s.controls = self.controls.struct;
                s.lower_limits = self.lower_limits.struct;
                s.upper_limits = self.upper_limits.struct;
            else
                for nn = 1:numel(self)
                    s(nn) = self(nn).struct;
                end
            end
        end
        
        function self = loadstruct(self,s)
            %LOADSTRUCT Loads a struct into the object
            if numel(self) == 1
                self.gains.set(s.gains.value);
                self.divisors.set(s.divisor.value);
                self.enable.set(s.enable.value);
                self.hold.set(s.hold.value);
                self.controls.set(s.controls.value);
                self.lower_limits.set(s.lower_limits.value);
                self.upper_limits.set(s.upper_limits.value);
            else
                for nn = 1:numel(self)
                    self(nn).loadstruct(s(nn));
                end
            end
        end
        
    end
    
end