/**
 * theme.js — single source of truth for all colors used in ghui.
 * Import { t } from './theme.js' everywhere — never inline hex strings.
 */

export const t = {
  pr: {
    open:   '#3fb950',
    merged: '#a371f7',
    closed: '#8b949e',
    draft:  '#8b949e',
  },
  issue: {
    open:   '#3fb950',
    closed: '#8b949e',
  },
  ci: {
    pass:    '#3fb950',
    fail:    '#f85149',
    pending: '#d29922',
    running: '#d29922',
  },
  ui: {
    selected:  '#58a6ff',  // focused row + active nav border
    muted:     '#8b949e',  // secondary text
    dim:       '#484f58',  // timestamps, hints
    border:    '#21262d',
    headerBg:  '#161b22',
  },
  diff: {
    addBg:        '#0d2a17',
    addFg:        '#3fb950',
    delBg:        '#2a0d0d',
    delFg:        '#f85149',
    ctxFg:        '#c9d1d9',
    hunkFg:       '#8b949e',
    hunkBg:       '#161b22',
    threadBg:     '#161b22',
    threadBorder: '#388bfd',
    cursorBg:     '#388bfd26',
  },
}
