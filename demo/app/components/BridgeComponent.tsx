import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { useWeb3React } from '@web3-react/core';
import { metaMask } from '../connector'; // Ensure you have a connector setup for MetaMask
import axios from 'axios';

export function BridgeComponent() {
  const { account, isActive, provider } = useWeb3React();
  const [amount, setAmount] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [status, setStatus] = useState<string>('');

  useEffect(() => {
    if (isActive && account) {
      // Additional setup if needed
    }
  }, [isActive, account]);

  const connectWallet = async () => {
    try {
      await metaMask.activate();
    } catch (error) {
      console.error('Failed to connect wallet:', error);
      alert('Failed to connect wallet.');
    }
  };

  const handleBridge = async () => {
    if (!isActive || !provider) {
      alert('Please connect your wallet');
      return;
    }
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      alert('Enter a valid ETH amount');
      return;
    }

    setLoading(true);
    setStatus('Requesting quote...');

    try {
      const amountWei = ethers.utils.parseUnits(amount, 'ether');

      // Step 1: Request a quote from Across API
      const quoteResponse = await axios.get('https://app.across.to/api/suggested-fees', {
        params: {
          originChainId: 42161, // Arbitrum chain ID
          destinationChainId: 11155111, // Sepolia chain ID
          token: '0x0000000000000000000000000000000000000000', // ETH address
          amount: amountWei.toString(),
        },
      });

      const { totalRelayFee, timestamp, exclusivityDeadline, exclusiveRelayer } = quoteResponse.data;

      // Step 2: Initiate a deposit using the quote data
      const signer = provider.getSigner();
      const spokePoolAddress = '0xYourSpokePoolAddress'; // Replace with actual SpokePool address
      const spokePoolABI = [ /* ABI for SpokePool contract */ ];
      const spokePool = new ethers.Contract(spokePoolAddress, spokePoolABI, signer);

      const depositTx = await spokePool.depositV3(
        account, // depositor
        account, // recipient
        '0x980B62Da83eFf3D4576C647993b0c1D7faf17c73', // inputToken (ETH)
        '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14', // outputToken (ETH)
        amountWei, // inputAmount
        amountWei.sub(totalRelayFee.total), // outputAmount
        11155111, // destinationChainId (Sepolia)
        exclusiveRelayer, // exclusiveRelayer
        timestamp, // quoteTimestamp
        Math.floor(Date.now() / 1000) + 18000, // fillDeadline (5 hours from now)
        exclusivityDeadline, // exclusivityDeadline
        '0x' // message
      );

      await depositTx.wait();

      setStatus('ETH bridged successfully to Sepolia!');
      alert('ETH bridged successfully to Sepolia!');
    } catch (error: any) {
      console.error('Bridge error:', error);
      setStatus('Bridge failed. Check console for details.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: '400px', margin: '0 auto', padding: '20px' }}>
      <h2>Bridge ETH from Arbitrum to Sepolia</h2>
      {isActive ? (
        <>
          <p><strong>Account:</strong> {account}</p>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="ETH Amount"
            style={{ width: '100%', padding: '8px', marginBottom: '10px' }}
          />
          <button
            onClick={handleBridge}
            style={{
              width: '100%',
              padding: '10px',
              backgroundColor: '#008CBA',
              color: 'white',
              border: 'none',
              cursor: 'pointer',
            }}
            disabled={loading}
          >
            {loading ? 'Processing...' : 'Bridge ETH'}
          </button>
          <p>{status}</p>
        </>
      ) : (
        <>
          <p>Connect your wallet.</p>
          <button
            onClick={connectWallet}
            style={{
              width: '100%',
              padding: '10px',
              backgroundColor: '#008CBA',
              color: 'white',
              border: 'none',
              cursor: 'pointer',
            }}
          >
            Connect Wallet
          </button>
        </>
      )}
    </div>
  );
}
