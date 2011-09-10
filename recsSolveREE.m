function [interp,x,z,f,exitflag] = recsSolveREE(interp,model,s,x,options)
% RECSSOLVEREE finds the rational expectations equilibrium (REE) of a model
%
% RECSSOLVEREE implementes various approximation schemes, and equation solvers to
% find the REE of a model.
%
% INTERP = RECSSOLVEREE(INTERP,MODEL,S,X) tries to find the rational expectations
% equilibrium of the model defined in the structure MODEL, by using the
% interpolation structure defined in the structure INTERP. The problem is solved
% on the grid of state variables provided in matrix S. Matrix X is used as a
% first guess of response variables on the grid. RECSSOLVEREE returns the
% interpolation structure containing the coefficient matrices cx
% and cz, and ch if this field was initially included in INTERP.
% INTERP is a structure, which has to include the following fields:
%    ch, cx or cz : a coefficient matrix providing a first guess of the
%                   approximation of the expectations function for ch, of the
%                   response variables for cx, or of the expectations for cz
%    fspace       : a definition structure for the interpolation family (created
%                   by the function fundef)
%    Phi          : a basis structure defined on the grid S (created by funbas
%                   or funbasx)
% MODEL is a structure, which has to include the following fields:
%    [e,w] : discrete distribution with finite support with e the values and w the
%            probabilities (it could be also the discretisation of a continuous
%            distribution through quadrature or Monte Carlo drawings)
%    func   : function name or anonymous function that defines the model's equations
%    params : model's parameters, it is preferable to pass them as a cell array
%             (compulsory with the functional option) but other formats are
%             acceptable
%
% INTERP = RECSSOLVEREE(INTERP,MODEL,S,X,OPTIONS) solves the problem with the 
% parameters defined by the structure OPTIONS. The fields of the structure are
%    display          : 1 to show iterations (default: 1)
%    eqsolver         : 'fsolve', 'lmmcp' (default), 'ncpsolve' or 'path'
%    eqsolveroptions  : options structure to be passed to eqsolver
%    extrapolate      : 1 if extrapolation is allowed outside the
%                       interpolation space or 0 to forbid it (default: 1)
%    functional       : 1 if the equilibrium equations are a functional equation
%                       problem (default: 0)
%    loop_over_s      : 0 (default) to solve all grid points at once or 1 to loop
%                       over each grid points
%    method           : 'expapprox', 'expfunapprox', 'resapprox-simple'
%                       or 'resapprox-complete' (default)
%    reesolver        : 'krylov', 'mixed', 'SA' (default) or 'fsolve' (in test)
%    reesolveroptions : options structure to be passed to reesolver
%    useapprox        : (default: 1) behaviour dependent of the chosen method. If
%                       0 and method is 'expapprox' then next-period responses are
%                       calculated by equations solve and not just interpolated. If 
%                       1 and method is 'resapprox', the guess of response variables 
%                       is found with the new approximation structure
%
% [INTERP,X] = RECSSOLVEREE(INTERP,MODEL,S,X,...) returns the value of the response
% variables on the grid.
%
% [INTERP,X,Z] = RECSSOLVEREE(INTERP,MODEL,S,X,...) returns the value of the
% expectations variables on the grid.
%
% [INTERP,X,Z,F] = RECSSOLVEREE(INTERP,MODEL,S,X,...) returns the value of the
% equilibrium equations on the grid.
%
% [INTERP,X,Z,F,EXITFLAG] = RECSSOLVEREE(INTERP,MODEL,S,X,...) returns EXITFLAG,
% which describes the exit conditions. Possible values are
%    1 : RECSSOLVEREE converges to the REE
%    0 : Failure to converge
%
% See also FUNBAS, FUNBASX, FUNDEF, RECSCHECK, RECSSIMUL, RECSSS.

% Copyright (C) 2011 Christophe Gouel
% Licensed under the Expat license, see LICENSE.txt

%% Initialization
if nargin <=4, options = struct([]); end

defaultopt = struct(                  ...
    'display'           , 1          ,...
    'eqsolver'          , 'lmmcp' ,...
    'eqsolveroptions'   , struct([]) ,...
    'extrapolate'       , 1          ,...
    'functional'        , 0          ,...
    'loop_over_s'       , 0          ,...
    'method'            , 'resapprox-complete',...
    'reesolver'         , 'sa'   ,...
    'reesolveroptions'  , struct([]) ,...
    'useapprox'         , 1);
warning('off','catstruct:DuplicatesFound')

options = catstruct(defaultopt,options);

extrapolate        = options.extrapolate;
functional         = options.functional;
method             = lower(options.method);
reesolver          = lower(options.reesolver);
reesolveroptions   = catstruct(struct('showiters' , options.display,...
                                      'atol'      , sqrt(eps),...
                                      'lmeth'     , 3,...
                                      'rtol'      , eps),...
                               options.reesolveroptions);
useapprox          = options.useapprox;

e      = model.e;
params = model.params;
w      = model.w;
if isa(model.func,'char')
  func = str2func(model.func);
elseif isa(model.func,'function_handle')
  func = model.func;
else
  error('model.func must be either a string or a function handle')
end

switch method
 case 'expapprox'
  c      = interp.cz;
 case 'expfunapprox'
  c      = interp.ch;
 otherwise
  c      = interp.cx;
end
fspace = interp.fspace;
Phi    = interp.Phi;
if functional, params = [params fspace c]; end

[n,m]  = size(x);
output = struct('F',1,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',0);
p      = size(func('h',s(1,:),x(1,:),[],e(1,:),s(1,:),x(1,:),params,output),2);
k      = length(w);               % number of shock values
z      = zeros(n,0);

%% Solve for the rational expectations equilibrium
switch reesolver
 % Attention: the variables x and z are changed by the nested function 'ResidualREE'
 case 'mixed'
  reesolveroptions.maxit = 10;
  reesolveroptions.atol  = 1E-2;
  reesolveroptions.rtol  = 1E-3;
  c = SA(@ResidualREE, c(:), reesolveroptions);

  reesolveroptions.maxit = 40;
  reesolveroptions.atol  = 1E-7;
  reesolveroptions.rtol  = 1E-25;
  [c,~,exitflag] = nsoli(@ResidualREE, c(:), reesolveroptions);
  if exitflag==0, exitflag = 1; else exitflag = 0; end

 case 'krylov'
  [c,~,exitflag] = nsoli(@ResidualREE, c(:), reesolveroptions);
  if exitflag==0, exitflag = 1; else exitflag = 0; end

 case 'sa'
  [c,~,exitflag] = SA(@ResidualREE, c(:), reesolveroptions);

 case 'fsolve' % In test - Slow, because it uses numerical derivatives
  if options.display==1
    reesolveroptions = optimset('display','iter-detailed','Diagnostics','on');
  end
  [c,~,exitflag] = fsolve(@ResidualREE, c(:), reesolveroptions);

 case 'kinsol'
  neq = numel(c);
  KINoptions  = KINSetOptions('Verbose',       false,...
                              'LinearSolver',  'GMRES',...
                              'ErrorMessages', false,...
                              'FuncNormTol',   reesolveroptions.atol);
  KINInit(@ResidualREE,neq,KINoptions);
  [status, c] = KINSol(c(:),'LineSearch',ones(neq,1),ones(neq,1));
  KINFree;
  if status==0 || status==1, exitflag = 1; else exitflag = 0; end

end

if exitflag~=1
  warning('recs:FailureREE','Failure to find a rational expectations equilibrium');
end

%% Outputs calculations
% Interpolation coefficients
c = reshape(c,n,[]);
switch method
 case 'expapprox'
  interp.cz = c;
  interp.cx = funfitxy(fspace,Phi,x); 
  if isfield(interp,'ch')
    output = struct('F',1,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',0);
    interp.ch = funfitxy(fspace,Phi,func('h',[],[],[],[],s,x,params,output));
  end
 case 'expfunapprox'
  interp.ch = c;
  interp.cx = funfitxy(fspace,Phi,x); 
 otherwise
  interp.cx = c;
  if ~isempty(z), interp.cz = funfitxy(fspace,Phi,z); end
  if isfield(interp,'ch')
    output = struct('F',1,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',0);
    interp.ch = funfitxy(fspace,Phi,func('h',[],[],[],[],s,x,params,output));
  end
end

% Calculation of z on the grid for output
if isempty(z)
  if functional, params{end} = c; end
  ind    = (1:n);
  ind    = ind(ones(1,k),:);
  ss     = s(ind,:);
  xx     = x(ind,:);
  output = struct('F',1,'Js',0,'Jx',0);
  snext  = func('g',ss,xx,[],e(repmat(1:k,1,n),:),[],[],params,output);
  if extrapolate, snextinterp = snext;
  else      
    snextinterp = max(min(snext,fspace.b(ones(n*k,1),:)),fspace.a(ones(n*k,1),:)); 
  end

  switch method
   case 'expfunapprox'
    h   = funeval(c,fspace,snextinterp);
    if nargout(func)==6
      output            = struct('F',0,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',1);
      [~,~,~,~,~,hmult] = func('h',[],[],[],e(repmat(1:k,1,n),:),snext,zeros(size(snext,1),m),params,output);
      h                 = h.*hmult;
    end

   case 'resapprox-complete'
    [LB,UB] = func('b',snextinterp,[],[],[],[],[],params);
    xnext   = min(max(funeval(c,fspace,snextinterp),LB),UB);
    output  = struct('F',1,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',1);
    if nargout(func)<6
       h                = func('h',ss,xx,[],e(repmat(1:k,1,n),:),snext,xnext,params,output);
    else
      [h,~,~,~,~,hmult] = func('h',ss,xx,[],e(repmat(1:k,1,n),:),snext,xnext,params,output);
      h               = h.*hmult;
    end

  end
  z         = reshape(w'*reshape(h,k,n*p),n,p);
  interp.cz = funfitxy(fspace,Phi,z); 
end

%%
function [R,FLAG] = ResidualREE(cc)
% RESIDUALREE Calculates the residual of the model with regards to rational expectations

  switch method
    case 'expapprox'
      cc    = reshape(cc,n,p);
      if functional, params{end} = cc; end
      
      z     = funeval(cc,fspace,Phi);
      [x,f] = recsSolveEquilibrium(s,x,z,func,params,cc,e,w,fspace,options);
      
      ind     = (1:n);
      ind     = ind(ones(1,k),:);
      ss      = s(ind,:);
      xx      = x(ind,:);
      output  = struct('F',1,'Js',0,'Jx',0);
      snext   = func('g',ss,xx,[],e(repmat(1:k,1,n),:),[],[],params,output);
      if extrapolate, snextinterp = snext;
      else          
        snextinterp = max(min(snext,fspace.b(ones(n*k,1),:)),...
                          fspace.a(ones(n*k,1),:)); 
      end
      [LB,UB] = func('b',snextinterp,[],[],[],[],[],params);
      
      % xnext calculated by interpolation
      xnext   = min(max(funeval(funfitxy(fspace,Phi,x),fspace,snextinterp),LB),UB);
      if ~useapprox  % xnext calculated by equation solve
        xnext = recsSolveEquilibrium(snext,...
                                     xnext,...
                                     funeval(cc,fspace,snextinterp),...
                                     func,params,cc,e,w,fspace,options);
      end
      
      output              = struct('F',1,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',1);
      if nargout(func)<6
        h                 = func('h',ss,xx,[],e(repmat(1:k,1,n),:),snext,xnext,params,output);
      else
        [h,~,~,~,~,hmult] = func('h',ss,xx,[],e(repmat(1:k,1,n),:),snext,xnext,params,output);
        h                 = h.*hmult;
      end
      z     = reshape(w'*reshape(h,k,n*p),n,p);
      
      R     = funfitxy(fspace,Phi,z)-cc;
      
    case 'expfunapprox'
      cc    = reshape(cc,n,p);
      if functional, params{end} = cc; end
      
      [x,f]  = recsSolveEquilibrium(s,x,z,func,params,cc,e,w, fspace,options);
      output = struct('F',1,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',0);
      R      = funfitxy(fspace,Phi,func('h',[],[],[],[],s,x,params,output))-cc;
      
    case {'resapprox-complete','resapprox-simple'}
      cc    = reshape(cc,n,m);
      if functional, params{end} = cc; end
      
      if useapprox % x calculated by interpolation
        [LB,UB] = func('b',s,[],[],[],[],[],params);
        x       = min(max(funeval(cc,fspace,Phi),LB),UB);
      end % if not previous x is used
      
      if strcmp(method,'resapprox-simple')
        ind    = (1:n);
        ind    = ind(ones(1,k),:);
        ss     = s(ind,:);
        xx     = x(ind,:);
        output = struct('F',1,'Js',0,'Jx',0);
        snext  = func('g',ss,xx,[],e(repmat(1:k,1,n),:),[],[],params,output);
        
        if extrapolate, snextinterp = snext;
        else          
          snextinterp = max(min(snext,fspace.b(ones(n*k,1),:)),...
                            fspace.a(ones(n*k,1),:)); 
        end
        [LB,UB] = func('b',snextinterp,[],[],[],[],[],params);
        xnext   = min(max(funeval(cc,fspace,snextinterp),LB),UB);
        
        output              = struct('F',1,'Js',0,'Jx',0,'Jsn',0,'Jxn',0,'hmult',1);
        if nargout(func)<6
          h                 = func('h',ss,xx,[],e(repmat(1:k,1,n),:),snext,xnext,params,output);
        else
          [h,~,~,~,~,hmult] = func('h',ss,xx,[],e(repmat(1:k,1,n),:),snext,xnext,params,output);
          h                 = h.*hmult;
        end
        z     = reshape(w'*reshape(h,k,n*p),n,p);
      end
      
      [x,f] = recsSolveEquilibrium(s,x,z,func,params,cc,e,w,fspace,options);
      R     = funfitxy(fspace,Phi,x)-cc;
  end
  
  R       = R(:);
  FLAG    = 0;
end

end
