function altered = ambiguate_dims(dims)
    %emulate matlab's singular-dimension-dropping behavior
    altered = dims;
    if length(dims) == 1 && dims(1) == 0
        altered(2) = 0; %emulate [] behavior
    end
    lastnonsingular = find(dims ~= 1, 1, 'last');
    %only applies to dimensions 3 and up
    if isempty(lastnonsingular) || lastnonsingular < 2
        lastnonsingular = 2;
    end
    altered((length(altered) + 1):2) = 1; %also extend (non-empty) 1D to 2D for better compatibility
    altered = altered(1:lastnonsingular); %clip trailing
end

%{
alternate implementation:

    altered = dims;
    %interpreted matlab doesn't initialize for zeros(), but compiled matlab might
    %TRAP: zeros([2]) behaves just like zeros(2), makes a square array
    %so concatenate a 1 to a single-dim input (or 0 if empty, to get [] behavior)
    if length(dims) == 1
        if dims(1) == 0
            altered(2) = 0; %empty convention is 0 x 0
        else
            altered(2) = 1;
        end
    end
    altered = size(zeros(altered, 'single')); %find out the direct way

%}

