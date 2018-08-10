function [x, cost, options] = conjugategradient(problem, x)

options.minstepsize = 1e-5;
options.maxiter = 50;
options.tolgradnorm = 1e-5;
options.storedepth = 2;
options.beta_type = 'H-S';
options.orth_value = Inf;
options.linesearch = @linesearch_adaptive;

% for convenience
inner = problem.M.inner;
lincomb = problem.M.lincomb;

% Create a store database
storedb = struct();

% If no initial point x is given by the user, generate one at random.
if ~exist('x', 'var') || isempty(x)
    x = problem.M.rand();
end

% Compute objective-related quantities for x
[cost grad storedb] = getCostGrad(problem, x, storedb);
gradnorm = problem.M.norm(x, grad);

Pgrad = grad;
gradPgrad = inner(x, grad, Pgrad);

% Iteration counter (at any point, iter is the number of fully executed
% iterations so far)
iter = 0;


% Initial linesearch memory
lsmem = [];


% Compute a first descent direction (not normalized)
desc_dir = lincomb(x, -1, Pgrad);

stepsize = 100;
% Start iterating until stopping criterion triggers
while true
    % Run standard stopping criterion checks
    info.stepsize = stepsize;
    info.gradnorm = gradnorm;
    info.iter = iter;
    [stop] = stoppingcriterion(options, info);
    if stop
        break;
    end
    
    
    % The line search algorithms require the directional derivative of the
    % cost at the current point x along the search direction.
    df0 = inner(x, grad, desc_dir);
    
    if df0 >= 0
        desc_dir = lincomb(x, -1, Pgrad);
        df0 = -gradPgrad;
    end
    
    % Execute line search
    [stepsize newx storedb lsmem lsstats] = options.linesearch(...
        problem, x, desc_dir, cost, df0, options, storedb, lsmem);
    
    
    % Compute the new cost-related quantities for x
    [newcost newgrad storedb] = getCostGrad(problem, newx, storedb);
    newgradnorm = problem.M.norm(newx, newgrad);
    Pnewgrad = newgrad;
    newgradPnewgrad = inner(newx, newgrad, Pnewgrad);
    
    
    % Apply the CG scheme to compute the next search direction.
    %
    % This paper https://www.math.lsu.edu/~hozhang/papers/cgsurvey.pdf
    % by Hager and Zhang lists many known beta rules. The rules defined
    % here can be found in that paper (or are provided with additional
    % references), adapted to the Riemannian setting.
    %
    
    oldgrad = problem.M.transp(x, newx, grad);
    orth_grads = inner(newx, oldgrad, Pnewgrad)/newgradPnewgrad;
    
    % Powell's restart strategy (see page 12 of Hager and Zhang's
    % survey on conjugate gradient methods, for example)
    if abs(orth_grads) >= options.orth_value,
        beta = 0;
        desc_dir = lincomb(x, -1, Pnewgrad);
        
    else % Compute the CG modification
        
        desc_dir = problem.M.transp(x, newx, desc_dir);
        
        diff = lincomb(newx, 1, newgrad, -1, oldgrad);
        ip_diff = inner(newx, Pnewgrad, diff);
        beta = ip_diff / inner(newx, diff, desc_dir);
        beta = max(0, beta);
        
        desc_dir = lincomb(newx, -1, Pnewgrad, beta, desc_dir);
    end
    
    
    
    % Make sure we don't use too much memory for the store database.
   % storedb = purgeStoredb(storedb, options.storedepth);
    
    % Update iterate info
    x = newx;
    cost = newcost;
    grad = newgrad;
    Pgrad = Pnewgrad;
    gradnorm = newgradnorm;
    gradPgrad = newgradPnewgrad;
    
    % iter is the number of iterations we have accomplished.
    iter = iter + 1;
    
    % Log statistics for freshly executed iteration
    %     stats = savestats();
    %     info(iter+1) = stats; %#ok<AGROW>
    
end
end

