"use client";

import { Web3ReactProvider } from '@web3-react/core'
import { connectors } from './connector'

export function Web3Provider({ children }: { children: React.ReactNode }) {
  return (
    <Web3ReactProvider connectors={connectors}>
      {children}
    </Web3ReactProvider>
  )
}