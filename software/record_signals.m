%
% Monitors applied DC biases, measurements of auxiliary demodulated
% signals, and spectrum analyzer sideband powers over time
%
d.fetch;
d.fifo_route.set([0,0,0,0]);
d.upload;

time_step = 60;
total_time = 3600*4;
num_samples = ceil(total_time/time_step);
tmr = timer('name','signal-recorder','period',time_step,'TasksToExecute',num_samples,'ExecutionMode','fixedDelay');
tmr.UserData.date = [];
tmr.UserData.t = [];
tmr.UserData.bias_voltages = [];
tmr.UserData.rp_signals = [];
tmr.UserData.sideband_power = [];
tmr.UserData.d = d;
tmr.UserData.sa = sa;
tmr.UserData.modulation_frequency = 3.4e9;
tmr.UserData.aom_frequency = 80e6;
tmr.UserData.rbw = 100e3;
tmr.UserData.sample = 0;
tmr.TimerFcn = @timer_fcn;
tmr.StopFcn = @timer_stop_fcn;
start(tmr);

function timer_fcn(obj,~)
obj.UserData.sample = obj.UserData.sample + 1;
if obj.UserData.sample == 1
    obj.UserData.date = datetime;
else
    obj.UserData.date(obj.UserData.sample) = datetime;
end
d = obj.UserData.d;
d.fifo_route.set([0,0,0,0]);
obj.UserData.d.getDemodulatedData(1e3);
obj.UserData.rp_signals(obj.UserData.sample,:) = mean(obj.UserData.d.data(:,1:3),1);
d.fifo_route.set([1,1,1,1]);
obj.UserData.d.getDemodulatedData(1e3);
obj.UserData.bias_voltages(obj.UserData.sample,:) = mean(obj.UserData.d.data(:,1:3),1)*DeviceControl.CONV_PWM;

obj.UserData.sideband_power(obj.UserData.sample,:) = get_sideband_power(obj.UserData.sa,...
    obj.UserData.modulation_frequency,obj.UserData.aom_frequency,obj.UserData.rbw);

if numel(obj.UserData.date) > 1
    figure(1442);clf;
    subplot(1,3,1);
    plot(obj.UserData.date,obj.UserData.bias_voltages,'.-');
    plot_format('','Bias voltage [V]','',10);
    legend({'DC1','DC2','DC3'});
    subplot(1,3,2);
    plot(obj.UserData.date,obj.UserData.rp_signals,'.-');
    legend({'1f I','1f Q','2f I'});
    plot_format('','RP Signals [arb units]','',10);
    subplot(1,3,3);
    plot(obj.UserData.date,obj.UserData.sideband_power,'.-');
    plot_format('','Sideband power [dBm]','',10);
    legend({'-1','0','+1'});
end

end

function timer_stop_fcn(obj,~)
data = obj.UserData;
data.sa = [];data.d = [];
save(['signal-series-',date],'data');
obj.UserData.d.fifo_route.set([0,0,0,0]).write;
end



