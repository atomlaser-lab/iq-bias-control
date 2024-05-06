function [Pmeas,f,P] = get_sideband_power(sa,modulation_frequency,aom_frequency,rp_modulation_frequency,rbw)

Pmeas = [0,0,0];
[f,P] = get_sideband_traces(sa,modulation_frequency,aom_frequency,rbw);

%
% Get carrier power
%
idx = find(f(:,2) >= aom_frequency,1,'first');
% Pmeas(2) = max(P(idx + (-5:5),2));
Pmeas(2) = P(idx,2);

idx = find(f(:,2) >= aom_frequency - rp_modulation_frequency,1,'first');
Pmeas(4) = P(idx,2);
idx = find(f(:,2) >= aom_frequency + rp_modulation_frequency,1,'first');
Pmeas(5) = P(idx,2);

%
% Get sideband power
%
idx = find(f(:,1) >= modulation_frequency - aom_frequency,1,'first');
% Pmeas(1) = max(P(idx + (-5:5),1));
Pmeas(1) = P(idx,1);
idx = find(f(:,1) >= modulation_frequency + aom_frequency,1,'first');
% Pmeas(3) = max(P(idx + (-5:5),1));
Pmeas(3) = P(idx,1);
