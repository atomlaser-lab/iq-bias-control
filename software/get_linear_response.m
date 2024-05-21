function [G,zero_voltages,data_lin] = get_linear_response(d,zero_voltages,V,Npoints)

if nargin < 4
    Npoints = 1000;
end
textprogressbar('RESET');
textprogressbar('Measuring linear responses...');
data_lin = zeros(numel(V),4,3);
tic;
for mm = 1:d.NUM_PWM
    d.pwm.set(zero_voltages).write;
    for nn = 1:numel(V)
        textprogressbar(round((nn/(numel(V)*d.NUM_PWM) + (mm - 1)/d.NUM_PWM)*100));
        d.pwm(mm).set(zero_voltages(mm) + V(nn)).write;
        if nn == 1
            pause(1);
        else
            pause(200e-3);
        end
        d.getDemodulatedData(Npoints);
        data_lin(nn,:,mm) = mean(d.data);
    end
end
t = toc;

G = zeros(3,3);
Z = zeros(size(zero_voltages));
lf = linfit;
lf.setFitFunc('poly',1);
for row = 1:3
    for col = 1:3
        lf.set(V,data_lin(:,row,col));
        lf.ex = (V + zero_voltages(col)) >= 1.25;
        lf.fit;
        G(row,col) = lf.c(2,1);
        if row == col
            Z(row) = -lf.c(1,1)./lf.c(2,1);
        end
        subplot(3,3,col + (row - 1)*3);
        plot(lf.x,lf.y,'.');
        hold on
        plot(lf.x,lf.f(lf.x),'--');
        grid on
        plot_format(sprintf('DC%d [V]',col),sprintf('Signal %d',row),sprintf('S%d - DC%d',row,col),10);
        drawnow;
    end
end
zero_voltages = zero_voltages + (G\(diag(G).*Z(:)))';
textprogressbar(sprintf('\nFinished measuring linear responses in %.1f s',t));
