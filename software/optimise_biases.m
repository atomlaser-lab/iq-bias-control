%
% Attempt at automatic bias optimisation
%

V = 0:0.1:1;
ph = 0:10:360;


% d.log2_rate.set(13).write;
% d.pwm(1).set(0.5).write;
% d.pwm(2).set(0.5).write;

%% Scan over 2f demodulation phase and DC3 bias
data = zeros(numel(V),numel(ph),4);
tic;
for row = 1:numel(V)
    fprintf('%d/%d\n',row,numel(V));
    d.pwm(3).set(V(row)).write;
    for col = 1:numel(ph)
        d.dds2_phase_offset.set(ph(col)).write;
        data(row,col,:) = get_data_auto_retry(d,1e3);
    end
end
toc;

%% Analyze scan over 2f data to get optimum demodulation phase
figure(855012);clf;
plot(ph,range(data(:,:,3),1),'o-');
xlabel('2f demodulation phase [deg]');
[~,idx] = max(range(data(:,:,3),1));
nlf = nonlinfit(ph,range(data(:,:,3),1));
nlf.setFitFunc(@(A,ph0,x) abs(A*cosd(x - ph0)));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'ph0',[50,270,ph(idx)]);
nlf.fit;
hold on
plot(nlf.x,nlf.f(nlf.x),'--');
optimum_2f_phase = nlf.c(2,1);
title(sprintf('Optimum 2f phase = %.1f',optimum_2f_phase));

% Fix 2f demodulation phase
d.dds2_phase_offset.set(optimum_2f_phase).write;

%% Scan over DC3 bias at optimum demodulation phase
V2 = 0:0.025:1;
data2 = zeros(numel(V2),4);
tic;
for row = 1:numel(V2)
    d.pwm(3).set(V2(row)).write;
    data2(row,:) = get_data_auto_retry(d,1e3);
end
toc;

%% Analyze DC3 scan data to find minimum of 2f signal
nlf = nonlinfit(V2,data2(:,3));
nlf.ex = nlf.x >= 1;
nlf.setFitFunc(@(A,s,x0,x) A*sin(2*pi*(x - x0)/s));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'s',[0.25,5,1.5],'x0',[0,3*max(nlf.x),0.4]);
nlf.fit;
figure(855013);clf;
nlf.plot('plotresiduals',0);
title(sprintf('Zero-crossing voltage = %.3f',nlf.c(3,1)));

approx_zero_voltages = nlf.get('x0',1) + [0,0.5*nlf.get('s',1)];
for nn = 1:numel(approx_zero_voltages)
    zero_crossing_voltages_2f(nn,1) = fsolve(@(x) interp1(nlf.x,nlf.y,x,'pchip'),approx_zero_voltages(nn),optimset('display','off'));
end

%%
% Set DC3 voltage
d.pwm(3).set(zero_crossing_voltages_2f(2)).write;

%% Scan over DC2 and 1f demodulation phase
old_voltages = [d.pwm(1).get,d.pwm(2).get];
data4 = zeros(numel(V),numel(ph),4);
tic;
for row = 1:numel(V)
    fprintf('%d/%d\n',row,numel(V));
    d.pwm(2).set(V(row)).write;
    for col = 1:numel(ph)
        d.phase_offset.set(ph(col)).write;
        data4(row,col,:) = get_data_auto_retry(d,1e3);
    end
end
toc;
d.pwm(1).set(old_voltages(1)).write;
d.pwm(2).set(old_voltages(2)).write;

%% Analyze scan over 1f data to get optimum demodulation phase
figure(855015);clf;
plot(ph,range(data4(:,:,1),1),'o-');
hold on
plot(ph,range(data4(:,:,2),1),'sq-');
xlabel('f demodulation phase [deg]');
[~,idx] = max(range(data4(:,:,2),1));
nlf = nonlinfit(ph,range(data4(:,:,2),1));
nlf.setFitFunc(@(A,ph0,x) A*abs(cosd(x - ph0)));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'ph0',[0,180,mod(ph(idx),180)]);
nlf.fit;
hold on
plot(nlf.x,nlf.f(nlf.x),'--');
optimum_f_phase = nlf.c(2,1);
title(sprintf('Optimum 2f phase = %.1f',optimum_f_phase));
% 
% % Fix 1f demodulation phase
d.phase_offset.set(optimum_f_phase).write;

%% Fine scan over DC1 and DC2 individually
data12 = zeros(numel(V2),4,2);
tic;
for row = 1:numel(V2)
    d.pwm(1).set(V2(row)).write;
    data12(row,:,1) = get_data_auto_retry(d,1e3);
end
toc;
d.pwm(1).set(old_voltages(1)).write;
tic;
for row = 1:numel(V2)
    d.pwm(2).set(V2(row)).write;
    data12(row,:,2) = get_data_auto_retry(d,1e3);
end
toc;
d.pwm(2).set(old_voltages(2)).write;

%% Analyze fine scan
figure(12751);clf;
plot(V2,data12(:,1,1),'b.');
hold on
plot(V2,data12(:,2,2),'r.');

plot(V2,data12(:,3,1)*1e2,'bsq','markersize',4);
plot(V2,data12(:,3,2)*1e2,'rsq','markersize',4);
grid on;
plot_format('Voltage [V]','Signal','',10);
legend('I-phase, DC1','Q-phase, DC2');

nlf = nonlinfit(V2,data12(:,1,1));
nlf.ex = nlf.x >= 1 | nlf.x < 0.1;
nlf.setFitFunc(@(A,s,x0,x) A*sin(2*pi*(x - x0)/s));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'s',[0.25,5,1.5],'x0',[0,3*max(nlf.x),0.4]);
nlf.fit;
plot(nlf.x,nlf.f(nlf.x),'b--','handlevisibility','off');
zero_crossing_voltages_DC1 = nlf.get('x0',1) + [0,0.5*nlf.get('s',1)];

nlf.y = data12(:,2,2);
nlf.fit;
plot(nlf.x,nlf.f(nlf.x),'r--','handlevisibility','off');
zero_crossing_voltages_DC2 = nlf.get('x0',1) + [0,0.5*nlf.get('s',1)];


%% Scan over DC1 and DC2
data3 = zeros(numel(V),numel(V),3);
tic;
for row = 1:numel(V)
    d.pwm(1).set(V(row)).write;
    for col = 1:numel(V)
        d.pwm(2).set(V(col)).write;
        data3(row,col,:) = get_data_auto_retry(d,1e3);
    end
end
toc;

%% Plot scan over DC1 and DC2
figure(855014);clf;
subplot(1,3,1);
surf(V,V,data3(:,:,1).^2);
xlabel('DC2');ylabel('DC1');
subplot(1,3,2);
surf(V,V,data3(:,:,2).^2);
xlabel('DC2');ylabel('DC1');
subplot(1,3,3);
surf(V,V,data3(:,:,3).^2);
xlabel('DC2');ylabel('DC1');

return
%% Use voltage scan to find minima in 1f components
M = zeros(size(D,1),size(D,2),3);
[D3min,idx] = deal(zeros(size(D,1),size(D,2)));
for row = 1:size(D,1)
    for col = 1:size(D,2)
        [D3min(row,col),idx(row,col)] = min(D(row,col,:,3).^2);
        M(row,col,:) = D(row,col,idx(row,col),:);
    end
end

figure(855017);clf;
subplot(1,2,1);
surf(ph,ph,log10(M(:,:,1).^2 + M(:,:,2).^2));
subplot(1,2,2);
surf(ph,ph,log10(M(:,:,3).^2));


%%
function r = get_data_auto_retry(d,N)
    for jj = 1:10
        try 
            d.getDemodulatedData(N);
            r = mean(d.data);
            return
        catch e
            if jj == 10
                rethrow(e);
            else
                jj = jj + 1;
            end
        end
    end
end