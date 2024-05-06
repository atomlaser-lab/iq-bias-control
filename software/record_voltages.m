%
% Monitors the DC biases over a long time to see how they change.
% This will run either to a maximum number of samples or until the user
% interrupts
%
d.fetch;
d.fifo_route.set([1,1,1,1]);
d.upload;

time_step = 15;
total_time = 3600*6;
num_samples = ceil(total_time/time_step);
tmr = timer('name','voltage-recorder','period',time_step,'TasksToExecute',num_samples,'ExecutionMode','fixedDelay');
tmr.UserData.date = [];
tmr.UserData.t = [];
tmr.UserData.v = [];
tmr.UserData.d = d;
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
obj.UserData.d.getDemodulatedData(1e3);
obj.UserData.v(obj.UserData.sample,:) = mean(obj.UserData.d.data(:,1:3),1)*DeviceControl.CONV_PWM;

if numel(obj.UserData.date) > 1
    figure(1442);clf;
    plot(obj.UserData.date,obj.UserData.v - obj.UserData.v(1,:),'.-');
%     ylim([0,1]);
    plot_format('','Voltage [V]','',10);
end

end

function timer_stop_fcn(obj,~)
v = obj.UserData.v;
t = obj.UserData.date;
save(['voltage-series-',date],'v','t');
obj.UserData.d.fifo_route.set([0,0,0,0]).write;
end



