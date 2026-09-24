import {$, number, node, status, api, cells, badge, detailLine, reviewRows, modelView, trend} from '/shared/ui.js';

let state, selected = null, detail = null, generation = 0, busy = false, refreshing = false, pendingReview = null;
const unitKey = u => JSON.stringify([u.site, u.equipment]);
function lock() {
  const waiting = busy || refreshing;
  $('refresh').disabled = waiting;
  $('flush').disabled = waiting || !state || state.summary.queued === 0;
  for (const control of $('sensor-form').elements) control.disabled = waiting || !state?.active_model.available;
  $('next-sequence').disabled = waiting || !detail || !state?.active_model.available;
  const eligible = detail && detail.samples.at(-1).prediction.state === 'predicted' && !detail.review;
  for (const control of $('review-form').elements) control.disabled = waiting || !eligible;
  document.querySelectorAll('.unit').forEach(button => button.disabled = waiting);
}
function renderUnits() {
  const list = $('equipment-list'); list.replaceChildren();
  const query = $('search').value.toLowerCase();
  const units = state.equipment.filter(u => `${u.event.site} ${u.event.equipment}`.toLowerCase().includes(query));
  $('fleet-empty').hidden = !!units.length;
  $('fleet-empty').textContent = state.equipment.length ? 'No equipment matches this search.' : 'No equipment yet. Submit five consecutive samples for a new unit.';
  for (const unit of units) {
    const button = node('button', undefined, 'unit'); button.type = 'button';
    button.setAttribute('aria-pressed', String(selected && unitKey(selected) === unitKey(unit.event)));
    button.append(node('small', unit.event.site), node('strong', unit.event.equipment),
      node('small', `Latest sequence ${unit.event.sequence}`),
      node('span', unit.prediction.remaining_cycles == null ? 'Collecting history' : `${number(unit.prediction.remaining_cycles, 1)} cycles remaining`));
    if (unit.prediction.inspection_advisory) button.append(badge('Inspection advisory', 'warn'));
    button.addEventListener('click', () => select({site:unit.event.site, equipment:unit.event.equipment}));
    list.append(button);
  }
  lock();
}
function render() {
  const s = state.summary;
  $('unit-count').textContent = number(s.units); $('advisory-count').textContent = number(s.advisories);
  $('queued').textContent = number(s.queued); $('central').textContent = number(s.central_rows);
  $('queue-caption').textContent = `${number(s.queued)} / ${number(s.spool_limit)} row capacity`;
  $('delivery-values').replaceChildren(...[
    ['Accepted edge samples', number(s.samples)], ['Waiting for acknowledgement', number(s.queued)],
    ['Committed central records', number(s.central_rows)]
  ].map(([k,v]) => detailLine(k,v)));
  renderUnits(); reviewRows(state.reviews, r => `${r.site} / ${r.equipment} / ${r.sequence}`);
  modelView(state.active_model, m => [
    ['Validation candidate MAE', `${number(m.validation_candidate_mae, 3)} cycles`],
    ['Validation age-baseline MAE', `${number(m.validation_baseline_mae, 3)} cycles`],
    ['Selected holdout MAE', `${number(m.test_mae_cycles, 3)} cycles`],
    ['Holdout baseline MAE', `${number(m.test_baseline_mae_cycles, 3)} cycles`],
    ['Selected holdout RMSE', `${number(m.test_rmse_cycles, 3)} cycles`],
    ['Held-out units warned', `${m.warning_policy.warned_units} / ${m.warning_policy.test_units}`]
  ]);
}
async function select(unit) {
  const token = ++generation; selected = unit; detail = null; pendingReview = null; lock();
  $('detail').hidden = true; $('detail-empty').hidden = false;
  $('detail-title').textContent = unit ? `${unit.site} / ${unit.equipment}` : 'Select equipment';
  $('detail-empty').textContent = unit ? 'Loading sample history…' : 'Submit a reading to begin an equipment history.';
  $('prediction-state').replaceChildren(); $('review-state').textContent = 'Waiting for a loaded prediction.';
  if (!unit) return true;
  try {
    const data = await api(`/v1/equipment-history?${new URLSearchParams(unit)}`);
    if (token !== generation) return false;
    detail = data;
    const latest = data.samples.at(-1), p = latest.prediction;
    $('detail').hidden = false; $('detail-empty').hidden = true;
    $('remaining').textContent = p.remaining_cycles == null ? 'Collecting history' : `${number(p.remaining_cycles, 1)} cycles`;
    $('remaining-context').textContent = `Sequence ${latest.event.sequence} · ${p.inspection_advisory ? 'Persistent inspection advisory' : p.state === 'predicted' ? 'No persistent advisory at this sample' : 'Five consecutive readings are required'}`;
    $('prediction-state').replaceChildren(badge(p.inspection_advisory ? 'Inspection advisory' : p.state.replaceAll('_', ' '), p.inspection_advisory ? 'warn' : ''));
    trend('chart', data.samples);
    cells('samples', data.samples.map(s => [s.event.sequence, number(s.event.temperature, 3), number(s.event.vibration, 3), number(s.prediction.remaining_cycles, 3), s.prediction.inspection_advisory ? 'Inspect' : '—']));
    $('prediction-release').textContent = p.release_id || 'No model used during warmup';
    $('prediction-evidence').textContent = data.model.available ? 'Original release verified. Promotion does not rewrite issued estimates.' : data.model.error;
    $('review-state').textContent = data.review ? `Finalized: ${data.review.decision} by ${data.review.reviewer}` : p.state !== 'predicted' ? 'Collect five consecutive samples before a model-based review.' : `Reviewing sequence ${latest.event.sequence}. New samples will require a refresh before saving.`;
    $('review-notes').value = data.review?.notes || '';
    if (data.review) { $('reviewer').value = data.review.reviewer; $('review-decision').value = data.review.decision; }
    renderUnits();
    return true;
  } catch (error) { if (token === generation) { status(error.message, true); $('detail-empty').textContent = 'Could not load equipment history. Refresh to retry.'; } return false; }
  finally { if (token === generation) lock(); }
}
async function refresh(prefer = selected, clearNotice = true) {
  if (refreshing) return false;
  refreshing = true;
  ++generation; detail = null; lock(); $('dashboard').hidden = true; $('loading').hidden = false;
  if (clearNotice) status();
  try {
    state = await api('/v1/fleet'); $('dashboard').hidden = false; render();
    const first = state.equipment[0]?.event;
    return await select(prefer || (first ? {site:first.site, equipment:first.equipment} : null));
  } catch (error) { status(error.message, true); return false; }
  finally { refreshing = false; $('loading').hidden = true; lock(); }
}
async function write(action, message, target) {
  if (busy) return;
  busy = true; lock(); status();
  try {
    const result = await action(); const loaded = await refresh(target || selected, false);
    const text = typeof message === 'function' ? message(result) : message;
    status(loaded ? text : `${text} The updated view could not load; use Refresh data to retry.`, !loaded);
  }
  catch (error) { status(error.message, true); }
  finally { busy = false; lock(); }
}
$('sensor-form').addEventListener('submit', event => {
  event.preventDefault();
  const payload = {site:$('site').value, equipment:$('equipment').value, sequence:Number($('sequence').value), temperature:Number($('temperature').value), vibration:Number($('vibration').value)};
  write(() => api('/v1/sensor-events', payload), 'Reading persisted at the edge. The unchanged request can be retried safely.', {site:payload.site, equipment:payload.equipment});
});
$('next-sequence').addEventListener('click', () => {
  if (!detail) return;
  const event = detail.samples.at(-1).event;
  $('site').value = event.site; $('equipment').value = event.equipment;
  $('sequence').value = event.sequence + 1; $('temperature').value = event.temperature; $('vibration').value = event.vibration;
});
$('review-form').addEventListener('submit', event => {
  event.preventDefault(); if (!detail || detail.review) return;
  pendingReview ||= {request_id:crypto.randomUUID(), ...selected, sequence:detail.samples.at(-1).event.sequence, decision:$('review-decision').value, reviewer:$('reviewer').value, notes:$('review-notes').value};
  write(() => api('/v1/inspection-reviews', pendingReview), 'Inspection review saved. No equipment action was executed.');
});
$('review-form').addEventListener('input', () => pendingReview = null);
$('flush').addEventListener('click', () => write(() => api('/v1/spool/flush', {}), result => `${result.acknowledged} queued records acknowledged by the simulated central database.`));
$('search').addEventListener('input', () => state && renderUnits());
$('refresh').addEventListener('click', () => refresh());
lock(); refresh();
