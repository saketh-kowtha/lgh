/**
 * useDialog.js — dialog open/close/stack management hook.
 */

import { useState, useCallback } from 'react'

/**
 * useDialog() — manages a stack of open dialogs.
 * Dialogs are identified by name and carry optional props.
 */
export function useDialog() {
  const [stack, setStack] = useState([])

  const openDialog = useCallback((name, props = {}) => {
    setStack((s) => [...s, { name, props }])
  }, [])

  const closeDialog = useCallback(() => {
    setStack((s) => s.slice(0, -1))
  }, [])

  const closeAll = useCallback(() => {
    setStack([])
  }, [])

  const currentDialog = stack.length > 0 ? stack[stack.length - 1] : null

  return {
    stack,
    currentDialog,
    openDialog,
    closeDialog,
    closeAll,
  }
}
