function [X_best_rec, result] = capped_tensor_tnnr(M, omega, opts)
%--------------------------------------------------------------------------
%    main loop of tensor completion based on truncated nuclear norm 
%
%    min_X ||X||_* - max tr(A * X * B')  s.t.  (X)_Omega = (M)_Omega
%
% Input:
%       M       -    n1 x n2 x n3 tensor
%       omega   -    index of the known elements
%       opts    -    struct contains parameters
% Output:
%       X_best_rec -  recovered tensor at the best rank
%       result     -  result of algorithm
%--------------------------------------------------------------------------

min_R = 1;
max_R = 1;
out_tol = 1e-3; 
out_iter = 5;%%%%%%%%%%%%%%%%%50
max_P = 255;% max pixel value
%method = 'ADMM';    % ADMM or APGL

if ~exist('opts', 'var'),   opts = [];  end

if isfield(opts, 'min_R');      min_R = opts.min_R;         end
if isfield(opts, 'max_R');      max_R = opts.max_R;         end
if isfield(opts, 'out_tol');    out_tol = opts.out_tol;     end
if isfield(opts, 'out_iter');   out_iter = opts.out_iter;	end
if isfield(opts, 'max_P');      max_P = opts.max_P;         end
%------------------------------ max pixel value
[n1, n2, n3] = size(M);
%-------------------------------------------------------------
Erec = zeros(max_R, 1);  % reconstruction error, best value in each rank
Psnr = zeros(max_R, 1);  % PSNR, best value in each rank
%-------------------------------------------------------------
time_cost = zeros(max_R, 1);      % consuming time, each rank
iter_outer = zeros(999, 1);     % number of outer iterations
iter_total = zeros(999, 1);     % number of total iterations
X_rec = zeros(n1, n2, n3, out_iter);  % recovered image under the best rank

best_R = 0;  % record the best value
best_psnr = 0;
best_erec = 0;

dim = size(M);
norm_M = norm(M(:));

for R = min_R :  max_R   % search from [ ~, ~] one by one
    theta = 0.01 * R ;
    X_iter = zeros(n1, n2, n3, out_iter);
    X = zeros(dim);
    
    X(omega) = M(omega);
    t_rank = tic;
    for i = 1 : out_iter%主干有opts.out_iter
       
        fprintf('theta = 0.0%d, outer_iter=%d\n', R, i);%
        last_X = X;  
            
        S = zeros(dim);
        Y = X;  
        [X, iter_in] = capped_tnn_admm(S, X, Y, M, omega, opts, theta);
        
        X_iter(:, :, :, i) = X;
        iter_outer(R) = iter_outer(R) + 1;%%%
        iter_total(R) = iter_total(R) + iter_in;
        
        delta = norm(vec(X - last_X)) / norm_M;
        fprintf('||X_k+1-X_k||_F/||M||_F = %.4f\n', delta);%误差大小
        if delta < out_tol
            fprintf('converged at iter=%d(%d)\n\n', i, iter_total(R));%收敛于何时
            break ;%迭代次数
        end                   
    end
    time_cost(R) = toc(t_rank);
    X = max(X, 0);
    X = min(X, max_P);
    [Erec(R), Psnr(R)] = psnr(M, X, omega);%
    if best_psnr < Psnr(R)%
        best_R = R;
        best_psnr = Psnr(R);
        best_erec = Erec(R);%
        X_rec = X_iter;
    end
    fprintf('Psnr(R) = %d       Erec(R) = %d\n', Psnr(R), Erec(R));%误差大小
end

%% compute the reconstruction error and PSNR in each iteration 
%  for the best rank
num_iter = iter_outer(best_R);
psnr_iter = zeros(num_iter, 1);
erec_iter = zeros(num_iter, 1);
for t = 1 : num_iter
    X_temp = X_rec(:, :, :, t);
    [erec_iter(t), psnr_iter(t)] = psnr(M, X_temp, omega);
end
X_best_rec = X_rec(:, :, :, num_iter);
X_best_rec = max(X_best_rec, 0);
X_best_rec = min(X_best_rec, max_P);

%% record performances for output
result.time = time_cost;
result.iterations = iter_outer;
result.total_iter = iter_total;
result.best_R = best_R;
result.best_psnr = best_psnr;
result.best_erec = best_erec;
result.R = (min_R : max_R)';
result.Psnr = Psnr(min_R:max_R);%Psnr !!!!!
result.Erec = Erec(min_R:max_R);%Erec !!!!!
result.Psnr_iter = psnr_iter;
result.Erec_iter = erec_iter;

end