# Atom Learning take-home: SATs scores, Harrys solution 

## Plan

The goal was a SATs-style score (80–120) for every pupil in every subject. The score needed to be re-runnable, able to show what it was at any point in time, and in a shape that could move into an app database. Or as far as I can get in 2 hours :) 

My approach:

1. Explore the raw data first, to find anything that would break the score. 
2. Clean it in a base layer. These will be views.
3. Do all the scoring in one analytics table.

For the scoring I used the DfE's own 2026 KS2 conversion tables from GOV.UK. A pupil's % correct is turned into the equivalent raw mark on the real SATs paper, then looked up in the table. For example, 7/12 in maths is 64 out of 110 marks, which is a scaled score of 101. That way every score traces back to a published table rather than a curve I made up.

The final table is `analytics_pupil_subject_sats_score`. 164 of 242 pupils have a score. The median is 103 in English and 101 in maths.

## EDA

The queries can be found in AI_USAGE, as I worked with Claude cowork to dive into this data quickly. Most of the data was clean: unique keys, a tidy subject hierarchy and no broken questions. These are the issues that I flagged:

- **Duplicate answers.** 2,082 questions were answered more than once in the same sitting, up to 5 times. I kept the latest answer.
- **Wellbeing is a survey,** but its questions still have `is_correct` values. Left in, it would have produced a "SATs score" for a wellbeing questionnaire. Surveys are excluded.
- **`responses.session_type` is `MOCK_TEST` on every row** and doesn't match the sittings table. I ignored it and used the sittings version.
- **Orphan responses.** 1,433 responses have no matching sitting. They're left out until the sitting arrives.
- **Bad year groups.** 25 sittings have year groups of 11, 14 or 15. I kept the sittings and blanked the year.
- **Subjects with no SATs equivalent.** Science, Screeners and Wellbeing aren't SATs subjects. Verbal and Non-Verbal Reasoning don't have a SATs test either.
- **No usable data.** 78 of 242 pupils have no usable test data at all.
- **No deleted records anywhere.** The deletion logic is written, but it hasn't been tested on real data.
- **Unpartitioned raw tables.** This will matter at scale (see "What I'd do next").

Smaller things:

- 13 incomplete sittings: excluded.
- 5 retakes of the same paper: first attempt only.
- 9 sittings missing a few responses: scored on what's there.

## Structure

```
LANDING (de_raw)          BASE (views)                             ANALYTICS (table)

responses            ──►  base_responses                   ──┐
assessment_sittings  ──►  base_assessment_sittings         ──┤
pupils               ──►  base_pupils                      ──┼──►  analytics_pupil_subject_sats_score
course_hierarchy     ──►  base_course_hierarchy            ──┤
                                                             │
                          REFERENCE (tables)                 │
                          ref_subject_sats_mapping         ──┤
                          ref_ks2_scaled_score_conversion  ──┘
```

**Base (views).** One view per raw table, doing cleaning only, with no business rules. Nothing else reads raw, so if Atom changes a raw table there's one place to fix it. 

**Reference (tables).** This is data from outside Atom: the DfE conversion table, and which subject maps to which SATs test. Keeping it separate makes it easy to check against the source and easy to update. A new year of SATs is just new rows. 

**Analytics (table).** All the scoring rules sit in one place. There's one row per pupil, subject and score change, with `valid_from` and `valid_to`:

- `WHERE is_current` gives today's score.
- Filtering on the two dates gives the score at any point in time.

It's a full rebuild each time, so running it twice gives the same result.

I considered splitting analytics into several tables. For 63k rows and a two-hour brief, one table covers every requirement. This I would look at to improve on in future.

## Assumptions

1. **A score means "on track for their year group".** 100 means working at the expected standard for their year. It is not a prediction of their Year 6 SATs, and it assumes each paper is set at the pupil's year level. The results back this up for Years 1 to 5, where scores are flat. Year 6 comes out about 3 points higher, which I can't explain from this data.
2. **Only real test attempts count.** A sitting has to be finished, not deleted, and use a fixed set of questions. Adaptive tests and surveys are left out.
3. **Skipped questions count as wrong, and retakes don't count.** That's how a real paper is marked. On a retake the pupil has already seen the questions.
4. **Scores use the last 12 months of tests.** A single test is too few questions to be reliable.
5. **The 2026 DfE table is used for all dates.** That way a score only changes when the pupil does, not when the DfE moves its thresholds. Anything below the lowest mark on the table gets 80.
6. **Subjects are matched to the nearest SATs test.**
   - Maths and English (reading) match directly.
   - Verbal Reasoning (reading) and Non-Verbal Reasoning (maths) have no SATs test, so they're flagged as estimates.
   - Science, Screeners and Wellbeing aren't scored.
7. **No evidence means no score.** A pupil with no tests in a subject has no row, rather than a made-up number.
8. **Past scores are rebuilt from today's data.** It can't show exactly what a dashboard displayed back then, because the data doesn't record when things were deleted.

## AI usage

I used AI for planning, the first round of EDA from initial query ideas I mapped out, code PR reviews, and finally for writing the queries I mapped out for checking the output. Details are in AI_USAGE.md doc!

## What I'd do next

1. **Productionise it.**
   - Move to Dataform: convert the `CREATE VIEW` / `CREATE TABLE` scripts to SQLX files with `ref()`, so dependencies and run order are handled for me.
   - Model the base and analytics layers properly as Dataform layers.
   - Set up dev and prod environments, and schedule the runs. 
   - Add assertions that fail the run if something's wrong: one current score per pupil and subject, scores between 80 and 120, and the KS2 table matching GOV.UK. I checked these by hand this time.
2. **Handle the extra 100m+ responses.** Only one step reads responses: counting answers per sitting and subject.
   - Pull that step out into an incremental table keyed on `session_id` and `subject_id`, so each run only reprocesses recent sittings.
   - Partition raw `responses` by `answered_at` and cluster on `pupil_id`, so those runs only scan new data.
   - Everything after that step works on sittings, which stays small.
3. **More analytics tables.** A couple of ideas that sprung out to mind whilst looking at the final results:
   - **Topic-level scores**, so a teacher can see which topics a pupil is weakest in. The course hierarchy already supports this.
   - **Term-on-term progress:** how much each pupil's score has moved since last term, to flag anyone who is falling behind.

My answer to the optional Step 3 is in Step3_GCSE_Prediction.md

Thanks for reading!
