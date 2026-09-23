/*
  base_responses
  Grain one row per (session_id, question_id)
  Source de_raw.responses
 
  2,082 (session, question) pairs appear 2-5 times; 1,304 of those are the
  same event under different response_ids. Keep the last answer given, as a
  marked paper would. 
 
  session_type is dropped: it's 'MOCK_TEST' on every row. assessment_sittings.session_type is of more use here.
*/

CREATE OR REPLACE VIEW harry_tullett.base_responses AS
SELECT
  response_id,
  session_id,
  pupil_id,
  question_id,
  question_number,
  is_correct,
  is_no_attempt,
  seconds_taken,
  answered_at
FROM `atom-analytics-candidates.de_raw.responses`
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY session_id, question_id
  ORDER BY answered_at DESC, response_id DESC
) = 1;
