-- lazyhub.nvim — Deep NeoVim integration for lazyhub
-- https://github.com/saketh-kowtha/lazyhub
--
-- Features:
--   :LazyHub              open lazyhub in a floating terminal
--   :LazyHubPR            open lazyhub focused on PR for current branch
--   :LazyHubBlame         open PR that introduced the line under cursor
--   :LazyHubDiagnostics   load PR review comments as vim diagnostics
--   :LazyHubState         show current lazyhub IPC state
--
-- IPC: communicates with a running lazyhub instance via ~/.lazyhub-socket
-- (lazyhub must be running with IPC enabled, which is the default)

local M = {}

-- ─── Default config ───────────────────────────────────────────────────────────

M.config = {
  -- Floating window dimensions (0–1 as fraction of screen, or absolute integer)
  width  = 0.9,
  height = 0.9,
  border = 'rounded',    -- 'none' | 'single' | 'double' | 'rounded' | 'solid'

  -- Key to close the floating window from within lazyhub
  -- (lazyhub's own Esc/q handles this, this is a fallback)
  close_key = '<C-q>',

  -- Namespace for diagnostics
  diagnostics_ns = vim.api.nvim_create_namespace('lazyhub'),

  -- Auto-load PR review comments as diagnostics when entering a buffer
  -- that belongs to an open PR (requires lazyhub to be running)
  auto_diagnostics = false,
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function socket_path()
  local pointer = vim.fn.expand('~/.lazyhub-socket')
  if vim.fn.filereadable(pointer) == 1 then
    return vim.fn.readfile(pointer)[1]
  end
  return nil
end

--- Send a request to a running lazyhub IPC server.
--- @param msg table   request object
--- @param cb  function(response|nil)  callback
local function ipc_send(msg, cb)
  local path = socket_path()
  if not path or vim.fn.filereadable(path) == 0 then
    if cb then cb(nil) end
    return
  end

  msg.id = tostring(math.random(1e9))
  local json = vim.json.encode(msg) .. '\n'

  local ok, uv = pcall(require, 'luv')
  if not ok then uv = vim.uv or vim.loop end

  local client = uv.new_pipe(false)
  local buf = ''

  client:connect(path, function(err)
    if err then
      client:close()
      if cb then vim.schedule(function() cb(nil) end) end
      return
    end
    client:write(json)
    client:read_start(function(rerr, data)
      if rerr or not data then
        client:close()
        return
      end
      buf = buf .. data
      for line in buf:gmatch('[^\n]+') do
        local ok2, parsed = pcall(vim.json.decode, line)
        if ok2 and parsed.id == msg.id then
          client:close()
          if cb then vim.schedule(function() cb(parsed) end) end
          return
        end
      end
    end)
  end)
end

--- Create a floating terminal window running `cmd`.
--- Returns the window id.
local function open_float(cmd)
  local width  = M.config.width  <= 1 and math.floor(vim.o.columns * M.config.width)  or M.config.width
  local height = M.config.height <= 1 and math.floor(vim.o.lines   * M.config.height) or M.config.height
  local row    = math.floor((vim.o.lines   - height) / 2)
  local col    = math.floor((vim.o.columns - width)  / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width    = width,
    height   = height,
    row      = row,
    col      = col,
    style    = 'minimal',
    border   = M.config.border,
    title    = ' lazyhub ',
    title_pos = 'center',
  })

  vim.fn.termopen(cmd, {
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })

  -- Close keybinding inside the terminal buffer
  vim.api.nvim_buf_set_keymap(buf, 't', M.config.close_key,
    '<C-\\><C-n>:close<CR>', { noremap = true, silent = true })

  vim.cmd('startinsert')
  return win
end

-- ─── Commands ─────────────────────────────────────────────────────────────────

--- Open lazyhub in a floating terminal.
function M.open(opts)
  opts = opts or {}
  local cmd = 'lazyhub'
  -- Pass current repo via env if not already set
  local repo_env = ''
  if opts.repo then
    repo_env = 'GHUI_REPO=' .. opts.repo .. ' '
  end
  open_float(repo_env .. cmd)
end

--- Open lazyhub focused on the PR for the current git branch.
function M.open_pr()
  local branch = vim.fn.system('git rev-parse --abbrev-ref HEAD 2>/dev/null'):gsub('%s+$', '')
  if branch == '' or branch == 'HEAD' then
    vim.notify('[lazyhub] not in a git repo or detached HEAD', vim.log.levels.WARN)
    return
  end
  -- Open lazyhub — it will auto-detect the repo; user navigates to the PR
  -- In the future this can be wired to IPC navigate once lazyhub supports branch→PR lookup
  M.open({ branch = branch })
end

--- Open lazyhub and navigate to the PR that introduced the line under the cursor
--- (uses git blame to find the commit SHA, then asks lazyhub via IPC).
function M.blame_pr()
  local file = vim.fn.expand('%:p')
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local sha  = vim.fn.system(
    string.format('git blame -L %d,%d --porcelain %s 2>/dev/null | head -1 | cut -d" " -f1',
      line, line, vim.fn.shellescape(file))
  ):gsub('%s+$', '')

  if sha == '' or sha:match('^0+$') then
    vim.notify('[lazyhub] could not determine commit for this line', vim.log.levels.WARN)
    return
  end

  -- Try to find a PR number from the commit message or gh CLI
  vim.fn.jobstart(
    { 'gh', 'pr', 'list', '--search', sha, '--json', 'number', '--jq', '.[0].number' },
    {
      stdout_buffered = true,
      on_stdout = function(_, data)
        local pr_num = tonumber((data[1] or ''):gsub('%s+', ''))
        if pr_num then
          ipc_send({ type = 'navigate', prNumber = pr_num }, function()
            M.open()
          end)
        else
          vim.notify('[lazyhub] no PR found for commit ' .. sha:sub(1, 8), vim.log.levels.INFO)
          M.open()
        end
      end,
    }
  )
end

--- Load PR review comments as Neovim diagnostics.
--- Requires a running lazyhub instance (for IPC state) or falls back to gh CLI.
function M.load_diagnostics()
  ipc_send({ type = 'state' }, function(resp)
    local pr_number = resp and resp.state and resp.state.prNumber
    if not pr_number then
      vim.notify('[lazyhub] no PR open in lazyhub', vim.log.levels.INFO)
      return
    end

    local repo = (resp.state and resp.state.repo) or
                 vim.fn.system('gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null'):gsub('%s+$', '')

    vim.fn.jobstart(
      { 'gh', 'api', string.format('repos/%s/pulls/%d/comments', repo, pr_number),
        '--jq', '[.[] | {path: .path, line: .line, body: .body, user: .user.login}]' },
      {
        stdout_buffered = true,
        on_stdout = function(_, data)
          local json = table.concat(data, '')
          if json == '' then return end
          local ok, comments = pcall(vim.json.decode, json)
          if not ok or type(comments) ~= 'table' then return end

          -- Clear existing diagnostics
          vim.diagnostic.reset(M.config.diagnostics_ns)

          -- Group comments by file
          local by_file = {}
          for _, c in ipairs(comments) do
            if c.path and c.line then
              by_file[c.path] = by_file[c.path] or {}
              table.insert(by_file[c.path], c)
            end
          end

          -- Set diagnostics on each open buffer
          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if not vim.api.nvim_buf_is_loaded(bufnr) then goto continue end
            local bufpath = vim.api.nvim_buf_get_name(bufnr)
            -- Match on the filename portion (PR paths are relative to repo root)
            for file_path, file_comments in pairs(by_file) do
              if bufpath:find(file_path, 1, true) then
                local diags = {}
                for _, c in ipairs(file_comments) do
                  table.insert(diags, {
                    lnum     = (c.line or 1) - 1,  -- 0-indexed
                    col      = 0,
                    severity = vim.diagnostic.severity.INFO,
                    message  = string.format('[%s] %s', c.user or 'reviewer', c.body or ''),
                    source   = 'lazyhub',
                  })
                end
                vim.diagnostic.set(M.config.diagnostics_ns, bufnr, diags)
              end
            end
            ::continue::
          end

          local total = #comments
          vim.notify(string.format('[lazyhub] loaded %d review comment%s as diagnostics',
            total, total == 1 and '' or 's'), vim.log.levels.INFO)
        end,
      }
    )
  end)
end

--- Show current lazyhub IPC state in a floating notification.
function M.show_state()
  ipc_send({ type = 'state' }, function(resp)
    if not resp or not resp.state then
      vim.notify('[lazyhub] not running or IPC unavailable', vim.log.levels.WARN)
      return
    end
    local s = resp.state
    local lines = {
      string.format('repo:  %s', s.repo  or '—'),
      string.format('pane:  %s', s.pane  or '—'),
      string.format('view:  %s', s.view  or '—'),
      s.prNumber    and string.format('PR:    #%d', s.prNumber)    or nil,
      s.issueNumber and string.format('issue: #%d', s.issueNumber) or nil,
    }
    -- Filter nils
    local filtered = {}
    for _, l in ipairs(lines) do if l then table.insert(filtered, l) end end
    vim.notify(table.concat(filtered, '\n'), vim.log.levels.INFO, { title = 'lazyhub state' })
  end)
end

-- ─── Setup ────────────────────────────────────────────────────────────────────

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  vim.api.nvim_create_user_command('LazyHub',          function() M.open() end,         { desc = 'Open lazyhub' })
  vim.api.nvim_create_user_command('LazyHubPR',        function() M.open_pr() end,      { desc = 'Open lazyhub for current branch PR' })
  vim.api.nvim_create_user_command('LazyHubBlame',     function() M.blame_pr() end,     { desc = 'Open PR that introduced line under cursor' })
  vim.api.nvim_create_user_command('LazyHubDiag',      function() M.load_diagnostics() end, { desc = 'Load PR review comments as diagnostics' })
  vim.api.nvim_create_user_command('LazyHubState',     function() M.show_state() end,   { desc = 'Show current lazyhub IPC state' })

  -- Auto-load diagnostics on BufEnter if enabled
  if M.config.auto_diagnostics then
    vim.api.nvim_create_autocmd('BufEnter', {
      group = vim.api.nvim_create_augroup('lazyhub_auto_diag', { clear = true }),
      callback = function() M.load_diagnostics() end,
    })
  end
end

return M
