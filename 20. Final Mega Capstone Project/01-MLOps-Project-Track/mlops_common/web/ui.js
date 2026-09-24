// Shared rendering only. Domain workflows live in each project's frontend/app.js.
export const $ = id => document.getElementById(id);
export const number = (value, digits = 0) => value == null ? '—' : Number(value).toLocaleString(undefined, {maximumFractionDigits: digits});
export const when = value => value == null ? '—' : new Date(value * 1000).toLocaleString();
export function node(tag, text, className) {
  const element = document.createElement(tag);
  if (text !== undefined) element.textContent = text;
  if (className) element.className = className;
  return element;
}
export function status(message = '', error = false) {
  $('notice').textContent = message;
  $('notice').className = error ? 'notice error' : 'notice';
  $('notice').hidden = !message;
}
export async function api(path, body) {
  let response;
  try {
    response = await fetch(path, body === undefined ? {} : {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)
    });
  } catch {
    throw new Error('Cannot reach the local API. Check the server, then retry the unchanged request.');
  }
  const data = await response.json();
  if (!response.ok) {
    const error = new Error(typeof data.detail === 'string' ? data.detail : 'Invalid input. Check the form values.');
    error.code = response.status;
    throw error;
  }
  return data;
}
export function cells(tableId, rows) {
  const body = $(tableId);
  body.replaceChildren();
  for (const values of rows) {
    const row = node('tr');
    for (const value of values) {
      const cell = node('td');
      if (value instanceof Node) cell.append(value); else cell.textContent = value ?? '—';
      row.append(cell);
    }
    body.append(row);
  }
}
export function badge(text, tone = '') { return node('span', text, `badge ${tone}`); }
export function detailLine(label, value) {
  const line = node('div', undefined, 'detail-line');
  line.append(node('span', label), node('strong', value));
  return line;
}
export function reviewRows(reviews, target) {
  cells('reviews', reviews.map(r => [target(r), badge(r.decision), r.reviewer, r.notes, when(r.created_at)]));
  $('reviews-empty').hidden = reviews.length > 0;
}
export function modelView(model, metrics) {
  $('model-values').replaceChildren();
  $('model-warning').hidden = model.available;
  $('model-warning').textContent = model.error || '';
  $('active-release').textContent = model.available ? model.release.release_id : 'No verified active model';
  $('model-name').textContent = model.available ? model.metrics.selected.replaceAll('_', ' ') : 'Unavailable';
  if (model.available) for (const [label, value] of metrics(model.metrics)) $('model-values').append(detailLine(label, value));
}
export function localDateNow() {
  const d = new Date();
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 19);
}
export function trend(target, samples) {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', '0 0 640 235');
  svg.setAttribute('role', 'img');
  svg.setAttribute('aria-label', 'Remaining-life estimates in cycles by sample sequence. Gaps mean no prediction; exact values appear in the sample table.');
  function add(tag, attributes, text) {
    const item = document.createElementNS(ns, tag);
    for (const [key, value] of Object.entries(attributes)) item.setAttribute(key, value);
    if (text !== undefined) item.textContent = text;
    svg.append(item);
  }
  const first = samples[0].event.sequence, last = samples.at(-1).event.sequence;
  const max = Math.max(40, ...samples.map(s => s.prediction.remaining_cycles || 0)) * 1.1;
  const x = sequence => 40 + (sequence - first) / Math.max(1, last - first) * 578;
  const y = value => 194 - value / max * 167;
  for (let i = 0; i <= 4; i++) {
    add('line', {x1:40, x2:618, y1:y(max*i/4), y2:y(max*i/4), stroke:'#e3e9ef'});
    add('text', {x:32, y:y(max*i/4)+4, 'text-anchor':'end'}, number(max*i/4));
  }
  add('line', {x1:40, x2:618, y1:y(20), y2:y(20), stroke:'#b87327', 'stroke-dasharray':'5 4'});
  add('text', {x:618, y:y(20)-6, 'text-anchor':'end'}, 'Inspection threshold: 20 cycles');
  let previous = null;
  for (const sample of samples) {
    const value = sample.prediction.remaining_cycles;
    if (value == null) { previous = null; continue; }
    if (previous && sample.event.sequence === previous.event.sequence + 1 && sample.prediction.release_id === previous.prediction.release_id) {
      add('line', {x1:x(previous.event.sequence), y1:y(previous.prediction.remaining_cycles), x2:x(sample.event.sequence), y2:y(value), stroke:'#087b77', 'stroke-width':2.5});
    }
    add('circle', {cx:x(sample.event.sequence), cy:y(value), r:3, fill:'#087b77'});
    previous = sample;
  }
  add('text', {x:40,y:220}, `Sequence ${first}`);
  add('text', {x:618,y:220,'text-anchor':'end'}, `Sequence ${last}`);
  $(target).replaceChildren(svg);
}
