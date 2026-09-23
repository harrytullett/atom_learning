-- ref_ks2_scaled_score_conversion
-- The DfE's 2026 KS2 raw score to scaled score tables, one row per test and raw mark.
-- Source: https://www.gov.uk/government/publications/key-stage-2-tests-2026-scaled-scores/2026-key-stage-2-scaled-score-conversion-tables
-- (Standards and Testing Agency, 16 July 2026, Open Government Licence)
--
-- Raw scores of 0-2 don't get a scaled score, so each list starts at 3.
-- The lists are ten marks per line so they're easy to check against GOV.UK.
-- To add another year, add another row to the array.

CREATE OR REPLACE TABLE harry_tullett.ref_ks2_scaled_score_conversion AS
WITH published AS (
  SELECT *
  FROM UNNEST(ARRAY<STRUCT<
    conversion_year INT64,
    sats_subject STRING,
    max_raw_score INT64,
    scaled_from_raw_3 ARRAY<INT64>
  >>[
    (2026, 'gps', 70, [
       80,  81,  82,  83,  84,  85,  86,  87,  87,  88, -- raw 3-12
       89,  90,  90,  91,  91,  92,  92,  93,  94,  94, -- raw 13-22
       95,  95,  95,  96,  96,  97,  97,  98,  98,  99, -- raw 23-32
       99, 100, 100, 100, 101, 101, 102, 102, 103, 103, -- raw 33-42
      104, 104, 105, 105, 106, 106, 107, 107, 108, 108, -- raw 43-52
      109, 109, 110, 111, 111, 112, 113, 114, 115, 116, -- raw 53-62
      117, 118, 119, 120, 120, 120, 120, 120 -- raw 63-70
    ]),
    (2026, 'reading', 50, [
       81,  82,  84,  85,  86,  87,  88,  89,  90,  91, -- raw 3-12
       92,  93,  93,  94,  95,  95,  96,  97,  98,  98, -- raw 13-22
       99,  99, 100, 101, 101, 102, 103, 103, 104, 105, -- raw 23-32
      106, 106, 107, 108, 109, 109, 110, 111, 112, 113, -- raw 33-42
      114, 116, 117, 118, 120, 120, 120, 120 -- raw 43-50
    ]),
    (2026, 'maths', 110, [
       80,  80,  80,  80,  81,  82,  83,  83,  84,  85, -- raw 3-12
       85,  86,  86,  87,  87,  88,  88,  89,  89,  90, -- raw 13-22
       90,  90,  91,  91,  92,  92,  92,  93,  93,  93, -- raw 23-32
       94,  94,  94,  94,  95,  95,  95,  96,  96,  96, -- raw 33-42
       96,  97,  97,  97,  97,  98,  98,  98,  98,  99, -- raw 43-52
       99,  99,  99, 100, 100, 100, 100, 101, 101, 101, -- raw 53-62
      101, 101, 102, 102, 102, 102, 103, 103, 103, 103, -- raw 63-72
      104, 104, 104, 104, 105, 105, 105, 106, 106, 106, -- raw 73-82
      106, 107, 107, 107, 108, 108, 108, 108, 109, 109, -- raw 83-92
      109, 110, 110, 111, 111, 112, 112, 113, 113, 114, -- raw 93-102
      114, 115, 116, 117, 118, 119, 120, 120 -- raw 103-110
    ])
  ])
)
SELECT
  conversion_year,
  sats_subject,
  max_raw_score,
  3 + raw_offset AS raw_score,
  scaled_score
FROM published,
  UNNEST(scaled_from_raw_3) AS scaled_score WITH OFFSET AS raw_offset;
