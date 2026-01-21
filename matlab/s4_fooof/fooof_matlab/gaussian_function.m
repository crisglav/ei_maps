function y = gaussian_function(guess,x)
% Guess is a vector, with all initial guesses for the parameters

y = zeros(size(x));
n_peaks = length(guess)/3;
for i=1:n_peaks
    c = guess(3*i-2);
    h = guess(3*i-1);
    w = guess(3*i);
    y = y + h * exp(-(x-c).^2 / (2*w^2));
end

end