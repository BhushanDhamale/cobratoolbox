function modelNew = mergeModelFieldPositions(model,type,positions)
% USAGE:
%    [modelNew] = mergeModelFieldPositions(model,type,positions)
%
% INPUTS:
%    model:           The model with the fields to merge
%    type:            the field type to merge ( rxns, mets, comps or genes)
%    positions:       The positions in the given field type to merge.
%
%
% OUTPUT:
%
%    modelNew:         merged model with the positions merged into one.
%                      Unique entries in Related String fields will be
%                      concatenated with ';' matrices will be summed up.
%
% .. Authors:
%                   - Thomas Pfau Sept 2017


modelNew = model;
if numel(positions) <= 1
    %If there is less than two positions to merge, we don't do anything.
    return;
end

posToKeep = positions(1);
posToMerge = positions(2:end);

%Store the original names.
origNames = modelNew.(type)(positions);

%get The fields and associated dimensions
[fields,dimensions] = getModelFieldsForType(modelNew, type, numel(model.(type)));


for i = 1:numel(fields)
    %Lets assume, that we only have 2 dimensional fields.    
    if isnumeric(modelNew.(fields{i})) || islogical(modelNew.(fields{i}))
        modelNew.(fields{i}) = setSlice(modelNew.(fields{i}),posToKeep,dimensions(i),sum(getSlice(modelNew.(fields{i}),positions,dimensions(i)),dimensions(i)));        
    end
    % if its cell arrays, concatenate unique data, we will assume here, that
    % all cell arrays are string arrays and that there are no
    % multi-dimensional 
    %There are two options for cell arrays currently. Either its all char
    %arrays, or its all cell arrays.
    if iscell(modelNew.(fields{i}))
        data = getSlice(modelNew.(fields{i}),positions,dimensions(i));
        if ischar([data{:}])
            %We have cell arrays with individual char arrays, So we will
            %take the concatenation of the unique values.
            %We have two exceptions for this: grRules and rules. All parts
            %of the old rules need to be present together.
            newData = {strjoin(unique(data),';')};
            if strcmp(fields{i}, 'rules')
                clauses = unique(data);
                clauses = setdiff(clauses,{''}); % remove empty clauses
                if ~isempty(clauses)
                    newData = {strjoin( strcat('(',unique(data),')'),' & ')};
                else
                    newData = {''};
                end
                    
            end
            if strcmp(fields{i}, 'grRules')
                clauses = unique(data);
                clauses = setdiff(clauses,{''}); % remove empty clauses
                if ~isempty(clauses)
                    newData = {strjoin( strcat('(',unique(data),')'),' and ')};
                else
                    newData = {''};
                end
            end
            modelNew.(fields{i}) = setSlice(modelNew.(fields{i}),posToKeep,dimensions(i),newData);     
        else
            dataconcatenation = unique([data{:}]);
            if iscell(dataconcatenation) % We have a field with Cell arrays of Cell arrays
                modelNew.(fields{i}) = setSlice(modelNew.(fields{i}),posToKeep,dimensions(i),{unique([data{:}])});     
            else
                %Not sure which fields this would apply to, but I assume,
                %this will lead to an error....
                modelNew.(fields{i}) = setSlice(modelNew.(fields{i}),posToKeep,dimensions(i),unique([data{:}]));     
            end
        end
    end
    if ischar(modelNew.(fields{i}))
        %This is a problem. as this is VERY dependent on the type of char
        %we have. We will simple not handle it for now... (as it is
        %currently only present in csense and whoever is doing it should
        %take care not to screw around when merging mets....
    end
    %now, having done this, we need to check whether we modified genes. If
    %so, we have to update the rules vector and the grRules vector, if
    %present
    if strcmp(type,'genes')
         if isfield(modelNew,'rules')
            for j = 1:numel(posToMerge)                
                %Replace by new position.
                modelNew.rules = strrep(modelNew.rules,['x(' num2str(posToMerge(j)) ')'],['x(' num2str(posToKeep) ')']);                                
            end
         end
         %Update the grRules field (if necessary).         
        if isfield(modelNew, 'grRules') && numel(unique(origNames)) > 1
            for j = 1:numel(positions)                
                %Replace by new name.
                %First, replace all occurences, which only contain the
                %name.                
                modelNew.grRules = regexprep(modelNew.grRules,['^' regexptranslate('escape',origNames{j}) '$'],modelNew.genes{posToKeep});            
                %The replace all occurences which are at the beginning or
                %end of a formula.
                modelNew.grRules = regexprep(modelNew.grRules,['^' regexptranslate('escape',origNames{j}) '([\) ]+)'],[ modelNew.genes{posToKeep} '$1']);                                
                modelNew.grRules = regexprep(modelNew.grRules,['([\( ]+)' regexptranslate('escape',origNames{j}) '$'],['$1' modelNew.genes{posToKeep} ]);                                
                %finally replace all  in the middle.
                modelNew.grRules = regexprep(modelNew.grRules,['([\( ]+)' regexptranslate('escape',origNames{j}) '([\) ]+)'],['$1' modelNew.genes{posToKeep} '$2']);                                
            end            
        end
    end
   
end
%After merging remove the merged fields.

modelNew = removeFieldEntriesForType(modelNew,posToMerge,type,numel(modelNew.(type)));  

end




function out = getSlice(A,idx,dim)
%Get a slice from a given matrix/vector 
% USAGE:
%    out = getSlice(A,idx,dim)
%
% INPUTS:
%    A:               The matrix/vector to obtain a slice from
%    idx:             the indices in the given dimension to extract
%    dim:             The dimension to obtain the given indices from.
%
%
% OUTPUT:
%
%    out:             A slice from the matix/vector with the given indices
%
% Note:  
%     Based on https://stackoverflow.com/questions/22537326/on-shape-agnostic-slicing-of-ndarrays
%
% .. Authors:
%                   - Thomas Pfau Sept 2017

slice = repmat({':'},1, ndims(A));
slice{dim} = idx;
out = A(slice{:});
end

function A = setSlice(A,idx,dim,B)
%Set a slice from a given matrix/vector 
% USAGE:
%    A = setSlice(A,idx,dim,B)
%
% INPUTS:
%    A:               The matrix/vector to obtain a slice from
%    idx:             the indices in the given dimension to extract
%    dim:             The dimension to obtain the given indices from.
%    B:               The values to set at the given position
%
% OUTPUT:
%    A:             A slice from the matix/vector with the given indices
%
% Note:  
%     Based on https://stackoverflow.com/questions/22537326/on-shape-agnostic-slicing-of-ndarrays
%
% .. Authors:
%                   - Thomas Pfau Sept 2017

slice = repmat({':'},1, ndims(A));
slice{dim} = idx;
%If B is a cell array of cell arrays
A(slice{:}) = B;
end