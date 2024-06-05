%
% Simulate MIMO feedback eigenvalues
%
clear;


dt = 2^13/125e6;
CONV = 1.6/(2^10 - 1);

G = 1e5*[7.1728,-1.5479,-3.6227;-0.7099,-6.1451,-1.4022;0.0047,-0.0276,0.0918];
tc = [0.1298,0.1256,0.1309];

target_low_pass_freqs = [1,1,0.1];
Ki_target = diag(2*pi*target_low_pass_freqs*dt/CONV);

Ktmp = G\Ki_target;

Kint = zeros(3);
Dint = zeros(3,1);
for row = 1:size(Kint,1)
    Dmin = min(abs(round(log2(abs(Ktmp(row,:))))));
    Dmax = max(abs(round(log2(abs(Ktmp(row,:))))));
    if Dmax - Dmin > 7
        Dint(row) = Dmax;
    else
        Dint(row) = Dmin + 7;
    end
    Kint(row,:) = Ktmp(row,:).*2.^Dint(row);
    if any(abs(Kint(row,:)) > 120)
        Dint(row) = Dint(row) - ceil(log2(max(abs(Kint(row,:)))/120));
        Kint(row,:) = Ktmp(row,:).*2.^Dint(row);
    end
end

% Kint = [23,-9,77;-5,-52,-97;-1,-4,87];
% Dint = [26,27,25];

K = zeros(size(G));
for row = 1:size(K,1)
    K(row,:) = Kint(row,:)./2.^Dint(row);
end
K = K*CONV/dt;

Decay = diag(1./tc);
L = Decay*G*K;

I = eye(size(K));
F = [zeros(size(K)),I;-L,-Decay];
B = [zeros(3);Decay*G];

%%
% dt2 = 1e-5;
dt2 = dt;
T = 20;
t = 0:dt2:T;
Nt = numel(t);

Ndim = 2*size(G,1);
I2 = eye(Ndim);
state = zeros(Ndim,Nt);
u = zeros(size(G,1),Nt);
% u(1,t > 0.1) = 10e-3;
% u = [zeros(3,1),diff(u,1,2)/dt2];

state(1:3,1) = 5e4*randn(3,1);

% U = expm(F*dt2);
U = I2 + F*dt2;

for nn = 2:Nt
    state(:,nn) = U*state(:,nn - 1) + dt2*B*u(:,nn);
end

%%
figure(10);clf;
plot(t,state(1:3,:),'.-');