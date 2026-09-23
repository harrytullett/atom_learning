-- ref_subject_sats_mapping
-- Which KS2 test each Atom subject is scored against.
-- sats_subject is NULL for subjects we don't score.
-- English uses the reading table. GPS would also work, but the two 2026 tables
-- are never more than a point apart.

CREATE OR REPLACE TABLE harry_tullett.ref_subject_sats_mapping AS
SELECT *
FROM UNNEST(ARRAY<STRUCT<
  subject_name STRING,
  sats_subject STRING,
  is_proxy_mapping BOOL,
  rationale STRING
>>[
  ('Maths', 'maths', FALSE, 'KS2 maths'),
  ('English', 'reading', FALSE, 'KS2 reading (GPS is within a point)'),
  ('Verbal Reasoning', 'reading', TRUE, 'No KS2 test, closest is reading'),
  ('Non-Verbal Reasoning', 'maths', TRUE, 'No KS2 test, closest is maths'),
  ('Science', NULL, NULL, 'No KS2 scaled score, and no responses yet'),
  ('Screeners', NULL, NULL, 'A type of test, not a subject'),
  ('Wellbeing', NULL, NULL, 'A survey, so there are no right answers')
]);
