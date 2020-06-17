function [LATEM] = LATE(allM,Lmax,T,nnei,nsur,alpha,showtxt)
% function [LATEM] = LATE(allM,Lmax,T,nnei,nsur,alpha,showtxt)
% Estimation of Partial Transfer Entropy (PTE) based on low-dimensional 
% approximation method & the Non-Uniform Embedding (NUE) scheme. 
% Computes the measure LATE_{X->Y|Z} for all combinations of X and Y time
% series from the multivariate time series given in matrix 'allM', of size
% N x K, where Z contains the rest K-2 time series.
% The components of X,Y, and Z, are found from a mixed embedding aiming at
% explaining Y. The mixed embedding is formed by using the progressive
% embedding algorithm based on conditional mutual information (CMI).
% CMI is estimated by the method of nearest neighbors (Kraskov's method).
% The function is the same as PMIME.m but defines the stopping criterion
% differently, using an adjusted rather than fixed threshold. Specifically,
% a significance test is performed for the CMI of the new component
% selected as best. For the significance test a number 'nsur' surrogates
% are given and the test decision is made at a given significance level
% 'alpha'. The ramdomized data are obtained using rand permutation of the
% time indices of the candidate lag variable and indpependent rand
% permutation of the lagged variables already selected.
% The derived LATE measure indicates the information flow of time series X to
% time series Y conditioned on the rest time series in Z. The measure
% values are stored in a K x K matrix 'LATE' and given to the output, where
% the value at position (i,j) indicates the effect from i to j (row to
% col), and the (i,i) components are zero.
% INPUTS
% - allM : the N x K matrix of the K time series of length N.
% - Lmax : the maximum delay to search for X and Y components for the mixed
%          embedding vector [default is 5].
% - T    : T steps ahead that the mixed embedding vector has to explain.
%          Note that if T>1 the future vector is of length T and contains
%          the samples at times t+1,..,t+T [dafault is 1].
% - nnei : number of nearest neighbors for density estimation [default is 5]
% - nsur : the number of surrogates for the significance test [default is 100]
% - alpha: the significance level for the test for the termination
%          criterion [default is 0.05].
% - showtxt : if 0 or negative do not print out anything,
%             if 1 print out the response variable index at each run,
%             if 2 or larger print also info for each embedding cycle [default is 1].
% OUTPUTS
% - LATEM  : A K x K matrix containing the R values computed by PMIME using
%          the surrogates for setting the stopping criterion.
%
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
%
% Created by Angeliki Papana (angeliki.papana@gmail.com)
%=========================================================================
%maxcomps = 20; % A safeguard, to make sure that the algorithm does not make 
% more than "maxcomps" embedding cycles.

if nargin==6
    showtxt = 1;
elseif nargin == 5
    showtxt = 1;
    alpha = 0.05;
elseif nargin == 4
    showtxt = 1;
    alpha = 0.05;
    nsur = 100;
elseif nargin == 3
    showtxt = 1;
    alpha = 0.05;
    nsur = 100;
    nnei = 5;
elseif nargin == 2
    showtxt = 1;
    alpha = 0.05;
    nsur = 100;
    nnei = 5;
    T = 1;
elseif nargin == 1
    showtxt = 1;
    alpha = 0.05;
    nsur = 100;
    nnei = 5;
    T = 1;
    Lmax = 5;
end
if isempty(alpha), alpha = 0.05; end
if isempty(nsur), nsur = 100; end
if isempty(nnei), nnei = 5; end
if isempty(T), T = 1; end
if isempty(Lmax), Lmax = 5; end

[N,K] = size(allM);
wV = Lmax*ones(K,1);

% Standardization of the input matrix columnwise in [0,1].
minallV=min(allM);
rang=kron((1./range(allM)),ones(N,1));
allM=(allM-kron(minallV,ones(N,1))).*rang;

% Build up the lag matrix from all variables
alllagM = NaN(N,sum(wV)); % lag matrix of all variables
indlagM = NaN(K,2); % Start and end of columns of each variable in lag matrix
count = 0;
for iK=1:K
    indlagM(iK,:) = [count+1 count+wV(iK)];
    alllagM(:,indlagM(iK,1))=allM(:,iK); % lag=0
    for ilag=1:wV(iK)-1  % lag=1,...,Lmax-1
        alllagM((ilag+1):end,indlagM(iK,1)+ilag)=allM(1:(end-ilag),iK);
    end
    count = count+wV(iK);
end
alllagM = alllagM(Lmax:end-T,:);
[N1,alllags] = size(alllagM);

% Find mixed embedding and LA measure for purpose: from (X,Y,Z) -> Y
LA = zeros(K,K);
ecC = cell(K,1);
psinnei = psi(nnei); % Computed once here, to be called in several times
psiN1 = psi(N1); % Computed once here, to be called in several times
for iK=1:K
    if showtxt==1
        fprintf('%d..',iK);
    elseif showtxt>=2
        fprintf('Response variable index=%d.. \n',iK);
        fprintf('EmbeddingCycle  Variable  Lag  I(x^F;w|wemb)  I(x^F;w,wemb)  I(x^F;w|wemb)/I(x^F;w,wemb) \n');
    end
    Xtemp = NaN(N,T);
    for iT=1:T
        Xtemp(1:(end-iT),iT)=allM((1+iT):end,iK);
    end
    xFM = Xtemp(Lmax:end-T,:); % The future vector of response
    % First embedding cycle: max I(y^T, w), over all candidates w
    miV=NaN*ones(alllags,1);
    
    for i1=1:alllags
        % Compute the mutual information of future response and each one of
        % the cadidate lags using the nearest neighbor estimate
        xnowM = [xFM alllagM(:,i1)];
        [~, distsM] = annMaxquery(xnowM', xnowM', nnei+1);
        maxdistV=distsM(end,:)';
        nyFV = nneighforgivenr(xFM,maxdistV-ones(N1,1)*10^(-10));
        nwcandV = nneighforgivenr(alllagM(:,i1),maxdistV-ones(N1,1)*10^(-10));
        psibothM=psi([nyFV nwcandV]);
        miV(i1)=psinnei + psiN1 - mean(sum(psibothM,2));
    end
    
    [maxmi,iembV]=max(miV);
    xembM=alllagM(:,iembV);
    % The randomization signficance test for the mutual information (MI) of
    % selected lagged variable and the future response state
    misurV = NaN*ones(nsur+1,1);
    misurV(1)=maxmi;
    
    for isur=1:nsur
        xsurV = xembM(randperm(N1));
        xnowM = [xFM xsurV];
        [~, distsM] = annMaxquery(xnowM', xnowM', nnei+1);
        maxdistV=distsM(end,:)';
        nyFV = nneighforgivenr(xFM,maxdistV-ones(N1,1)*10^(-10));
        nwsurV = nneighforgivenr(xsurV,maxdistV-ones(N1,1)*10^(-10));
        psibothM=psi([nyFV nwsurV]);
        misurV(isur+1)=psinnei + psiN1 - mean(sum(psibothM,2));
    end
    
    % percentile 
    soglia = prctile(misurV(2:end),100*(1-alpha));
    
    % obtained by the rank ordering applying a suggested correction)
    if misurV(1) > soglia   % stati. signific - add the component and continue
        % add the selected lag variable in the first embedding cycle and
        % show it
        varind = ceil(iembV/Lmax); % the variable
        lagind = mod(iembV,Lmax);  % the lag of the variable
        if lagind==0
            lagind = Lmax;
        end
        ecC{iK}= [varind lagind miV(iembV) NaN NaN]; % For the first component
        if showtxt>=2
            fprintf('%d \t %d \t %d \t %2.5f \t %2.5f \t %2.5f \n',...
                size(ecC{iK},1),ecC{iK}(end,1),ecC{iK}(end,2),...
                ecC{iK}(end,3),ecC{iK}(end,4),ecC{iK}(end,5));
        end
        % End of first embedding cycle, the first lagged variale is found
        terminator=0; % Flag for terminating the embedding cycles
        maxcomps = min(size(alllagM,2),20); % To avoid large embedding        
        % Run iteratively, for each embedding cycle select w from max I(y^; w | wemb)
        while (terminator==0 && size(xembM,2)<maxcomps)
            activeV = setdiff((1:alllags),iembV); % The indexed of the candidates 
            cmiV=NaN*ones(alllags,1);     % I(y^; w | wemb)
            
            % Low-dimensional approximation for CMI!!!
            for i1=activeV
                I1 = NaN*ones(size(xembM,2),1);
                I2 = NaN*ones(size(xembM,2),1);
                for ijk = 1:size(xembM,2)                  
                    I1(ijk) = mkraskov1(alllagM(:,i1),xembM(:,ijk),nnei);                    
                    I2(ijk) = cmikra1n(alllagM(:,i1),xembM(:,ijk),xFM,nnei);                 
                end
                I0 = mkraskov1(alllagM(:,i1),xFM,nnei);                              
                cmiV(i1) =  I0 - 2*mean(I1) + 2*mean(I2);  % Eq.(7), Zhang, (2018)                                                   
            end
            
            [maxcmi,ind]=max(cmiV); % ind: index of the selected lagged variable
            xVnext=alllagM(:,ind);
            varind = ceil(ind/Lmax); % the variable
            lagind = mod(ind,Lmax);  % the lag of the variable
            if lagind==0
                lagind = Lmax;
            end
            % The termination criterion of the surrogate significance test
            cmisurV = NaN*ones(nsur+1,1);
            cmisurV(1) = maxcmi;
            for isur=1:nsur
                indxsurV = randperm(N1);
                xVnextsur = xVnext(indxsurV);
                indxsur2V = randperm(N1);
                xembMsur = xembM(indxsur2V,:);

                % Low-dimensional aproximation for surrogates !!
                I1 = NaN*ones(size(xembM,2),1);
                I2 = NaN*ones(size(xembM,2),1);
                for ijk = 1:size(xembMsur,2)                  
                    I1(ijk) = mkraskov1(xVnextsur,xembMsur(:,ijk),nnei);                    
                    I2 = cmikra1n(xVnextsur,xembMsur(:,ijk),xFM,nnei);                 
                end
                I0 = mkraskov1(xVnextsur,xFM,nnei);                              
                cmisurV(isur+1) =  I0 - 2*mean(I1) + 2*mean(I2);                
            end
            
            soglia = prctile(cmisurV(2:end),100*(1-alpha));            
            if cmisurV(1) <= soglia
                terminator=1;
            else
                  xembM=[xembM xVnext];
                  iembV=[iembV ind]; % The index of the subsequent component is added
            end                           
         end % while not terminate
    
        % Identify the lags of each variable in the embedding vector, if not
        % empty, and compute the LA measure for each driving variable.
        if ~isempty(find(iembV<indlagM(iK,1) | iembV>indlagM(iK,2),1))
            % Find the lags of the variables
            xformM = NaN(length(iembV),2);
            xformM(:,1) = ceil(iembV/Lmax); % The variable indices
            xformM(:,2) = mod(iembV,Lmax); % The lag indices for each variable
            xformM(xformM(:,2)==0,2)=Lmax;
            % Make computations only for the active variables, which are the
            % variables included in the mixed embedding vector.
            activeV = unique(xformM(:,1));
            % Store the lags of the response and remove it from the active
            % variable list
            if ~isempty(intersect(activeV,iK))
                inowV = find(xformM(:,1)==iK);
                xrespM = xembM(:,inowV);
                activeV = setdiff(activeV,iK);
            else
                xrespM = []; % This is the case where the response is not
                % represented in the mixed embedding vector
            end
            KK = length(activeV);
            indKKM = NaN(KK,2); % Start and end in xembM of the active variables
            iordembV = NaN(length(iembV),1); % the index for reordering the lag
            % matrix to set together lags of the same variable
            count = 0;
            for iKK=1:KK
                inowV = find(xformM(:,1)==activeV(iKK));
                indKKM(iKK,:)=[count+1 count+length(inowV)];
                iordembV(indKKM(iKK,1):indKKM(iKK,2))=inowV;
                count = count+length(inowV);
            end
            iordembV = iordembV(1:indKKM(KK,2));
            % The total embedding vector ordered with respect to the active
            % variables and their lags, except from the response
            xembM = xembM(:,iordembV);
            % Compute the entropy for the largest state space, containing the
            % embedding vector and the future response vector. This is done
            % once for all active variables, to be used in the computation of R.
            if isempty(xrespM)
                xpastM = xembM;
            else
                xpastM = [xrespM xembM];
            end
            [~,dists] = annMaxquery([xFM xpastM]',[xFM xpastM]',nnei+1);
            maxdistV=dists(end,:)';
            nyFV = nneighforgivenr(xFM,maxdistV-ones(N1,1)*10^(-10));
            nwV = nneighforgivenr(xpastM,maxdistV-ones(N1,1)*10^(-10));
            psi0V = psi([nyFV nwV]);
            psinnei = psi(nnei);
            IyFw = psinnei+psi(N1)-mean(sum(psi0V,2)); % I(y^T; w)
            % For each active (driving) variable build the arguments in
            % I(y^T; w^X | w^Y w^Z) and then compute it. Note that w^X is not
            % needed to be specified because it is used only to form
            % w=[w^X w^Y w^Z], which was done above one for all active variables.
            for iKK=1:KK
                indnowV = (indKKM(iKK,1):indKKM(iKK,2))';
                irestV = setdiff((1:size(xembM,2)),indnowV);
                % Construct the conditioning embedding vector [w^Y w^Z],
                % considering the cases one of the two components is empty.
                if isempty(irestV) && isempty(xrespM)
                    xcondM = [];
                elseif isempty(irestV) && ~isempty(xrespM)
                    xcondM = xrespM;
                elseif ~isempty(irestV) && isempty(xrespM)
                    xcondM = xembM(:,irestV);
                else
                    xcondM = [xrespM xembM(:,irestV)];
                end
                % Compute I(y^T; w^X | w^Y w^Z)
                if isempty(xcondM)
                    IyFwXcond = IyFw;
                else
                    nxFcondV = nneighforgivenr([xFM xcondM],maxdistV-ones(N1,1)*10^(-10));
                    ncondV = nneighforgivenr(xcondM,maxdistV-ones(N1,1)*10^(-10));
                    psinowV = [psi(nxFcondV) psi0V(:,2) -1*psi(ncondV)];
                    IyFwXcond = psinnei - mean(sum(psinowV,2));
                end               
                
                LA(activeV(iKK),iK) = IyFwXcond;
            end % for all active variables
        end % if on lags of the embedding vector
    end % if pval>alpha at the first embedding cycle
    if ~isempty(ecC{iK})
        ecC{iK}(end,:)=[]; % Upon termination delete tha last selected component.
    end
end % for all variables
if showtxt>0
    fprintf('\n');
end

LA(LA<0)=0;

% -------------------------------------------------------------------------
function npV=nneighforgivenr(xM,rV)
npV = annMaxRvaryquery(xM', xM',rV, 1, 'search_sch', 'fr', 'radius', sqrt(1));
npV=double(npV);
npV(npV==0)=1;

