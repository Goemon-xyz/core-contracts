"use client";

import React, { useState } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers } from 'ethers';
import UserManagerABI from '../abi/UserManagerABI.json';

const USER_MANAGER_ADDRESS = '';

const UserBalance = () => {
  const { account, isActive, provider } = useWeb3React();
  const [loading, setLoading] = useState<boolean>(false);
  const [status, setStatus] = useState<string>('');
  const [availableBalance, setAvailableBalance] = useState<string | null>(null);
  const [lockedBalance, setLockedBalance] = useState<string | null>(null);

  async function getUserBalance() {
    if (!isActive || !provider || !account) {
      alert('Please connect your wallet');
      return;
    }

    setLoading(true);
    setStatus('Fetching user\'s balance...');

    try {
      const signer = provider.getSigner();
      const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, UserManagerABI, signer);

      // Call the view function directly without sending a transaction
      const [available, locked] = await userManager.getUserBalance(account);

      console.log("Available balance:", ethers.utils.formatUnits(available, 6));
      console.log("Locked balance:", ethers.utils.formatUnits(locked, 6));

      setAvailableBalance(ethers.utils.formatUnits(available, 6));
      setLockedBalance(ethers.utils.formatUnits(locked, 6));
      setStatus('Successfully fetched user balance');
    } catch (error: any) {
      console.error('User Balance error:', error);
      setStatus('Failed to fetch balance');
    } finally {
      setLoading(false);
    }
  }


  return (
    <div>
      <h2 className="text-xl font-semibold">User Balance in Smart Contract: UserManager.sol</h2>
      <hr className='mt-2 mb-4'/>
      <p><strong>Your available balance:</strong> {availableBalance ?? 'N/A'}</p>
      <p><strong>Your locked balance:</strong> {lockedBalance ?? 'N/A'}</p>
      
      <button
        onClick={getUserBalance}
        className='w-full p-3 bg-[#008CBA] hover:bg-blue-800 text-white cursor-pointer my-4'
      >
        {loading ? 'Processing...' : 'Get Balance'}
      </button>

      <p>Status: {status}</p>
    </div>
  );
};

export default UserBalance;
