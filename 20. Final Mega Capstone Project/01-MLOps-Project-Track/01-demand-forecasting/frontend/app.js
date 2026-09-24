"use strict";
const $ = (id) => document.getElementById(id);
const format = (v, digits = 0) => Number(v).toLocaleString(undefined, {maximumFractionDigits: digits});
const stamp = (v) => new Date(v * 1000).toLocaleString();
const method = (v) => v === "seasonal_naive" ? "Seasonal baseline" : "Random forest";
let overview, selected, detail, generation = 0, busy = false, pendingReview = null;
function notice(message, kind = "") { $("notice").textContent = message; $("notice").className = kind; $("notice").hidden = !message; }
async function api(path, options = {}) {
  const response = await fetch(path, {...options, headers: {"Content-Type": "application/json", ...options.headers}});
  const data = await response.json();
  if (!response.ok) throw new Error(typeof data.detail === "string" ? data.detail : "Invalid input. Check the form values.");
  return data;
}
function cell(row, text) { const td = document.createElement("td"); td.textContent = text; row.append(td); return td; }
function lockForms() {
  const dirty = detail && $("on-hand").value !== String(detail.product.on_hand ?? "");
  $("save-inventory").disabled = busy || !detail;
  $("save-review").disabled = busy || !detail || detail.product.revision === 0 || dirty || (detail.batch.stale && $("decision").value === "approved");
  $("refresh").disabled = busy;
  for (const button of $("product-list").querySelectorAll("button")) button.disabled = busy;
  $("on-hand").disabled = busy || !detail;
  $("review-form").querySelectorAll("input,select,textarea").forEach(el => el.disabled = busy || !detail);
}
function renderProducts() {
  const list = $("product-list"); list.replaceChildren();
  const products = overview.products.filter(p => p.sku.toLowerCase().includes($("search").value.toLowerCase()));
  for (const product of products) {
    const button = document.createElement("button"); button.className = "product"; button.type = "button";
    button.setAttribute("aria-pressed", String(product.sku === selected)); button.disabled = busy;
    const title = document.createElement("strong"); title.textContent = product.sku;
    const subtitle = document.createElement("span"); subtitle.textContent = `${format(product.demand)} units forecast`;
    button.append(title, subtitle); button.addEventListener("click", () => selectProduct(product.sku)); list.append(button);
  }
  if (!products.length) { const p = document.createElement("p"); p.className = "small subtle"; p.textContent = "No products match your search."; list.append(p); }
}
function chart(history, forecasts) {
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg"); svg.setAttribute("viewBox", "0 0 620 245"); svg.setAttribute("role", "img");
  svg.setAttribute("aria-label", "28 days of observed demand followed by 7 forecast days. Exact future values are in the table below.");
  const make = (tag, attrs, text) => { const el = document.createElementNS(ns, tag); for (const [k,v] of Object.entries(attrs)) el.setAttribute(k,v); if (text !== undefined) el.textContent = text; svg.append(el); return el; };
  const values = [...history.map(p => p.actual), ...forecasts.flatMap(p => [p.prediction,p.baseline])];
  const max = Math.max(10, Math.ceil(Math.max(...values) / 10) * 10);
  const x = i => 38 + i * 564 / (history.length + forecasts.length - 1), y = v => 210 - v / max * 182;
  make("rect", {x:x(history.length - .5),y:20,width:602-x(history.length - .5),height:190,fill:"#eff7f1"});
  for (let i=0;i<=4;i++) { const value=max*i/4; make("line",{x1:38,x2:602,y1:y(value),y2:y(value),stroke:"#e5eeea"}); make("text",{x:28,y:y(value)+4,"text-anchor":"end"},format(value)); }
  const line = (points, color, dashed = false) => make("polyline", {points:points.map(([i,v])=>`${x(i)},${y(v)}`).join(" "), fill:"none",stroke:color,"stroke-width":2.4,...(dashed?{"stroke-dasharray":"5 4"}:{})});
  line(history.map((p,i)=>[i,p.actual]),"#819795");
  line([[history.length-1,history.at(-1).actual],...forecasts.map((p,i)=>[history.length+i,p.prediction])],"#078677");
  line(forecasts.map((p,i)=>[history.length+i,p.baseline]),"#bd7b30",true);
  for (const [i, text, anchor] of [[0,history[0].date,"start"],[history.length-1,history.at(-1).date,"end"],[history.length+forecasts.length-1,forecasts.at(-1).date,"end"]]) make("text",{x:x(i),y:235,"text-anchor":anchor},text);
  make("text",{x:x(history.length),y:13,fill:"#087d70"},"FORECAST"); $("chart").replaceChildren(svg);
}
function renderEvidence(data) {
  const metrics = data.metrics;
  $("selected-model").textContent = method(metrics.selected);
  $("batch-status").textContent = data.batch.stale ? "Batch over 24 hours old" : "Published batch available";
  $("model-explanation").textContent = metrics.candidate_eligible ? "The random forest passed both acceptance checks and supplies this batch." : "The candidate did not pass both acceptance checks. The simpler seasonal baseline supplies this batch.";
  $("model-values").replaceChildren();
  for (const [name, val, test] of [["Seasonal baseline",metrics.validation_baseline,metrics.test_baseline],["Random forest",metrics.validation_candidate,metrics.test_candidate]]) {
    const tr = document.createElement("tr"); cell(tr,name); cell(tr,format(val.mae,3)); cell(tr,format(test.mae,3)); cell(tr,test.wape === null ? "N/A" : `${format(test.wape*100,2)}%`); $("model-values").append(tr);
  }
  $("published-release").textContent = data.batch.release_id; $("active-release").textContent = data.active_release_id || "No active release";
  $("batches").replaceChildren();
  for (const batch of data.batches) { const div=document.createElement("div"); div.className="batch-item"; const a=document.createElement("strong"), b=document.createElement("span"); a.textContent=`${batch.id.slice(0,10)} · ${batch.id === data.batch.id ? "Current" : "Previous"}`; b.textContent=stamp(batch.created); div.append(a,b); $("batches").append(div); }
  renderReviews(data.reviews);
}
function renderReviews(reviews) {
  $("reviews").replaceChildren(); $("no-reviews").hidden = reviews.length > 0; $("reviews-table").hidden = !reviews.length;
  for (const review of reviews) {
    const row=document.createElement("tr"); const product=cell(row,review.sku), time=document.createElement("small"); time.textContent=stamp(review.created_at); product.append(time);
    cell(row,review.decision).className=review.decision; cell(row,format(review.on_hand)); cell(row,format(review.recommended_units));
    const who=cell(row,review.reviewer), notes=document.createElement("small"); notes.textContent=review.notes || "No notes"; who.append(notes); $("reviews").append(row);
  }
}
function warnings(data) {
  const messages=[];
  if (data.batch.stale) messages.push("This batch is over 24 hours old. Approval is disabled by the API; you can defer a review or publish a new release and batch.");
  if (data.release_mismatch) messages.push("The active model differs from the published batch. This page shows evidence from the batch’s original release.");
  notice(messages.join(" "), "warning");
}
async function selectProduct(sku) {
  const token=++generation; selected=sku; detail=null; pendingReview=null; lockForms(); renderProducts();
  $("forecast-title").textContent=`${sku} · Loading…`; $("chart").replaceChildren(); $("daily-values").replaceChildren(); $("sku-demand").textContent="—"; $("recommended").textContent="—"; $("on-hand").value=""; $("notes").value=""; $("inventory-state").textContent="Loading saved inventory…";
  try {
    const data=await api(`/v1/products/${encodeURIComponent(sku)}/planning`); if(token!==generation) return;
    detail=data; overview=data; renderOverview();
    const product=data.product; $("forecast-title").textContent=sku; $("sku-demand").textContent=format(product.demand,1);
    $("forecast-range").textContent=`${data.forecasts[0].date} → ${data.forecasts.at(-1).date}`;
    $("on-hand").value=product.on_hand ?? ""; $("inventory-state").textContent=product.revision ? `Saved · revision ${product.revision} · ${stamp(product.updated_at)}` : "No stock count saved yet. Enter your observed inventory.";
    $("recommended").textContent=product.recommended_units === null ? "Save stock first" : `${format(product.recommended_units)} units`;
    chart(data.history,data.forecasts); $("daily-values").replaceChildren();
    for(const day of data.forecasts) {const row=document.createElement("tr"); cell(row,day.date);cell(row,format(day.prediction,2));cell(row,format(day.baseline,2));$("daily-values").append(row);}
    warnings(data);
  } catch(error) { if(token===generation) notice(error.message,"error"); }
  finally {if(token===generation) lockForms();}
}
function renderOverview() {
  $("product-count").textContent=overview.products.length; $("total-demand").textContent=format(overview.products.reduce((sum,p)=>sum+p.demand,0));
  $("inventory-count").textContent=`${overview.products.filter(p=>p.revision>0).length} / ${overview.products.length}`; renderProducts(); renderEvidence(overview);
}
async function refresh() {
  const token=++generation; detail=null; lockForms(); notice(""); $("loading").hidden=false; $("dashboard").hidden=true; $("empty").hidden=true;
  try { const data=await api("/v1/planner"); if(token!==generation) return; overview=data;
    $("empty").hidden=Boolean(data.batch); $("dashboard").hidden=!data.batch;
    if(data.batch) {renderOverview(); await selectProduct(data.products.some(p=>p.sku===selected)?selected:data.products[0].sku);}
  } catch(error) {notice(`${error.message} Use Refresh data to retry.`,"error");}
  finally {$("loading").hidden=true;lockForms();}
}
$("search").addEventListener("input",()=>{if(overview)renderProducts();}); $("refresh").addEventListener("click",refresh);
$("on-hand").addEventListener("input",lockForms);
$("review-form").addEventListener("input",()=>{pendingReview=null;lockForms();});
$("inventory-form").addEventListener("submit",async event=>{
  event.preventDefault(); if(!detail || busy)return; const sku=selected, revision=detail.product.revision;
  busy=true;lockForms();
  try{await api(`/v1/inventory/${encodeURIComponent(sku)}`,{method:"PUT",body:JSON.stringify({on_hand:Number($("on-hand").value),revision})});await selectProduct(sku);notice("Inventory saved. The suggestion now uses your saved stock count.");}
  catch(error){notice(error.message,"error");}finally{busy=false;lockForms();}
});
$("review-form").addEventListener("submit",async event=>{
  event.preventDefault(); if(!detail || busy || $("save-review").disabled)return;
  if(!pendingReview)pendingReview={request_id:crypto.randomUUID(),sku:selected,batch_id:detail.batch.id,inventory_revision:detail.product.revision,decision:$("decision").value,reviewer:$("reviewer").value,notes:$("notes").value};
  busy=true;lockForms();
  try{await api("/v1/replenishment-reviews",{method:"POST",body:JSON.stringify(pendingReview)});await selectProduct(selected);notice("Review saved to SQLite. No purchase order was created.");}
  catch(error){notice(error.message,"error");}finally{busy=false;lockForms();}
});
refresh();
