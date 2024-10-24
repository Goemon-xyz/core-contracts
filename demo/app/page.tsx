"use client";

import React from 'react'
import dynamic from 'next/dynamic'
import { Web3Provider } from './Web3Provider'
import UserBalance from './components/UserBalance';
import ConnectWallet from './components/ConnectWallet';
import WithdrawComponent from './components/WithdrawComponent';
import LockUserBalance from './components/LockUserBalance';
import SettleIntentComponent from './components/SettleIntentComponent';



const DepositComponent = dynamic(
  () => import('./components/DepositComponent').then((mod) => mod.DepositComponent),
  { ssr: false }
)


export default function Home() {
  return (
    <Web3Provider>
      <main className="p-4">
        <div className='relative'>
        <h1 className='text-3xl font-medium text-center mt-2'>Core-contracts Integration Demo</h1>
         <ConnectWallet/>
        </div>
        <hr className='mt-4 mb-10'/>
        <section className='max-w-2xl mx-auto space-y-16'>
            <DepositComponent />
            <UserBalance/>
            <WithdrawComponent/>
            <LockUserBalance/>
            <SettleIntentComponent/>

        </section>
      </main>
    </Web3Provider>
  )
}