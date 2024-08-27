function [f,P] = get_sideband_traces(sa,modulation_frequency,aom_frequency,rbw)
%GET_SIDEBAND_TRACES Gets sideband traces associated with AOM
%offset measurement.
%
if nargin < 4
    rbw = 100e3;
end
[f1,P1] = sa.get_trace('center',modulation_frequency,'span',2.5*aom_frequency,'rbw',rbw);
[f2,P2] = sa.get_trace('center',aom_frequency,'span',0.5*aom_frequency,'rbw',rbw);
f = [f1 f2];P = [P1 P2];
if nargout == 0
    subplot(1,2,1);
    plot(f2/1e6,P2,'.-');
    yy1 = ylim();
    hold on
    xlabel('Frequency [MHz]');ylabel('Power [dBm]');
    subplot(1,2,2);
    plot(f1/1e6,P1,'.-');
    yy2 = ylim();
    hold on
    xlabel('Frequency [MHz]');ylabel('Power [dBm]');

    yy = [min([yy1(1),yy2(1)]),max([yy1(2),yy2(2)])];
    subplot(1,2,1);
    ylim(yy);
    subplot(1,2,2);
    ylim(yy);
end