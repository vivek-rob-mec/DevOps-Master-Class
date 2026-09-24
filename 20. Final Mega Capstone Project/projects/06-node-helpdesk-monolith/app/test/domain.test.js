import test from"node:test";import assert from"node:assert/strict";import{calculateDueAt,validateTicket}from"../src/domain.js";
test("normalizes a valid ticket",()=>assert.deepEqual(validateTicket({title:" Login failure ",customerEmail:"USER@EXAMPLE.COM",priority:"high"}).value,{title:"Login failure",customerEmail:"user@example.com",priority:"high"}));
test("rejects unsupported priority",()=>assert.equal(validateTicket({title:"Login failure",customerEmail:"u@example.com",priority:"urgent"}).code,"INVALID_PRIORITY"));
test("critical SLA is thirty minutes",()=>assert.equal(calculateDueAt("critical",new Date("2026-01-01T00:00:00Z")),"2026-01-01T00:30:00.000Z"));
