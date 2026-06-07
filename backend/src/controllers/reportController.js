const PDFDocument = require('pdfkit');
const User = require('../models/User');
const asyncHandler = require('../utils/asyncHandler');
const { gatherReportData } = require('../utils/reportData');

// JSON preview of totals — the app shows this before the user exports.
const getReportSummary = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const data = await gatherReportData(req.user.userId, from, to);
  res.json({ summary: data.totals, from: from || null, to: to || null });
});

// Downloadable report. ?format=csv|pdf (default pdf), ?from=&to= (ISO dates).
const getReport = asyncHandler(async (req, res) => {
  const { from, to, format = 'pdf' } = req.query;
  const user = await User.findById(req.user.userId);
  const data = await gatherReportData(req.user.userId, from, to);
  const stamp = fileStamp(from, to);

  if (format === 'csv') return sendCsv(res, data, stamp);
  return sendPdf(res, data, user, stamp);
});

function sendCsv(res, { trips, expenses }, stamp) {
  const lines = [];
  lines.push('Type,Date,Description,Category,Miles,Amount');
  for (const t of trips) {
    lines.push([
      'Trip',
      iso(t.startTime),
      `${fmtDate(t.startTime)} drive`,
      t.category,
      t.distance,
      t.deductionValue || 0,
    ].map(csvCell).join(','));
  }
  for (const e of expenses) {
    lines.push([
      'Expense',
      iso(e.date),
      e.vendor || '',
      e.category || '',
      '',
      e.amount,
    ].map(csvCell).join(','));
  }
  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="mileworth-${stamp}.csv"`);
  res.send(lines.join('\n'));
}

function sendPdf(res, { trips, expenses, totals, from, to }, user, stamp) {
  const currency = user?.currency || 'USD';
  const money = (n) => `${currency} ${Number(n).toFixed(2)}`;

  const doc = new PDFDocument({ margin: 50, size: 'A4' });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="mileworth-${stamp}.pdf"`);
  doc.pipe(res);

  doc.fontSize(22).fillColor('#1565C0').text('MileWorth Mileage Report');
  doc.moveDown(0.3);
  doc.fontSize(10).fillColor('#555')
    .text(`Period: ${from ? fmtDate(from) : 'all time'} – ${to ? fmtDate(to) : 'now'}`)
    .text(`Account: ${user?.email || ''}`)
    .text(`Mileage rate: ${money(user?.mileageRate || 0)} / mile`);
  doc.moveDown();

  // Summary block
  doc.fontSize(14).fillColor('#000').text('Summary');
  doc.moveDown(0.3).fontSize(11).fillColor('#333');
  doc.text(`Total trips: ${totals.totalTrips}   (business: ${totals.businessTrips})`);
  doc.text(`Business miles: ${totals.businessMiles}   of ${totals.totalMiles} total`);
  doc.fillColor('#2E7D32').text(`Estimated deduction: ${money(totals.totalDeductions)}`);
  doc.fillColor('#333').text(`Expenses: ${money(totals.totalExpenses)}`);
  doc.moveDown();

  // Trips table
  doc.fontSize(14).fillColor('#000').text('Trips');
  doc.moveDown(0.3).fontSize(9).fillColor('#333');
  if (trips.length === 0) {
    doc.text('No trips in this period.');
  } else {
    for (const t of trips) {
      doc.text(
        `${fmtDate(t.startTime)}  ·  ${t.distance.toFixed(1)} mi  ·  ${t.category}` +
        (t.deductionValue ? `  ·  ${money(t.deductionValue)}` : ''),
      );
    }
  }
  doc.moveDown();

  if (expenses.length) {
    doc.fontSize(14).fillColor('#000').text('Expenses');
    doc.moveDown(0.3).fontSize(9).fillColor('#333');
    for (const e of expenses) {
      doc.text(`${fmtDate(e.date)}  ·  ${e.vendor || 'Expense'}  ·  ${e.category || ''}  ·  ${money(e.amount)}`);
    }
    doc.moveDown();
  }

  doc.moveDown().fontSize(8).fillColor('#999')
    .text('Deduction figures are estimates only and are not tax advice. ' +
      'Confirm with a qualified accountant before filing.');

  doc.end();
}

// --- helpers ---
function round(n) { return Math.round(n * 100) / 100; }
function iso(d) { return new Date(d).toISOString(); }
function fmtDate(d) { return new Date(d).toISOString().slice(0, 10); }
function csvCell(v) {
  const s = String(v ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}
function fileStamp(from, to) {
  const a = from ? fmtDate(from) : 'all';
  const b = to ? fmtDate(to) : 'now';
  return `${a}_to_${b}`;
}

module.exports = { getReport, getReportSummary, round };
