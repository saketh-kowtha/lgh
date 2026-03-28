/**
 * useNav.js — global pane navigation state hook.
 */

import { useState, useCallback } from 'react'

export const PANES = ['prs', 'issues', 'branches', 'actions', 'releases', 'gists', 'notifications']

/**
 * useNav() — manages which sidebar pane is active and which item is selected.
 */
export function useNav() {
  const [activePane, setActivePane] = useState('prs')
  const [selectedItem, setSelectedItem] = useState(null)

  const nextPane = useCallback(() => {
    setActivePane((current) => {
      const idx = PANES.indexOf(current)
      return PANES[(idx + 1) % PANES.length]
    })
    setSelectedItem(null)
  }, [])

  const prevPane = useCallback(() => {
    setActivePane((current) => {
      const idx = PANES.indexOf(current)
      return PANES[(idx - 1 + PANES.length) % PANES.length]
    })
    setSelectedItem(null)
  }, [])

  const goToPane = useCallback((pane) => {
    if (PANES.includes(pane)) {
      setActivePane(pane)
      setSelectedItem(null)
    }
  }, [])

  return {
    activePane,
    selectedItem,
    setSelectedItem,
    nextPane,
    prevPane,
    goToPane,
  }
}
