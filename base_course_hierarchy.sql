/*
  base_course_hierarchy
  Grain one row per question
  Source de_raw.course_hierarchy (from initial EDA: strict tree, one row per question, subject_id and subject_name 1:1)

  Again like pupils, no real logic sits here - but we keep it for consistency, and to allow for future buisness requirements, changing column names etc. 
*/

CREATE OR REPLACE VIEW harry_tullett.base_course_hierarchy AS
SELECT
  question_id,
  atom_id,
  subtopic_id,
  topic_id,
  subject_id,
  subject_name
FROM `atom-analytics-candidates.de_raw.course_hierarchy`;
