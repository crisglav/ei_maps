function [s]= myft_statfun_anova ( cfg, data, design )


% Sanitizes the input.
data    = data';
design  = design';

% Gets the data dimension.
ndatas  = size ( design, 1 );
nvars   = size ( design, 2 );


% Initializes the counter for degrees of freemdom.
dfs     = zeros ( 1, nvars );

% Calculates the number of degrees of freedom for the factors.
fvar    = design ( :, cfg.ivar );
dfs ( cfg.ivar )  = sum ( diff ( sort ( fvar, 1 ) ) > 0, 1 );

% Detects the covariates and sets their degree of freedom to 1.
cvar    = ( dfs > 0.2 * ndatas ) | ( dfs > 5 );
dfs ( cvar ) = 1;


% Computes the critical value, if requested.
if isfield ( cfg, 'computecritval' ) && strcmp ( cfg.computecritval, 'yes' )
    
    % Calculates the degrees of freedom of the main effect and the error.
    df1     = dfs (1);
    df2     = ndatas - 1 - sum ( dfs );
    
    % Calculates the critical value.
    s.critval = finv ( 1 - cfg.alpha, df1, df2 );
end

% If the statistic is not requiered, exits.
if isfield ( cfg, 'computestat' ) && strcmp ( cfg.computestat, 'no' )
    return
end

% Replaces the design factors and covariates for the original ones.
design ( :, 2: end ) = cfg.design ( 2: end, : )';

% % Calculates the ANOVA.
% [ ~, table ] = my_anovan_0orig ( data, design, 'continuous', cvar, 'display', 'off' );
% 
% % Gets the F- and p-values.
% s.stat = cat ( 1, table { 2, 6, : } );
% s.prob = cat ( 1, table { 2, 7, : } );

% Calculates the ANOVA.
[ ~, table, stats ] = my_anovan_lite ( data, design, 'continuous', cvar, 'display', 'off' );


% If only one permutation, calculates the pairwise comparison.
if ~isfield ( cfg, 'numrandomization' ) || cfg.numrandomization == 1
    
    % Gets the pairwise statistics.
%     [ pval, means, ~, ~, tval, critval ] = my_multcompare ( stats, 'ctype', 'lsd', 'display', 'off' );
    [ pval, means, ~, ~, tval, critval ] = my_multcompare ( stats, 'ctype', 'hsd', 'display', 'off' );
    
    % Re-formats the results.
    s.critval = critval;
    s.ppair   = permute ( pval  ( :, 6, : ), [ 1 3 2 ] );
    s.mean    = permute ( means ( :, 1, : ), [ 1 3 2 ] );
    s.stder   = permute ( means ( :, 2, : ), [ 1 3 2 ] );
    s.tpair   = tval;
end


% Gets the F- and p-values.
s.stat = table { 2, 6 } (:);
s.prob = table { 2, 7 } (:);
