v = [10;20;30;40];        % column
m = logical([1 0 1 0]);   % ROW logical mask
r = v(m);
fprintf('v col, m row logical -> size(r) = %d x %d\n', size(r,1), size(r,2));
idx = 1:4; K = [1;3];
s = setdiff(idx,K);
fprintf('setdiff(1:4 row, [1;3] col) -> size = %d x %d\n', size(s,1), size(s,2));
O = [0;0;1;-1];
o = O(s);
fprintf('O col indexed by row idx -> size = %d x %d\n', size(o,1), size(o,2));
% max tie / NaN
[mv,mi] = max([1/3 1/3 1/3],[],2); fprintf('tie max idx=%d\n',mi);
[mv,mi] = max([NaN 0.2 0.3],[],2); fprintf('NaN-first max idx=%d val=%g\n',mi,mv);
[mv,mi] = max([NaN NaN NaN],[],2); fprintf('all-NaN max idx=%d val=%g\n',mi,mv);
% combvec ordering
disp('combvec(1:2,1:2) ='); disp(combvec(1:2,1:2));
A=[101;102]; C=combvec(A',A')'; disp('C1C1 (D=1,n=2):'); disp(C);
ti=combvec(1:2,1:2); disp('t_equ_ind:'); disp(ti(1,:)==ti(2,:));
% mapminmax constant row
X=[1 1 1; 0 5 10];
[Y,st]=mapminmax(X);
disp('mapminmax Y for constant row1:'); disp(Y);
fprintf('gain=[%g %g] xoffset=[%g %g]\n',st.gain(1),st.gain(2),st.xoffset(1),st.xoffset(2));
% ceil split
n0=1876;np=1875;
fprintf('train0=%d trainp=%d total_train=%d total=%d frac=%.4f\n', ceil(0.75*n0),ceil(0.75*np),ceil(0.75*n0)+2*ceil(0.75*np), 5626, (ceil(0.75*n0)+2*ceil(0.75*np))/5626);
for n=1:6, fprintf('n=%d ceil(0.75n)=%d test=%d\n',n,ceil(0.75*n),n-ceil(0.75*n)); end
