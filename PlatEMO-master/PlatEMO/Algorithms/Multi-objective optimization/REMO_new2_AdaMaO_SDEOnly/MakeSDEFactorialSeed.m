function seed = MakeSDEFactorialSeed(runId,generation,phase,recipe)
%MakeSDEFactorialSeed Build reproducible seeds without floating overflow.
%   The recipes preserve the original seeds for ordinary integer run IDs.
%   Inputs are reduced modulo the recipe modulus before uint64 products, so
%   every multiplication and addition remains within the uint64 range.

    if isstring(recipe) && isscalar(recipe)
        recipe = char(recipe);
    end
    if ~ischar(recipe) || ~isrow(recipe)
        error('AdaMaO:InvalidSeedRecipe', ...
            'The seed recipe must be relation, regression, split, or legacy.');
    end

    switch lower(strtrim(recipe))
        case 'relation'
            modulus = uint64(2147483647);
            multipliers = uint64([104729 130363 15485863]);
            offset = uint64(32452843);
            usePhaseFallback = true;
        case 'regression'
            modulus = uint64(2147483647);
            multipliers = uint64([179424673 15485863 32452843]);
            offset = uint64(49979687);
            usePhaseFallback = true;
        case 'split'
            modulus = uint64(4294967295);
            multipliers = uint64([1103515245 2654435761 0]);
            offset = uint64(12345);
            usePhaseFallback = false;
        case 'legacy'
            modulus = uint64(4294967295);
            multipliers = uint64([1103515245 2654435761 0]);
            offset = uint64(2246822519);
            usePhaseFallback = false;
        otherwise
            error('AdaMaO:InvalidSeedRecipe', ...
                'The seed recipe must be relation, regression, split, or legacy.');
    end

    components = [integerResidue(runId,1,1,modulus), ...
        integerResidue(generation,0,0,modulus), ...
        integerResidue(phase,0,0,modulus)];
    value = mod(offset,modulus);
    for i = 1:numel(components)
        term = mod(components(i).*mod(multipliers(i),modulus),modulus);
        value = mod(value+term,modulus);
    end
    if value == 0 && usePhaseFallback
        value = components(3);
        if value == 0
            value = uint64(1);
        end
    end
    seed = double(value);
end

function residue = integerResidue(value,defaultValue,minimum,modulus)
    if isempty(value) || ~isnumeric(value) || ~isreal(value) || ...
            ~isscalar(value) || ~isfinite(value) || value < minimum
        value = defaultValue;
    else
        value = floor(double(value));
    end
    residue = uint64(mod(value,double(modulus)));
end
