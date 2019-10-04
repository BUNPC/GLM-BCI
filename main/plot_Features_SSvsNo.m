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


%%choose HRF level
hrflab = {'HRF 100%', 'HRF 50%'};
hh = 1;

disp(['running for ' hrflab{hh} '...'])
%% load data
switch hh
    case 1 % 100%
        load([path.save '\FV_results_SSvsNo_ldrift1_resid0stlindrift_hrf_amp100_20soffs.mat'])
        %load([path.save '\FV_results_SSvsNo_ldrift1_resid0_tccaIndiv_hrf_amp100_20soffs.mat'])
    case 2 % 50%
        load([path.save '\FV_results_SSvsNo_ldrift1_resid0stlindrift_hrf_amp50_20soffs.mat'])
        %load([path.save '\FV_results_SSvsNo_ldrift1_resid0_tccaIndiv_hrf_amp50_20soffs.mat'])
end




%% load ground truth hrf
hrf = load([path.code '\sim HRF\hrf_simdat_100_shorterHRF.mat']);

% outlier symbol
osymb = '';

% Features/structs for feature extraction function
eval_param.HRFmin = -2;
eval_param.HRFmax = 15; % used only for block design runs
fparam.swdw=[0,4;8,11]; % need to discuss this selection!
ival = [eval_param.HRFmin eval_param.HRFmax];

% get features from ground truth
hrfdat.x = hrf.hrf_conc;
hrfdat.fs = 25;
hrfdat.t = hrf.t_hrf';
[FVgt] = featureExtract(hrfdat, fparam);

%% Get HRF features from all augmented channels to compare against  ground truth
%Sort through results and append
FV_Raw = cell(2);
FV_SS = cell(2,2);
%% sbj list
sbjl = [1:3 5:12];
for sbj = sbjl
    % only look at the crossvalidated test results. These are stored where cell and trial index
    % coincide (== os)
    for os = 1:numel(TTM{sbj}.tstidx)
        for cc=1:2 % stim and resting condition
            % channel indices that have or dont have gt HRF
            idxChHrf = lstHrfAdd{sbj}(:,1);
            idxChNoHrf = setdiff(lstLongAct{sbj},squeeze(lstHrfAdd{sbj}(:,1)));
            if size(idxChHrf,1) > size(idxChNoHrf,1)
                idxChHrf = idxChHrf(1:size(idxChNoHrf,1));
            else
                idxChNoHrf = idxChNoHrf(1:size(idxChHrf,1));
            end
            % number of available channels
            nHrf = size(FMdc{sbj}(:,:,idxChHrf,:,cc));
            nNoHrf = size(FMdc{sbj}(:,:,idxChNoHrf,:,cc));
            % extract and append crossvalidated features (from testing trial), new dimension is F x C x I,
            % where F: # of Features, C: # Number of Chromophores, I: # of all
            % trials (epochs*channels)
            FV_Raw{cc} = cat(3, FV_Raw{cc}, FMdc{sbj}(:,:,idxChHrf,os,cc));
            for rr=1:2 % stim and resting hrf regressor
                FV_SS{cc,rr} = cat(3, FV_SS{cc,rr}, FMss{sbj,os}(:,:,idxChHrf,os,cc,rr));
            end
        end
    end
end


%% Paired T-Tests for STIM trials with HRF added and HRF STIM regressor
cc = 1;
rr = 1;
for ff = 1:9
    for ch=1:3
        [h_co(ff,ch,1),p_co(ff,ch)]= ttest(squeeze(FV_Raw{cc,rr}(ff,ch,:)),squeeze(FV_SS{cc,rr}(ff,ch,:)));
    end
end


%% (Box)Plot results (metric errors)
cc = 1;
rr = 1;
figure
labels = {'No GLM', 'GLM SS'};
chrom = {' HbO', ' HbR'};
ylims = {[-.1 3], [-.1 3], [-.1 3], [-.1 3], [-.3 7], [-.01 .4]; ...
    [-.1 1.5], [-.1 1.5], [-.1 1.5], [-.1 1.5], [-.3 7], [-.01 .15]};
% for all features
for ff=1:6
    % for both chromophores
    for ch=1:2
        subplot(2,6,(ch-1)*6+ff)
        xtickangle(35)
        hold on
        %% boxplots
        if ff==5
            FVgt.x(ff,ch) = 6; % set time to peak to 6 seconds (due to gt hrf plateau)
        end
        % without GLM, with GLM+SS,
        boxplot([abs(squeeze(FV_Raw{cc,rr}(ff,ch,:))-FVgt.x(ff,ch)), abs(squeeze(FV_SS{cc,rr}(ff,ch,:))-FVgt.x(ff,ch))], 'labels', labels, 'Notch','on', 'symbol', osymb)
        ylim(ylims{ch,ff})
        grid on
        %plot significance level
        if p_co(ff,ch) <= 1e-3
            p = '***';
        elseif p_co(ff,ch) <= 1e-2
            p = '**';
        elseif p_co(ff,ch) <= 0.05
            p = '*';
        end
        text(1.45, ylims{ch,ff}(2)*0.9, p)
        title([FMclab{ff} chrom{ch}])
        if ff<5
            ylabel('\muMol')
        end
        if ff==5
            ylabel('sec')
        end
    end
end

%% RMSE + CORR
figure
ylims = {[-.1 1.1], [-.1 2.5]; [-.1 1.1], [-.1 2.5]};
for ff=1:2
    % for both chromophores
    for ch=1:2
        subplot(2,2,(ch-1)*2+ff)
        xtickangle(35)
        hold on
        %% boxplots
        boxplot([squeeze(FV_Raw{cc,rr}(7+ff,ch,:)), squeeze(FV_SS{cc,rr}(7+ff,ch,:))], 'labels', labels(1:2) ,'Notch','on', 'symbol', osymb)
        ylim(ylims{ch,ff})
        grid on
        %plot significance level
        if p_co(7+ff,ch) <= 1e-3
            p = '***';
        elseif p_co(7+ff,ch) <= 1e-2
            p = '**';
        elseif p_co(7+ff,ch) <= 0.05
            p = '*';
        end
        text(1.45, ylims{ch,ff}(2)*0.9, p)
        title([FMclab{7+ff} chrom{ch}])
        if ff==2
            ylabel('\muMol')
        end
    end
end



%% Get HRF Weights from all augmented channels to compare against  ground truth
%Sort through results and append
W_SS = cell(2,2);
for sbj = 1:numel(TTM)
    % only look at the crossvalidated test results. These are stored where cell and trial index
    % coincide (== os)
    for os = 1:numel(TTM{sbj}.tstidx)
        % channel indices that have or dont have gt HRF
        idxChHrf = lstHrfAdd{sbj}(:,1);
        idxChNoHrf = setdiff(lstLongAct{sbj},squeeze(lstHrfAdd{sbj}(:,1)));
        if size(idxChHrf,1) > size(idxChNoHrf,1)
            idxChHrf = idxChHrf(1:size(idxChNoHrf,1));
        else
            idxChNoHrf = idxChNoHrf(1:size(idxChHrf,1));
        end
        % number of available channels for HRF added
        cc=1;
        nHrf = size(FWss{sbj,os}(:,:,idxChHrf,:,cc));
        nNoHrf = size(FWss{sbj,os}(:,:,idxChNoHrf,:,cc));
        % extract and append crossvalidated weights (from testing trial), new dimension is
        % CHROMOPHORES x Concatenated weights of active CHANNELS (trials)
        for cc=1:2 % stim and resting condition
            for rr=1:2 % stim and resting hrf regressor
                W_SS{cc,rr} = cat(2, W_SS{cc,rr}, squeeze(FWss{sbj,os}(1,:,idxChHrf,os,cc,rr)));
            end
        end
    end
end

%% Histograms of weights and target features
% hrf regressor for condition
featurelab = {'HRF Weight (GLM)', 'Avg (GLM)', 'Avg (no GLM)',  'Slope (GLM)', 'Slope (no GLM)'};
hblab = {'HbO', 'HbR'};
W = {W_SS, FV_SS, FV_Raw, FV_SS, FV_Raw};
featidx = [1, 4, 4, 6, 6];
xlims = {[-3 4], [-1 1.5], [-5 5], [-.5 .75], [-.75 1]; [-4 4], [-.4 .4], [-3 3], [-.2 .15], [-.4 .3]};
hcol{1} = {rgb('Red'), rgb('Red'), rgb('Red'), rgb('Red'), rgb('Red'); ...
    rgb('Blue'), rgb('Blue'), rgb('Blue'), rgb('Blue'), rgb('Blue')}; %stim
hcol{2} = {rgb('DarkGray'), rgb('DarkGray'),rgb('DarkGray'),rgb('DarkGray'),rgb('DarkGray'); ...
    rgb('DarkGray'),rgb('DarkGray'),rgb('DarkGray'),rgb('DarkGray'),rgb('DarkGray'),}; %rest
% Plot both methods
%number of bins
nbins = 100;
figure
for ww = 1:numel(W)
    % for both chromophores
    for hb=1:2
        % plot weights for HRF stim regressor for STIM vs REST trials (cc=1 vs 2)
        subplot(2,5,(hb-1)*5+ww)
        hold on
        if ww == 1
            h1=histfit(W{ww}{1,1}(hb,:), nbins); % stim
            h1(1).FaceColor = hcol{1}{hb,ww};
            h1(1).FaceAlpha = .5;
            h1(2).Color = hcol{1}{hb,ww};
            hold on
            h2=histfit(W{ww}{2,1}(hb,:), nbins); % rest
            h2(1).FaceColor = hcol{2}{hb,ww};
            h2(1).FaceAlpha = .5;
            h2(2).Color = hcol{2}{hb,ww};
            % calculate gaussian fits
            pd1 = fitdist(W{ww}{1,1}(hb,:)','Normal');
            pd2 = fitdist(W{ww}{2,1}(hb,:)','Normal');
            legend([h1(1), h2(1)], 'STIM Trials','REST Trials')
        else
            h1=histfit(squeeze(W{ww}{1,1}(featidx(ww),hb,:)), nbins); % stim
            h1(1).FaceColor = hcol{1}{hb,ww};
            h1(1).FaceAlpha = .5;
            h1(2).Color = hcol{1}{hb,ww};
            hold on
            h2=histfit(squeeze(W{ww}{2,1}(featidx(ww),hb,:)), nbins); % rest
            h2(1).FaceColor = hcol{2}{hb,ww};
            h2(1).FaceAlpha = .5;
            h2(2).Color = hcol{2}{hb,ww};
            % calculate gaussian fits
            pd1 = fitdist(squeeze(W{ww}{1,1}(featidx(ww),hb,:)),'Normal');
            pd2 = fitdist(squeeze(W{ww}{2,1}(featidx(ww),hb,:)),'Normal');
        end
        xlim(xlims{hb,ww});
        set(gca,'YTickLabel',[]);
        grid on
        % calculate overlap between gaussians and add to plot
        x_range=-10:0.01:10;
        overlap=cumtrapz(x_range,min([normpdf(x_range,pd1.mu,pd1.sigma)' normpdf(x_range,pd2.mu,pd2.sigma)']'));
        overlap2 = round(overlap(end)*100);
        title([featurelab{ww} ', ' num2str(overlap2) '%'])
    end
end
