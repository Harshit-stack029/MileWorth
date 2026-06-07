/**
 * Deduction = business miles × mileage rate.
 * Only business trips have a deduction value; personal/uncategorized are 0.
 * The rate is always passed in (from the user's setting) — never hardcoded.
 */
function computeDeduction({ distance, category, mileageRate }) {
  if (category !== 'business' || !distance || !mileageRate) return 0;
  return Math.round(distance * mileageRate * 100) / 100;
}

module.exports = { computeDeduction };
