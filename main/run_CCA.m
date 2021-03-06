clear all;

malexflag = 1; % user flag
if malexflag
    %Meryem
    path.code = 'C:\Users\mayucel\Documents\PROJECTS\CODES\GLM-BCI'; addpath(genpath(path.code)); % code directory
    path.dir = 'C:\Users\mayucel\Google Drive\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    path.save = 'C:\Users\mayucel\Google Drive\tCCA_GLM_PAPER'; % save directory
    
    %Meryem Laptop
    %     path.code = 'C:\Users\m\Documents\GitHub\GLM-BCI'; addpath(genpath(path.code)); % code directory
    %     path.dir = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % data directory
    %     path.save = 'C:\Users\m\Documents\tCCA_GLM_PAPER\FB_RESTING_DATA'; % save directory
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
flag_detrend = 0; % input paramater to load_nirs function: performing linear detrend if 1, no detrending if 0 during "pre-processing" 
drift_term = 1; % input parameter to hmrDeconvHRF_DriftSS function: performing linear detrend for GLM_SS and GLM_CCA during single trial estimation
drift_hrfestimate = 3; % input parameter to hmrDeconvHRF_DriftSS function: polynomial order, performs linear/polynomial detrending during estimation of HRF from training data
flag_hrf_resid = 0; % 0: hrf only; 1: hrf+yresid
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

% motion artifact detection
motionflag = true;
%plot flag
flag_plot = true;
% include tcca results or not in plots?
flag_plotCCA = true;


% Validation parameters
% tlags = 0:1:10;
% stpsize = 2:2:24;
% cthresh = 0:0.1:0.9;
tlags = 3;
stpsize = 2;
cthresh = 0.3;

tic;

%% Eval plot flag (developing/debugging purposes only)
evalplotflag = 0; % compares dc, hrf_ss, hrf_tcca, true hrf for hrf added channels
evalplotflag_glm = 0; % displays raw signal, model fit, yresid, hrf, ss, drift etc for sanity check (now for glm_ss only)



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
        t = t(tstIDX,:);
        
        if motionflag
            [tIncAuto] = hmrMotionArtifact(dod,fq,SD,ones(size(d,1),1),0.5,1,30,5);
            [s,tRangeStimReject] = enStimRejection(t,s,tIncAuto,ones(size(d,1),1),[-2  10]);
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
                dod_new = dod; dod_new([pre_stim:post_stim],:) = 0;
                dc_new = hmrOD2Conc(dod_new, SD, [6 6]);
                s_new = s; s_new([pre_stim:post_stim],:) = 0;
                % estimate HRF from training data
                [yavg_ss_estimate, yavgstd_ss, tHRF, nTrialsSS, d_ss, yresid_ss, ysum2_ss, beta_ss, yR_ss] = ...
                hmrDeconvHRF_DriftSS(dc_new, s_new, t, SD, [], [], [eval_param.HRFmin eval_param.HRFmax], 1, 1, [0.5 0.5], rhoSD_ssThresh, 1, drift_hrfestimate, 0,hrf,lstHrfAdd{sbj},0,[pre_stim post_stim]);
      
              
            %% Save normal raw data (single trials)
            y_raw(:,:,:,os)= dc{tt}(pre_stim:post_stim,:,:);
            
            
            %% Perform GLM with SS
            [yavg_ss(:,:,:,os), yavgstd_ss, tHRF, nTrialsSS, ynew_ss(:,:,:,os), yresid_ss, ysum2_ss, beta_ss, yR_ss] = ...
                hmrDeconvHRF_DriftSS(dc{tt}(pre_stim:post_stim,:,:), s(pre_stim:post_stim,:), t(pre_stim:post_stim,:), SD, [], [], [eval_param.HRFmin eval_param.HRFmax], 1, 5, yavg_ss_estimate, rhoSD_ssThresh, 1, drift_term, 0, hrf,lstHrfAdd{sbj},evalplotflag_glm,[] );
       
            %% CCA with optimum parameters
            tl = tlags;
            sts = stpsize;
            ctr = cthresh;
            
            %% set stepsize for CCA
            param.tau = sts; %stepwidth for embedding in samples (tune to sample frequency!)
            param.NumOfEmb = ceil(tl*fq / sts);
            
                %% Temporal embedding of auxiliary data from testing split
                aux_sigs = AUX(tstIDX,:);
                aux_sigs = aux_sigs(pre_stim:post_stim,:);
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
                [yavg_cca(:,:,:,os), yavgstd_cca, tHRF, nTrials(tt), ynew_cca(:,:,:,os), yresid_cca, ysum2_cca, beta_cca, yR_cca] = ...
                    hmrDeconvHRF_DriftSS(dc{tt}(pre_stim:post_stim,:,:), s(pre_stim:post_stim,:), t(pre_stim:post_stim,:), SD, REG_tst, [], [eval_param.HRFmin eval_param.HRFmax], 1, 5, yavg_ss_estimate, 0, 0, drift_term, 0, hrf,lstHrfAdd{sbj},0,[]);
          
            if evalplotflag  % plotting all hrf added channels for a single subject
                a=dc{tt}(pre_stim:post_stim,:,:)-repmat(mean(dc{tt}(pre_stim:onset_stim(os),:,:),1),numel(pre_stim:post_stim),1);
                figure;subplot(1,3,1);plot(tHRF,squeeze(a(:,1,lstHrfAdd{sbj}(:,1))));ylim([-1e-6 1.5e-6]);title('none'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);ylabel('HbO (hrf only)'); 
                subplot(1,3,2);plot(tHRF,squeeze(yavg_ss(:,1,lstHrfAdd{sbj}(:,1),os))); ylim([-1e-6 1.5e-6]);title('ss'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);
                subplot(1,3,3);plot(tHRF,squeeze(yavg_cca(:,1,lstHrfAdd{sbj}(:,1),os)));ylim([-1e-6 1.5e-6]);title('cca'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);
                figure;subplot(1,3,1);plot(tHRF,squeeze(a(:,2,lstHrfAdd{sbj}(:,1))));ylim([-1e-6 0.5e-6]);title('none'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,2),'k','LineWidth',2);ylabel('HbR (hrf only)'); 
                subplot(1,3,2);plot(tHRF,squeeze(yavg_ss(:,2,lstHrfAdd{sbj}(:,1),os)));ylim([-1e-6 0.5e-6]); title('ss'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,2),'k','LineWidth',2); 
                subplot(1,3,3);plot(tHRF,squeeze(yavg_cca(:,2,lstHrfAdd{sbj}(:,1),os)));ylim([-1e-6 0.5e-6]);title('cca'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,2),'k','LineWidth',2);
                
                
                figure;subplot(1,3,1);plot(tHRF,squeeze(a(:,1,lstHrfAdd{sbj}(:,1))));ylim([-1e-6 1.5e-6]);title('none'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);ylabel('HbO (hrf+resid)'); 
                subplot(1,3,2);plot(tHRF,squeeze(ynew_ss(:,1,lstHrfAdd{sbj}(:,1),os))); ylim([-1e-6 1.5e-6]);title('ss'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2); 
                subplot(1,3,3);plot(tHRF,squeeze(ynew_cca(:,1,lstHrfAdd{sbj}(:,1),os)));ylim([-1e-6 1.5e-6]);title('cca'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,1),'k','LineWidth',2);
                figure;subplot(1,3,1);plot(tHRF,squeeze(a(:,2,lstHrfAdd{sbj}(:,1))));ylim([-1e-6 0.5e-6]);title('none'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,2),'k','LineWidth',2);ylabel('HbR (hrf+resid)'); 
                subplot(1,3,2);plot(tHRF,squeeze(ynew_ss(:,2,lstHrfAdd{sbj}(:,1),os)));ylim([-1e-6 0.5e-6]); title('ss'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,2),'k','LineWidth',2); 
                subplot(1,3,3);plot(tHRF,squeeze(ynew_cca(:,2,lstHrfAdd{sbj}(:,1),os)));ylim([-1e-6 0.5e-6]);title('cca'); hold on; plot(hrf.t_hrf,hrf.hrf_conc(:,2),'k','LineWidth',2);
             end
            % display current state:
            disp(['sbj ' num2str(sbj) ', epoch ' num2str(os) ])
        end
        
        if flag_hrf_resid
            
            yavg_ss = ynew_ss;
            yavg_cca = ynew_cca;
            
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

%% (Box)Plot results (normal metrics)
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
        if flag_plotCCA
            boxplot([squeeze(F_Raw_Hrf(ff,cc,:)), squeeze(F_SS_Hrf(ff,cc,:)), squeeze(F_CCA_Hrf(ff,cc,:))], 'labels', labels)
            H=sigstar({[1,2],[1,3],[2,3]},squeeze(p_co(ff,cc,1:3)));
        else
            % without cca
            boxplot([squeeze(F_Raw_Hrf(ff,cc,:)), squeeze(F_SS_Hrf(ff,cc,:))], 'labels', labels(1:2))
            H=sigstar({[1,2]},squeeze(p_co(ff,cc,1)));
        end
        
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


%% (Box)Plot results (metric errors)
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
        if ff==5
            FVgt.x(ff,cc) = 6; % set time to peak to 6 seconds (due to gt hrf plateau)
        end
        
        if ff<8
            % without GLM, with GLM+SS, with GLM+CCA
            if flag_plotCCA
                boxplot([abs(squeeze(F_Raw_Hrf(ff,cc,:))-FVgt.x(ff,cc)), abs(squeeze(F_SS_Hrf(ff,cc,:))-FVgt.x(ff,cc)), abs(squeeze(F_CCA_Hrf(ff,cc,:))-FVgt.x(ff,cc))], 'labels', labels)
                H=sigstar({[1,2],[1,3],[2,3]},squeeze(p_co(ff,cc,1:3)));
            else
                boxplot([abs(squeeze(F_Raw_Hrf(ff,cc,:))-FVgt.x(ff,cc)), abs(squeeze(F_SS_Hrf(ff,cc,:))-FVgt.x(ff,cc))], 'labels', labels(1:2))
                H=sigstar({[1,2]},squeeze(p_co(ff,cc,1)));
            end
            title(['ERR ' clab{ff} chrom{cc}])
        else
            if flag_plotCCA
                boxplot([squeeze(F_Raw_Hrf(ff,cc,:)), squeeze(F_SS_Hrf(ff,cc,:)), squeeze(F_CCA_Hrf(ff,cc,:))], 'labels', labels)
                H=sigstar({[1,2],[1,3],[2,3]},squeeze(p_co(ff,cc,1:3)));
            else
                boxplot([squeeze(F_Raw_Hrf(ff,cc,:)), squeeze(F_SS_Hrf(ff,cc,:))], 'labels', labels(1:2))
                H=sigstar({[1,2]},squeeze(p_co(ff,cc,1)));
            end
            
            title([clab{ff} chrom{cc}])
        end
        
        
        if ff<5
            ylabel('\muMol')
        end
        if ff==5
            ylabel('sec')
        end
        if ff==9
            ylabel('\muMol')
        end
    end
end


toc;







