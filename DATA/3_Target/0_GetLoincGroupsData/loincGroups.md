# loincGroups stats

Summary of `loincGroups.tsv`: 2,997 LOINC Groups holding 7,563 standard `Measurement` concepts (`loincGroupMembership.tsv`).

# Groups

A Group has a harmonised unit when lab2clean gives it a reference unit.

| groups | n groups | % groups |
| --- | --- | --- |
| with a harmonised unit | 1,701 | 56.8% |
| with no harmonised unit | 1,296 | 43.2% |
| total | 2,997 | 100% |

# has_property

The kind of quantity of the Group, the `has_property` of its concepts (`measurementOmopData.tsv`) leaving out the conventional concepts mapped from their SI partner (they are converted, not a property of their own) and `Presence or Threshold`: `(several)` when the rest differ, `(none)` when no concept has one. `n also PS` is the Groups that also hold `Presence or Threshold` concepts next to that property: those concepts also map to a presence/threshold result, which has no unit.

| has_property | n groups | % groups | n also PS | n with no unit |
| --- | --- | --- | --- | --- |
| Mass Concentration | 566 | 18.9% | 15 | 66 |
| Presence or Threshold | 509 | 17.0% | 0 | 509 |
| Susceptibility (microorganisms) | 376 | 12.5% | 2 | 376 |
| Arbitrary Concentration | 301 | 10.0% | 2 | 22 |
| Substance Concentration | 294 | 9.8% | 2 | 19 |
| Number Concentration | 158 | 5.3% | 2 | 19 |
| Substance Ratio | 131 | 4.4% | 0 | 12 |
| Mass Ratio | 108 | 3.6% | 0 | 12 |
| (several) | 92 | 3.1% | 73 | 92 |
| Impression/interpretation of study | 83 | 2.8% | 0 | 83 |
| Titer | 79 | 2.6% | 0 | 0 |
| Ratio | 54 | 1.8% | 0 | 2 |
| Mass Rate | 47 | 1.6% | 0 | 11 |
| Catalytic Concentration | 43 | 1.4% | 0 | 2 |
| Mass fraction | 22 | 0.7% | 0 | 1 |
| Number Areic (per area) | 22 | 0.7% | 19 | 20 |
| Presence or Identity | 22 | 0.7% | 2 | 22 |
| Substance Rate | 17 | 0.6% | 0 | 3 |
| Log molar concentration | 12 | 0.4% | 0 | 1 |
| Decimal mass fraction | 8 | 0.3% | 0 | 7 |
| Catalytic Fraction | 6 | 0.2% | 0 | 0 |
| Catalytic Content | 5 | 0.2% | 0 | 0 |
| Specific gravity | 5 | 0.2% | 0 | 4 |
| Osmolality | 3 | 0.1% | 0 | 0 |
| Pressure | 3 | 0.1% | 0 | 3 |
| Score | 3 | 0.1% | 0 | 0 |
| Energy Difference | 2 | 0.1% | 0 | 0 |
| Length | 2 | 0.1% | 0 | 2 |
| Mass Content | 2 | 0.1% | 0 | 1 |
| Number (count) | 2 | 0.1% | 0 | 0 |
| Number Fraction | 2 | 0.1% | 0 | 0 |
| Number Rate | 2 | 0.1% | 0 | 2 |
| Partial pressure | 2 | 0.1% | 0 | 0 |
| Volume Rate | 2 | 0.1% | 0 | 0 |
| Volume Rate/Area | 2 | 0.1% | 0 | 0 |
| Catalytic Rate | 1 | 0.0% | 0 | 0 |
| Catalytic Ratio | 1 | 0.0% | 0 | 0 |
| Color | 1 | 0.0% | 0 | 1 |
| Mass | 1 | 0.0% | 0 | 1 |
| Scale | 1 | 0.0% | 0 | 1 |
| Substance Content | 1 | 0.0% | 0 | 0 |
| Temperature | 1 | 0.0% | 0 | 1 |
| Time (e.g. seconds) | 1 | 0.0% | 0 | 0 |
| Type | 1 | 0.0% | 0 | 1 |
| Volume | 1 | 0.0% | 0 | 0 |
| total | 2,997 | 100% | 117 | 1,296 |
