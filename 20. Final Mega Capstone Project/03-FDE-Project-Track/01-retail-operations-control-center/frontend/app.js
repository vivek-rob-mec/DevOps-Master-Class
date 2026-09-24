const $ = id => document.getElementById(id);
const id = () => crypto.randomUUID();
let view = null, selectedJob = null, reviewId = id();
const message = (text, error=false) => { $('notice').textContent=text; $('notice').classList.toggle('error',error); };
async function api(path, body) {
  const response = await fetch(path, body === undefined ? {} : {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  const value = await response.json();
  if (!response.ok) throw Error(typeof value.detail === 'string' ? value.detail : JSON.stringify(value.detail));
  return value;
}
function node(tag,text,className) { const el=document.createElement(tag); el.textContent=text; if(className) el.className=className; return el; }
function table(headers,rows) {
  const wrap=node('div','', 'scroll'), t=document.createElement('table'), head=document.createElement('thead'), h=document.createElement('tr');
  headers.forEach(v=>h.append(node('th',v))); head.append(h); t.append(head);
  const body=document.createElement('tbody'); rows.forEach(row=>{const tr=document.createElement('tr');row.forEach(v=>tr.append(node('td',String(v))));body.append(tr);});
  t.append(body);wrap.append(t);return wrap;
}
function reviewEnabled() {
  const finalized=view?.reviews.find(r=>r.job_id===selectedJob?.id && r.sku===$('sku').value);
  $('decision').disabled=!!finalized; $('reviewer').readOnly=!!finalized; $('notes').readOnly=!!finalized;
  if(finalized) { $('decision').value=finalized.decision; $('reviewer').value=finalized.reviewer; $('notes').value=finalized.notes; }
  $('save-review').disabled=!selectedJob || !selectedJob.result || finalized;
}
async function refresh() {
  view=await api('/v1/desk'); const batch=view.batch;
  $('through').textContent=batch?.through_date || '—'; $('coverage').textContent=batch ? `${batch.skus} / ${batch.days}` : '—';
  $('empty').hidden=!!batch; $('batch').textContent=batch ? `Snapshot ${batch.id}` : '';
  $('historical').textContent=batch?.historical ? 'Historical snapshot: this is a replay, not a current purchasing instruction.' : '';
  selectedJob=view.current_job;
  $('job-state').textContent=selectedJob?.state || 'Not queued'; $('queue').disabled=!batch || !!selectedJob;
  $('forecast').replaceChildren();
  const oldSku=$('sku').value; $('sku').replaceChildren();
  if(selectedJob?.result) {
    const result=selectedJob.result;
    $('forecast').append(node('p',result.assumptions,'hint'),table(['Product','7-day units','On hand','Buffer','Suggested','Backtest MAE'],result.items.map(i=>[i.sku,i.forecast_units,i.on_hand,i.safety_stock,i.suggested_units,i.backtest_mae.toFixed(2)])));
    result.items.forEach(i=>{const option=node('option',i.sku);option.value=i.sku;$('sku').append(option);});
    if(result.items.some(i=>i.sku===oldSku)) $('sku').value=oldSku;
    $('forecast').append(node('p',result.evaluation,'hint'));
  }
  $('jobs').replaceChildren(table(['Job','State','Attempts','Details'],view.jobs.map(j=>[j.id.slice(0,12),j.state,j.attempts,j.error || (j.state==='queued' ? 'Waiting for worker' : j.method)])));
  $('reviews').replaceChildren();
  view.reviews.forEach(r=>{const card=node('article','','review-card');card.append(node('strong',`${r.sku} · ${r.decision} · ${r.recommendation.suggested_units} suggested units`),node('p',`${r.reviewer}: ${r.notes}`),node('p',`Saved ${new Date(r.created_at*1000).toLocaleString()} · Executed: no`,'hint'),node('p',`Forecast ${r.job_id}`,'mono'));$('reviews').append(card);});
  if(!view.reviews.length) $('reviews').append(node('p','No reviews recorded.','hint'));
  reviewEnabled();
}
async function action(work) {
  const buttons=[...document.querySelectorAll('button')]; const disabled=buttons.map(b=>b.disabled); buttons.forEach(b=>b.disabled=true);
  try {await work();} catch(error) {message(error.message,true);} finally {buttons.forEach((b,i)=>b.disabled=disabled[i]); $('queue').disabled=!view?.batch || !!selectedJob;reviewEnabled();}
}
$('import-id').value=id();
$('refresh').onclick=()=>action(async()=>{await refresh();message('Ledger refreshed.');});
$('sample').onclick=()=>action(async()=>{const data=await api('/v1/erp/export');$('sales').value=data.sales_csv;$('inventory').value=data.inventory_csv;$('import-id').value=id();message(data.source);});
for(const field of ['sales','inventory']) {
  $(field).addEventListener('input',()=>{$('import-id').value=id();});
  $(`${field}-file`).addEventListener('change',()=>action(async()=>{const file=$(`${field}-file`).files[0];if(!file)return;if(file.size>(field==='sales'?1000000:50000))throw Error('CSV file is too large');$(field).value=await file.text();$('import-id').value=id();message('File loaded. Validate to publish.');}));
}
$('import-form').onsubmit=event=>{event.preventDefault();action(async()=>{await api('/v1/imports',{request_id:$('import-id').value,sales_csv:$('sales').value,inventory_csv:$('inventory').value});await refresh();message('Snapshot validated and published.');});};
$('queue').onclick=()=>action(async()=>{await api('/v1/jobs',{request_id:`queue-${view.batch.id}`,batch_id:view.batch.id});await refresh();message('Forecast queued. Start the worker, then refresh data.');});
for(const field of ['sku','decision','reviewer','notes']) $(field).addEventListener('input',()=>{reviewId=id();reviewEnabled();});
$('review-form').onsubmit=event=>{event.preventDefault();action(async()=>{await api('/v1/reviews',{request_id:reviewId,job_id:selectedJob.id,sku:$('sku').value,decision:$('decision').value,reviewer:$('reviewer').value,notes:$('notes').value});await refresh();message('Review saved. No purchase order was executed.');});};
action(async()=>{await refresh();message('Ready. Start with a customer export.');});
