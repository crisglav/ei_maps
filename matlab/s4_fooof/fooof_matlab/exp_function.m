function y = exp_function(guess,x)
if length(guess) == 2
    % Exponential function without knee
    of = guess(1);
    ex = guess(2);
    
    y = of - log10(x.^ex);
else
    % Exponential function with knee
    of = guess(1);
    kn = guess(2);
    ex = guess(3);
    
    y = of - log10(kn + x.^ex);
end
end