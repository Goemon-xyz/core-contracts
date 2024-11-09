"use client";

import React, { useState, useEffect, useCallback } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers } from 'ethers';
import IntentsEngineABI from '../abi/IntentsEngineABI.json';
import UserManagerABI from '../abi/UserManagerABI.json';

// Constants
const INTENTS_ENGINE_ADDRESS = process.env.NEXT_PUBLIC_INTENTS_ENGINE_ADDRESS!;
const USER_MANAGER_ADDRESS = process.env.NEXT_PUBLIC_USER_MANAGER_ADDRESS!;
const USDC_DECIMALS = 6;

const LockUserBalance = () => {
    const { account, isActive, provider } = useWeb3React();
    const [amount, setAmount] = useState<string>('');
    const [intentType, setIntentType] = useState<string>('LIMIT_ORDER');
    const [loading, setLoading] = useState<boolean>(false);
    const [status, setStatus] = useState<string>('');
    const [availableBalance, setAvailableBalance] = useState<string>('0.0');
    const [lockedBalance, setLockedBalance] = useState<string>('0.0');
    const [userIntents, setUserIntents] = useState<any[]>([]);

    // Get user balances
    const updateBalances = useCallback(async () => {
        if (!account || !provider) return;
        
        try {
        const userManager = new ethers.Contract(
            USER_MANAGER_ADDRESS,
            UserManagerABI,
            provider
        );
        
        const [available, locked] = await userManager.getUserBalance(account);
        setAvailableBalance(ethers.utils.formatUnits(available, USDC_DECIMALS));
        setLockedBalance(ethers.utils.formatUnits(locked, USDC_DECIMALS));
        } catch (error) {
        console.error('Error fetching balances:', error);
        }
    }, [account, provider]);

    // Get user intents
    const updateUserIntents = useCallback(async () => {
        if (!account || !provider) return;
        
        try {
        const intentsEngine = new ethers.Contract(
            INTENTS_ENGINE_ADDRESS,
            IntentsEngineABI,
            provider
        );
        
        const intents = await intentsEngine.getUserIntents(account);
        setUserIntents(intents);
        } catch (error) {
        console.error('Error fetching intents:', error);
        }
    }, [account, provider]);


    useEffect(() => {
        if (isActive && account) {
          updateBalances();
          updateUserIntents();
        }
      }, [isActive, account, provider, updateBalances, updateUserIntents]);


    // Main lock function
  async function handleLock() {
    if (!isActive || !provider) {
      alert('Please connect your wallet');
      return;
    }
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      alert('Enter a valid USDC amount');
      return;
    }

    setLoading(true);
    setStatus('Starting lock process...');

    try {
      const signer = provider.getSigner();
      const intentsEngine = new ethers.Contract(
        INTENTS_ENGINE_ADDRESS,
        IntentsEngineABI,
        signer
      );

      const amountWei = ethers.utils.parseUnits(amount, USDC_DECIMALS);
      
      // Example metadata - modify based on your needs
      const metadata = ethers.utils.defaultAbiCoder.encode(
        ['uint256', 'string'],
        [Date.now(), 'Additional data here']
      );

      setStatus('Submitting intent...');
      const tx = await intentsEngine.submitIntent(
        amountWei,
        intentType,
        metadata,
        { gasLimit: 1500000 }
      );

      setStatus('Processing transaction...');
      await tx.wait();

      await updateBalances();
      await updateUserIntents();
      
      setStatus('Balance locked successfully!');
      alert('Balance locked successfully!');
    } catch (error: any) {
      console.error('Lock error:', error);
      handleLockError(error);
    } finally {
      setLoading(false);
    }
  }

  // Handle lock errors
  function handleLockError(error: any) {
    if (error.reason) {
        setStatus(`Transaction failed: ${error.reason}`);
    }

    if (error.data) {
      try {
        const intentsEngine = new ethers.Contract(
          INTENTS_ENGINE_ADDRESS,
          IntentsEngineABI,
          provider
        );
        const decodedError = intentsEngine.interface.parseError(error.data);
        console.log('Decoded Error:', decodedError);
        setStatus(`Lock failed: ${decodedError.name}`);
      } catch (parseError) {
        console.log('Failed to parse error:', parseError);
        setStatus('Lock failed. Check console for details.');
      }
    } else {
      setStatus('Lock failed. Check console for details.');
    }
  }

  // Function to decode metadata
function decodeMetadata(metadata: string) {
  try {
      // Define the types that match the encoded data structure
      const types = [
          'string',  // Likely an identifier or name
          'string',  // Likely an option type (CALL/PUT)
          'uint256', // Timestamp or other numeric value
          'uint256', // Numeric value (possibly price or amount)
          'uint256'  // Another numeric value
      ];

      // Decode the metadata using ethers
      const decodedData = ethers.utils.defaultAbiCoder.decode(types, metadata);

      // Return a structured object with the decoded data
      return {
          optionSymbol: decodedData[0],    // e.g., "ETH-20241108-2800C"
          optionType: decodedData[1],    // e.g., "CALL"
          orderQuantity: decodedData[2].toString(),
          price: decodedData[3].toString(),
          expiryTimestamp: decodedData[4].toString()
      };
  } catch (error) {
      console.error('Error decoding metadata:', error);
      throw error;
  }
}

 // Add this function to display decoded metadata
 const renderDecodedMetadata = (metadata: string) => {
  try {
      const decoded = decodeMetadata(metadata);
      return (
          <div className="text-sm">
              <p>option Symbol: {decoded.optionSymbol}</p>
              <p>Option Type: {decoded.optionType}</p>
              <p>Expiry Date: {new Date(Number(decoded.expiryTimestamp)).toLocaleString()}</p>
              <p>Expiry date timestamp: {decoded.expiryTimestamp}</p>
              <p>Order Quantity: {decoded.orderQuantity}</p>
              <p>Price: {decoded.price}</p>
          </div>
      );
  } catch (error) {
      return <p className="text-red-500">Error decoding metadata</p>;
  }
};

  return (
    <div>
      <h2 className="text-xl font-semibold">Lock Balance</h2>
      <hr className="mt-2 mb-4"/>
      <div className="space-y-4">
        <div>
          <p><strong>Available Balance:</strong> {availableBalance} USDC</p>
          <p><strong>Locked Balance:</strong> {lockedBalance} USDC</p>
        </div>
        
        <div>
          <label htmlFor="amount" className="block">USDC Amount to Lock</label>
          <input
            id="amount"
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0"
            className="border-2 rounded-lg w-full my-1 px-4 py-1.5"
          />
        </div>

        <div>
          <label htmlFor="intentType" className="block">Intent Type</label>
          <select
            id="intentType"
            value={intentType}
            onChange={(e) => setIntentType(e.target.value)}
            className="border-2 rounded-lg w-full my-1 px-4 py-1.5"
          >
            <option value="LIMIT_ORDER">Limit Order</option>
            <option value="MARKET_ORDER">Market Order</option>
            <option value="STOP_LOSS">Stop Loss</option>
          </select>
        </div>

        <button
          onClick={handleLock}
          disabled={loading}
          className="w-full p-3 bg-blue-500 hover:bg-blue-600 text-white cursor-pointer disabled:bg-gray-400"
        >
          {loading ? 'Processing...' : 'Lock Balance'}
        </button>

        <p className="mt-2"><strong>Status:</strong> {status}</p>

        {userIntents.length > 0 && (
          <div className="mt-4">
            <h3 className="text-lg font-semibold">Your Active Intents</h3>
            <div className="max-h-60 overflow-y-auto">
              {userIntents.map((intent, index) => (
                <div key={index} className="border p-2 my-1 rounded">
                  <p>Amount: {ethers.utils.formatUnits(intent.amount, USDC_DECIMALS)} USDC</p>
                  <p>Type: {intent.intentType}</p>
                  <p>Executed: {intent.isExecuted ? 'Yes' : 'No'}</p>
                  <p>Timestamp: {new Date(intent.timestamp.toNumber() * 1000).toLocaleString()}</p>
                  <div className="mt-2 border-t pt-2">
                    <p className="font-semibold">Decoded Metadata:</p>
                    {renderDecodedMetadata(intent.metadata)}
                </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default LockUserBalance