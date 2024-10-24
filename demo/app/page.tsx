"use client";

import React from 'react'
import dynamic from 'next/dynamic'
import { Web3Provider } from './Web3Provider'


const DepositComponent = dynamic(
  () => import('./components/DepositComponent').then((mod) => mod.DepositComponent),
  { ssr: false }
)


export default function Home() {
  return (
    <Web3Provider>
      <main>
        <h1>USDC Deposit Demo</h1>
        <DepositComponent />
      </main>
    </Web3Provider>
  )
}