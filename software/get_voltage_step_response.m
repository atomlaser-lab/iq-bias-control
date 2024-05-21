function [tc,G,c,res] = get_voltage_step_response(d,num_samples,jump_amount,jump_index)

num_samples = round(num_samples);
if nargin < 4
    c = zeros(6,3,3);
    res = zeros(num_samples,3,3);
    jump_index = [1,2,3];
    make_subplot = 1;
else
    c = zeros(6,3);
    res = zeros(num_samples,3);
    make_subplot = 0;
end

nlf = nonlinfit;
if d.control.enable.get()
    nlf.setFitFunc(@(y0,A,tau,f,phi,x0,x) y0 + A.*exp(-(x - x0)/tau).*sin(2*pi*f*(x - x0) + phi).*(x > x0));
else
    nlf.setFitFunc(@(y0,A,tau,x0,x) y0 + A*(1 - exp(-(x - x0)/tau)).*(x > x0));
end

figure(12852);clf;
for mm = 1:size(c,3)
    d.getVoltageStepResponse(num_samples,jump_index(mm),jump_amount);
    orders = circshift([1,2,3],-mm + 1);
    for nn = orders
        if nn == mm
            tau_bounds = [0,5,0.01];
        else
            tau_bounds = nlf.get('tau',1)*[0.99,1.01,1];
        end
        nlf.set(d.t,d.data(:,nn),std(d.data(1:floor(0.05*num_samples),nn)));
        nlf.bounds([],[],[]);
        nlf.bounds2('y0',[-1e5,1e5,mean(nlf.y(1:10))],'A',[-1e5,1e5,nlf.y(end) - nlf.y(1)],...
                'tau',tau_bounds,'x0',0.25*max(d.t)*[0.8,1.2,1]);
        if d.control.enable.get()
            nlf.bounds2('f',[0,200,10],'phi',[-pi,pi,0],'A',[-1e5,1e5,range(nlf.y)]);
        end
        nlf.fit;
        c(1:size(nlf.c,1),nn,mm) = nlf.c(:,1);
        res(:,nn,mm) = nlf.res.*nlf.dy;
        if make_subplot
            subplot(3,3,mm + (nn - 1)*3);
        end
        plot(nlf.x,nlf.y);
        hold on
        plot(nlf.x,nlf.f(nlf.x),'--','linewidth',2);
        if make_subplot
            plot_format('Time [s]',sprintf('Signal %d',nn),sprintf('Signal %d vs DC%d jump',nn,jump_index(mm)),10);
        end
    end
    if ~make_subplot
        plot_format('Time [s]','Signal',sprintf('Signals vs DC%d jump',jump_index(mm)),10);
    end
end
tc = reshape(c(3,:,:),3,[]);
G = reshape(c(2,:,:),3,[])./jump_amount;
c = c(1:size(nlf.c,1),:,:);