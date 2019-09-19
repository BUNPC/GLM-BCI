clear all;

malexflag = 1; % user flag
if malexflag
    %Meryem
    path.code = 'C:\Users\mayucel\Documents\PROJECTS\CODES\GLM-BCI'; addpath(genpath(path.code)); % code directory
    path.dir = 'C:\Users\mayucel\Google Drive\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    path.save = path.code; % save directory
    
    %Meryem Laptop
    %     path.code = 'C:\Users\m\Documents\GitHub\GLM-BCI'; addpath(genpath(path.code)); % code directory
    %     path.dir = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    %     path.save = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % save directory
else
    %Alex
    path.code = 'D:\Office\Research\Software - Scripts\Matlab\GLM-BCI'; addpath(genpath(path.code)); % code directory
    path.dir = 'C:\Users\avolu\Google Drive\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    path.save = path.code; % save directory
end

load([path.save '\FV_results.mat'])

% load and init BBCI toolbox
% bbci toolbox paths
if malexflag
    %Meryem
    paths.bbciDir = 'C:\Users\mayucel\Documents\PROJECTS\CODES\bbci_public-master';
    paths.bbciDataDir = 'C:\Users\mayucel\Documents\PROJECTS\CODES\bbci_public-master\bbci_data';
    paths.bbciTmpDir = 'C:\Users\mayucel\Documents\PROJECTS\CODES\bbci_public-master\bbci_data\tmp';
    addpath(genpath(paths.bbciDir))
    cd(paths.bbciDir);
    startup_bbci_toolbox('DataDir', paths.bbciDataDir, 'TmpDir',paths.bbciTmpDir);
else
    % Alex
    paths.bbciDir = 'D:\Office\Archive Office\Toolboxes - Code Libraries\Matlab\BBCI\';
    paths.bbciDataDir = 'D:\Datasets\bbci_data';
    paths.bbciTmpDir = 'D:\Datasets\bbci_data\tmp\';
    addpath(genpath(paths.bbciDir))
    cd(paths.bbciDir);
    startup_bbci_toolbox('DataDir', paths.bbciDataDir, 'TmpDir',paths.bbciTmpDir);
end

% use hrf STIM regressor weights as features (not the REST regressor
% weights, as they are useless here)
% and transform to bbci data structure
rr = 1;
epo.className = {'STIM', 'REST'};
epo.clab = FMclab;

% for both GLM methods
FW = {FWss, FWcca};
for gg = 1:2
    % for all subjects
    for sbj=1:numel(TTM)
        % for all trials
        for tt = 1:numel(TTM{sbj}.tstidx)
            xTr{gg,sbj,tt} =[];
            xTst{gg,sbj,tt}=[];
            yTr{gg,sbj,tt}=zeros(numel(epo.className),2*numel(TTM{sbj}.tnridx(tt,:)));
            yTst{gg,sbj,tt}=zeros(numel(epo.className),2*numel(TTM{sbj}.tstidx(tt)));
            for cc=1:2
                % train data  (from GLM with trained HRF regressor on seen training data)
                % append features for hbo and hbr and all channels without SS
                fvbuf = [];
                fvbuf = squeeze(FW{gg}{sbj,tt}(:,:,lstLongAct{sbj},TTM{sbj}.tnridx(tt,:),cc,rr));
                xTr{gg,sbj,tt} = [xTr{gg,sbj,tt} reshape(fvbuf, size(fvbuf,1)*size(fvbuf,2),numel(TTM{sbj}.tnridx(tt,:)))];
                % generate label vector
                yTr{gg,sbj,tt}(cc,(cc-1)*numel(TTM{sbj}.tnridx(tt,:))+1:cc*numel(TTM{sbj}.tnridx(tt,:)))=1;
                % test data (from GLM with trained HRF regressor on unseen data)
                % append features for hbo and hbr and all channels without SS
                fvbuf = [];
                fvbuf = squeeze(FW{gg}{sbj,tt}(:,:,lstLongAct{sbj},TTM{sbj}.tstidx(tt),cc,rr));
                xTst{gg,sbj,tt} = [xTst{gg,sbj,tt} reshape(fvbuf, size(fvbuf,1)*size(fvbuf,2),numel(TTM{sbj}.tstidx(tt)))];
                % generate label vector
                yTst{gg,sbj,tt}(cc,(cc-1)*numel(TTM{sbj}.tstidx(tt))+1:cc*numel(TTM{sbj}.tstidx(tt)))=1;
            end
        end
    end
end


%% CROSSVALIDATION using rLDA as classifier
% for both GLM methods
for gg = 1:2
    % for all subjects
    for sbj=1:numel(TTM)
        % for all splits
        for tt=1:numel(TTM{sbj}.tstidx)
            
            %% training of rLDA
            C = train_RLDAshrink(xTr{gg,sbj,tt}, yTr{gg,sbj,tt});
            
            %% testing of rLDA
            fv.x = xTst{gg,sbj,tt};
            fv.y = yTst{gg,sbj,tt};
            out = applyClassifier(fv, C);
            % loss function
            loss{gg,sbj}(tt,:,:)=loss_classwiseNormalized(fv.y, out, size(fv.y));
        end
        lossAvg(gg,sbj) = mean(loss{gg,sbj}(:));
    end
end
accuracy = 1-lossAvg;

figure
bar(accuracy)
set(gca,'xtickLabel',{'GLM SS', 'GLM tCCA'})
ylabel('mean accuracy / subject')
