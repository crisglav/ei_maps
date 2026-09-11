function surfinf = my_grid2surf ( config, srcmodel, surface, surfinf )
% Interpolates a source model into a surface.

% Checs the inputs.
if nargin < 3, error ( 'This function requires three input parameters, at least.' ), end
if nargin < 4, surfinf = surface; end

% If the surface is provided as a file name, loads it.
if ischar ( surface ), surface  = ft_read_headshape ( surface ); end
if ischar ( surfinf ), surfinf  = ft_read_headshape ( surfinf ); end

% Defines the default parameters.
if ~isfield ( config, 'method' ),    config.method    = 'sphere'; end
if ~isfield ( config, 'maxdist' ),   config.maxdist   = 0.02;     end
if ~isfield ( config, 'parameter' ), config.parameter = {};       end

% If no parameter rises an error.
if isempty ( config.parameter )
    error ( 'This funtion requires the parmeter to ve provided' )
end

% Gets the method.
switch config.method
    case 'sphere',  nearest = false;
    case 'nearest', nearest = true;
    otherwise,      error ( 'Unknown method.' )
end


% Sanitizes the input.
if ~isfield ( srcmodel, 'inside' )
    srcmodel.inside = true ( size ( srcmodel.pos, 1 ), 1 );
end

% Converts the source model and the surfaces to SI units (meters).
srcmodel  = ft_convert_units ( srcmodel, 'm' );
surface   = ft_convert_units ( surface,  'm' );


% % Reshapes the sources and sufaces defintions.
% pos_from  = permute ( srcmodel.pos ( srcmodel.inside, : ), [ 3 1 2 ] );
% pos_tor   = permute ( surface.pos, [ 1 3 2 ] );
% 
% % Calculates the distance matrix.
% distmat2  = sum ( ( pos_from - pos_tor ) .^ 2, 3 );

% Calculates the distance matrix.
distmat2  = my_dist2mat ( surface.pos, srcmodel.pos ( srcmodel.inside, : ) );

% Keeps only the closest neighbor, if required.
if nearest
    distthres = min ( min ( distmat2, [], 2 ), config.maxdist .^ 2 );
else
    distthres = config.maxdist .^ 2;
end

% Calculates the weight matrix by thresholding the distance matrix.
weightmat = sparse ( distmat2 <= distthres );

% Normalizes the weight matrix.
weightmat = weightmat ./ sum ( weightmat, 2 );


% Goes through each parameter.
for pindex = 1: numel ( config.parameter )
    
    % Projects the sources onto the inflated surfaces.
    surfinf.( config.parameter { pindex } ) = weightmat * srcmodel.( config.parameter { pindex } ) ( srcmodel.inside );
end
