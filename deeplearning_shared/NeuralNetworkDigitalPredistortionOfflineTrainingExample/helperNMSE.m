function nmse = helperNMSE(in,out)
%helperNMSE Normalized mean square error in dB
%   NMSE = helperNMSE(X,Y) returns the normalized mean square
%   error (NMSE) between X and Y. 

%   Copyright 2023 The MathWorks, Inc.

mse = mean(abs(in-out).^2,'all');
nmse = 10*log(mse / mean(abs(in).^2,'all'))/log(10);
end