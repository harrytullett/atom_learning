-- analytics_pupil_subject_sats_score
-- One row per pupil, subject and score change.

-- A new row starts each time a pupil finishes a sitting that counts, and
-- valid_to is when the next one started. So:
--   current score: WHERE is_current
--   score on a date: WHERE valid_from <= date AND (valid_to IS NULL OR valid_to > date)

-- How the score works: take the pupil's % correct over the last 12 months,
-- work out what that would be as a raw mark on the real KS2 paper, and look it
-- up in the DfE table. Below 3 marks the DfE doesn't give a score, so we use 80.

-- No row means no evidence, so no score. Subjects we don't score are listed
-- in ref_subject_sats_mapping.

-- The events step is the only part that reads responses. If responses gets to
-- 100m+ rows, that's the bit to pull out into its own incremental table.

CREATE OR REPLACE TABLE harry_tullett.analytics_pupil_subject_sats_score
CLUSTER BY pupil_id, subject_id
AS
WITH
params AS (
  SELECT
    2026 AS conversion_year,  -- one table for all dates, so a score only moves when the pupil does
    'ks2_2026_v1' AS methodology_version,
    20 AS min_questions_for_sufficient_evidence
),

scored_subjects AS (
  SELECT DISTINCT
    h.subject_id,
    h.subject_name,
    m.sats_subject,
    m.is_proxy_mapping
  FROM harry_tullett.base_course_hierarchy AS h
  JOIN harry_tullett.ref_subject_sats_mapping AS m
    ON LOWER(m.subject_name) = LOWER(h.subject_name)
  WHERE m.sats_subject IS NOT NULL
),

scorable_sittings AS (
  SELECT
    s.session_id,
    s.pupil_id,
    s.year_group,
    TIMESTAMP_TRUNC(s.finished_at, SECOND) AS scored_at
  FROM harry_tullett.base_assessment_sittings AS s
  JOIN harry_tullett.base_pupils AS p
    ON p.pupil_id = s.pupil_id
  WHERE s.is_complete
    AND NOT s.is_deleted
    AND NOT p.is_deleted
    -- Only these types and styles count. Adaptive tests and surveys are left
    -- out, and anything new stays out until someone adds it here.
    AND s.session_type IN ('summative_assessment', 'mock_session', 'entrance_exam')
    AND s.style IN ('fixed_question', 'non_adaptive')
  -- If a pupil sits the same paper twice, only the first go counts.
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY s.pupil_id, s.assessment_id
    ORDER BY s.finished_at, s.session_id
  ) = 1
),

-- One row per pupil, subject and finish time. Two sittings finishing in the
-- same second get merged, so the 12-month window below has no ties.
events AS (
  SELECT
    s.pupil_id,
    sub.subject_id,
    sub.subject_name,
    sub.sats_subject,
    sub.is_proxy_mapping,
    s.scored_at,
    MAX(s.year_group) AS year_group,
    COUNT(DISTINCT s.session_id) AS n_sittings,
    COUNT(*) AS n_questions,  -- includes skipped questions, which are never correct, so they count as wrong
    COUNTIF(r.is_correct) AS n_correct
  FROM scorable_sittings AS s
  JOIN harry_tullett.base_responses AS r
    ON r.session_id = s.session_id
  JOIN harry_tullett.base_course_hierarchy AS h
    ON h.question_id = r.question_id
  JOIN scored_subjects AS sub
    ON sub.subject_id = h.subject_id
  GROUP BY 1, 2, 3, 4, 5, 6
),

rolling AS (
  SELECT
    pupil_id,
    subject_id,
    subject_name,
    sats_subject,
    is_proxy_mapping,
    scored_at,
    year_group,
    SUM(n_sittings) OVER last_365_days AS n_sittings,
    SUM(n_questions) OVER last_365_days AS n_questions,
    SUM(n_correct) OVER last_365_days AS n_correct
  FROM events
  WINDOW last_365_days AS (
    PARTITION BY pupil_id, subject_id
    ORDER BY UNIX_SECONDS(scored_at)
    RANGE BETWEEN 31536000 PRECEDING AND CURRENT ROW  -- 365 days in seconds
  )
),

with_raw_equivalent AS (
  SELECT
    r.*,
    p.conversion_year,
    p.methodology_version,
    p.min_questions_for_sufficient_evidence,
    -- Multiply first and round once, so the answer is the same every run.
    CAST(ROUND(CAST(r.n_correct * c.max_raw_score AS NUMERIC) / r.n_questions) AS INT64) AS raw_equivalent
  FROM rolling AS r
  CROSS JOIN params AS p
  JOIN (
    SELECT DISTINCT conversion_year, sats_subject, max_raw_score
    FROM harry_tullett.ref_ks2_scaled_score_conversion
  ) AS c
    ON  c.conversion_year = p.conversion_year
    AND c.sats_subject = r.sats_subject
)

SELECT
  w.pupil_id,
  w.subject_id,
  w.subject_name,
  w.sats_subject,
  w.is_proxy_mapping,
  COALESCE(k.scaled_score, 80) AS sats_score,
  k.scaled_score IS NULL AS is_below_scale_floor,
  w.raw_equivalent,
  ROUND(CAST(w.n_correct AS NUMERIC) / w.n_questions, 4) AS pct_correct,
  w.n_questions,
  w.n_correct,
  w.n_sittings,
  w.n_questions >= w.min_questions_for_sufficient_evidence AS has_sufficient_evidence,
  w.year_group,
  w.scored_at AS valid_from,
  LEAD(w.scored_at) OVER pupil_subject AS valid_to,
  LEAD(w.scored_at) OVER pupil_subject IS NULL AS is_current,
  w.conversion_year,
  w.methodology_version
FROM with_raw_equivalent AS w
LEFT JOIN harry_tullett.ref_ks2_scaled_score_conversion AS k
  ON  k.conversion_year = w.conversion_year
  AND k.sats_subject = w.sats_subject
  AND k.raw_score = w.raw_equivalent
WINDOW pupil_subject AS (PARTITION BY w.pupil_id, w.subject_id ORDER BY w.scored_at);
