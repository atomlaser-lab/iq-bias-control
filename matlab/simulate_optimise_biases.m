%
% Attempt at automatic bias optimisation
%
V = 0:10:360;
ph = 0:10:360;

ph1f_offset = 25;
ph2f_offset = 60;
phA_offset = 70;
phB_offset = 120;

phA = 30;
phB = 50;

phmode = '';

%% Scan over 2f demodulation phase and DC3 bias
data = zeros(numel(V),numel(ph),3);
for row = 1:numel(V)
    for col = 1:numel(ph)
        tmp = squeeze(phase_detection_simulation_simple('phP',V(row),'dphi2',ph(col) - ph2f_offset,...
            'phA',phA - phA_offset,'phB',phB - phB_offset,'mode',phmode,'dphi1',-ph1f_offset));
        data(row,col,:) = tmp(1:3);
    end
end

%% Analyze scan over 2f data to get optimum demodulation phase
figure(855012);clf;
plot(ph,range(data(:,:,3),1),'o-');
xlabel('2f demodulation phase [deg]');
[~,idx] = max(range(data(:,:,3),1));
nlf = nonlinfit(ph,range(data(:,:,3),1));
nlf.setFitFunc(@(A,ph0,x) A*abs(cosd(x - ph0)));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'ph0',[-360,360,ph(idx)]);
nlf.fit;
hold on
plot(nlf.x,nlf.f(nlf.x),'--');
optimum_2f_phase = nlf.c(2,1);
title(sprintf('Optimum 2f phase = %.1f',optimum_2f_phase));

%% Scan over DC3 bias at optimum demodulation phase
data2 = zeros(numel(V),3);
for row = 1:numel(V)
    tmp = squeeze(phase_detection_simulation_simple('phP',V(row),'dphi2',optimum_2f_phase - ph2f_offset,...
        'phA',phA - phA_offset,'phB',phB - phB_offset,'mode',phmode,'dphi1',-ph1f_offset));
    data2(row,:) = tmp(1:3);
end

%% Analyze DC3 scan data to find minimum of 2f signal
nlf = nonlinfit(V,data2(:,3));
nlf.setFitFunc(@(A,x0,x) A*sind(x - x0));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'x0',[0,max(nlf.x),150]);
nlf.fit;
figure(855013);clf;
nlf.plot('plotresiduals',0);
title(sprintf('Zero-crossing voltage = %.3f',nlf.c(2,1)));

zero_crossing_voltage = nlf.c(2,1);

%% Scan over DC1 and 1f demodulation phase
data4 = zeros(numel(V),numel(ph),3);
for row = 1:numel(V)
    for col = 1:numel(ph)
        tmp = squeeze(phase_detection_simulation_simple('phP',zero_crossing_voltage,'dphi2',optimum_2f_phase - ph2f_offset,...
            'phA',V(row) - phA_offset,'phB',phB - phB_offset,'mode',phmode,'dphi1',ph(col) - ph1f_offset));
        data4(row,col,:) = tmp(1:3);
    end
end

%% Analyze scan over 1f data to get optimum demodulation phase
figure(855015);clf;
plot(ph,range(data4(:,:,1),1),'o-');
hold on
plot(ph,range(data4(:,:,2),1),'sq-');
xlabel('f demodulation phase [deg]');
[~,idx] = max(range(data4(:,:,1),1));
nlf = nonlinfit(ph,range(data4(:,:,1),1));
nlf.setFitFunc(@(A,ph0,x) A*abs(cosd(x - ph0)));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'ph0',[-360,360,ph(idx)]);
nlf.fit;
hold on
plot(nlf.x,nlf.f(nlf.x),'--');
optimum_f_phase = nlf.c(2,1);
title(sprintf('Optimum 2f phase = %.1f',optimum_f_phase));

%% Scan over DC1 and DC2
data3 = zeros(numel(V),numel(V),3);
for row = 1:numel(V)
    for col = 1:numel(V)
        tmp = squeeze(phase_detection_simulation_simple('phP',zero_crossing_voltage,'dphi2',optimum_2f_phase - ph2f_offset,...
            'phA',V(row) - phA_offset,'phB',V(col) - phB_offset,'mode',phmode,'dphi1',optimum_f_phase - ph1f_offset));
        data3(row,col,:) = tmp(1:3);
    end
end

%% Plot scan over DC1 and DC2
figure(855014);clf;
subplot(1,3,1);
surf(V,V,data3(:,:,1));
xlabel('DC1');ylabel('DC2');
subplot(1,3,2);
surf(V,V,data3(:,:,2));
xlabel('DC1');ylabel('DC2');
subplot(1,3,3);
surf(V,V,data3(:,:,3));
xlabel('DC1');ylabel('DC2');

%% Scan over all voltages
[A,B,P] = meshgrid(ph,ph,ph);
[D,S] = phase_detection_simulation_simple('phP',P,'dphi2',optimum_2f_phase - ph2f_offset,...
            'phA',A - phA_offset,'phB',B - phB_offset,'mode',phmode,'dphi1',optimum_f_phase - ph1f_offset);

M = zeros(size(D,1),size(D,2),2);
idx = zeros(size(D,1),size(D,2));
for row = 1:size(D,1)
    for col = 1:size(D,2)
        [~,idx(row,col)] = min(D(row,col,:,3).^2);
        M(row,col,:) = D(row,col,idx(row,col),1:2);
    end
end
