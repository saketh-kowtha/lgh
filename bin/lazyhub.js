if (process.argv.includes('--mouse')) {
  process.env.LAZYHUB_MOUSE = '1'
}

// MCP server mode: lazyhub --mcp
// Speaks Model Context Protocol over stdio so AI assistants can query/act on GitHub data.
if (process.argv.includes('--mcp')) {
  const { bootstrap } = await import('../src/bootstrap.js')
  const { runMCPServer } = await import('../src/mcp.js')
  // Detect repo context (needed for executor calls) but skip Ink rendering
  await bootstrap(null)
  await runMCPServer()
  process.exit(0)
}

import { bootstrap } from '../src/bootstrap.js'
import { renderApp } from '../src/app.jsx'
import { loadConfig } from '../src/config.js'
import { startIPC } from '../src/ipc.js'

const cfg = loadConfig()

// Start IPC server for IDE integrations (unless disabled in config)
if (cfg.ipc?.enabled !== false) {
  const socketPath = startIPC()
  process.env.LAZYHUB_SOCKET = socketPath
}

await bootstrap(renderApp)
