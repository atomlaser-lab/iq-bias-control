%
% Collect bias data
%
V = 0:0.1:1.6;
data = zeros([numel(V)*[1,1,1],3]);

for row = 1:numel(V)
    fprintf('%d/%d\n',row,numel(V));
    tic;
    for col = 1:numel(V)
        for page = 1:numel(V)
            d.pwm(1).set(V(row)).write;d.pwm(2).set(V(col)).write;d.pwm(3).set(V(page)).write;
            jj = 1;
            while jj <= 10
                try 
                    d.getDemodulatedData(1e3);
                    data(row,col,page,:) = mean(d.data);
                    break;
                catch e
                    if jj == 10
                        rethrow(e);
                    else
                        jj = jj + 1
                    end
                end
            end
        end
    end
    toc;
end