function plgndr = my_plgndr ( degree, order, x )

% Based on FieldTrip 20160222 functions:
% * plgndr

% Checks the input.
if order < 0 || round ( order ) ~= order
    error ( 'The order must be a positive integer or zero.' )
end
if degree < order || round ( degree ) ~= degree
    error ( 'The degree must be a positive integer equal or greated than m.' )
end
if any ( abs ( x ) > 1 )
    error ( 'abs (x) vannot be greater than 1.' )
end


% % Gets the dimensions of the input and the output.
% dsize  = size ( x );
% osize  = cat ( 2, dsize, order + 1 );


% Initializes the output.
plgndr = zeros ( numel ( x ), degree + 1 );


% Gets the solution at degree = order analitically.
root   = sqrt ( 1 - x (:) .* x (:) );
plgndr ( :, order + 1 ) = prod ( 1: 2: 2 * order - 1 ) * root .^ order;

% Corrects the sign.
if rem ( abs ( order ), 2 )
    plgndr ( :, order + 1 ) = -plgndr ( :, order + 1 );
end

% If the degree equals the order, returns.
if degree == order, return, end


% Uses a simplified version of the formula for the second iteration.
plgndr ( :, order + 2 ) = x (:) .* ( 2 * ( order + 1 ) - 1 ) .* plgndr ( :, order + 1 );


% Uses the iterative formula for the rest of iterations.
for dindex = order + 2: degree
    
    % Calculates the value of the polynomial in the current iteration.
    plgndr ( :, dindex + 1 ) = ( x (:) .* ( 2 * dindex - 1 ) .* plgndr ( :, dindex ) - ( dindex + order - 1 ) .* plgndr ( :, dindex - 1 ) ) ./ ( dindex - order );
end


% % Reshapes the output.
% plgndr = reshape ( plgndr, osize );
