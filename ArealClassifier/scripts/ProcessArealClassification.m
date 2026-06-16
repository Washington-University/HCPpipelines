function ProcessArealClassification(RawName, JoinedName, JoinedFCName, RawFCName, RobustJoinedOutput, VAName, midthickness, hemisphereword)
%  #Find number of clusters for each area, if Joined > Raw, then mask out Joined from all areas and insert Joined into the correct area location.  Also, check for overlap between Joined areas and mask out any overlapping vertices

wbcommand = 'wb_command';

Raw = ciftiopen(RawName, wbcommand);
Joined = ciftiopen(JoinedName, wbcommand);
JoinedFC = ciftiopen(JoinedFCName, wbcommand);
RawFC = ciftiopen(RawFCName, wbcommand);
VA = ciftiopen(VAName, wbcommand);

Output = Raw;

for i = 1:size(Raw.cdata, 2)
    disp(['area = ' num2str(i)]);
    correspondence = pac_joining_helper(JoinedFC.cdata(:, i), RawFC.cdata(:, i));%mapping from raw cluster ID to joined cluster ID
    if sum(correspondence > 0) > length(unique(correspondence(correspondence > 0))) %Test if this area has fewer clusters after joining
        tempout = Joined; %The joined areas file contains area ROIs (one area per map) that have overlap
        tempout.cdata = Joined.cdata .* repmat(~Joined.cdata(:, i), 1, size(Raw.cdata, 2)); %Does the joined area in question break another joined area (multiply all the joined areas by zeros inside the joined area in question)
        tempout.cdata(:, i) = Joined.cdata(:, i); %Reset the joined area in question to equal the joined area in question (previous step would zero it out)
        
        %Test if this area breaks another area leading to a larger number of clusters       
        ciftisave(tempout, [RobustJoinedOutput '_temp1.dscalar.nii'], wbcommand);
        system([wbcommand ' -cifti-find-clusters ' RobustJoinedOutput '_temp1.dscalar.nii 0.99 25 0.99 125 COLUMN ' RobustJoinedOutput '_temp2.dscalar.nii -' hemisphereword '-surface ' midthickness]);
        checkbreakclusters = ciftiopen([RobustJoinedOutput '_temp2.dscalar.nii'], wbcommand);
        
        joinedarea = sum(VA.cdata(JoinedFC.cdata(:, i) > 0)); %Find the total surface area of the joined area in question
        %pieceIDs = unique(RawFC.cdata(RawFC.cdata(:, i) > 0, i)); %Find the number of clusters in the raw area in question
        
        %Find the surface area of each raw cluster for the area in question
        rawareapiecess = correspondence;%just for the size
        for c = 1:length(correspondence) 
            rawareapiece = sum(VA.cdata(RawFC.cdata(:, i) == c));
            rawareapiecess(c) = rawareapiece;
        end
        rawarea = sum(VA.cdata(RawFC.cdata(:, i) > 0)); %Find the total surface area of the raw area
        ratios = rawareapiecess / rawarea; %Find the proportion of the raw area's surface area for each raw cluster
        arearatio = 0;
        clusterunique = unique(correspondence(correspondence > 0));
        for cluster = 1:length(clusterunique)%loop over merged clusters
            sortedratios = sort(ratios(correspondence == clusterunique(cluster)), 'descend'); %Sort the raw cluster ratios of the participating clusters
            if length(sortedratios) > 1
                arearatio = max(arearatio, sortedratios(2)); %Find the second biggest cluster
            end
        end
        clear rawareapiecess
        broken = 0;
        
        for j = 1:size(Raw.cdata, 2)
            if i ~= j %For all areas other than the area in question
                correspondence2 = pac_joining_helper(JoinedFC.cdata(:, j), checkbreakclusters.cdata(:, j));%mapping from possibly broken cluster ID to joined cluster ID
                if sum(correspondence2 > 0) > length(unique(correspondence2(correspondence2 > 0))) %Check if the area in question has broken another area
                    %pieceIDs2 = unique(checkbreakclusters.cdata(checkbreakclusters.cdata(:, j) > 0, j)); %Find the number of clusters in the joined, broken area in question
                    
                    %Find the surface area of each joined, broken area piece
                    pieces = correspondence2;%just for the size
                    for c = 1:length(correspondence2)
                        piecearea = sum(VA.cdata(checkbreakclusters.cdata(:, j) == c));
                        pieces(c) = piecearea;
                    end
                                        
                    otherjoinedarea = sum(VA.cdata(checkbreakclusters.cdata(:, j) > 0)); %Find the total surface area of the other joined area
                    otheratios = pieces / otherjoinedarea; %Find the proportion of the other joined area's surface area for each cluster
                    clusterunique2 = unique(correspondence2(correspondence2 > 0));
                    for cluster2 = 1:length(clusterunique2)
                        sortedotheratios = sort(otheratios(correspondence2 == clusterunique2(cluster2)), 'descend'); %Sort the other areas joined cluster ratios
                        if length(sortedotheratios) > 1 && arearatio < sortedotheratios(2) %If the broken area's second cluster ratio is larger than the joined area in question's second cluster, declare that the joined area broke the other area
                            broken = 1;
                            disp(['joinedarea = ' num2str(joinedarea)]);
                            disp(['arearatio = ' num2str(arearatio)]);
                            disp(['otherjoinedarea = ' num2str(otherjoinedarea)]);
                            disp(['otheratio = ' num2str(sortedotheratios(2))]);
                            disp(['area ' num2str(i) ' would break area ' num2str(j)]);
                            break;
                        end
                    end
                    if broken
                        break;
                    end
                end
            end
        end
        
        if ~broken
            %Mask out all other areas from containing the joined areas vertices
            tempmask = repmat(~Joined.cdata(:, i), 1, size(Raw.cdata, 2)); 
            Output.cdata = Output.cdata.*tempmask;
            %Set the output to equal the joined area
            Output.cdata(:, i) = Joined.cdata(:, i);
        end
    end
end

%Remove the temporary files
delete([RobustJoinedOutput '_temp1.dscalar.nii']);
delete([RobustJoinedOutput '_temp2.dscalar.nii']);

%Save the output
ciftisave(Output, [RobustJoinedOutput '.dscalar.nii'], wbcommand);
end

%NOTE: inputs must be 1D
function correspondence = pac_joining_helper(joinedFC, unjoinedFC)
    [vals, first, junk2] = unique(unjoinedFC);
    correspondence = zeros(length(first), 1);
    for i = 1:length(first)
        if (vals(i) ~= 0)
            correspondence(vals(i)) = joinedFC(first(i));
        end
    end
end

function joinedlist = pac_identify_joined(correspondence)
    used = false(length(correspondence));
    joinedlist = [];
    for i = 1:length(correspondence)
        if ~used(i)
            for j = (i + 1):length(correspondence)
                if ~used(j) && correspondence(i) == correspondence(j)
                    used([i j]) = 1;
                    joinedlist = [joinedlist i j];
                end
            end
        end
    end
    joinedlist = unique(joinedlist);
end

