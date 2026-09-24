import {$, number, when, node, status, api, cells, badge, detailLine, modelView} from '/shared/ui.js';

let state, detail = null, selected = null, busy = false, refreshing = false, generation = 0;
let fixtureId = crypto.randomUUID();
const serviceName = name => ({'demand-forecasting':'Demand forecasting','payment-risk':'Payment risk','predictive-maintenance':'Predictive maintenance'})[name] || name;
const date = value => value == null ? 'Not recorded in legacy incident' : when(value);
function lock() {
  const waiting = busy || refreshing;
  $('refresh').disabled = waiting;
  $('analyze').disabled = waiting || !state?.active_model.available;
  for (const control of $('fixture-form').elements) control.disabled = waiting || !state;
  for (const control of $('review-form').elements) control.disabled = waiting || !detail || detail.state !== 'pending';
  document.querySelectorAll('.row-button').forEach(b => b.disabled = waiting);
}
function renderServices() {
  $('services').replaceChildren();
  for (const service of state.services) {
    const card = node('article', undefined, 'service-card');
    card.append(node('h3', serviceName(service.service)));
    const label = service.status === 'eligible' ? 'Eligible for analysis' : service.status === 'insufficient_samples' ? 'Insufficient samples' : 'No recent samples';
    card.append(badge(label), detailLine('Samples', `${service.sample_count} / 5 minimum`));
    card.append(node('p', `${service.http_samples} HTTP · ${service.fixture_samples} fixture samples`, 'small muted'));
    if (service.features) {
      card.append(detailLine('Mean latency', `${number(service.features[0],1)} ms`),
        detailLine('Error fraction', `${number(service.features[1]*100,1)}%`),
        detailLine('Queue signal', service.queue_signal === 'fixture' ? `${number(service.features[2])} (fixture)` : 'Not measured'),
        node('p', service.static_rule ? 'Static threshold crossed' : 'Static thresholds not crossed', 'small muted'));
    }
    card.append(node('p', `Last sample: ${service.last_seen == null ? 'none recorded' : when(service.last_seen)}`, 'small muted'));
    $('services').append(card);
  }
}
function renderIncidents() {
  const query = $('search').value.toLowerCase(), filter = $('state-filter').value, source = $('source-filter').value;
  const rows = state.incidents.filter(r => `${r.id} ${r.service}`.toLowerCase().includes(query))
    .filter(r => filter === 'all' || r.state === filter)
    .filter(r => source === 'all' || (source === 'fixture' ? r.evidence.contains_fixture : !r.evidence.contains_fixture));
  $('incidents-empty').hidden = rows.length > 0;
  $('incidents-empty').textContent = state.incidents.length ? 'No incidents match these filters.' : 'No incidents yet. Analyze eligible windows or add a labeled fixture for the lab.';
  cells('incidents', rows.map(r => {
    const box = node('div'), button = node('button', r.id.slice(0,12), 'row-button');
    button.type = 'button'; button.dataset.id = r.id;
    button.setAttribute('aria-label', `Open incident ${r.id.slice(0,12)} for ${serviceName(r.service)}`);
    button.addEventListener('click', () => select(r.id));
    box.append(button, node('small', serviceName(r.service)));
    const signals = [r.evidence.anomaly ? 'ML anomaly' : null, r.evidence.static_rule ? 'Static threshold' : null].filter(Boolean).join(' + ');
    return [box, signals, badge(r.evidence.contains_fixture ? 'Includes fixtures' : 'HTTP samples'), badge(r.state === 'pending' ? 'Pending review' : `Review ${r.state}`, r.state === 'pending' ? 'warn' : '')];
  }));
  for (const row of $('incidents').rows) if (row.querySelector('button').dataset.id === selected) row.className = 'selected';
  lock();
}
function render() {
  $('eligible').textContent = number(state.services.filter(s => s.status === 'eligible').length);
  $('incident-count').textContent = number(state.summary.total); $('pending-count').textContent = number(state.summary.pending);
  $('fixture-count').textContent = number(state.services.reduce((n,s) => n+s.fixture_samples,0));
  $('observed-at').textContent = `Snapshot: ${when(state.observed_at)}`;
  renderServices(); renderIncidents();
  cells('runs', state.runs.map(r => [when(r.completed), r.window_count, r.incident_ids.length, r.detector_release.slice(0,12)]));
  $('runs-empty').hidden = state.runs.length > 0;
  modelView(state.active_model, m => [
    ['Isolation Forest precision', `${number(m.heldout_anomaly_detector.precision*100,2)}%`],
    ['Isolation Forest recall', `${number(m.heldout_anomaly_detector.recall*100,2)}%`],
    ['Isolation Forest false alerts', number(m.heldout_anomaly_detector.false_alerts)],
    ['Static rule precision', `${number(m.heldout_static_rules.precision*100,2)}%`],
    ['Static rule recall', `${number(m.heldout_static_rules.recall*100,2)}%`],
    ['Static rule false alerts', number(m.heldout_static_rules.false_alerts)]
  ]);
  $('model-name').textContent = state.active_model.available ? 'Isolation Forest vs. static rules' : 'Detector unavailable';
}
async function select(id) {
  const token = ++generation; selected = id; detail = null; lock();
  $('detail').hidden = true; $('detail-empty').hidden = false;
  $('detail-title').textContent = id ? `Incident ${id.slice(0,12)}` : 'Select an incident';
  $('detail-empty').textContent = id ? 'Loading preserved evidence…' : 'No incident selected. Analyze current windows to investigate their signals.';
  $('detail-source').replaceChildren(); $('review-state').textContent = 'Select a loaded incident first.';
  if (!id) return true;
  try {
    const data = await api(`/v1/incidents/${encodeURIComponent(id)}`);
    if (token !== generation) return false;
    detail = data; const e = data.evidence;
    $('detail').hidden = false; $('detail-empty').hidden = true;
    $('detail-source').replaceChildren(badge(e.contains_fixture ? 'Includes fixture samples' : 'HTTP sample evidence'));
    $('finding-title').textContent = serviceName(data.service);
    $('finding-context').textContent = `${e.sample_count} samples · event IDs ${e.first_event_id}–${e.last_event_id} · Isolation Forest ${e.anomaly ? 'flagged' : 'did not flag'} · Static rules ${e.static_rule ? 'flagged' : 'did not flag'}`;
    $('signal-values').replaceChildren(...[
      ['Mean latency / static threshold', `${number(e.features[0],2)} ms / ≥100 ms`],
      ['Error fraction / static threshold', `${number(e.features[1]*100,2)}% / ≥10%`],
      ['Reported queue maximum / threshold', `${number(e.features[2])} / ≥20 · ${e.contains_fixture ? 'includes fixture values' : 'HTTP placeholder, not measured'}`]
    ].map(([k,v]) => detailLine(k,v)));
    $('hypotheses').replaceChildren();
    for (const h of data.proposal.hypotheses) {
      const card = node('article', undefined, 'hypothesis');
      card.append(node('h3', h.hypothesis), node('p', h.next_check, 'small muted'));
      if (h.evidence_event_ids) card.append(node('p', `Referenced release events: ${h.evidence_event_ids.join(', ')}`, 'small muted'));
      $('hypotheses').append(card);
    }
    $('proposal').textContent = data.proposal.action;
    const source = [...(e.source_events || []), ...(e.release_event_snapshots || [])].sort((a,b) => a.id-b.id);
    $('source-summary').textContent = data.source_snapshots_available ? `Showing ${Math.min(source.length,200)} of ${source.length} preserved source/release events. Times and context belong to this incident's saved window.` : 'Legacy incident: only event references and aggregates were saved. Full source snapshots were not captured; no event details are invented.';
    cells('source-events', source.slice(0,200).map(r => {
      const identity = node('div', String(r.id)); identity.append(node('small', when(r.ts)));
      return [identity, r.kind, number(r.latency,2), number(r.error,2), number(r.queue), node('span', JSON.stringify(r.context), 'source-context')];
    }));
    $('incident-release').textContent = e.detector_release;
    $('incident-model-status').textContent = data.model.available ? 'Original detector release verified. A later promotion does not relabel this incident.' : data.model.error;
    $('incident-times').replaceChildren(...[
      ['Created', date(data.created_at)], ['Reviewed', data.reviewed_at == null ? 'No recorded review timestamp' : when(data.reviewed_at)],
      ['Window start', date(e.window_start)], ['Window end', date(e.window_end)]
    ].map(([k,v]) => detailLine(k,v)));
    $('review-state').textContent = data.review ? `Finalized: ${data.state} by ${data.review.reviewer}. No action executed.` : `Reviewing ${data.id.slice(0,12)}. Approval is a saved judgment, not execution.`;
    $('reason').value = data.review?.reason || '';
    if (data.review) { $('reviewer').value = data.review.reviewer; $('review-decision').value = data.review.decision; }
    renderIncidents(); return true;
  } catch (error) { if (token === generation) status(error.message,true); return false; }
  finally { if (token === generation) lock(); }
}
async function refresh(prefer = selected, clearNotice = true) {
  if (refreshing) return false;
  refreshing = true; ++generation; detail = null; lock();
  $('dashboard').hidden = true; $('loading').hidden = false;
  if (clearNotice) status();
  try {
    state = await api('/v1/desk'); $('dashboard').hidden = false; render();
    return await select(prefer || state.incidents[0]?.id || null);
  } catch (error) { status(error.message,true); return false; }
  finally { refreshing = false; $('loading').hidden = true; lock(); }
}
async function write(action, message, choose) {
  if (busy) return;
  busy = true; lock(); status();
  try {
    const result = await action();
    const loaded = await refresh(choose ? choose(result) : selected,false);
    const text = typeof message === 'function' ? message(result) : message;
    status(loaded ? text : `${text} The updated view could not load; use Refresh data.`, !loaded);
  } catch (error) { status(error.message,true); }
  finally { busy = false; lock(); }
}
$('analyze').addEventListener('click', () => write(() => api('/v1/analyze',{}), r => `Analyzed ${r.analyzed_windows} eligible windows; returned ${r.incident_ids.length} incident IDs. Existing evidence is deduplicated.`, r => r.incident_ids[0] || selected));
$('fixture-form').addEventListener('submit', event => {
  event.preventDefault();
  const body = {request_id:fixtureId,service:$('fixture-service').value,scenario:$('scenario').value};
  write(() => api('/v1/fixtures',body), r => `Labeled replay ready: ${r.sample_count} samples for ${serviceName(r.service)}. Select Analyze to evaluate the current window. No represented service was changed.`);
});
$('fixture-form').addEventListener('change', () => fixtureId = crypto.randomUUID());
$('new-fixture').addEventListener('click', () => { fixtureId = crypto.randomUUID(); status('New replay prepared. Select Add labeled fixture to write its samples.'); });
$('review-form').addEventListener('submit', event => {
  event.preventDefault(); if (!detail || detail.state !== 'pending') return;
  const body = {decision:$('review-decision').value,reviewer:$('reviewer').value,reason:$('reason').value};
  write(() => api(`/v1/incidents/${encodeURIComponent(selected)}/review`,body), 'Human review saved. No command was executed and no outage was marked resolved.');
});
$('search').addEventListener('input', () => state && renderIncidents());
for (const id of ['state-filter','source-filter']) $(id).addEventListener('change', () => state && renderIncidents());
$('refresh').addEventListener('click', () => refresh());
lock(); refresh();
