function Y = MiniMaSAEAHandler(F,w,mode)
%MINIMASAEAHANDLER Map normalized minimization objectives to scalar labels.
% F is normalized by the caller using the current evaluated archive only.

    switch mode
        case 'TCH'
            Y = max(F.*w,[],2);
        case 'PBI'
            direction = w./norm(w);
            d1 = F*direction';
            d2 = sqrt(sum((F-d1.*direction).^2,2));
            Y = d1 + 5*d2;
        case 'SDE'
            n = size(F,1);
            Y = zeros(n,1);
            neighbor = min(n,floor(sqrt(n))+1);
            for i = 1:n
                shifted = max(F,F(i,:));
                distance = sqrt(sum((shifted-F(i,:)).^2,2));
                distance = sort(distance);
                Y(i) = 1/(distance(neighbor)+2);
            end
        otherwise
            error('MiniMaSAEA:InvalidHandler','Unknown scalar handler: %s',mode);
    end
end
