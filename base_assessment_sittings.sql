/*
  base_assessment_sittings
  Grain one row per sitting (session_id)
  Source de_raw.assessment_sittings

  Cleaning only. Which sittings count towards a score is a business rule and
  lives in fct_pupil_subject_sats_score_history.
*/

CREATE OR REPLACE VIEW harry_tullett.base_assessment_sittings AS
SELECT
  session_id,
  pupil_id,
  assessment_id,
  LOWER(TRIM(session_type)) AS session_type,
  LOWER(TRIM(style)) AS style,
  -- 25 sittings carry 11, 14 or 15, which aren't primary year groups.
  -- The answers are still real, so keep the sitting and drop the year.
  IF(year_group_at_sitting BETWEEN 1 AND 6, year_group_at_sitting, NULL) AS year_group,
  total_questions,
  is_complete,
  is_deleted,
  started_at,
  finished_at
FROM `atom-analytics-candidates.de_raw.assessment_sittings`;
