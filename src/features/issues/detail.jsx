/**
 * src/features/issues/detail.jsx — Issue detail pane
 */

import React, { useState } from 'react'
import { Box, Text, useInput } from 'ink'
import { format } from 'timeago.js'
import { useGh } from '../../hooks/useGh.js'
import { getIssue, addPRComment } from '../../executor.js'
import { FooterKeys } from '../../components/FooterKeys.jsx'
import { t } from '../../theme.js'

const FOOTER_KEYS = [
  { key: 'r', label: 'reply' },
  { key: 'Esc', label: 'back' },
]

export function IssueDetail({ issueNumber, repo, onBack }) {
  const { data: issue, loading, error, refetch } = useGh(getIssue, [repo, issueNumber])
  const [bodyExpanded, setBodyExpanded] = useState(false)
  const [replyMode, setReplyMode] = useState(false)
  const [replyText, setReplyText] = useState('')
  const [statusMsg, setStatusMsg] = useState(null)

  useInput((input, key) => {
    if (replyMode) {
      if (key.escape) { setReplyMode(false); setReplyText(''); return }
      if (key.return && key.ctrl) {
        addPRComment(repo, issueNumber, replyText)
          .then(() => { setStatusMsg('Reply sent'); refetch() })
          .catch(err => setStatusMsg(`Failed: ${err.message}`))
        setTimeout(() => setStatusMsg(null), 3000)
        setReplyMode(false)
        setReplyText('')
        return
      }
      if (key.backspace || key.delete) { setReplyText(r => r.slice(0, -1)); return }
      if (input && !key.ctrl && !key.meta) { setReplyText(r => r + input); return }
      return
    }

    if (input === 'r' && !replyMode) { setReplyMode(true); return }
    if (key.escape || input === 'q') { onBack(); return }
    if (key.return && !bodyExpanded) { setBodyExpanded(true); return }
  })

  if (loading) return <Box paddingX={1}><Text color={t.ui.muted}>Loading...</Text></Box>
  if (error) return <Box paddingX={1}><Text color={t.ci.fail}>⚠ Failed — r to retry</Text></Box>
  if (!issue) return null

  const bodyLines = (issue.body || '').split('\n')
  const displayBody = bodyExpanded ? bodyLines : bodyLines.slice(0, 8)
  const stateColor = issue.state === 'OPEN' ? t.issue.open : t.issue.closed

  return (
    <Box flexDirection="column" flexGrow={1} paddingX={1}>
      <Box marginBottom={1} flexDirection="column">
        <Box gap={1}>
          <Text color={stateColor}>{issue.state === 'OPEN' ? '○' : '✓'}</Text>
          <Text bold color={t.ui.selected} wrap="truncate">#{issue.number} {issue.title}</Text>
        </Box>
        <Box gap={2}>
          <Text color={t.ui.muted}>by {issue.author?.login}</Text>
          <Text color={t.ui.dim}>{format(issue.updatedAt)}</Text>
        </Box>
      </Box>

      {issue.labels?.length > 0 && (
        <Box marginBottom={1} gap={1}>
          {issue.labels.map(l => (
            <Box key={l.name} paddingX={1} borderStyle="round" borderColor={`#${l.color}`}>
              <Text color={`#${l.color}`}>{l.name}</Text>
            </Box>
          ))}
        </Box>
      )}

      {issue.body && (
        <Box flexDirection="column" marginBottom={1}>
          <Text color={t.ui.muted} bold>Description:</Text>
          <Box flexDirection="column" borderStyle="single" borderColor={t.ui.border} paddingX={1}>
            {displayBody.map((line, i) => (
              <Text key={i} color={t.diff.ctxFg} wrap="truncate">{line || ' '}</Text>
            ))}
            {!bodyExpanded && bodyLines.length > 8 && (
              <Text color={t.ui.dim}>[Enter] expand ({bodyLines.length - 8} more lines)</Text>
            )}
          </Box>
        </Box>
      )}

      {issue.comments?.length > 0 && (
        <Box flexDirection="column" marginBottom={1}>
          <Text color={t.ui.muted} bold>Comments ({issue.comments.length}):</Text>
          {issue.comments.slice(0, 5).map((c, i) => (
            <Box key={i} flexDirection="column" paddingX={1} marginBottom={1}>
              <Box gap={1}>
                <Text color={t.ui.selected}>{c.author?.login}</Text>
                <Text color={t.ui.dim}>{format(c.updatedAt || c.createdAt)}</Text>
              </Box>
              <Text color={t.diff.ctxFg} wrap="truncate">{c.body?.slice(0, 120)}</Text>
            </Box>
          ))}
        </Box>
      )}

      {replyMode && (
        <Box flexDirection="column" borderStyle="round" borderColor={t.diff.threadBorder} paddingX={1}>
          <Text color={t.ui.muted}>Reply:</Text>
          <Box>
            <Text color={t.ui.selected}>{replyText}</Text>
            <Text color={t.ui.dim}>█</Text>
          </Box>
          <Text color={t.ui.dim}>[Ctrl+Enter] send  [Esc] cancel</Text>
        </Box>
      )}

      {statusMsg && <Text color={t.ci.pass}>{statusMsg}</Text>}

      <FooterKeys keys={FOOTER_KEYS} />
    </Box>
  )
}
