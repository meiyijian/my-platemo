function varargout = hcv_test_harness(what,varargin)
%hcv_test_harness Test-only accessor for this algorithm's private/ functions.
%   private/ is not visible from the tests folder, so unit tests call the
%   private modules through this harness, which lives in the algorithm
%   directory and therefore can see private/.
%
%   Not used by the algorithm itself.

    switch lower(what)
        case 'hcv'
            % [Lambda,B,Info] = harness('hcv',M,nHarm)
            [varargout{1:max(1,nargout)}] = ...
                HarmonicComplementaryVectors(varargin{:});

        case 'pop'
            % Obj = harness('pop',M,N) - synthetic objective matrix
            M = varargin{1};
            N = varargin{2};
            F = rand(N,M);
            F = F./vecnorm(F,2,2).*(1+0.6*rand(N,1));
            varargout{1} = F;

        case 'classify'
            % [g,Catalog,Diag] = harness('classify',Obj,ratio,nHarm)
            Obj   = varargin{1};
            ratio = varargin{2};
            nHarm = varargin{3};
            Pop   = MakeSolutions(Obj);
            k     = max(6,ceil(1.5*size(Obj,2)));
            [~,~,Catalog,~,~,Diag] = ComplementaryPBI_Classification( ...
                Pop,ratio,'k',k,'theta',5,'rGood',0.25,'nHarm',nHarm);
            % 复算排序键，供测试断言 nHarm=0 时等价于纯锚点排序
            Ref = RefSelect(Pop,k);
            g   = HarnessAnchorPBI(Obj,[Ref.objs],5);
            varargout{1} = g;
            varargout{2} = Catalog;
            varargout{3} = Diag;

        case 'refselect'
            % idx = harness('refselect',Obj,k,wCon)
            Obj  = varargin{1};
            k    = varargin{2};
            wCon = varargin{3};
            Pop  = MakeSolutions(Obj);
            if isempty(wCon)
                Ref = RefSelect(Pop,k);
            else
                Ref = RefSelect(Pop,k,wCon);
            end
            varargout{1} = [Ref.objs];

        otherwise
            error('AdaMaO:UnknownHarnessRequest', ...
                'Unknown harness request: %s',what);
    end
end

function Pop = MakeSolutions(Obj)
    N   = size(Obj,1);
    dec = zeros(N,size(Obj,2));
    Pop = SOLUTION(dec,Obj,zeros(N,1));
end

function g = HarnessAnchorPBI(PopObj,RefObj,theta)
% 与 ComplementaryPBI_Classification/AnchorPBI 相同的几何，供测试独立复算
    N = size(PopObj,1);
    g = zeros(N,1);
    Z = min(PopObj,[],1);
    [~,ai] = max(1 - pdist2(PopObj,RefObj,'cosine'),[],2);
    ai(~isfinite(ai)) = 1;
    X = PopObj - Z;
    for i = 1 : size(RefObj,1)
        sel = ai == i;
        if ~any(sel)
            continue;
        end
        w  = RefObj(i,:) - Z;
        nw = norm(w);
        if nw < 1e-12
            g(sel) = vecnorm(X(sel,:),2,2);
            continue;
        end
        W  = w./nw;
        Xs = X(sel,:);
        d1 = Xs*W';
        d2 = vecnorm(Xs - d1*W,2,2);
        g(sel) = (d1 + theta.*d2)./nw;
    end
    g(~isfinite(g)) = max([g(isfinite(g));0]);
end
