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

R = 100;
C = 8.2e-9 + 47e-6;
low_pass_freq = 1/(R*C);


Vset = 1;
Vmax = 1.6;
Vin = Vmax*(mod(t,1./pwm_freq)*pwm_freq*Vmax < Vset);

Vout = zeros(size(Vin));
Vout(1) = Vmax;

for nn = 2:numel(t)
    Vout(nn) = (Vin(nn)*dt*low_pass_freq + Vout(nn - 1))./(1 + dt*low_pass_freq);
end

%%
figure(1);clf;
plot(t,Vin,'.-');
hold on
plot(t,Vout,'.-');