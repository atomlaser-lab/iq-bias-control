function [tc,G,c,res] = get_open_loop_responses(d,num_samples,jump_amount,jump_index)

if nargin < 4
    c = zeros(4,3,3);
    res = zeros(num_samples,3,3);
    jump_index = [1,2,3];
    make_subplot = 1;
else
    c = zeros(4,3);
    res = zeros(num_samples,3);
    make_subplot = 0;
end

nlf = nonlinfit;
nlf.setFitFunc(@(y0,A,tau,x0,x) y0 + A*(1 - exp(-(x - x0)/tau)).*(x > x0));

figure(12852);clf;
for mm = 1:size(c,3)
    d.getOpenLoopResponse(num_samples,jump_index(mm),jump_amount);
    for nn = 1:3
        nlf.set(d.t,d.data(:,nn),std(d.data(1:floor(0.05*num_samples),nn)));
        nlf.bounds2('y0',[-1e5,1e5,mean(nlf.y(1:10))],'A',[-1e5,1e5,range(nlf.y)],...
            'tau',[0,5,0.1],'x0',0.25*max(d.t)*[0.8,1.2,1]);
        nlf.fit;
        c(:,nn,mm) = nlf.c(:,1);
        res(:,nn,mm) = nlf.res.*nlf.dy;
        if make_subplot
            subplot(3,3,nn + (mm - 1)*3);
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
tc = reshape(c(3,:,:),3,[])';
G = reshape(c(2,:,:),3,[])'./jump_amount;