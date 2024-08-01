function generate_axi_data(d)

p = properties(d);
addr = {};data = {};
for nn = 1:numel(p)
    r = d.(p{nn});
    if isa(r,'DeviceRegister')
        for mm = 1:numel(r)
            if ~r(mm).read_only
                addr{end + 1} = sprintf('X"%08x"',r(mm).addr);
                data{end + 1} = sprintf('X"%08x"',r(mm).value);
            end
        end
    end
end
%% Make address constant
addr_string = sprintf('constant axi_addresses   :   t_axi_addr_array(%d downto 0) := (',numel(addr) - 1);
addr_string_width = length(addr_string);
for nn = 1:numel(addr)
    addr_string = sprintf('%s%d  =>  %s',addr_string,nn - 1,addr{nn});
    if nn < numel(addr)
        addr_string = sprintf('%s,\n%s',addr_string,repmat(' ',1,addr_string_width));
    else
        addr_string = sprintf('%s);',addr_string);
    end
end

disp(addr_string);
%% Make data constant
data_string = sprintf('constant axi_data   :   t_axi_data_array(%d downto 0) := (',numel(data) - 1);
data_string_width = length(data_string);
for nn = 1:numel(data)
    data_string = sprintf('%s%d  =>  %s',data_string,nn - 1,data{nn});
    if nn < numel(data)
        data_string = sprintf('%s,\n%s',data_string,repmat(' ',1,data_string_width));
    else
        data_string = sprintf('%s);',data_string);
    end
end

disp(data_string);
