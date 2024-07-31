classdef(Abstract) DeviceControlSubModule < handle
    properties(SetAccess=protected)
        parent
    end

    methods(Abstract)
        setDefaults(self);
        print(self,width);
    end

    methods
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
                p = properties(self);
                for nn = 1:numel(p)
                    if isa(self.(p{nn}),'DeviceParameter')
                        self.(p{nn}).get;
                    end
                end
            end
        end
        function s = struct(self)
            %STRUCT Creates a struct from the object
            if numel(self) > 1
                for nn = 1:numel(self)
                    self(nn).struct;
                end
            else
                p = properties(self);
                for nn = 1:numel(p)
                    if isa(self.(p{nn}),'DeviceParameter')
                        s.(p{nn}) = self.(p{nn}).struct;
                    end
                end
            end
        end
        
        function self = loadstruct(self,s)
            %LOADSTRUCT Loads a struct into the object
            if numel(self) > 1
                for nn = 1:numel(self)
                    self(nn).loadstruct;
                end
            else
            p = properties(self);
                for nn = 1:numel(p)
                    if isfield(s,p{nn})
                        if isa(self.(p{nn}),'DeviceParameter')
                            try
                                self.(p{nn}).loadstruct(s.(p{nn}));
                            catch
                                
                            end
                        end
                    end
                end
            end
        end
    end
end