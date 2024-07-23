%
% Simulate PWM output
%

clock_freq = 250e6;
pwm_bit_depth = 10;
pwm_freq = clock_freq/2^pwm_bit_depth;

% num_cycles = 100;
dt = 1/clock_freq;
% T = num_cycles/pwm_freq;
T = 10e-3;
t = 0:dt:T;

Vset = 0.8;
Vmax = 1.6;
Vin = Vmax*(mod(t,1./pwm_freq)*pwm_freq*Vmax < Vset);
Vin = Vin - mean(Vin);

f = 1/(2*dt)*linspace(-1,1,numel(t));
w = 2*pi*f;
Vin_fft = fftshift(fft(Vin));

R1 = 100;
C1 = 8.2e-9 + 00e-9;
R2 = 1e3;
Resr = 1;
C2 = 47e-6;
C3 = 100e-9;

ZC1 = 1./(1i*w*C1);
ZC2 = (1 + 1i*w*Resr*C2)./(1i*w*C2);
ZC2 = (1./ZC2 + 1i*w*C3).^-1;

H = ZC1.*ZC2./(R1.*ZC1 + (R1 + ZC1).*(R2 + ZC2));

H(isinf(H) | isnan(H)) = 0;

Vout_fft = Vin_fft.*H;
Vout = real(ifft(ifftshift(Vout_fft)));

%%
figure(1);clf;
% plot(t,Vin,'.-');
% hold on
plot(t,Vout,'.-');

figure(2);%clf;
loglog(f(f > 0),abs(H(f > 0)));
hold on;