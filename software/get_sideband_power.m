function [Pmeas,f,P] = get_sideband_power(sa,modulation_frequency,aom_frequency,rbw)

Pmeas = [0,0,0];
if nargin < 4
    rbw = 100e3;
end
[f,P] = get_sideband_traces(sa,modulation_frequency,aom_frequency,rbw);

%
% Get carrier power
%
idx = find(f(:,2) >= aom_frequency,1,'first');
% Pmeas(2) = max(P(idx + (-5:5),2));
Pmeas(2) = P(idx,2);
%
% Get sideband power
%
idx = find(f(:,1) >= modulation_frequency - aom_frequency,1,'first');
% Pmeas(1) = max(P(idx + (-5:5),1));
Pmeas(1) = P(idx,1);
idx = find(f(:,1) >= modulation_frequency + aom_frequency,1,'first');
% Pmeas(3) = max(P(idx + (-5:5),1));
Pmeas(3) = P(idx,1);
% 
% %
% % Get carrier power
% %
% sa.set_measurement_settings('center',aom_frequency,'span',0.5*aom_frequency,'rbw',rbw);
% pause(1);
% sa.set_marker_x(aom_frequency);
% P(2) = sa.get_marker_y();
% %
% % Get sideband powers
% %
% sa.set_measurement_settings('center',modulation_frequency,'span',2.5*aom_frequency,'rbw',rbw);
% pause(1);
% sa.set_marker_x(modulation_frequency - aom_frequency);
% pause(100e-3);
% P(1) = sa.get_marker_y();
% sa.set_marker_x(modulation_frequency + aom_frequency);
% pause(100e-3);
% P(3) = sa.get_marker_y();