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

% if mod(nargin,2) ~= 0
%     error('Arguments must occur in name/value pairs!');
% else
%     for nn = 1:2:nargin
%         v = varargin{nn + 1};
%         switch lower(varargin{nn})
%             case 'pha'
%                 NamedArgs.phA = v;
%             case 'phb'
%                 NamedArgs.phB = v;
%             case 'php'
%                 NamedArgs.phP = v;
%         end
%     end
% end

mod_depth = 0.1;        %radians
mod_freq = 2*pi*1e6;    %1/s

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
E1 = 0.5*exp(1i*mod_depth*sin(mod_freq*t) + 1i*ph1);
E2 = 0.5*exp(1i*mod_depth*sin(mod_freq*t + pi) + 1i*ph2);
E3 = 0.5*exp(1i*mod_depth*sin(mod_freq*t + pi/2 + ph_err) + 1i*ph3);
E4 = 0.5*exp(1i*mod_depth*sin(mod_freq*t + 3*pi/2 + ph_err) + 1i*ph4);

EA = 1/sqrt(2)*(E1 + E2);
EB = 1/sqrt(2)*(E3 + E4);
Ep = 1/sqrt(2)*(EA*exp(1i*phA) + EB*exp(1i*phB));

Ip = abs(Ep).^2;

%% Demodulate and filter
demod_phase1 = 0;
demod_phase2 = 0;

raw1 = Ip.*sin(mod_freq*t + demod_phase1);
raw2 = Ip.*cos(mod_freq*t + demod_phase1);
raw3 = Ip.*sin(2*mod_freq*t + demod_phase2);

R = 2^10;
[S1,tmeas] = cicfilter(t,raw1,R,3);
S2 = cicfilter(t,raw2,R,3);
S3 = cicfilter(t,raw3,R,3);

%% Plot and output
Y = fftshift(fft(Ep));
f = 1./(2*dt)*linspace(-1,1,numel(Y));
YP = abs(Y/numel(f)).^2;
if nargout == 0
    figure(1);clf;
    plot(t,Ip);
    xlim([0,1*2*pi./mod_freq]);
    
    figure(2);clf;
    plot(tmeas,[S1,S2,S3],'.-');
    
    figure(3);clf;
    plot(f/1e6,YP);
    xlim(mod_freq/(2*pi*1e6)*4*[-1,1])
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
