"use client";

import React, { useState } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers } from 'ethers';
import UserManagerABI from '../UserManagerABI.json';

const USER_MANAGER_ADDRESS = '0x424D1CAce0EbEC1Cdb38BcE19002A39541E46Ca8';

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
    <div style={{ maxWidth: '400px', margin: '0 auto', padding: '20px' }}>
      <h3>Check User's Balance in Smart Contract: UserManager.sol</h3>
      <p><strong>Your available balance:</strong> {availableBalance ?? 'N/A'}</p>
      <p><strong>Your locked balance:</strong> {lockedBalance ?? 'N/A'}</p>
      
      <button
        onClick={getUserBalance}
        style={{
          width: '100%',
          padding: '10px',
          backgroundColor: '#008CBA',
          color: 'white',
          border: 'none',
          cursor: 'pointer',
        }}
      >
        {loading ? 'Processing...' : 'Get Balance'}
      </button>

      <p>Status: {status}</p>
    </div>
  );
};

export default UserBalance;
