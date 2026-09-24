import {$, number, when, node, status, api, cells, badge, detailLine, reviewRows, modelView, localDateNow} from '/shared/ui.js';

let state, selected = null, detail = null, busy = false, refreshing = false, generation = 0, pendingReview = null;
function newEvent() { $('event-id').value = `lab-${crypto.randomUUID()}`; $('event-time').value = localDateNow(); }
newEvent(); $('available-at').value = localDateNow();

function lock() {
  const waiting = busy || refreshing;
  $('refresh').disabled = waiting;
  for (const control of $('score-form').elements) control.disabled = waiting || !state?.active_model.available;
  for (const control of $('review-form').elements) control.disabled = waiting || !detail || !!detail.review;
  for (const control of $('label-form').elements) control.disabled = waiting || !detail || detail.label.state !== 'unknown';
  document.querySelectorAll('.row-button').forEach(b => b.disabled = waiting);
}
function renderLedger() {
  const query = $('search').value.toLowerCase(), filter = $('filter').value;
  const rows = state.decisions.filter(r => `${r.event.event_id} ${r.event.entity_id}`.toLowerCase().includes(query))
    .filter(r => filter === 'all' || (filter === 'review' ? r.decision.advisory === 'review' && !r.review : r.label.state === 'unknown'));
  $('ledger-empty').hidden = rows.length > 0;
  $('ledger-empty').textContent = state.decisions.length ? 'No events match these filters.' : 'No decisions yet. Submit a simulated payment to start.';
  cells('ledger', rows.map(r => {
    const box = node('div'), button = node('button', r.event.event_id, 'row-button');
    button.type = 'button'; button.dataset.event = r.event.event_id;
    button.addEventListener('click', () => select(r.event.event_id));
    box.append(button, node('small', r.event.entity_id));
    return [box, `${r.event.currency} ${(r.event.amount_minor / 100).toFixed(2)}`, number(r.decision.risk_score, 4),
      badge(r.decision.advisory.replaceAll('_', ' '), r.decision.advisory === 'review' ? 'warn' : 'good'),
      r.label.state === 'matured' ? (r.label.fraud ? 'Fraud' : 'Legitimate') : r.label.state];
  }));
  for (const row of $('ledger').rows) if (row.querySelector('button').dataset.event === selected) row.className = 'selected';
  lock();
}
function render() {
  const s = state.summary;
  $('scored').textContent = number(s.scored); $('flagged').textContent = number(s.flagged);
  $('reviewed').textContent = number(s.reviewed); $('matured').textContent = number(s.matured_labels);
  $('coverage').textContent = `${number(s.matured_labels / Math.max(1, s.scored) * 100, 1)}% label coverage · not accuracy`;
  renderLedger(); reviewRows(state.reviews, r => r.event_id);
  modelView(state.active_model, m => [
    ['Validation candidate AP', number(m.validation_candidate_ap, 4)],
    ['Validation amount-rule AP', number(m.validation_baseline_ap, 4)],
    ['Selected holdout AP', number(m.test_selected.average_precision, 4)],
    ['Holdout review rate', `${number(m.test_selected.review_rate * 100, 2)}%`],
    ['Review threshold', number(m.review_threshold, 4)],
    ['Training labels excluded as unavailable', number(m.labels_excluded_at_training_cutoff)]
  ]);
}
async function select(id) {
  const token = ++generation; selected = id; detail = null; pendingReview = null;
  $('detail').hidden = true; $('detail-empty').hidden = false;
  $('detail-title').textContent = id || 'Select an event';
  $('detail-empty').textContent = id ? 'Loading saved decision…' : 'Score a payment to see its saved decision.';
  $('review-state').textContent = 'Select a loaded event to review.';
  $('label-state').textContent = 'Select a loaded event to record feedback.';
  $('advisory').replaceChildren(); $('label-form').hidden = true; lock();
  if (!id) return true;
  try {
    const result = await api(`/v1/risk-decisions/${encodeURIComponent(id)}`);
    if (token !== generation) return false;
    detail = result;
    $('detail').hidden = false; $('detail-empty').hidden = true;
    $('risk-score').textContent = number(result.decision.risk_score, 4);
    $('score-bar').style.width = `${Math.max(0, Math.min(1, result.decision.risk_score)) * 100}%`;
    $('score-context').textContent = `Method: ${result.decision.score_type.replaceAll('_', ' ')} · original decision`;
    $('advisory').replaceChildren(badge(result.decision.advisory.replaceAll('_', ' '), result.decision.advisory === 'review' ? 'warn' : 'good'));
    $('decision-fields').replaceChildren(...[
      ['Entity', result.event.entity_id], ['Amount', `${result.event.currency} ${(result.event.amount_minor / 100).toFixed(2)}`],
      ['Event time', when(result.event.event_time)], ['Received at', when(result.event.received_at)],
      ['Outcome', result.label.state === 'matured' ? (result.label.fraud ? 'Fraud' : 'Legitimate') : result.label.state]
    ].map(([k,v]) => detailLine(k,v)));
    const names = ['Log amount', 'Prior hour count', 'Prior day count', 'Log prior mean amount', 'Relative amount'];
    $('features').replaceChildren(...result.decision.features.map((v,i) => detailLine(names[i], number(v, 4))));
    $('decision-release').textContent = result.decision.release_id;
    $('decision-evidence').textContent = result.model.available ? `Verified original release · threshold ${number(result.model.release.policy.threshold, 4)}` : result.model.error;
    $('review-state').textContent = result.review ? `Finalized: ${result.review.decision} by ${result.review.reviewer}` : `Reviewing ${id}. A review is not an outcome label.`;
    $('label-state').textContent = result.label.state === 'unknown' ? 'No label recorded. Unknown remains unknown.' : `${result.label.state}${result.label.state === 'matured' ? (result.label.fraud ? ' · Fraud' : ' · Legitimate') : ''} · available ${when(result.label.available_at)}`;
    $('label-form').hidden = result.label.state !== 'unknown';
    $('review-notes').value = result.review?.notes || '';
    if (result.review) { $('reviewer').value = result.review.reviewer; $('review-decision').value = result.review.decision; }
    renderLedger();
    return true;
  } catch (error) { if (token === generation) { status(error.message, true); $('detail-empty').textContent = 'Could not load this decision. Refresh to retry.'; } return false; }
  finally { if (token === generation) lock(); }
}
async function refresh(prefer = selected, clearNotice = true) {
  if (refreshing) return false;
  refreshing = true;
  ++generation; detail = null; lock(); $('dashboard').hidden = true; $('loading').hidden = false;
  if (clearNotice) status();
  try {
    state = await api('/v1/desk'); $('dashboard').hidden = false; render();
    return await select(prefer || state.decisions[0]?.event.event_id || null);
  } catch (error) { status(error.message, true); return false; }
  finally { refreshing = false; $('loading').hidden = true; lock(); }
}
async function write(action, message, target) {
  if (busy) return;
  busy = true; lock(); status();
  try { await action(); const loaded = await refresh(target || selected, false); status(loaded ? message : `${message} The updated view could not load; use Refresh data to retry.`, !loaded); }
  catch (error) { status(error.message, true); }
  finally { busy = false; lock(); }
}
$('score-form').addEventListener('submit', event => {
  event.preventDefault();
  const payload = {event_id:$('event-id').value, entity_id:$('entity-id').value, amount_minor:Number($('amount').value), currency:$('currency').value, event_time:new Date($('event-time').value).getTime() / 1000};
  write(() => api('/v1/risk-decisions', payload), 'Decision saved. An unchanged retry returns this same result.', payload.event_id);
});
$('review-form').addEventListener('submit', event => {
  event.preventDefault(); if (!detail || detail.review) return;
  pendingReview ||= {request_id:crypto.randomUUID(), event_id:selected, decision:$('review-decision').value, reviewer:$('reviewer').value, notes:$('review-notes').value};
  write(() => api('/v1/risk-reviews', pendingReview), 'Analyst review saved. No payment action was executed.');
});
$('review-form').addEventListener('input', () => pendingReview = null);
$('label-form').addEventListener('submit', event => {
  event.preventDefault(); if (!detail || detail.label.state !== 'unknown') return;
  const payload = {event_id:selected, fraud:$('fraud').value === 'true', available_at:new Date($('available-at').value).getTime() / 1000};
  write(() => api('/v1/labels', payload), 'Simulator label saved. Coverage counts it only when its availability time arrives.');
});
$('new-event').addEventListener('click', newEvent);
$('search').addEventListener('input', () => state && renderLedger());
$('filter').addEventListener('change', () => state && renderLedger());
$('refresh').addEventListener('click', () => refresh());
lock(); refresh();
