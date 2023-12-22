function [D,S] = phase_detection_simulation_simple(NamedArgs)
%
% Simulate CS-SSB
%

arguments
    NamedArgs.phA = 180;
    NamedArgs.phB = 180;
    NamedArgs.phP = 90;
    NamedArgs.dphi1 = 0;
    NamedArgs.dphi2 = 0;
    NamedArgs.mode = 'diff';
end

mod_depth = 0.1;        %radians

%% Generate fast time signals
dphi1 = NamedArgs.dphi1*pi/180;
dphi2 = NamedArgs.dphi2*pi/180;

if strcmpi(NamedArgs.mode,'')
    ph1 = 0;
    ph2 = ph1 + NamedArgs.phA*pi/180;
    ph3 = pi/2;
    ph4 = ph3 + NamedArgs.phB*pi/180;
    phA = 0;
    phB = phA + NamedArgs.phP*pi/180;
elseif strcmpi(NamedArgs.mode,'diff')
    ph1 = -0.5*NamedArgs.phA*pi/180 - pi/2;
    ph2 = 0.5*NamedArgs.phA*pi/180 + pi/2;
    ph3 = pi/2 - 0.5*NamedArgs.phB*pi/180 - pi/2;
    ph4 = pi/2 + 0.5*NamedArgs.phB*pi/180 + pi/2;
    phA = -0.5*NamedArgs.phP*pi/180;
    phB = 0.5*NamedArgs.phP*pi/180;
else
    error('Unrecognized mode options');
end

deltaA = (ph1 - ph2)/2 + pi/2;
deltaB = (ph3 - ph4)/2 + pi/2;
deltaP = (phA - phB)/2 + 0.25*(ph1 + ph2 + ph3 + ph4);

Ec = exp(1i*deltaP).*sin(deltaA) + exp(-1i*deltaP).*sin(deltaB);
Ep = mod_depth/2*(-1i*exp(1i*deltaP).*cos(deltaA) + exp(-1i*deltaP).*cos(deltaB));
En = mod_depth/2*(1i*exp(1i*deltaP).*cos(deltaA) + exp(-1i*deltaP).*cos(deltaB));

S = cat(4,abs(En).^2,abs(Ec).^2,abs(Ep).^2);

Dsin1f_0 = 2*mod_depth*(cos(deltaA).*(sin(deltaA) + cos(2*deltaP).*sin(deltaB)));
Dcos1f_0 = 2*mod_depth*(cos(deltaB).*(sin(deltaB) + cos(2*deltaP).*sin(deltaA)));
Dsin1f = Dsin1f_0.*cos(dphi1) + Dcos1f_0.*sin(dphi1);
Dcos1f = -Dsin1f_0.*sin(dphi1) + Dcos1f_0.*cos(dphi1);

Dsin2f_0 = 0.5*mod_depth.^2.*(2*cos(deltaA).*cos(deltaB).*cos(2*deltaP));
Dcos2f_0 = 0.5*mod_depth.^2.*(cos(deltaA).^2 - cos(deltaB).^2);
Dsin2f = Dsin2f_0.*cos(dphi2) + Dcos2f_0.*sin(dphi2);
Dcos2f = -Dsin2f_0.*sin(dphi2) + Dcos2f_0.*cos(dphi2);

D = cat(4,Dsin1f,Dcos1f,Dsin2f,Dcos2f);

