%
% Script for automatically determining feedback parameters
%


Vcoarse = 0:0.1:1.2;
Vfine = 0:0.025:1.2;
ph = 10:20:270;
Npoints = 1e3;
fig_offset = 1500;

estimated_zero_crossings = [d.pwm(1).get,d.pwm(2).get,d.pwm(3).get];

%% Scan over 2f demodulation phase and DC3 bias
%
% First we want to find the DC3 V-pi value, but we also need to avoid
% cross-coupling to the wrong quadrature of measurement.  So we scan over
% the voltage and the demodulation phase, and look for where the amplitude
% of the response is maximum
%
check_app;
textprogressbar('RESET');
textprogressbar('Finding optimum 2f phase...');
data = zeros(numel(Vcoarse),numel(ph),4);
tic;
for row = 1:numel(Vcoarse)
%     fprintf('DC3 = %.3f V (%d/%d)\n',Vcoarse(row),row,numel(Vcoarse));
    textprogressbar(round(row/numel(Vcoarse)*100));
    d.pwm(3).set(Vcoarse(row)).write;
    for col = 1:numel(ph)
        d.dds2_phase_offset.set(ph(col)).write;
        data(row,col,:) = get_data(d,Npoints);
    end
end
t = toc;

%% Analyze scan over 2f data to get optimum demodulation phase
figure(fig_offset);clf;
plot(ph,range(data(:,:,3),1),'o-');
xlabel('2f demodulation phase [deg]');
[~,idx] = max(range(data(:,:,3),1));
nlf = nonlinfit(ph,range(data(:,:,3),1));
nlf.setFitFunc(@(A,ph0,x) abs(A*cosd(x - ph0)));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'ph0',[0,200,ph(idx)]);
nlf.fit;
hold on
plot(nlf.x,nlf.f(nlf.x),'--');
optimum_2f_phase = nlf.c(2,1);
plot_format('Phase [deg]','Signal',sprintf('Optimum 2f phase = %.1f',optimum_2f_phase),10);
textprogressbar(sprintf('\nOptimum 2f phase is %.1f deg. Time taken = %.1f s\n',optimum_2f_phase,t));
% Fix 2f demodulation phase
d.dds2_phase_offset.set(optimum_2f_phase).write;
update_app_display;

%% Scan over DC3 bias at optimum demodulation phase
%
% Do a fine scan over the DC3 bias at the optimum demodulation phase to
% determine the zero crossings
%
check_app;
textprogressbar('RESET');
textprogressbar('Finding optimum DC3 bias...');
data2 = zeros(numel(Vfine),4);
tic;
for row = 1:numel(Vfine)
    textprogressbar(round(row/numel(Vfine)*100));
    d.pwm(3).set(Vfine(row)).write;
    data2(row,:) = get_data(d,Npoints);
end
t = toc;

%% Analyze DC3 scan data to find minimum of 2f signal
%
% Use a fit to get the rough locations of the zero crossings, and then
% fsolve using an interpolation to get better estimates
%
nlf = nonlinfit(Vfine,data2(:,3));
% nlf.ex = nlf.x >= 1;
nlf.setFitFunc(@(A,s,x0,x) A*sin(2*pi*(x - x0)/s));
nlf.bounds2('A',[-2*max(nlf.y),2*max(nlf.y),max(nlf.y)],'s',[0.25,5,1.5],'x0',[0,max(nlf.x),0.25]);
nlf.fit;
figure(fig_offset + 1);clf;
nlf.plot('plotresiduals',0);
grid on;

approx_zero_voltages = nlf.get('x0',1) + [0,0.5*nlf.get('s',1)];
zero_crossing_voltages_2f = get_zero_crossing_voltages(nlf,approx_zero_voltages);
zero_crossing_voltages_2f = zero_crossing_voltages_2f(zero_crossing_voltages_2f > 0.1);

plot_format('DC3 [V]','Signal',sprintf('Zero-crossing voltage = %.3f',zero_crossing_voltages_2f(end)),10);
textprogressbar(sprintf('\nDC3 biases = [%.3f,%.3f] V. Time taken = %.1f s',zero_crossing_voltages_2f,t));
%% Set DC3 voltage
check_app;
d.pwm(3).set(closest_value_to(zero_crossing_voltages_2f,estimated_zero_crossings(3))).write;
update_app_display;
%% Scan over DC2 and 1f demodulation phase
%
% We first get the old voltages to store them later.  Then we scan over the
% DC2 voltage and the 1f demodulation phase to find the phase that
% maximally decouples the effects of DC1 and DC2
%
old_voltages = [d.pwm(1).get,d.pwm(2).get];
data3 = zeros(numel(Vcoarse),numel(ph),4);
check_app;
textprogressbar('RESET');
textprogressbar('Determining optimum 1f phase...');
tic;
for row = 1:numel(Vcoarse)
%     fprintf('DC2 = %.3f V (%d/%d)\n',Vcoarse(row),row,numel(Vcoarse));
    textprogressbar(round(row/numel(Vcoarse)*100));
    d.pwm(2).set(Vcoarse(row)).write;
    for col = 1:numel(ph)
        d.phase_offset.set(ph(col)).write;
        data3(row,col,:) = get_data(d,1e3);
    end
end
t = toc;
d.pwm(1).set(old_voltages(1)).write;
d.pwm(2).set(old_voltages(2)).write;

%% Analyze scan over 1f data to get optimum demodulation phase
%
% I'm looking for the phase that results in a maximum amplitude of the 1f Q
% modulation and a simultaneous minimum in the 1f I modulation
%
figure(fig_offset + 2);clf;
plot(ph,range(data3(:,:,1),1),'o-');
hold on
plot(ph,range(data3(:,:,2),1),'sq-');
xlabel('f demodulation phase [deg]');
[~,idx] = max(range(data3(:,:,2),1));
nlf = nonlinfit(ph,range(data3(:,:,2),1));
nlf.setFitFunc(@(A,ph0,y0,x) A*abs(cosd(x - ph0)) + y0);
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'ph0',[0,180,mod(ph(idx),180)],'y0',[0,0.5*max(nlf.y),min(nlf.y)]);
nlf.fit;
hold on
plot(nlf.x,nlf.f(nlf.x),'--');
optimum_1f_phase = nlf.c(2,1);
plot_format('Phase [deg]','Signal',sprintf('Optimum 1f phase = %.1f',optimum_1f_phase),10);
% 
% % Fix 1f demodulation phase
check_app;
d.phase_offset.set(optimum_1f_phase).write;
textprogressbar(sprintf('\nOptimum 1f phase = %.1f deg. Time taken = %.1f s',optimum_1f_phase,t));
update_app_display;
%% Fine scan over DC1 and DC2 individually
%
% We then want to find the approximate voltages at which the 1f I and Q
% signals are zero
%
data12 = zeros(numel(Vfine),4,2);
check_app;
textprogressbar('RESET');
textprogressbar('Measuring DC1 and DC2 biases...');
tic;
for col = 1:2
    d.pwm(1).set(old_voltages(1)).write;
    d.pwm(2).set(old_voltages(2)).write;
    for row = 1:numel(Vfine)
        textprogressbar(round((row/(2*numel(Vfine)) + (col - 1)/2)*100));
        d.pwm(col).set(Vfine(row)).write;
        data12(row,:,col) = get_data(d,1e3);
    end
end
d.pwm(1).set(old_voltages(1)).write;
d.pwm(2).set(old_voltages(2)).write;
t = toc;
%% Analyze fine scan over DC1 and DC2
%
% We use the same fit-then-interpolate procedure as for the DC3 signal to
% find the DC1 and DC2 biases that approximately zero out the the 1f I and
% Q signals.
%

figure(fig_offset + 3);clf;
plot(Vfine,data12(:,1,1),'b.');
hold on
plot(Vfine,data12(:,2,2),'r.');
grid on;
plot_format('Voltage [V]','Signal','',10);
legend('I-phase, DC1','Q-phase, DC2');

nlf = nonlinfit(Vfine,data12(:,1,1));
nlf.ex = nlf.x >= 1 | nlf.x < 0.1;
nlf.setFitFunc(@(A,s,x0,x) A*sin(2*pi*(x - x0)/s));
nlf.bounds2('A',[0,2*max(nlf.y),max(nlf.y)],'s',[0.25,5,1.5],'x0',[0,3*max(nlf.x),0.8]);
nlf.fit;
plot(nlf.x,nlf.f(nlf.x),'b--','handlevisibility','off');
approx_zero_crossing_voltages_DC1 = nlf.get('x0',1) + [0,0.5*nlf.get('s',1)];
zero_crossing_voltages_DC1 = get_zero_crossing_voltages(nlf,approx_zero_crossing_voltages_DC1);
zero_crossing_voltages_DC1 = zero_crossing_voltages_DC1(zero_crossing_voltages_DC1 > 0.1);
nlf.y = data12(:,2,2);
nlf.fit;
plot(nlf.x,nlf.f(nlf.x),'r--','handlevisibility','off');
approx_zero_crossing_voltages_DC2 = nlf.get('x0',1) + [0,0.5*nlf.get('s',1)];
zero_crossing_voltages_DC2 = get_zero_crossing_voltages(nlf,approx_zero_crossing_voltages_DC2);
zero_crossing_voltages_DC2 = zero_crossing_voltages_DC2(zero_crossing_voltages_DC2 > 0.1);
textprogressbar(sprintf('\nDC1 biases = [%.3f,%.3f] V, DC2 biases = [%.3f,%.3f] V. Time taken = %.1f s',zero_crossing_voltages_DC1,zero_crossing_voltages_DC2,t));

%% Set DC1 and DC2 to zero-crossing values
check_app;
d.pwm(1).set(closest_value_to(zero_crossing_voltages_DC1,estimated_zero_crossings(1))).write;
d.pwm(2).set(closest_value_to(zero_crossing_voltages_DC2,estimated_zero_crossings(2))).write;
update_app_display;
%% Measure linear responses around zero crossing values
%
% Apply small variations around the nominal zero crossing values and
% measure the responses
%
zero_voltages = [d.pwm(1).get(),d.pwm(2).get(),d.pwm(3).get()];
dV = 5e-3;
V = dV*(-10:10);
check_app;
figure(fig_offset + 5);clf;
[G,zero_voltages,data_lin] = get_linear_response(d,zero_voltages,V,Npoints);
d.pwm.set(zero_voltages).write;
update_app_display;
%% Redo linear measurement with new zero voltage values
check_app;
figure(fig_offset + 5);clf;
[G,zero_voltages,data_lin] = get_linear_response(d,zero_voltages,V,Npoints);
d.pwm.set(zero_voltages).write;
update_app_display;
%% Get open-loop response
%
% Applies a step voltage to each DC bias and then measures the dynamic
% response of the signals to get a gain matrix and a matrix of time
% constants
% fprintf('Measuring dynamic responses...');
check_app;
tic;
[tc,Gdynamic] = get_voltage_step_response(d,1/d.dt(),20e-3);
response_freqs = 1./(2*pi*diag(tc));
t = toc;
fprintf('Finished measuring dynamic responses in %.1f s\n',t);
%% Compute feedback matrix
%
% Using a target low-pass frequency (in Hz), we now compute the feedback
% matrix K and its integer values taking into account the row-wise divisors
%
target_low_pass_freqs = 0.5*[2,2,0.5];
% target_low_pass_freqs = 0.5*response_freqs;
Ki_target = 2*pi*target_low_pass_freqs*d.dt()/DeviceControl.CONV_PWM;

K_target = diag(Ki_target);
Ktmp = G\K_target;
K = zeros(3);
D = zeros(3,1);
for row = 1:3
    Dmin = min(abs(round(log2(abs(Ktmp(row,:))))));
    Dmax = max(abs(round(log2(abs(Ktmp(row,:))))));
    if Dmax - Dmin > 7
        D(row) = Dmax;
    else
        D(row) = Dmin + 7;
    end
    K(row,:) = Ktmp(row,:).*2.^D(row);
    if any(abs(K(row,:)) > 120)
        D(row) = D(row) - ceil(log2(max(abs(K(row,:)))/120));
        K(row,:) = Ktmp(row,:).*2.^D(row);
    end
end
fprintf('Feedback matrix computed\n');

%% Set gains
check_app;
for row = 1:size(K,1)
    for col = 1:size(K,2)
        d.control.gains(row,col).set(round(K(row,col)));
    end
    d.control.divisors(row).set(D(row));
end
d.pwm.set(zero_voltages);
d.upload;
fprintf('Parameters uploaded\n');
update_app_display;
%%
function r = get_data(d,N)
    d.getDemodulatedData(N);
    r = mean(d.data);
end

function r = get_zero_crossing_voltages(nlf,x0)
    idx = find(diff(sign(nlf.y)) ~= 0);
    r = [0,0];
    for nn = 1:numel(idx)
        r(nn) = fsolve(@(x) interp1(nlf.x,nlf.y,x,'pchip'),nlf.x(idx(nn)),optimset('display','off'));
    end
end

function check_app
    app = DeviceControl.get_running_app_instance();
    app.set_timer('off');
end

function update_app_display
    app = DeviceControl.get_running_app_instance();
    app.updateDisplay;
end

function closest_value = closest_value_to(values,target)
    d = abs(values - target);
    [~,idx] = min(d);
    closest_value = values(idx);
end
