# 1_Input

Steps that work on the data to be mapped. They read and write `DATA/1_Input/`.
Run them in this order:

| Step | Purpose |
|---|---|
| `1_BuildKantaAgregatedTable` | Combine the Kanta aggregated tables into one long `KantaAgregatedTable`. |

`0_KantaAgregatedData` is the input of the block (copied in from outside this
repo), not a step.
