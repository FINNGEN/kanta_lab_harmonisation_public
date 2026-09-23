

# PLAN

## Map finnish codes to the 6 axes of the LOINC + is_pannel


INITIAl data: 
test_unit_counts.txt 

NAME	UNIT	COUNT	%MISSING

- filter by n more than 500
- Create initial table with name, code, unit, values, missing, is_pannel and 6 dimension 

1. Gather known information 
 - Fill as much of that table as we know from strucuture sources : eg list of Systems, kodisto palvely names, etc

2. LLM to complete information
 - Group rows by string distance in 50 codes buckets 
 - Prompt: LOINC gideliles, Finnland code system, etc, list of Scale, list of Time, most common Properties in our current data?
 - Prompt output complete missing cels in table if possible, most important is Component, System, Property
 - Text table to Structure table: use Hecate to find the conceptids for the dimmension lables, ask the llm to pic the correct one

3. Map to LOINC: 
 - Map the 6 dimensions + is_panel to the LOINC
 - If not mapped, look for close Componenent, System 
 - If not System then ask if any default to use 

 4. Correction of the table: 
 - Group by similar Comopone names 
 - Make a prompt asking if any of these belong to any of the other groups 
 - Same for system ?

 5. Compare with current mappings 

 6. Group based on Componets and System



## Once mapped as precise as possible, join them in compatible groups with same values 