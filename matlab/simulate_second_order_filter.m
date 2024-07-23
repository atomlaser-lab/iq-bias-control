%
% Simulate PWM output
%

clock_freq = 250e6;
pwm_bit_depth = 10;
pwm_freq = clock_freq/2^pwm_bit_depth;
gain = 9.3;
Vin_peak = 0.8;

f = logspace(-1,7,1e4);
w = 2*pi*f;

R1 = 1e3;
R2 = 1e3;
C1 = 1e-6;
C2 = 1e-6;

H = 1./(1 + 1i*w*(R1*C2 + R2*C1) - w.^2.*R1*R2*C1*C2);

g = @(x) Vin_peak*gain*abs(interp1(f,H,x,'pchip'));

%%
figure(2);%clf;
loglog(f,abs(H));
hold on;
grid on;

fprintf('Amplitude at PWM freq is %.3f mV\n',1e3*g(pwm_freq));