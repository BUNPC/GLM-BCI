clear all;

malexflag = 0; % user flag
if malexflag
    %Meryem
    path.code = 'C:\Users\mayucel\Documents\PROJECTS\CODES\GLM-BCI'; addpath(genpath(path.code)); % code directory
    path.dir = 'C:\Users\mayucel\Google Drive\GLM_BCI_PAPER\RESTING_DATA'; % data directory
    path.save = 'C:\Users\mayucel\Google Drive\GLM_BCI_PAPER\PROCESSED_DATA'; % save directory
    
    %Meryem Laptop
    %     path.code = 'C:\Users\m\Documents\GitHub\GLM-BCI'; addpath(genpath(path.code)); % code directory
    %     path.dir = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    %     path.save = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % save directory
else
    %Alex
    path.code = 'D:\Office\Research\Software - Scripts\Matlab\GLM-BCI'; addpath(genpath(path.code)); % code directory
    path.dir = 'C:\Users\avolu\Google Drive\GLM_BCI_PAPER\RESTING_DATA'; % data directory
    path.save = 'C:\Users\avolu\Google Drive\GLM_BCI_PAPER\PROCESSED_DATA'; % save directory
end

%% load data
load([path.save '\FV_results_SSvsNo_ldrift1_resid0_tccaIndiv_hrf_amp100_20soffs.mat'])

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

%% get weight features from GLM method
FW = FWss;
% for all subjects
gg=1;
for sbj=1:numel(TTM)
    % for all trials
    for tt = 1:numel(TTM{sbj}.tstidx)
        xTrF{gg,sbj,tt} =[];
        xTstF{gg,sbj,tt}=[];
        yTrF{gg,sbj,tt}=zeros(numel(epo.className),2*numel(TTM{sbj}.tnridx(tt,:)));
        yTstF{gg,sbj,tt}=zeros(numel(epo.className),2*numel(TTM{sbj}.tstidx(tt)));
        for cc=1:2
            % train data  (from GLM with trained HRF regressor on seen training data)
            % append features for hbo and hbr and all channels without SS
            fvbuf = [];
            fvbuf = squeeze(FW{sbj,tt}(:,:,lstLongAct{sbj},TTM{sbj}.tnridx(tt,:),cc,rr));
            xTrF{gg,sbj,tt} = [xTrF{gg,sbj,tt} reshape(fvbuf, size(fvbuf,1)*size(fvbuf,2),numel(TTM{sbj}.tnridx(tt,:)))];
            % generate label vector
            yTrF{gg,sbj,tt}(cc,(cc-1)*numel(TTM{sbj}.tnridx(tt,:))+1:cc*numel(TTM{sbj}.tnridx(tt,:)))=1;
            % test data (from GLM with trained HRF regressor on unseen data)
            % append features for hbo and hbr and all channels without SS
            fvbuf = [];
            fvbuf = squeeze(FW{sbj,tt}(:,:,lstLongAct{sbj},TTM{sbj}.tstidx(tt),cc,rr));
            xTstF{gg,sbj,tt} = [xTstF{gg,sbj,tt} reshape(fvbuf, size(fvbuf,1)*size(fvbuf,2),numel(TTM{sbj}.tstidx(tt)))];
            % generate label vector
            yTstF{gg,sbj,tt}(cc,(cc-1)*numel(TTM{sbj}.tstidx(tt))+1:cc*numel(TTM{sbj}.tstidx(tt)))=1;
        end
        %feature vector dimensionality
        nfeat(gg,sbj,tt) = size(xTrF{gg,sbj,tt},1);
    end
end
glab = {'W | GLM'};

%% for conventional features
% select features
flab = {'min ', 'max ', 'p2p ', 'avg ', 't2p ', 'slope ', 'slope w2 '};
mlab = {'no GLM', 'GLM'};
fsel = {[], [1], [1], [2], [2], [3], [3], [4], [4], [5], [5], [6], [6],...
    [3,4], [3,4], [3,5], [3,5], [3,6], [3,6], [4,5], [4,5], [4,6], [4,6], ...
    [5,6],[5,6]};

FW = {FMdc', FMss};
% for all features
for gg = 2:numel(fsel)
    % for all subjects
    for sbj=1:numel(TTM)
        % for all trials
        for tt = 1:numel(TTM{sbj}.tstidx)
            if mod(gg,2)+1 == 1
                cvidx = 1;
            else
                cvidx = tt;
            end
            
            xTrF{gg,sbj,tt} =[];
            xTstF{gg,sbj,tt}=[];
            yTrF{gg,sbj,tt}=zeros(numel(epo.className),2*numel(TTM{sbj}.tnridx(tt,:)));
            yTstF{gg,sbj,tt}=zeros(numel(epo.className),2*numel(TTM{sbj}.tstidx(tt)));
            for cc=1:2
                % train data  (from GLM with trained HRF regressor on seen training data)
                % append features for hbo and hbr and all channels without SS
                fvbuf = [];
                fvbuf = FW{mod(gg,2)+1}{sbj,cvidx}(fsel{gg},1:2,lstLongAct{sbj},TTM{sbj}.tnridx(tt,:),cc);
                xTrF{gg,sbj,tt} = [xTrF{gg,sbj,tt} reshape(fvbuf, size(fvbuf,1)*size(fvbuf,2)*size(fvbuf,3),numel(TTM{sbj}.tnridx(tt,:)))];
                % generate label vector
                yTrF{gg,sbj,tt}(cc,(cc-1)*numel(TTM{sbj}.tnridx(tt,:))+1:cc*numel(TTM{sbj}.tnridx(tt,:)))=1;
                % test data (from GLM with trained HRF regressor on unseen data)
                % append features for hbo and hbr and all channels without SS
                fvbuf = [];
                fvbuf = squeeze(FW{mod(gg,2)+1}{sbj,cvidx}(fsel{gg},1:2,lstLongAct{sbj},TTM{sbj}.tstidx(tt),cc,rr));
                xTstF{gg,sbj,tt} = [xTstF{gg,sbj,tt} reshape(fvbuf, size(fvbuf,1)*size(fvbuf,2)*size(fvbuf,3),numel(TTM{sbj}.tstidx(tt)))];
                % generate label vector
                yTstF{gg,sbj,tt}(cc,(cc-1)*numel(TTM{sbj}.tstidx(tt))+1:cc*numel(TTM{sbj}.tstidx(tt)))=1;
                % feature vector dimensionality
                nfeat(gg,sbj,tt) = size(xTrF{gg,sbj,tt},1);
            end
        end
        glab{gg}= [join([join(flab(fsel{gg})) mlab{mod(gg,2)+1}])];
    end
end




%% CROSSVALIDATION using rLDA as classifier and all features 
% for all methods/feature types (1> NO GLM, 2> GLM SS, 3> GLM CCA)
for gg = 1:size(xTrF,1)
    disp(['CV for all subjects and feature set ' num2str(gg) '...'])
    % for all subjects
    for sbj=1:numel(TTM)
        % for all splits
        for tt=1:numel(TTM{sbj}.tstidx)
            
            %% training of rLDA
            C = train_RLDAshrink(xTrF{gg,sbj,tt}, yTrF{gg,sbj,tt});
            
            %% testing of rLDA
            fv.x = xTstF{gg,sbj,tt};
            fv.y = yTstF{gg,sbj,tt};
            out = applyClassifier(fv, C);
            % loss function
            lossF{gg,sbj}(tt,:,:)=loss_classwiseNormalized(fv.y, out, size(fv.y));
        end
        lossAvgF(gg,sbj) = mean(lossF{gg,sbj}(:));
    end
end
accuracyGLMF = 1-lossAvgF;
meanaccsF = mean(accuracyGLMF,2);

% Plot Classification results
glmacc = round(accuracyGLMF(1:2:end,:)*1000)/10;
noglmacc(1,1:numel(TTM)) = 0;
noglmacc = round([noglmacc; accuracyGLMF(2:2:end,:)]*1000)/10;
% xticklabels (class accuracies)
xtckglm =  round(meanaccsF(1:2:end,:)*1000)/10;
xtcknoglm(1) = 0;
xtcknoglm = round([xtcknoglm; meanaccsF(2:2:end)]*1000)/10;
% used feature labels
fidx = fsel(1:2:end);
for i=1:numel(fidx)
    uflab{i} = string(join(flab(fidx{i})))
end
uflab{1} = '\beta GLM ';

figure
subplot(2,1,1)
hold on
plot([.5 13.5], [50 50], '--k')
bar(glmacc)
ylabel('sbj avg accuracy / %')
xlim([0.5 13.5])
xticks(1:13)
xticklabels(xtckglm)
% create upper x axis for feature type labels
ax1 = gca;
ax2 = axes('Position',ax1.Position,...
    'XAxisLocation','top',...
    'YAxisLocation','right',...
    'Color','none');
xlim([0.5, 13.5])
xticks(1:13)
yticks([])
xticklabels(uflab)
subplot(2,1,2)
hold on
plot([.5 13.5], [50 50], '--k')
xlim([0.5, 13.5])
xticks(1:13)
bar(noglmacc)
ylabel('sbj avg accuracy / %')
xticks(1:13)
xticklabels(xtcknoglm)




% %% CROSSVALIDATION using rLDA as classifier and weight features
% % for GLM methods ( 2> GLM SS, 3> GLM CCA)
% 
% for gg = 2:3
%     % for all subjects
%     for sbj=1:numel(TTM)
%         % for all splits
%         for tt=1:numel(TTM{sbj}.tstidx)
%             
%             %% training of rLDA
%             C = train_RLDAshrink(xTrW{gg,sbj,tt}, yTrW{gg,sbj,tt});
%             
%             %% testing of rLDA
%             fv.x = xTstW{gg,sbj,tt};
%             fv.y = yTstW{gg,sbj,tt};
%             out = applyClassifier(fv, C);
%             % loss function
%             lossW{gg,sbj}(tt,:,:)=loss_classwiseNormalized(fv.y, out, size(fv.y));
%         end
%         lossAvgW(gg,sbj) = mean(lossW{gg,sbj}(:));
%     end
% end
% accuracyGLMW = 1-lossAvgW;
% accuracyGLMW(1,:)=0;
% meanaccsW = mean(accuracyGLMW,2);
% 
% 
% figure
% bar(accuracyGLMW)
% hold on
% plot([.5 3.5], [0.5 0.5], '--k')
% set(gca,'xtickLabel',{...
%     '', ...
%     ['GLM SS (' num2str(100*meanaccsW(2),'%2.1f') '%)'], ...
%     ['GLM tCCA (' num2str(100*meanaccsW(3),'%2.1f') '%)']})
% ylabel('mean accuracy / subject')
% title('Weight Features')