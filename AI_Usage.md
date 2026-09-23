# How I used AI

## Planning

Before writing any SQL, I talked the brief through with Claude. The aim was to find the parts that were open to interpretation:

- what a SATs score means for a Year 1 pupil;
- which subjects and session types should count;
- what "point in time" means when deletions have no timestamp.

I then decided the approach and the base → reference → analytics structure.

## EDA

Once I'd done an initial pass of the data myself, I got Claude to write the first set of data quality queries (`ai_code/intial_eda.sql`). I ran them and went through the results.
They surfaced the issues that shaped the model:

- duplicate answers within a sitting;
- Wellbeing being a survey with `is_correct` values;
- session types that don't match between tables;
- responses with no sitting.

## Coding

I built the base and analytics layers myself, with AI as a coding assistant along the way.

- Claude helped turn the DfE conversion tables on GOV.UK into SQL. I checked the result against the source.
- Claude Cowork reviewed my PRs.

## Checking the output

I used Claude to write a set of checks on the finished tables (`ai_code/final_checks.sql`). Every failure check returned 0. I also worked one pupil's score out by hand against the GOV.UK table to be sure.

## What worked and what didn't

- **Useful for:** spotting ambiguity early, and writing lots of repetitive check queries quickly.
- **Needed steering:** it tends to over-build. Its first suggestion had three analytics tables, incremental loads and a build script. I cut that down to one table, which covers the brief.
