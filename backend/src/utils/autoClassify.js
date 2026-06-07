/**
 * Auto-classification rules (FR-14). Only ever acts on trips the user (or the
 * tracker) left as 'uncategorized' — it never overrides an explicit choice.
 *
 * Current rule set (opt-in via user settings):
 *   - classifyWeekendsAsPersonal: a drive that starts on Sat/Sun -> personal.
 *
 * Returns the category to use.
 */
function autoClassify({ category, startTime, settings = {} }) {
  if (category && category !== 'uncategorized') return category;

  if (settings.classifyWeekendsAsPersonal && startTime) {
    const day = new Date(startTime).getUTCDay(); // 0 = Sun, 6 = Sat
    if (day === 0 || day === 6) return 'personal';
  }

  return category || 'uncategorized';
}

module.exports = { autoClassify };
