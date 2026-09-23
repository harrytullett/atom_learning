/*
  base_pupils
  Grain one row per pupil
  Source de_raw.pupils (clean in EDA: no duplicates, no nulls, no deletions yet)
  
  No buisness logic here at the moment, creates a view from de_raw, including it for consistency however, 
  the table pupil_subject_sats_score should read only base views and reference objects. 
*/

CREATE OR REPLACE VIEW harry_tullett.base_pupils AS
SELECT
  pupil_id,
  is_deleted
FROM `atom-analytics-candidates.de_raw.pupils`;
