%
% Attempt to quantify the systematic error of the CS-SSB laser system on an
% atom interferometer
%
clear;
c = 299792458;
f_Rb_groundHFS = 6834.682610904e6;
keff = 4*pi*384.230e12/c;
Tint = 75e-3;
dz = sqrt(0.5e-6^2 + (const.kb*3e-6/const.mRb)*150e-3^2);
% These suppression values are the mean suppression values in dB as
% measured on 19/05/2024.
power_positive_hf = 0;
power_negative_hf = -26.3;
power_carrier = -25.86;
power_positive_lf = -20.59;
power_negative_lf = -38.69;

detuning = 2*pi*f_Rb_groundHFS*linspace(-1,1,1e4);    %Measured from the fine structure center
omega_hf = 2*pi*f_Rb_groundHFS/2;
omega_lf = 2*pi*4e6;
k_hf = omega_hf/c;
k_lf = omega_lf/c;
%
% These account for the different detunings from the F' = 1 and F' = 2
% manifolds, as well as the different dipole matrix elements assuming that
% the atoms are in the m_F = 0 states and are coupled to the excited states
% using circularly polarized light
%
excited_state.F3 = 2*pi*193.74e6;
excited_state.F2 = -2*pi*72.9113e6;
excited_state.F1 = -2*pi*229.8518e6;
%
% This is the detuning and dipole factor
%
D = @(p,q) 0.25./(detuning - excited_state.F2 + (p - 2)*omega_hf + q*omega_lf) + 1/12./(detuning - excited_state.F1 + (p - 2)*omega_hf + q*omega_lf);
%
% Suppression ratios are square-rooted to give electric field amplitudes
%
E_phf = 1;  %This is an arbitrary value for the +HF sideband electric field
% Calculate the carrier field assuming that we nullify the differential AC
% Stark shift
B0 = E_phf*rabi_scale(detuning,excited_state);  %This is the additional carrier electric field
E_nhf = E_phf.*10.^(0.1/2*power_negative_hf);   %This is the -HF electric field
E_plf = E_phf.*10.^(0.1/2*power_positive_lf);   %This is the +LF electric field
E_nlf = E_phf.*10.^(0.1/2*power_negative_lf);   %This is the -LF electric field
E_c = E_phf.*10.^(0.1/2*power_carrier);         %This is the unsuppressed carrier
%
% Calculate the maximum phase error
%
max_phase_error(1,:) = B0.*E_nhf.^2.*D(0,0);
max_phase_error(2,:) = E_c.^2.*E_phf.*E_nhf.*D(1,0);
max_phase_error(3,:) = E_phf.*E_nhf.*E_plf.^2.*D(1,1);
max_phase_error(4,:) = E_phf.*E_nhf.*E_nlf.^2.*D(1,-1);
max_phase_error = 4*max_phase_error./(B0.*E_phf.^2.*D(2,0));

p = [0,1,1,1];q = [0,0,1,-1];
for nn = 1:numel(p)
    max_rabi_variation(nn,:) = max_phase_error(nn,:).*((p(nn) - 2)*k_hf*dz + q(nn)*dz);
end


%% Make plot

h = figure(9128);clf;
set(h,'units','centimeters','paperunits','centimeters');
h.Position(3:4) = [14,8];
set(h,'papersize',h.Position(3:4),'paperposition',[0,0,h.Position(3:4)]);

ax = axes('Position',[0.11,0.15,0.77,0.8]);

semilogy(detuning/(2*pi*1e9),abs(max_phase_error),'--');
hold on
semilogy(detuning/(2*pi*1e9),abs(sum(max_phase_error,1)),'k-','linewidth',1);
grid on;
legend({'(0,0)','(1,0)','(1,1)','(1,-1)','Total'},'location','northwest');
% legend({'(0,0)','(1,0)','(1,1)','(1,-1)','Total'},'location','northwest');
xlabel('Detuning [GHz]','fontsize',10);
ylabel('Maximum systematic error [mrad]','FontSize',10);
ylim([1e-4,1]);
% ax = gca;
% ax.XTick = -10:10;
set(ax,'box','off');
yy = @(x) x./(keff*Tint^2)*1e8;
ax2 = axes('position',ax.Position,'box','off','color','none','XAxisLocation','top','xtick',[],...
    'YAxisLocation','right','ytick',yy(ax.YTick),'ylim',yy(ax.YLim),'yscale','log',...
    'yticklabel',strtrim(strsplit(sprintf('10^{%.0f}\n',log10(yy(ax.YTick))))));
ylabel(ax2,'Bias [µGal]','fontsize',10);
% axes(ax);

figure(9129);clf;
semilogy(detuning/(2*pi*1e9),abs(max_rabi_variation),'--');
hold on
semilogy(detuning/(2*pi*1e9),abs(sum(max_rabi_variation,1)),'k-','linewidth',1);
grid on;
xlabel('Detuning [GHz]','fontsize',10);
ylabel('Maximum fractional Rabi variation','fontsize',10);


%% LOCAL FUNCTIONS
function S = rabi_scale(x,ex)
% This calculates the ratio of carrier to sideband amplitudes (at 780 nm)
% required to cancel out the differential AC Stark shift
hfs = 6834.682610904e6*2*pi;

ac_E1 = 1/60./(x - ex.F1 + hfs) + 1/4./(x - ex.F2 + hfs) + 2/5./(x - ex.F3 + hfs) - 5/12./(x - ex.F1) - 1/4./(x - ex.F2);
ac_E2 = 1/60./(x - ex.F1) + 1/4./(x - ex.F2) + 2/5./(x - ex.F3) - 5/12./(x - ex.F1 - hfs) - 1/4./(x - ex.F2 - hfs);

S = -ac_E1./ac_E2;
S(S < 0) = 1;
S = sqrt(S);

end