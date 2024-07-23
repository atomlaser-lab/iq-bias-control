%
% Simulate MIMO feedback
%
clear;

G = 1e5*7.1728;
tc = 0.1298;

Kint = 23;
Dint = 26 + 5;

dt = 2^13/125e6;

K = zeros(size(G));
for row = 1:size(K,1)
    K(row,:) = Kint(row,:)./2.^Dint(row);
end
K = K*1.6/(2^10 - 1)/dt;

Decay = diag(1./tc);
L = Decay*G*K;


I = eye(size(K));
M = [zeros(size(K)),I;-L,-Decay];

[VD,E] = eig(M);
E