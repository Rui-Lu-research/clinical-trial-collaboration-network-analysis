# Data and analytical definitions

## I. Source snapshot

| Item | Description |
|---|---|
| Source | ClinicalTrials.gov registry export |
| Recorded download date | November 2, 2026, as recorded in the project notes |
| Included sample | 3,432 unique NCT records; all marked INTERVENTIONAL; start years 2020–2024 |
| Topic | Lung cancer trial records in the supplied extract |
| Raw file | `clinical_trials_lung_cancer_2020_2024_raw.csv` |
| MD5 | `0adfba613c653f6cbacdd15e5d25435e` |
| Exact historical search expression | Not retained; the included snapshot defines the sample |
| Missing site fields | 248 records (7.2%); retained in annual trial denominators |

The study start year is derived from `Start Date`; the registry download date is a different date. Records include several recruitment and completion statuses. This is a retrospective analysis of the included sample, not a count of trials active at the same moment.

The raw CSV is unchanged. Organization names are adjusted only in memory when building sponsor–collaborator pairs. The filename describes the study-start period, not the download date. ClinicalTrials.gov is the original data source; the repository does not claim ownership of the registry records.

## II. Input fields

| Field | Use |
|---|---|
| `NCT Number` | Unique study identifier; prevents duplicate trial records |
| `Study Title`, `Study URL` | Source context and study lookup |
| `Conditions`, `Interventions` | Clinical context; not model predictors in this script |
| `Sponsor` | Lead sponsor endpoint in each collaboration pair |
| `Collaborators` | Pipe-separated collaborator endpoints |
| `Study Type` | Describes the included interventional sample |
| `Start Date` | First four characters determine the annual cohort |
| `Study Status`, `Phases`, `Funder Type` | Retained source metadata; not used for stratified analysis |
| `Locations` | Pipe-separated sites; the final comma-delimited field is parsed as country |
| `Last Update Posted` | Source metadata; not used as a study start date |

## III. Network construction

An undirected edge joins a sponsor and a listed collaborator. A given pair is counted once per trial; shared trial counts become edge-frequency weights. The script does not connect every collaborator to every other collaborator in the same trial. Only organizations with at least one recorded tie enter the graph. The 2,347 trials without a listed collaborator remain in the trial-level analysis, but do not create isolated nodes in this edge-only graph.

Whitespace is standardized. Two inherited name-grouping assumptions are applied:

| Source name | Grouped name |
|---|---|
| Jiangsu Hengrui Pharmaceutical Co., Ltd. | Jiangsu HengRui Medicine Co., Ltd. |
| Innovent Biologics, Inc. | Innovent Biologics (Suzhou) Co. Ltd. |

These mappings are explicit analytical choices, not independently verified statements that the named legal entities are identical. Other name variants may remain. Universities and affiliated hospitals are not automatically combined. All headline findings use the same harmonized graph: **1,438 nodes and 1,610 distinct edges**. The unmerged 1,440-node count should not be mixed with these results.

Degree counts distinct partners, not trial volume. Betweenness is normalized within the 998-node largest component, using `weights = NA`. Trial counts are frequencies and are not treated as path distances. The degree top five is selected from the full graph; the betweenness top five is selected within the largest component. All five degree leaders are in the largest component in this sample.

The selected network figure uses the seven highest-betweenness institutions plus other organizations directly tied to at least two of them. It contains 29 nodes and 53 edges. Colors in both network figures encode the categories stated in their legends, not detected communities or nationality.

## IV. Removal scenarios

The top-five bridge and top-five degree groups are each removed simultaneously from the original full graph. The random benchmark samples five original nodes without replacement within each of 50 independent draws, using seed 42. Largest-component shares always divide by the original **1,438** nodes, rather than the surviving 1,433 nodes.

No edges are added after removal and no institutions adapt or find replacement partners. This tests static structural sensitivity, not operational disruption probabilities, trial delays, or losses.

## V. Geographic denominators

| Category | Definition |
|---|---|
| China only | Every country field extracted from the recorded sites equals `China` |
| US only | Every extracted country field equals `United States` |
| China and US | Both countries appear among recorded sites; other countries may also appear |
| Annual denominator | All records with a start year equal to that year, including missing sites |

These categories do not cover every trial. Other international or domestic configurations and missing sites account for the remainder. The parser is specific to the supplied export and does not standardize every possible country label. “China only” describes the recorded site footprint, not the nationality of its sponsor, its collaborators, or its patients. A trial with both-country sites does not by itself demonstrate a sponsor–collaborator relationship between Chinese and US institutions.

## VI. Repeated collaboration denominators

- **Distinct pairs:** 1,610; recurring means a pair appears in more than one trial
- **Recurring pairs:** 124 (7.7% of distinct pairs)
- **Pair-trial events:** 1,849; a study with multiple collaborators may contribute multiple events
- **Events from recurring pairs:** 363 (19.6% of pair-trial events)

The 19.6% figure is not the share of all 3,432 trials. Frequency is measured within the included window; the script does not measure relationship continuity, contractual commitment, or strategic intent.

## VII. Generated outputs

| Output | Rows and columns |
|---|---|
| `results/centrality.csv` | 998 organizations in the largest component; `organization`, `degree`, `betweenness`; sorted by decreasing betweenness |
| `results/removal.csv` | Four scenarios; `scenario`, `percentage`; percentage of original graph nodes in the largest remaining component |
| `results/geography.csv` | Five start-year cohorts; `year`, `all_trials`, `china_only`, `us_only`, `china_and_us`, and the corresponding three percentage columns |
| `results/partnerships.csv` | One-time and recurring categories; `type`, `pairs`, `percentage`; denominator is all distinct pairs |

Six PNG files correspond to the six figures in the script. They were exported for this repository; running `analysis.R` updates the CSV files and displays figures without overwriting PNGs. Recommendations in the written results are interpretations of these outputs, not additional model estimates.
