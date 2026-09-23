# Plan & Assumptions

## Plan

**Goal:** to produce a score on the KS2 scale (80 to 120) for every pupil in every subject. As per the requirements, this will be re-runnable, queryable as of any date, and ready to load into the app database. Or as far as I get in the few hours :)

**Scoring:** each pupil's % correct is turned into the equivalent raw mark on the real KS2 paper, which is then looked up in the DfE's 2026 conversion table (STA, GOV.UK, 16 July 2026). For example, 7/12 in maths is 64 of 110 marks, which scores **101**. 

Using the published curve rather than a straight line means every score traces back to a government table. 

**How the pieces fit together:** The 4 raw tables from de_raw will flow through 4 base views and 2 reference tables into 1 final output table. 

```
landing (de_raw)          base (views)                             analytics (table)

responses            ->   base_responses                   ──┐
assessment_sittings  ->   base_assessment_sittings         ──┤
pupils               ->   base_pupils                      ──| ->  analytics_pupil_subject_sats_score
course_hierarchy     ->   base_course_hierarchy            ──┤
                                                             │
                          reference (seed tables)            │
                          ref_subject_sats_mapping         ──┤
                          ref_ks2_scaled_score_conversion  ──┘
```

| Object | One row per | Job |
|---|---|---|
| `base_responses` | sitting × question | Removes duplicate answers, keeping the last one |
| `base_assessment_sittings` | sitting | Standardises text; nulls impossible year groups |
| `base_pupils` | pupil | Pass-through, so raw is only read in one place |
| `base_course_hierarchy` | question | Links each question to its subject |
| `ref_subject_sats_mapping` | Atom subject | Which KS2 curve each subject uses, or "not scored" |
| `ref_ks2_scaled_score_conversion` | test × raw mark | DfE's 2026 raw mark → scaled score table |
| `pupil_subject_sats_score` | pupil × subject × score change | **The final output** |

## Assumptions

1. **A score means "on track for their year group".** 100 means working at the expected standard for their year, not a prediction of their Year 6 SATs. This assumes each paper is set at the pupil's own year level. It's the weakest assumption: 23 of 112 papers are sat by more than one year group.
2. **Only real test attempts count.** Sittings must be finished, not deleted, and a fixed set of questions. Adaptive tests and surveys are left out.
3. **Skipped questions count as wrong, and retakes don't count.** This is how a real paper is marked. On a retake the pupil has already seen the questions, so only the first attempt is used.
4. **Scores use the last 12 months of tests.** One test alone is too few questions to be reliable.
5. **We use the DfE's 2026 conversion table for all dates.** Using one table means a score only changes because the pupil changed, not because the DfE moved its thresholds. Pupils below the lowest mark on the table get 80.
6. **Subjects are matched to the nearest SATs test.** Maths and English (reading) match directly. Verbal Reasoning (reading) and Non-Verbal Reasoning (maths) have no SATs test, so they are flagged as estimates. Science, Screeners and Wellbeing are not scored.
7. **No evidence means no score.** A pupil with no tests in a subject has no row, rather than a made-up number.
8. **Past scores are rebuilt from today's data.** A score "as at" a past date shows what it would have been, using everything we know now. It can't show exactly what a dashboard displayed then, because the data doesn't record when things were deleted.
## Data issues found

| Issue | Scale | Handling |
|---|---|---|
| Same question answered more than once in a sitting | 2,082 pairs, up to 5×; 1,304 are identical events | Keep the last answer (tie-break on `response_id`) |
| Responses with no sitting | 1,433 responses / 56 sessions | Excluded; picked up on the next rebuild once the sitting lands |
| `responses.session_type` is `MOCK_TEST` on every row | 100% | Ignored; `assessment_sittings.session_type` is used instead |
| Wellbeing is a survey but has `is_correct` values | 125 sittings | Excluded by `style = 'survey'` |
| Year groups 11, 14, 15 in a primary product | 25 sittings | Year set to NULL; sitting still scored |
| Complete sittings with fewer responses than `total_questions` | 9 | Denominator is responses present. Skips are recorded explicitly, so a missing response looks like data loss, not a wrong answer |
| Incomplete sittings; complete sittings with no responses | 13; 68 | Excluded; contribute nothing |
| Retakes of the same paper | 5 pupil-papers | First attempt only |
| Live pupils with no usable responses | 78 of 242 | No row (no score) |
| Thin subjects | NVR 3 pupils, VR 8; Science 0 | Scored, flagged as proxy |
| No deletions anywhere in the data | 0 | Deletion logic is written but untested on real data |
| Raw tables unpartitioned; every column nullable | all | Recommend partitioning `responses` on `answered_at` before going incremental |
