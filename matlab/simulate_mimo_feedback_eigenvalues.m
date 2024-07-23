%
% Simulate MIMO feedback eigenvalues
%
clear;

% x = -10:1:2;
% x = [0.01,0.1,0.2,0.5,1];
% x = logspace(-2,1,100);
x = 1;
Nruns = numel(x);

dt = 2^13/125e6;
CONV = 1.6/(2^10 - 1);

E = [];VD = [];
for nn = 1:Nruns

    Gmeas = 1e5*[7.1728,-1.5479,-3.6227;-0.7099,-6.1451,-1.4022;0.0047,-0.0276,0.0918];
    G = Gmeas.*(1 + 0.0*randn(size(Gmeas)));
    tc = [0.1298,0.1256,0.1309];
    
    target_low_pass_freqs = x(nn)*[1,1,0.1];
    Ki_target = diag(2*pi*target_low_pass_freqs*dt/CONV);

    Ktmp = Gmeas\Ki_target;
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

%     Kint = [23,-9,77;-5,-52,-97;-1,-4,87];
%     Dint = [26,27,25];
    
    K = zeros(size(G));
    for row = 1:size(K,1)
        K(row,:) = Kint(row,:)./2.^Dint(row);
    end
    K = K*CONV/dt;
    
    Decay = diag(1./tc);
    L = Decay*G*K;
    
    
    I = eye(size(K));
    M = [zeros(size(K)),I;-L,-Decay];
    E(:,nn) = eig(M);
%     Mstore(:,:,nn) = M;
%     if nn == 1
%         [VD(:,:,nn),Etmp] = eig(M);
%         E(:,nn) = diag(Etmp);
%     else
%         [VD(:,:,nn),E(:,nn)] = eigenvalue_follower(M,VD(:,:,nn - 1));
%     end
    
end

% E = eigfollower([],Mstore);

figure(10);clf;
for nn = 1:size(E,1)
    h = plot(real(E(nn,:)),imag(E(nn,:)),'o-');
    h.MarkerFaceColor = h.Color;
    hold on
end
grid on;
xlim([-8,0]);