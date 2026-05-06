function [Frf,Fbb] = omp_precoding(Fopt,NtRF,Ns,At)
% This function helperOMPHybridWeights is only in support of
% HybridPrecodingExample. It may change in a future release.

% Copyright 2017 The MathWorks, Inc.
Fres = Fopt;
for m = 1:NtRF
    Psi = At'*Fres;
    [~,k] = max(diag(Psi*Psi'));
    Frf(:,m) = At(:,k);
    Fbb = (Frf(:,1:m)'*Frf(:,1:m))\Frf(:,1:m)'*Fopt;
    temp = Fopt-Frf(:,1:m)*Fbb;
    Fres = temp/norm(temp,'fro');
end
Fbb = sqrt(Ns)*Fbb/norm(Frf*Fbb,'fro');
end
