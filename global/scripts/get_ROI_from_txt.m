function first_column_values = get_ROI_from_txt(filename)
    fileID = fopen(filename, 'r');
    even_lines = {};
    
    is_even_line = false;
    
    line = fgetl(fileID);
    while ischar(line)
        if is_even_line
            even_lines{end+1} = line;
        end
        
        is_even_line = ~is_even_line;
        
        line = fgetl(fileID);
    end
    
    fclose(fileID);
   
    first_column_values = [];
    
    for i = 1:length(even_lines)
        % Split the line by spaces
        columns = strsplit(even_lines{i}, ' ');
        if numel(columns) >= 1
            % Convert the first column to a number and add it to the array
            first_column_values(end+1) = str2double(columns{1});
        end
    end
    
end

