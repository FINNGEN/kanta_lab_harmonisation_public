


# slide 1

compare the number v3 vs v4 

name	unit	value	n rows	% rows	n records	% records
X	X	X	8606	32.3%	179527254	69.8%
X	X		150	0.6%	17034	0.0%
X		X	3541	13.3%	61271567	23.8%
X			14316	53.8%	16547150	6.4%
total			26613	100.0%	257363005	100.0%
(source DATA_v3/1_GetSummaryData/labSummaryStats.md#name--unit--value-coverage)

name	unit	value	n rows	% rows	n records	% records
X	X	X	8745	32.6%	212508947	82.4%
X	X		170	0.6%	31102	0.0%
X		X	2928	10.9%	10479927	4.1%
X			14955	55.8%	34795820	13.5%
total			26798	100.0%	257815796	100.0%

DATA_v4/1_GetSummaryData/labSummaryStats.md#name--unit--value-coverage

Message: More values have now a unit



for the following slides use the same example with 5 rows, find good examples that ilustrate some of the messages in the presentation 

# slide 2

Initial data 

show a example table with the 5 example osw with the coumsn 
TEST_NAME	UNIT	n	value_missing_p		value_deciles

#  slide 3

weAppend the iinfomation we could find 
- name if in the koodistopalvely
- prefix or sufix if in the document we found 

show an example of the 5 rows we use as example with the new added 3 columns 

# slide 4

groupping the codes by string simialrity in buckets of size 100

- show stats on how many buckets 
- show what limit we use in the counts from now on I think it was n more than 100

# slide 5

buckets sends for guessing a loinc

add link to a example cache prompt 

show table with the guess for the 5 example rows and the guess loinc 

# slide 6 

use hecate to find the possible candidates
ask llm again 
add link to samEexample chache promt now in the fixloinc step


show table with the guess for the 5 example rows and the picked loinc

# slide 7 
table in 

overview in the evaluate mappings 

step	n_codes	p_codes	n_events	p_events
total	2,687	100.0%	51,790,415	100.0%
has a guessed loinc	2,577	95.9%	51,567,886	99.6%
has a fixed loinc	2,077	77.3%	47,581,148	91.9%
exists in reference	1,209	45.0%	50,528,414	97.6%
agrees with reference (concept id)	742	27.6%	40,275,283	77.8%
agrees with reference (LOINC Group)	845	31.4%	41,457,043	80.0%


and 

evidence_level	n_codes	n_ai_mapped	n_agree	n_agree_group	p_codes	p_ai_mapped	p_agree	p_agree_group
name+unit+values	590	570	428	485	48.8%	96.6%	75.1%	85.1%
name	441	292	177	210	36.5%	66.2%	60.6%	71.9%
name+values	138	136	107	114	11.4%	98.6%	78.7%	83.8%
name+unit	40	39	30	36	3.3%	97.5%	76.9%	92.3%
total	1209	1037	742	845	100.0%	85.8%	71.6%	81.5%

message here 
- mot lost is due to name only not finding a loinc bcs the unit is needed to find the corect quantity 
- most disagreements die to small things but belong to same group 

