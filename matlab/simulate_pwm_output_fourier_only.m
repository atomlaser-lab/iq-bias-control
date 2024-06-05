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

R1 = 100;
C1 = 8.2e-9 + 2.2e-6;
R2 = 1e3;
Resr = 0;
C2 = .22e-6;
C3 = 0e-6;

% R1 = 100;
% C1 = 8.2e-9;
% R2 = 0*2.2e3;
% Resr = 2.478;
% C2 = 47e-6;
% C3 = 0e-6;

ZC1 = 1./(1i*w*C1);
ZC2 = (1 + 1i*w*Resr*C2)./(1i*w*C2);
ZC2 = (1./ZC2 + 1i*w*C3).^-1;

H = ZC1.*ZC2./(R1.*ZC1 + (R1 + ZC1).*(R2 + ZC2));
H1 = ZC1./(R1 + ZC1).*(1 - ZC1.*R1./(R1.*ZC1 + (R1 + ZC1).*(R2 + ZC2)));

g = @(x) Vin_peak*gain*abs(interp1(f,H,x,'pchip'));
g1 = @(x) Vin_peak*gain*abs(interp1(f,H1,x,'pchip'));

%%
figure(2);%clf;
loglog(f,abs(H));
hold on;
grid on;

fprintf('Amplitude at PWM freq is %.3f mV\n',1e3*g(pwm_freq));