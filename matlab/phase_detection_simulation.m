function varargout = phase_detection_simulation(NamedArgs)
%
% Simulate CS-SSB
%

arguments
    NamedArgs.phA = 180;
    NamedArgs.phB = 180;
    NamedArgs.phP = 180;
    NamedArgs.mode = 'diff';
end

mod_depth = 0.1;        %radians
mod_freq1 = 2*pi*3e6;    %1/s
mod_freq2 = 2*pi*4e6;

%% Generate fast time signals
dt = 8e-9;
T = 100e-6;
t = (0:dt:T)';

if strcmpi(NamedArgs.mode,'')
    ph1 = 0;
    ph2 = ph1 + NamedArgs.phA*pi/180;
    ph3 = pi/2;
    ph4 = ph3 + NamedArgs.phB*pi/180;
    phA = 0;
    phB = phA + NamedArgs.phP*pi/180;
elseif strcmpi(NamedArgs.mode,'diff')
    ph1 = -0.5*NamedArgs.phA*pi/180;
    ph2 = 0.5*NamedArgs.phA*pi/180;
    ph3 = pi/2 - 0.5*NamedArgs.phB*pi/180;
    ph4 = pi/2 + 0.5*NamedArgs.phB*pi/180;
    phA = -0.5*NamedArgs.phP*pi/180;
    phB = 0.5*NamedArgs.phP*pi/180;
else
    error('Unrecognized mode options');
end
ph_err = 0;
E1 = 0.5*exp(1i*mod_depth*sin(mod_freq1*t) + 1i*ph1);
E2 = 0.5*exp(1i*mod_depth*sin(mod_freq1*t + pi) + 1i*ph2);
E3 = 0.5*exp(1i*mod_depth*sin(mod_freq2*t + pi/2 + ph_err) + 1i*ph3);
E4 = 0.5*exp(1i*mod_depth*sin(mod_freq2*t + 3*pi/2 + ph_err) + 1i*ph4);

EA = 1/sqrt(2)*(E1 + E2);
EB = 1/sqrt(2)*(E3 + E4);
Ep = 1/sqrt(2)*(EA*exp(1i*phA) + EB*exp(1i*phB));

Ip = abs(Ep).^2;

%% Demodulate and filter
demod_phase(1) = pi/4;
demod_phase(2) = pi/6;
demod_phase(3) = 0;
demod_phase(4:5) = 0;

raw(:,1) = Ip.*sin(mod_freq1*t + demod_phase(1));
raw(:,2) = Ip.*cos(mod_freq1*t + demod_phase(1));
raw(:,3) = Ip.*sin(mod_freq2*t + demod_phase(2));
raw(:,4) = Ip.*cos(mod_freq2*t + demod_phase(2));
raw(:,5) = Ip.*sin((mod_freq1 - mod_freq2)*t + demod_phase(3));
raw(:,6) = Ip.*cos((mod_freq1 - mod_freq2)*t + demod_phase(3));
raw(:,7) = Ip.*sin(2*mod_freq1*t + demod_phase(4));
raw(:,8) = Ip.*cos(2*mod_freq1*t + demod_phase(4));
raw(:,9) = Ip.*sin(2*mod_freq2*t + demod_phase(5));
raw(:,10) = Ip.*cos(2*mod_freq2*t + demod_phase(5));

R = 2^10;
for nn = 1:size(raw,2)
    if nn == 1
        [S(:,nn),tmeas] = cicfilter(t,raw(:,nn),R,3);
    else
        S(:,nn) = cicfilter(t,raw(:,nn),R,3);
    end
end

%% Plot and output
Y = fftshift(fft(Ep));
f = 1./(2*dt)*linspace(-1,1,numel(Y));
YP = abs(Y/numel(f)).^2;
if nargout == 0
    figure(1);clf;
    plot(t,Ip);
    xlim([0,1*2*pi./min(mod_freq1,mod_freq2)]);
    
    figure(2);clf;
    plot(tmeas,S,'.-');
    
    figure(3);clf;
    plot(f/1e6,YP);
    xlim(max(mod_freq1,mod_freq2)/(2*pi*1e6)*4*[-1,1])
else
    D = mean([S1,S2,S3],1);
    [~,idx] = min((f + mod_freq/(2*pi)).^2);
    P = YP(idx);
    [~,idx] = min((f).^2);
    P(2) = YP(idx);
    [~,idx] = min((f - mod_freq/(2*pi)).^2);
    P(3) = YP(idx);

    varargout{1} = D;
    varargout{2} = P;
end
