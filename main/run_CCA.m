clear all;

malexflag = 1; % user flag
if malexflag
    %Meryem
%     path.code = 'C:\Users\mayucel\Documents\PROJECTS\CODES\GLM-BCI'; addpath(genpath(path.code)); % code directory
%     path.dir = 'C:\Users\mayucel\Google Drive\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
%     path.save = 'C:\Users\mayucel\Google Drive\tCCA_GLM_PAPER'; % save directory
    
    %Meryem Laptop
    path.code = 'C:\Users\m\Documents\GitHub\GLM-BCI'; addpath(genpath(path.code)); % code directory
    path.dir = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    path.save = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % save directory
else
    %Alex
    path.code = 'D:\Office\Research\Software - Scripts\Matlab\GLM-BCI'; addpath(genpath(path.code)); % code directory
    path.dir = 'C:\Users\avolu\Google Drive\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    path.save = 'C:\Users\avolu\Google Drive\tCCA_GLM_PAPER'; % save directory
end

% #####
%% simulated data file names
filename = 'resting_sim';
%% load ground truth hrf
hrf = load([path.code '\sim HRF\hrf_simdat_100.mat']);
%% save folder name
sfoldername = '\CV_results_data';
% flag for mse/corr for each trial (1 = get sum of mse for each trial, 0 = get mse for average estimated hrf)
flag_trial = 0;

set(groot,'defaultFigureCreateFcn',@(fig,~)addToolbarExplorationButtons(fig))
set(groot,'defaultAxesCreateFcn',@(ax,~)set(ax.Toolbar,'Visible','off'))
sbjfolder = {'Subj33','Subj34','Subj36','Subj37','Subj38','Subj39', 'Subj40', 'Subj41', 'Subj43', 'Subj44','Subj46','Subj47','Subj49','Subj51'};


%% Options/Parameter Settings
rhoSD_ssThresh = 15;  % mm
flag_save = 0;
flag_conc = 1; % if 1 CCA inputs are in conc, if 0 CCA inputs are in intensity
% results eval parameters
eval_param.HRFmin = -2;
eval_param.HRFmax = 17; % used only for block design runs
eval_param.Hb = 1; % 1 HbO / 0 HbR (for block only)
eval_param.pre = 5;  % HRF range in sec to calculate ttest
eval_param.post = 10;
flag_detrend = 1; % linear detrend if 1, no trend if 0 during "pre-processing" (drift correction in GLM is set to 0 for now)
drift_term = 1; % linear detrend for GLM_SS and GLM_CCA (not for getting hrf estimate)
% CCA parameters
flags.pcaf =  [0 0]; % no pca of X or AUX
flags.shrink = true;
% perform regularized (rtcca) (alternatively old approach)
rtccaflag = true;

% Features/structs for feature extraction function
fparam.swdw=[0,4;10,17]; % need to discuss this selection!
ival = [eval_param.HRFmin eval_param.HRFmax];

% get features from ground truth
hrfdat.x = hrf.hrf_conc;
hrfdat.fs=25;
hrfdat.t=hrf.t_hrf';
[FVgt] = featureExtract(hrfdat, fparam);

%motion artifact detection
motionflag = true;
%plot flag
flag_plot = true;


% Validation parameters
% tlags = 0:1:10;
% stpsize = 2:2:24;
% cthresh = 0:0.1:0.9;

tlags = 3;
stpsize = 2;
cthresh = 0.3;

tlidx =0;
stpidx =0;
ctidx =0;

tic;

%% Eval plot flag (developing/debugging purposes only)
evalplotflag = 1;


for sbj = 1:numel(sbjfolder) % loop across subjects
    disp(['subject #' num2str(sbj)]);
    
    %% (re-)initialize result matrices
    nTrials= NaN(2,numel(tlags),numel(stpsize),numel(cthresh));
    DET_SS= NaN(34,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    DET_CCA= NaN(34,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    pval_SS = NaN(34,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    pval_CCA = NaN(34,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    MSE_SS = NaN(16,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    MSE_CCA = NaN(16,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    CORR_SS = NaN(16,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    CORR_CCA = NaN(16,2,2,numel(tlags),numel(stpsize),numel(cthresh));
    
    % change to subject directory
    cd([path.dir filesep sbjfolder{sbj} filesep]);
    
    %% load data
    [fq, t, AUX, d_long, d_short, d0_long, d0_short, d, d0, SD, s, lstLongAct{sbj},lstShortAct{sbj},lstHrfAdd{sbj}] = load_nirs(filename,flag_conc,flag_detrend);
    
    %% lowpass filter AUX signals
    AUX = hmrBandpassFilt(AUX, fq, 0, 0.5);
    %% AUX signals
    AUX = [AUX, d0_short]; % full AUX = [acc1 acc2 acc3 PPG BP RESP, d_short];
    %% zscore AUX signals
    AUX = zscore(AUX);
    
    
    %% check if the number of time points is odd/even, if odd make it even... (number of embedded should be the same)
    if mod(size(AUX,1),2) == 1
        AUX(end,:)=[];
        d(end,:)=[];
        d_long(end,:)=[];
        d_short(end,:)=[];
        d0(end,:)=[];
        d0_long(end,:)=[];
        d0_short(end,:)=[];
        t(end,:)=[];
        s(end,:)=[];
    end
    
    % create data split indices
    len = size(AUX,1);
    spltIDX = {1:floor(len/5),floor(len/5)+1:len};
    trntst = {[2,1], [1,2]};
    
    %% run test and train CV splits
    for tt = 1%1:2
        tstIDX = spltIDX{trntst{tt}(1)};
        trnIDX = spltIDX{trntst{tt}(2)};
        
        %% convert testing fNIRS data to concentration and detect motion artifacts
        dod = hmrIntensity2OD(d(tstIDX,:));
        s = s(tstIDX,:);
        
        if motionflag
            [tIncAuto] = hmrMotionArtifact(dod,fq,SD,ones(size(d,1),1),0.5,1,30,5);
            [s,tRangeStimReject] = enStimRejection(t(tstIDX,:),s,tIncAuto,ones(size(d,1),1),[-2  10]);
        end
        
        dod = hmrBandpassFilt(dod, fq, 0, 0.5);
        dc{tt} = hmrOD2Conc( dod, SD, [6 6]);
        
        %% run test and train CV splits
        onset_stim = find(s==1);
        if onset_stim(1) < abs(eval_param.HRFmin*fq)
            onset_stim(1) = [];
        end
        
        
        for os = 1:size(onset_stim,1)%% loop around each stimulus
            
            pre_stim = onset_stim(os)+eval_param.HRFmin*fq;
            post_stim = onset_stim(os)+eval_param.HRFmax*fq;
            
            % training
            dod_stitched = [dod(1:pre_stim,:);(dod(post_stim:end,:)-(dod(post_stim,:)-dod(pre_stim,:)))];
            dc_stitched = hmrOD2Conc(dod_stitched, SD, [6 6]);
            s_stitched = s([1:pre_stim,post_stim:size(dod,1)],:);
            t_stitched = t(1:size(s_stitched,1));
            
            % estimate HRF from training data
            [yavg_ss_estimate, yavgstd_ss, tHRF, nTrialsSS, d_ss, yresid_ss, ysum2_ss, beta_ss, yR_ss] = ...
                hmrDeconvHRF_DriftSS(dc_stitched, s_stitched, t_stitched, SD, [], [], [eval_param.HRFmin eval_param.HRFmax], 1, 1, [0.5 0.5], rhoSD_ssThresh, 1, 0, 0,hrf);
            
            %% Save normal raw data (single trials)
            y_raw(:,:,:,os)= dc{tt}(pre_stim:post_stim,:,:);
            
            
            %% Perform GLM with SS
            [yavg_ss(:,:,:,os), yavgstd_ss, tHRF, nTrialsSS, d_ss, yresid_ss, ysum2_ss, beta_ss, yR_ss] = ...
                hmrDeconvHRF_DriftSS(dc{tt}(pre_stim:post_stim,:,:), s(pre_stim:post_stim,:), t(pre_stim:post_stim,:), SD, [], [], [eval_param.HRFmin eval_param.HRFmax], 1, 5, yavg_ss_estimate, rhoSD_ssThresh, 1, drift_term, 0, hrf);
            
            %% CCA with optimum parameters
            tl = tlags;
            sts = stpsize;
            ctr = cthresh;
            
            %% set stepsize for CCA
            param.tau = sts; %stepwidth for embedding in samples (tune to sample frequency!)
            param.NumOfEmb = ceil(tl*fq / sts);
            
            %% Temporal embedding of auxiliary data from testing split
            %                 aux_sigs = AUX(tstIDX,:);
            aux_sigs = AUX(pre_stim:post_stim,:);
            aux_emb = aux_sigs;
            for i=1:param.NumOfEmb
                aux=circshift( aux_sigs, i*param.tau, 1);
                aux(1:2*i,:)=repmat(aux(2*i+1,:),2*i,1);
                aux_emb=[aux_emb aux];
            end
            
            % zscore
            aux_emb=zscore(aux_emb);
            % set correlation trheshold for CCA to 0 so we dont lose anything here
            param.ct = 0;   % correlation threshold
            % Perform CCA on training data % AUX = [acc1 acc2 acc3 PPG BP RESP, d_short];
            % use test data of LD channels without synth HRF
            X = d0_long(trnIDX,:);
            % new tCCA with shrinkage
            [REG_trn{tt},  ADD_trn{tt}] = rtcca(X,AUX(trnIDX,:),param,flags);
            
            disp(['split: ' num2str(tt) ', tlag: ' num2str(tl) ', stsize: ' num2str(sts) ', ctrhesh: ' num2str(ctr)])
            
            %% now use correlation threshold for CCA outside of function to avoid redundant CCA recalculation
            % overwrite: auxiliary cca components that have
            % correlation > ctr
            compindex=find(ADD_trn{tt}.ccac>ctr);
            %overwrite: reduced mapping matrix Av
            ADD_trn{tt}.Av_red = ADD_trn{tt}.Av(:,compindex);
            
            %% Calculate testig regressors with CCA mapping matrix A from testing
            REG_tst = aux_emb*ADD_trn{tt}.Av_red;
            
            %% Perform GLM with CCA
            [yavg_cca(:,:,:,os), yavgstd_cca, tHRF, nTrials(tt), d_cca, yresid_cca, ysum2_cca, beta_cca, yR_cca] = ...
                hmrDeconvHRF_DriftSS(dc{tt}(pre_stim:post_stim,:,:), s(pre_stim:post_stim,:), t(pre_stim:post_stim,:), SD, REG_tst, [], [eval_param.HRFmin eval_param.HRFmax], 1, 5, yavg_ss_estimate, 0, 0, drift_term, 0, hrf);
            
            if evalplotflag
                a=dc{tt}(pre_stim:post_stim,:,:)-repmat(mean(dc{tt}(pre_stim:onset_stim(os),:,:),1),numel(pre_stim:post_stim),1);
                figure;subplot(1,3,1);plot(tHRF,squeeze(a(:,1,lstHrfAdd{sbj}(:,1))));ylim([-1e-6 1.5e-6]);title('none'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);
                subplot(1,3,2);plot(tHRF,squeeze(yavg_ss(:,1,lstHrfAdd{sbj}(:,1)))); ylim([-1e-6 1.5e-6]);title('ss'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);
                subplot(1,3,3);plot(tHRF,squeeze(yavg_cca(:,1,lstHrfAdd{sbj}(:,1))));ylim([-1e-6 1.5e-6]);title('cca'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);
                
                figure;
                plot(squeeze(yavg_ss_estimate(:,1,lstHrfAdd{sbj}(:,1))));title('hrf estimate')
                
                ch = [lstHrfAdd{sbj}(:,1)];
                i = 2;
                figure;
                plot(tHRF,squeeze(a(:,1,lstShortAct{sbj})),'g');ylim([-1e-6 1.5e-6]);hold on;
                plot(tHRF,squeeze(yresid_ss(:,1,ch(i))),'y');
                plot(tHRF,squeeze(yavg_ss(:,1,ch(i))),'r');
                plot(tHRF,squeeze(a(:,1,ch(i))),'k');
                plot(hrf.t_hrf,hrf.hrf_conc(:,1),'--r');
                legend('SS','Residual','HRFestimate','Raw','Ground Truth')
            end
            % display current state:
            disp([', sbj ' num2str(sbj) ', epoch ' num2str(os) ])
            %             foo_all_none(:,:,:,os) = yavg_ss;
            %             foo_all_ss(:,:,:,os) = yavg_ss;
            %             foo_all_cca(:,:,:,os) = yavg_ss;
        end
        %% get features/markers
        % short separation
        [FMdc{sbj}, clab] = getFeaturesAndMetrics(y_raw, fparam, ival, hrf);
        % short separation
        [FMss{sbj}, clab] = getFeaturesAndMetrics(yavg_ss, fparam, ival, hrf);
        % tCCA
        [FMcca{sbj}, clab] = getFeaturesAndMetrics(yavg_cca, fparam, ival, hrf);
    end
    % clear vars
    clear vars AUX d d0 d_long d0_long d_short d0_short t s REG_trn ADD_trn
end

% %% save data
%     if flag_save
%         disp(['saving sbj ' num2str(sbj) '...'])
%         save([path.save sfoldername '\results_sbj' num2str(sbj) '.mat'], 'DET_SS', 'DET_CCA', 'pval_SS', 'pval_CCA', 'ROCLAB', 'MSE_SS', 'MSE_CCA', 'CORR_SS', 'CORR_CCA', 'nTrials');
%     end


%% Sort through results and append
F_Raw_Hrf=[];
F_Raw_NoHrf=[];
F_SS_Hrf=[];
F_SS_NoHrf=[];
F_CCA_Hrf=[];
F_CCA_NoHrf=[];
for sbj = 1:numel(sbjfolder)
    % channel indices that have or dont have gt HRF
    idxChHrf = lstHrfAdd{sbj}(:,1);
    idxChNoHrf = arrayfun(@(x) find(lstLongAct{sbj}==x,1),squeeze(lstHrfAdd{sbj}(:,1)));
    % number of available channels
    sHrf = size(FMdc{sbj}(:,:,idxChHrf,:));
    sNoHrf = size(FMdc{sbj}(:,:,idxChNoHrf,:));
    % extract and append data, new dimension is F x C x I,
    % where F: # of Features, C: # Number of Chromophores, I: # of all
    % trials (epochs*channels)
    F_Raw_Hrf = cat(3, F_Raw_Hrf, reshape(FMdc{sbj}(:,:,idxChHrf,:),numel(clab),3,sHrf(3)*sHrf(4)));
    F_Raw_NoHrf = cat(3, F_Raw_NoHrf, reshape(FMdc{sbj}(:,:,idxChNoHrf,:),numel(clab),3,sNoHrf(3)*sNoHrf(4)));
    F_SS_Hrf = cat(3, F_SS_Hrf, reshape(FMss{sbj}(:,:,idxChHrf,:),numel(clab),3,sHrf(3)*sHrf(4)));
    F_SS_NoHrf = cat(3, F_SS_NoHrf, reshape(FMss{sbj}(:,:,idxChNoHrf,:),numel(clab),3,sNoHrf(3)*sNoHrf(4)));
    F_CCA_Hrf = cat(3, F_CCA_Hrf, reshape(FMcca{sbj}(:,:,idxChHrf,:),numel(clab),3,sHrf(3)*sHrf(4)));
    F_CCA_NoHrf = cat(3, F_CCA_NoHrf, reshape(FMcca{sbj}(:,:,idxChNoHrf,:),numel(clab),3,sNoHrf(3)*sNoHrf(4)));
    
end

%% Paired T-Tests
for ff = 1:9
    for cc=1:3
        [h_co(ff,cc,1),p_co(ff,cc,1)]= ttest(squeeze(F_Raw_Hrf(ff,cc,:)),squeeze(F_SS_Hrf(ff,cc,:)));
        [h_co(ff,cc,2),p_co(ff,cc,2)]= ttest(squeeze(F_Raw_Hrf(ff,cc,:)),squeeze(F_CCA_Hrf(ff,cc,:)));
        [h_co(ff,cc,3),p_co(ff,cc,3)]= ttest(squeeze(F_SS_Hrf(ff,cc,:)),squeeze(F_CCA_Hrf(ff,cc,:)));
    end
end

%% (Box)Plot results
figure
labels = {'No GLM', 'GLM SS', 'GLM tCCA'};
chrom = {' HbO', ' HbR'};
% for all features
for ff=1:9
    % for both chromophores
    for cc=1:2
        subplot(2,9,(cc-1)*9+ff)
        xtickangle(35)
        hold on
        %% boxplots 
        % with cca
        boxplot([squeeze(F_Raw_Hrf(ff,cc,:)), squeeze(F_SS_Hrf(ff,cc,:)), squeeze(F_CCA_Hrf(ff,cc,:))], 'labels', labels)
        % without cca
        %boxplot([squeeze(F_Raw_Hrf(ff,cc,:)), squeeze(F_SS_Hrf(ff,cc,:))], 'labels', labels)
        H=sigstar({[1,2],[1,3],[2,3]},squeeze(p_co(ff,cc,1:3)));
        % ground truth
        if ff<8
            hAx=gca;                                   % retrieve the axes handle
            %xtk=hAx.XTick;                             % and the xtick values to plot() at...
            xtk = [0.5, 1, 2, 3, 3.5];
            hold on
            if ff==5
                FVgt.x(ff,cc) = 6; % set time to peak to 6 seconds (due to gt hrf plateau)
            end
            hL=plot(xtk, ones(numel(xtk))*FVgt.x(ff,cc),'--g');
        end
        if ff<5
           ylabel('\muMol') 
        end
        if ff==5
           ylabel('sec') 
        end
        if ff==9
           ylabel('Mol') 
        end
        
        title([clab{ff} chrom{cc}])
    end
end

toc;







