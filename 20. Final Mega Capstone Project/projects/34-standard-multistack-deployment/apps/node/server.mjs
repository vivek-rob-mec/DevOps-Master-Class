import http from 'node:http';

const server = http.createServer((req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  let status = 200;
  let body = { status: 'ok' };
  if (req.method !== 'GET') {
    status = 405;
    body = { error: 'method not allowed' };
    res.setHeader('Allow', 'GET');
  } else if (path === '/api/info') {
    body = { service: 'deployment-demo', stack: 'node',
      version: process.env.APP_VERSION || 'dev', environment: process.env.APP_ENV || 'local' };
  } else if (!['/healthz', '/readyz'].includes(path)) {
    status = 404;
    body = { error: 'not found' };
  }
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
  console.log(JSON.stringify({ event: 'request', status, stack: 'node' }));
});
server.requestTimeout = 15000;
server.headersTimeout = 10000;
server.listen(Number(process.env.PORT || 8080), '0.0.0.0');
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 20000).unref();
  });
}
