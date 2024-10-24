"use client";

import React from 'react'
import { metaMask } from '../connector';
import { useWeb3React } from '@web3-react/core';

const ConnectWallet = () => {
    const { account, isActive } = useWeb3React();
  
 // Connect wallet function
 async function connectWallet() {
    try {
      await metaMask.activate();
    } catch (error) {
      console.error('Failed to connect wallet:', error);
      alert('Failed to connect wallet.');
    }
  }

  return (
    <div className='absolute right-0 top-0'>
        {isActive ? 
        <div> <span className='font-semibold mr-2'>Wallet :</span> 
            {account?.slice(0,7)}...
            {account?.slice(-5)}
        </div> :
        <button
            className='px-5 py-2.5 bg-[#008CBA] text-white rounded-full hover:bg-blue-800'
            onClick={connectWallet}
          >
            Connect Wallet
          </button> }
    </div>
  )
}

export default ConnectWallet