# Step 3: predicting GCSE results from primary-school work

The main thing we'd need is real GCSE results for pupils we already have primary data on. We could get these from schools, or from the DfE's National Pupil Database, matched on each pupil's UPN. We'd also need each pupil's scores as they stood at the end of Year 6, not as they are today, so the model isn't learning from information it wouldn't have had at the time. The point-in-time design of `analytics_pupil_subject_sats_score` already gives us that.

I'd start fairly simple. The DfE already publishes the average GCSE outcome (Attainment 8) for pupils at each KS2 starting point, so a first version is just: predicted KS2 score → expected Attainment 8 → likely grades. It's transparent and needs no training data. One catch is that KS2 wasn't sat in 2020 or 2021, so recent years of that data may not be usable. Once we have linked results, I'd add what Atom knows on top, such as whether a pupil's scores are rising or falling and which topics they're weak in. A simple regression would do, and it only earns its place if it beats the baseline.

The assumptions I'd be most careful about:

- The link between Year 6 and GCSE stays stable over five years.
- Atom pupils probably aren't typical (more engaged schools and families), so a model trained only on them would be biased.
- School has a big effect on results.
- Our SATs scores are estimates, so any error carries through. Where a pupil has real KS2 results, I'd use those instead.

Because of all this, I'd predict a range of likely grades rather than a single grade.
