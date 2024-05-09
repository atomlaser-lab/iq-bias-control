%
% Monitors applied DC biases, measurements of auxiliary demodulated
% signals, and spectrum analyzer sideband powers over time.
%
% Starts with the lock enabled and then disables it half-way through
%
check_app;
d.fetch;
d.fifo_route.set([0,0,0,0]);
d.control.enable.set(1);
d.control.hold.set(0);
d.upload;

time_step = 20;
hours_to_record = 8;
total_time = round(3600*hours_to_record);
num_samples = ceil(total_time/time_step);
tmr = timer('name','signal-recorder','period',time_step,'TasksToExecute',num_samples,'ExecutionMode','fixedDelay');
tmr.UserData.date = [];
tmr.UserData.t = [];
tmr.UserData.bias_voltages = [];
tmr.UserData.rp_signals = [];
tmr.UserData.sideband_power = [];
tmr.UserData.f = {};
tmr.UserData.P = {};
tmr.UserData.d = d;
tmr.UserData.sa = sa;
tmr.UserData.rp_modulation_frequency = 4e6;
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
d.fifo_route.set([0,0,0,0]).write;
obj.UserData.d.getDemodulatedData(1e3);
obj.UserData.rp_signals(obj.UserData.sample,:) = mean(obj.UserData.d.data(:,1:3),1);
d.fifo_route.set([1,1,1,1]).write;
obj.UserData.d.getDemodulatedData(1e3);
obj.UserData.bias_voltages(obj.UserData.sample,:) = mean(obj.UserData.d.data(:,1:3),1)*DeviceControl.CONV_PWM;

if isfield(obj.UserData,'sa')
    [obj.UserData.sideband_power(obj.UserData.sample,:),f,P] = get_sideband_power(obj.UserData.sa,...
        obj.UserData.modulation_frequency,obj.UserData.aom_frequency,obj.UserData.rp_modulation_frequency,obj.UserData.rbw);
    obj.UserData.f{obj.UserData.sample} = f;
    obj.UserData.P{obj.UserData.sample} = P;
end

if numel(obj.UserData.date) > 1
    num_panels = 2 + isfield(obj.UserData,'sa')*1;
    figure(1442);clf;
    subplot(1,num_panels,1);
    plot(obj.UserData.date,obj.UserData.bias_voltages,'.-');
    plot_format('','Bias voltage [V]','',10);
    legend({'DC1','DC2','DC3'},'location','west');
    subplot(1,num_panels,2);
    plot(obj.UserData.date,obj.UserData.rp_signals,'.-');
    legend({'1f I','1f Q','2f I'},'location','west');
    plot_format('','RP Signals [arb units]','',10);
    if isfield(obj.UserData,'sa')
        subplot(1,num_panels,3);
        plot(obj.UserData.date,obj.UserData.sideband_power,'.-');
        plot_format('','Sideband power [dBm]','',10);
        legend({'-1','0','+1'},'location','west');
    end
end

if obj.UserData.d.control.hold.value == 0 && obj.TasksExecuted > 0.5*obj.TasksToExecute
    obj.UserData.d.control.hold.set(1).write;
end

if mod(obj.UserData.sample,100) == 0
    data = obj.UserData;
    data.sa = [];data.d = [];
    save('tmp-data','data');
end

end

function timer_stop_fcn(obj,~)
data = obj.UserData;
data.sa = [];data.d = [];
t = datetime('now','format','y-M-d-HH-mm-ss');
save(['signal-series-',char(t)],'data');
obj.UserData.d.fifo_route.set([0,0,0,0]).write;
fprintf('Data acquisition completed\n');
end

function check_app
    app = DeviceControl.get_running_app_instance();
    app.set_timer('off');
end
