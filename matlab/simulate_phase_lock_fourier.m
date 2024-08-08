%
% Compute phase lock response using Fourier methods
%
CONV_PWM = 1.6/2^10;
CONV_PHASE = pi/2^13;

f = logspace(0,6,1e4);
w = 2*pi*f;
Tclk = 8e-9;
R = 2^10;
Ts = Tclk*R;

zclk = exp(-1i*w*Tclk);
zs = exp(-1i*w*Ts);

%% Actuator gain
actuator_corner_freq = 1/1.7e-3;  %[rad/s]
G0 = 20;    %[rad/V]
G = G0./(1 + 1i*w./actuator_corner_freq);

%% Feedback
Kp_int = 400;
Ki_int = 100;
Kd_int = 0e3;
divisor = 11;

Kp = Kp_int/2^divisor*CONV_PWM/CONV_PHASE;
Ki = Ki_int/2^divisor/Ts*CONV_PWM/CONV_PHASE;
Kd = Kd_int/2^divisor*Ts*CONV_PWM/CONV_PHASE;

K = (Kp.*(1 - zs) + Ki*Ts.*(1 + zs)/2 + Kd/Ts*(1 - 2*zs + zs.^2))./(1 - zs);
%% Measurement
M = 1./(R.^3).*(1 - zclk.^R).^3./(1 - zclk).^3;
M = M.*exp(-1i*w*Tclk*20);
% M = ones(size(f));

%% Calculate
measurement_nsd = 1e-6*ones(size(f));
environmental_nsd = sqrt(1e-2*(20./f).^2);

L = M.*G.*K;
S = 1./(1 + L);
T = 1 - S;

true_phase_nsd = -1./M.*T.*measurement_nsd + S.*environmental_nsd;
measured_phase_nsd = S.*M.*environmental_nsd + S.*measurement_nsd;

figure(1);clf;
loglog(f,abs(K));
hold on
loglog(f,1./abs(G));

figure(2);clf;
subplot(2,1,1);
loglog(f,abs(S),'b-');
hold on
plot(f,abs(T),'r-');
plot_format('Frequency [Hz]','Response','',10);
grid on;
subplot(2,1,2);
semilogx(f,180/pi*(angle(S)),'b--');
hold on
semilogx(f,180/pi*(angle(T)),'r--');
plot_format('Frequency [Hz]','Phase [rad]','',10);
grid on;

figure(3);clf;
loglog(f,abs(true_phase_nsd).^2);
hold on
loglog(f,abs(measured_phase_nsd).^2);
loglog(f,environmental_nsd.^2,'k--');
ylim([1e-12,1]);
grid on;
plot_format('Frequency [Hz]','Phase PSD [rad^2/Hz]','',10);
yyaxis right
plot(f,sqrt(cumtrapz(f,abs(measured_phase_nsd).^2)));
ylabel('Total phase noise [rad]');
ax = gca;
ax.YAxis(2).Scale = 'log';
ylim([1e-6,1]);

