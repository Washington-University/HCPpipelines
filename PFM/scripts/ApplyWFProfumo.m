function ApplyWFProfumo(inputFile, outputFile, numWisharts)
  numWisharts = str2double(numWisharts);
  cii = ciftiopen(strtrim(inputFile), 'wb_command');
  Out = icaDim(cii.cdata, 0, 1, -1, numWisharts);
  cii.cdata = Out.data(:, startTP:endTP);
  ciftisave(cii, strtrim(outputFile), 'wb_command');
end