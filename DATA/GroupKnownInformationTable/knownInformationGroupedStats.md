# Known Information Grouped -- Stats

Source: `DATA/GroupKnownInformationTable/knownInformationGrouped.tsv`

Group sizes measured two ways: how many distinct `TEST_NAME`s landed in a
group, and how many `TEST_NAME`+`UNIT` rows that pulled in (a `TEST_NAME`
with several units counts once in the first, several times in the
second).

n groups: 170

| metric | mean | min | max |
|---|---|---|---|
| distinct TEST_NAME per group | 54.2 | 1 | 100 |
| TEST_NAME+UNIT rows per group | 81.2 | 2 | 210 |

## Dendrogram

The tree of splits that produced the groups, reconstructed from every
group's `group_path`. Each leaf is a final group, labelled with its
`group_id` and its number of distinct `TEST_NAME`s (`n=`); unlabelled
branch points are splits that were still above `--group-size` and so got
divided further.

```
groups
├── 1
│   ├── 1
│   │   ├── 1 (group_id=1, n=67)
│   │   └── 2
│   │       ├── 1 (group_id=2, n=62)
│   │       └── 2
│   │           ├── 1 (group_id=3, n=68)
│   │           └── 2
│   │               ├── 1 (group_id=4, n=12)
│   │               └── 2
│   │                   ├── 1 (group_id=5, n=69)
│   │                   └── 2 (group_id=6, n=77)
│   └── 2
│       ├── 1
│       │   ├── 1
│       │   │   ├── 1 (group_id=7, n=13)
│       │   │   └── 2
│       │   │       ├── 1
│       │   │       │   ├── 1 (group_id=8, n=58)
│       │   │       │   └── 2 (group_id=9, n=86)
│       │   │       └── 2 (group_id=10, n=23)
│       │   └── 2 (group_id=11, n=60)
│       └── 2
│           ├── 1
│           │   ├── 1 (group_id=12, n=96)
│           │   └── 2
│           │       ├── 1 (group_id=13, n=84)
│           │       └── 2
│           │           ├── 1 (group_id=14, n=43)
│           │           └── 2
│           │               ├── 1 (group_id=15, n=36)
│           │               └── 2
│           │                   ├── 1 (group_id=16, n=49)
│           │                   └── 2
│           │                       ├── 1 (group_id=17, n=41)
│           │                       └── 2
│           │                           ├── 1 (group_id=18, n=26)
│           │                           └── 2
│           │                               ├── 1 (group_id=19, n=17)
│           │                               └── 2
│           │                                   ├── 1 (group_id=20, n=45)
│           │                                   └── 2
│           │                                       ├── 1 (group_id=21, n=18)
│           │                                       └── 2
│           │                                           ├── 1 (group_id=22, n=27)
│           │                                           └── 2
│           │                                               ├── 1 (group_id=23, n=29)
│           │                                               └── 2
│           │                                                   ├── 1 (group_id=24, n=20)
│           │                                                   └── 2
│           │                                                       ├── 1 (group_id=25, n=22)
│           │                                                       └── 2
│           │                                                           ├── 1 (group_id=26, n=96)
│           │                                                           └── 2 (group_id=27, n=12)
│           └── 2
│               ├── 1 (group_id=28, n=36)
│               └── 2
│                   ├── 1 (group_id=29, n=57)
│                   └── 2
│                       ├── 1 (group_id=30, n=1)
│                       └── 2
│                           ├── 1 (group_id=31, n=27)
│                           └── 2
│                               ├── 1 (group_id=32, n=32)
│                               └── 2
│                                   ├── 1 (group_id=33, n=21)
│                                   └── 2
│                                       ├── 1 (group_id=34, n=18)
│                                       └── 2
│                                           ├── 1 (group_id=35, n=11)
│                                           └── 2
│                                               ├── 1 (group_id=36, n=27)
│                                               └── 2 (group_id=37, n=99)
└── 2
    ├── 1
    │   ├── 1
    │   │   ├── 1
    │   │   │   ├── 1
    │   │   │   │   ├── 1 (group_id=38, n=54)
    │   │   │   │   └── 2 (group_id=39, n=80)
    │   │   │   └── 2
    │   │   │       ├── 1 (group_id=40, n=73)
    │   │   │       └── 2
    │   │   │           ├── 1
    │   │   │           │   ├── 1 (group_id=41, n=29)
    │   │   │           │   └── 2 (group_id=42, n=74)
    │   │   │           └── 2
    │   │   │               ├── 1 (group_id=43, n=55)
    │   │   │               └── 2 (group_id=44, n=68)
    │   │   └── 2
    │   │       ├── 1
    │   │       │   ├── 1 (group_id=45, n=54)
    │   │       │   └── 2 (group_id=46, n=60)
    │   │       └── 2 (group_id=47, n=96)
    │   └── 2
    │       ├── 1
    │       │   ├── 1
    │       │   │   ├── 1 (group_id=48, n=38)
    │       │   │   └── 2 (group_id=49, n=64)
    │       │   └── 2
    │       │       ├── 1
    │       │       │   ├── 1
    │       │       │   │   ├── 1 (group_id=50, n=71)
    │       │       │   │   └── 2 (group_id=51, n=66)
    │       │       │   └── 2
    │       │       │       ├── 1 (group_id=52, n=89)
    │       │       │       └── 2
    │       │       │           ├── 1 (group_id=53, n=20)
    │       │       │           └── 2
    │       │       │               ├── 1 (group_id=54, n=52)
    │       │       │               └── 2
    │       │       │                   ├── 1
    │       │       │                   │   ├── 1 (group_id=55, n=12)
    │       │       │                   │   └── 2 (group_id=56, n=98)
    │       │       │                   └── 2
    │       │       │                       ├── 1 (group_id=57, n=54)
    │       │       │                       └── 2 (group_id=58, n=67)
    │       │       └── 2
    │       │           ├── 1
    │       │           │   ├── 1
    │       │           │   │   ├── 1 (group_id=59, n=100)
    │       │           │   │   └── 2 (group_id=60, n=48)
    │       │           │   └── 2
    │       │           │       ├── 1
    │       │           │       │   ├── 1 (group_id=61, n=70)
    │       │           │       │   └── 2 (group_id=62, n=97)
    │       │           │       └── 2
    │       │           │           ├── 1 (group_id=63, n=36)
    │       │           │           └── 2 (group_id=64, n=67)
    │       │           └── 2
    │       │               ├── 1
    │       │               │   ├── 1 (group_id=65, n=51)
    │       │               │   └── 2
    │       │               │       ├── 1 (group_id=66, n=56)
    │       │               │       └── 2
    │       │               │           ├── 1 (group_id=67, n=54)
    │       │               │           └── 2 (group_id=68, n=75)
    │       │               └── 2
    │       │                   ├── 1 (group_id=69, n=57)
    │       │                   └── 2
    │       │                       ├── 1 (group_id=70, n=92)
    │       │                       └── 2 (group_id=71, n=59)
    │       └── 2
    │           ├── 1
    │           │   ├── 1 (group_id=72, n=49)
    │           │   └── 2
    │           │       ├── 1
    │           │       │   ├── 1 (group_id=73, n=30)
    │           │       │   └── 2
    │           │       │       ├── 1 (group_id=74, n=27)
    │           │       │       └── 2 (group_id=75, n=91)
    │           │       └── 2 (group_id=76, n=87)
    │           └── 2
    │               ├── 1
    │               │   ├── 1
    │               │   │   ├── 1
    │               │   │   │   ├── 1
    │               │   │   │   │   ├── 1 (group_id=77, n=47)
    │               │   │   │   │   └── 2 (group_id=78, n=82)
    │               │   │   │   └── 2
    │               │   │   │       ├── 1 (group_id=79, n=31)
    │               │   │   │       └── 2
    │               │   │   │           ├── 1
    │               │   │   │           │   ├── 1 (group_id=80, n=54)
    │               │   │   │           │   └── 2 (group_id=81, n=64)
    │               │   │   │           └── 2 (group_id=82, n=89)
    │               │   │   └── 2
    │               │   │       ├── 1
    │               │   │       │   ├── 1
    │               │   │       │   │   ├── 1 (group_id=83, n=34)
    │               │   │       │   │   └── 2
    │               │   │       │   │       ├── 1 (group_id=84, n=25)
    │               │   │       │   │       └── 2
    │               │   │       │   │           ├── 1
    │               │   │       │   │           │   ├── 1 (group_id=85, n=28)
    │               │   │       │   │           │   └── 2 (group_id=86, n=86)
    │               │   │       │   │           └── 2
    │               │   │       │   │               ├── 1 (group_id=87, n=40)
    │               │   │       │   │               └── 2 (group_id=88, n=83)
    │               │   │       │   └── 2
    │               │   │       │       ├── 1
    │               │   │       │       │   ├── 1 (group_id=89, n=26)
    │               │   │       │       │   └── 2 (group_id=90, n=92)
    │               │   │       │       └── 2
    │               │   │       │           ├── 1 (group_id=91, n=86)
    │               │   │       │           └── 2
    │               │   │       │               ├── 1 (group_id=92, n=83)
    │               │   │       │               └── 2 (group_id=93, n=83)
    │               │   │       └── 2
    │               │   │           ├── 1
    │               │   │           │   ├── 1
    │               │   │           │   │   ├── 1 (group_id=94, n=15)
    │               │   │           │   │   └── 2 (group_id=95, n=93)
    │               │   │           │   └── 2
    │               │   │           │       ├── 1 (group_id=96, n=58)
    │               │   │           │       └── 2 (group_id=97, n=57)
    │               │   │           └── 2
    │               │   │               ├── 1
    │               │   │               │   ├── 1 (group_id=98, n=53)
    │               │   │               │   └── 2
    │               │   │               │       ├── 1
    │               │   │               │       │   ├── 1 (group_id=99, n=27)
    │               │   │               │       │   └── 2 (group_id=100, n=85)
    │               │   │               │       └── 2
    │               │   │               │           ├── 1 (group_id=101, n=19)
    │               │   │               │           └── 2
    │               │   │               │               ├── 1 (group_id=102, n=56)
    │               │   │               │               └── 2 (group_id=103, n=60)
    │               │   │               └── 2 (group_id=104, n=90)
    │               │   └── 2
    │               │       ├── 1
    │               │       │   ├── 1 (group_id=105, n=41)
    │               │       │   └── 2
    │               │       │       ├── 1 (group_id=106, n=62)
    │               │       │       └── 2
    │               │       │           ├── 1 (group_id=107, n=54)
    │               │       │           └── 2 (group_id=108, n=56)
    │               │       └── 2
    │               │           ├── 1
    │               │           │   ├── 1
    │               │           │   │   ├── 1 (group_id=109, n=52)
    │               │           │   │   └── 2
    │               │           │   │       ├── 1 (group_id=110, n=46)
    │               │           │   │       └── 2
    │               │           │   │           ├── 1 (group_id=111, n=33)
    │               │           │   │           └── 2 (group_id=112, n=75)
    │               │           │   └── 2
    │               │           │       ├── 1
    │               │           │       │   ├── 1 (group_id=113, n=54)
    │               │           │       │   └── 2
    │               │           │       │       ├── 1 (group_id=114, n=61)
    │               │           │       │       └── 2
    │               │           │       │           ├── 1 (group_id=115, n=46)
    │               │           │       │           └── 2 (group_id=116, n=56)
    │               │           │       └── 2
    │               │           │           ├── 1
    │               │           │           │   ├── 1 (group_id=117, n=62)
    │               │           │           │   └── 2
    │               │           │           │       ├── 1 (group_id=118, n=27)
    │               │           │           │       └── 2 (group_id=119, n=75)
    │               │           │           └── 2
    │               │           │               ├── 1
    │               │           │               │   ├── 1
    │               │           │               │   │   ├── 1 (group_id=120, n=63)
    │               │           │               │   │   └── 2 (group_id=121, n=73)
    │               │           │               │   └── 2 (group_id=122, n=67)
    │               │           │               └── 2 (group_id=123, n=89)
    │               │           └── 2
    │               │               ├── 1 (group_id=124, n=82)
    │               │               └── 2 (group_id=125, n=51)
    │               └── 2
    │                   ├── 1
    │                   │   ├── 1 (group_id=126, n=24)
    │                   │   └── 2 (group_id=127, n=100)
    │                   └── 2
    │                       ├── 1 (group_id=128, n=47)
    │                       └── 2
    │                           ├── 1
    │                           │   ├── 1 (group_id=129, n=26)
    │                           │   └── 2
    │                           │       ├── 1 (group_id=130, n=22)
    │                           │       └── 2
    │                           │           ├── 1
    │                           │           │   ├── 1 (group_id=131, n=39)
    │                           │           │   └── 2 (group_id=132, n=68)
    │                           │           └── 2 (group_id=133, n=29)
    │                           └── 2 (group_id=134, n=44)
    └── 2
        ├── 1
        │   ├── 1
        │   │   ├── 1 (group_id=135, n=34)
        │   │   └── 2
        │   │       ├── 1 (group_id=136, n=81)
        │   │       └── 2 (group_id=137, n=85)
        │   └── 2
        │       ├── 1
        │       │   ├── 1 (group_id=138, n=52)
        │       │   └── 2 (group_id=139, n=59)
        │       └── 2
        │           ├── 1
        │           │   ├── 1 (group_id=140, n=26)
        │           │   └── 2 (group_id=141, n=87)
        │           └── 2
        │               ├── 1
        │               │   ├── 1 (group_id=142, n=47)
        │               │   └── 2
        │               │       ├── 1
        │               │       │   ├── 1 (group_id=143, n=17)
        │               │       │   └── 2
        │               │       │       ├── 1 (group_id=144, n=21)
        │               │       │       └── 2 (group_id=145, n=95)
        │               │       └── 2
        │               │           ├── 1 (group_id=146, n=48)
        │               │           └── 2
        │               │               ├── 1
        │               │               │   ├── 1 (group_id=147, n=94)
        │               │               │   └── 2 (group_id=148, n=42)
        │               │               └── 2 (group_id=149, n=33)
        │               └── 2
        │                   ├── 1 (group_id=150, n=29)
        │                   └── 2
        │                       ├── 1 (group_id=151, n=83)
        │                       └── 2 (group_id=152, n=67)
        └── 2
            ├── 1
            │   ├── 1
            │   │   ├── 1 (group_id=153, n=44)
            │   │   └── 2
            │   │       ├── 1 (group_id=154, n=29)
            │   │       └── 2
            │   │           ├── 1
            │   │           │   ├── 1 (group_id=155, n=23)
            │   │           │   └── 2
            │   │           │       ├── 1 (group_id=156, n=51)
            │   │           │       └── 2 (group_id=157, n=93)
            │   │           └── 2
            │   │               ├── 1 (group_id=158, n=85)
            │   │               └── 2
            │   │                   ├── 1 (group_id=159, n=73)
            │   │                   └── 2
            │   │                       ├── 1
            │   │                       │   ├── 1 (group_id=160, n=12)
            │   │                       │   └── 2
            │   │                       │       ├── 1 (group_id=161, n=35)
            │   │                       │       └── 2 (group_id=162, n=75)
            │   │                       └── 2 (group_id=163, n=31)
            │   └── 2
            │       ├── 1 (group_id=164, n=26)
            │       └── 2 (group_id=165, n=97)
            └── 2
                ├── 1 (group_id=166, n=40)
                └── 2
                    ├── 1
                    │   ├── 1 (group_id=167, n=31)
                    │   └── 2
                    │       ├── 1 (group_id=168, n=55)
                    │       └── 2 (group_id=169, n=71)
                    └── 2 (group_id=170, n=75)
```
