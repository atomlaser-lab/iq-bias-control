%
% Simulate IQ modulator
%
clear;
ph = 0:15:360;

[A,B,P] = meshgrid(ph,ph,ph);

[D,S] = deal(zeros([numel(ph)*[1,1,1],3]));
mode = '';

for row = 1:numel(ph)
    for col = 1:numel(ph)
        for page = 1:numel(ph)
            [D(row,col,page,:),S(row,col,page,:)] = phase_detection_simulation('phA',ph(row),'phB',ph(col),'phP',ph(page),'mode',mode);
        end
    end
end


%%
figure(1);clf;
% idx = 13;
idx = 1:numel(ph);
for page = idx
    for nn = 1:size(D,4)
        subplot(1,3,nn);
        surf(ph,ph,squeeze(D(page,:,:,nn)));
        shading flat;
        xlabel('A');ylabel('B');
    end
    pause(1000e-3);
end

