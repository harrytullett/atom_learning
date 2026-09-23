-- Checks on the built tables. Run each block on its own.

-- 1. Health check. Everything not starting with info_ should be 0.
WITH
s AS (
  SELECT * FROM harry_tullett.pupil_subject_sats_score
),
per_pupil_subject AS (
  SELECT
    pupil_id,
    subject_id,
    COUNTIF(is_current)        AS n_current,
    COUNT(*)                   AS n_rows,
    COUNT(DISTINCT valid_from) AS n_valid_from
  FROM s
  GROUP BY 1, 2
)
SELECT check_name, n
FROM (
  SELECT
    (SELECT COUNTIF(NOT is_deleted) FROM harry_tullett.base_pupils)          AS info_live_pupils,
    (SELECT COUNT(DISTINCT pupil_id) FROM s)                              AS info_pupils_with_a_score,
    (SELECT COUNT(*) FROM per_pupil_subject)                              AS info_pupil_subjects_scored,
    (SELECT COUNT(*) FROM s)                                              AS info_rows,
    (SELECT COUNTIF(is_below_scale_floor) FROM s)                         AS info_below_floor,
    (SELECT COUNTIF(NOT has_sufficient_evidence) FROM s)                  AS info_thin_evidence,
    (SELECT COUNTIF(n_current != 1) FROM per_pupil_subject)               AS not_one_current_row,
    (SELECT COUNTIF(n_rows != n_valid_from) FROM per_pupil_subject)       AS duplicate_valid_from,
    (SELECT COUNTIF(sats_score IS NULL OR sats_score NOT BETWEEN 80 AND 120) FROM s) AS score_out_of_range,
    (SELECT COUNTIF(valid_to <= valid_from) FROM s)                       AS empty_validity_window,
    (SELECT COUNTIF(is_current != (valid_to IS NULL)) FROM s)             AS is_current_mismatch,
    (SELECT COUNTIF(n_correct > n_questions OR pct_correct NOT BETWEEN 0 AND 1) FROM s) AS bad_counts
)
UNPIVOT (n FOR check_name IN (
  info_live_pupils, info_pupils_with_a_score, info_pupil_subjects_scored, info_rows,
  info_below_floor, info_thin_evidence, not_one_current_row, duplicate_valid_from,
  score_out_of_range, empty_validity_window, is_current_mismatch, bad_counts
));


-- 2. KS2 reference table matches GOV.UK (these replace the assertions we took out).
-- Expect:  gps      68 rows, max raw 70,  100 at 34, 110 at 55
--          maths   108 rows, max raw 110, 100 at 56, 110 at 94
--          reading  48 rows, max raw 50,  100 at 25, 110 at 39
SELECT
  sats_subject,
  COUNT(*)                                       AS n_rows,
  MAX(raw_score)                                 AS max_raw,
  MIN(IF(scaled_score >= 100, raw_score, NULL))  AS first_raw_at_100,
  MIN(IF(scaled_score >= 110, raw_score, NULL))  AS first_raw_at_110,
  MIN(scaled_score)                              AS min_scaled,
  MAX(scaled_score)                              AS max_scaled
FROM harry_tullett.ref_ks2_scaled_score_conversion
GROUP BY 1
ORDER BY 1;


-- 3. Current scores by subject. Maths and English should have ~150 pupils each,
-- with medians around 100-106 given the % correct we saw in the EDA.
SELECT
  subject_name,
  sats_subject,
  is_proxy_mapping,
  COUNT(*)                                         AS pupils,
  APPROX_QUANTILES(sats_score, 4)                  AS score_quartiles,
  ROUND(AVG(sats_score), 1)                        AS mean_score,
  ROUND(COUNTIF(sats_score >= 100) / COUNT(*), 2)  AS share_at_100_plus,
  ROUND(COUNTIF(sats_score >= 110) / COUNT(*), 2)  AS share_at_110_plus,
  ROUND(AVG(n_questions))                          AS avg_questions_in_window
FROM harry_tullett.pupil_subject_sats_score
WHERE is_current
GROUP BY 1, 2, 3
ORDER BY pupils DESC;


-- 4. Point in time. The number of scores should grow over time, never with
-- duplicates, and the last date should match the current row count.
SELECT
  as_of,
  COUNT(*)                                                  AS pupil_subjects_with_a_score,
  COUNT(*) - COUNT(DISTINCT CONCAT(pupil_id, '|', subject_id)) AS duplicates,
  ROUND(AVG(sats_score), 1)                                 AS mean_score
FROM harry_tullett.pupil_subject_sats_score
CROSS JOIN UNNEST([
  TIMESTAMP '2025-12-01', TIMESTAMP '2026-03-01', TIMESTAMP '2026-06-01',
  TIMESTAMP '2026-08-01', TIMESTAMP '2026-10-01'
]) AS as_of
WHERE valid_from <= as_of
  AND (valid_to IS NULL OR valid_to > as_of)
GROUP BY 1
ORDER BY 1;


-- 5. One pupil's history, to check by hand. Take any row:
-- n_correct / n_questions x max raw (maths 110, reading 50), round it, and look
-- it up on the GOV.UK table. It should match raw_equivalent and sats_score.
WITH busiest AS (
  SELECT pupil_id, subject_id
  FROM harry_tullett.pupil_subject_sats_score
  GROUP BY 1, 2
  ORDER BY COUNT(*) DESC, pupil_id, subject_id
  LIMIT 1
)
SELECT
  s.pupil_id,
  s.subject_name,
  s.valid_from,
  s.valid_to,
  s.is_current,
  s.n_sittings,
  s.n_questions,
  s.n_correct,
  s.pct_correct,
  s.raw_equivalent,
  s.sats_score
FROM harry_tullett.pupil_subject_sats_score AS s
JOIN busiest USING (pupil_id, subject_id)
ORDER BY s.valid_from;


-- 6. Did the de-duplication work? Base should have no repeats, and at least
-- 2,082 fewer rows than raw (63,707).
SELECT
  (SELECT COUNT(*) FROM `atom-analytics-candidates.de_raw.responses`) AS raw_responses,
  (SELECT COUNT(*) FROM harry_tullett.base_responses)                     AS base_responses,
  (SELECT COUNT(*) FROM (
     SELECT session_id, question_id
     FROM harry_tullett.base_responses
     GROUP BY 1, 2
     HAVING COUNT(*) > 1
   ))                                                                  AS repeats_left_in_base;


-- 7. Mean current score by year group. If scores climb steadily with year
-- group, our papers may not be pitched at each year's level (assumption 1).
-- Worth a line in the README either way.
SELECT
  subject_name,
  year_group,
  COUNT(*)                   AS pupils,
  ROUND(AVG(sats_score), 1)  AS mean_score
FROM harry_tullett.pupil_subject_sats_score
WHERE is_current
  AND subject_name IN ('Maths', 'English')
GROUP BY 1, 2
ORDER BY 1, 2;
