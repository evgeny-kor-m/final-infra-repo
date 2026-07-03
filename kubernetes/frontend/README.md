

### Trace

Step 1 — Install the package:
cd final-frontend-repo/src
npm install @elastic/apm-rum

Step 2 — Add the following to src/main.jsx as the first line:
import { init as initApm } from '@elastic/apm-rum'

initApm({
serviceName: 'frontend',
serverUrl: 'http://apm-server-apm-server.monitoring.svc.cluster.local:8200',
environment: 'production',
active: true,
})

Step 3 — Commit and push to DEV:
git add src/main.jsx src/package.json src/package-lock.json
git commit -m "add elastic APM RUM agent"
git push origin DEV