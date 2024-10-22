"use client";

import React, { useState, useEffect } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers, BigNumber } from 'ethers';
import { metaMask } from '../connector';
import UserManagerABI from '../UserManagerABI.json';
import Permit2ABI from '../Permit2ABI.json';

// Constants
const USER_MANAGER_ADDRESS = '0xABc84968376556B5e5B3C3bda750D091a06De536';
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';
const TOKEN_ADDRESS = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'; // USDC address
const USDC_DECIMALS = 6;

export function DepositComponent() {
  const { account, isActive, provider, chainId } = useWeb3React();
  const [amount, setAmount] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [status, setStatus] = useState<string>('');
  const [usdcBalance, setUsdcBalance] = useState<string>('0.0');

  useEffect(() => {
    if (isActive && account) {
      updateUSDCBalance();
    }
  }, [isActive, account, provider]);

  // Connect wallet function
  async function connectWallet() {
    try {
      await metaMask.activate();
    } catch (error) {
      console.error('Failed to connect wallet:', error);
      alert('Failed to connect wallet.');
    }
  }

  // Get current nonce from Permit2 contract
  async function getNonce() {
    if (!provider || !account) return BigNumber.from(0);
    const permit2Contract = new ethers.Contract(PERMIT2_ADDRESS, Permit2ABI, provider);
    
    let nonce;
    try {
      // Try to use the nonces function first
      nonce = await permit2Contract.nonces(account);
    } catch (error) {
      console.log('Error fetching nonce from nonces function:', error);
      // If nonces function fails, fall back to allowance
      const [, , allowanceNonce] = await permit2Contract.allowance(account, TOKEN_ADDRESS, USER_MANAGER_ADDRESS);
      nonce = allowanceNonce;
    }
  
    // For Anvil testing, increment the nonce
    if (process.env.NEXT_PUBLIC_NETWORK === 'anvil') {
      nonce = nonce.add(1); // Increment by 1 instead of 3 for more predictable behavior
    }
  
    console.log('Current nonce:', nonce.toString());
    return nonce;
  }

  // Get USDC balance for an address
  async function getUSDCBalance(address: string): Promise<BigNumber> {
    if (!provider) return BigNumber.from(0);
    const usdcContract = new ethers.Contract(
      TOKEN_ADDRESS,
      ['function balanceOf(address) view returns (uint256)'],
      provider
    );
    return usdcContract.balanceOf(address);
  }

  // Update USDC balance in the UI
  async function updateUSDCBalance() {
    if (!account) return;
    const balance = await getUSDCBalance(account);
    setUsdcBalance(ethers.utils.formatUnits(balance, USDC_DECIMALS));
  }

  // Main deposit function
  async function handleDeposit() {
    if (!isActive || !provider) {
      alert('Please connect your wallet');
      return;
    }
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      alert('Enter a valid USDC amount');
      return;
    }
    setLoading(true);
    setStatus('Starting deposit...');
    try {
      const signer = provider.getSigner();
      const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, UserManagerABI, signer);
      const permit2Contract = new ethers.Contract(PERMIT2_ADDRESS, Permit2ABI, signer);
      
      const amountWei = ethers.utils.parseUnits(amount, USDC_DECIMALS);
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const nonce = await getNonce();
  
      const domain = {
        name: 'Permit2',
        chainId: chainId,
        verifyingContract: PERMIT2_ADDRESS
      };
  
      const types = {
        PermitTransferFrom: [
          { name: 'permitted', type: 'TokenPermissions' },
          { name: 'spender', type: 'address' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' }
        ],
        TokenPermissions: [
          { name: 'token', type: 'address' },
          { name: 'amount', type: 'uint256' }
        ]
      };
  
      const message = {
        permitted: {
          token: TOKEN_ADDRESS,
          amount: amountWei.toString()
        },
        spender: USER_MANAGER_ADDRESS,
        nonce: nonce,
        deadline: deadline
      };
  
      setStatus('Signing permit...');
      const signature = await signer._signTypedData(domain, types, message);
  
      console.log('Deposit details:', { amount, amountWei: amountWei.toString(), deadline, nonce: nonce.toString() });
      console.log('Signed message:', JSON.stringify(message, null, 2));
      console.log('Signature:', signature);
  
      setStatus('Depositing...');
      const permitTransferFromData = ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256'],
        [TOKEN_ADDRESS, amountWei]
      );
  
      const permitTx = await userManager.permitDeposit(
        amountWei,
        deadline,
        nonce,
        permitTransferFromData,
        signature,
        { gasLimit: 500000 }
      );

      try {
        await userManager.callStatic.permitDeposit(
          amountWei,
          deadline,
          nonce,
          permitTransferFromData,
          signature
        );
      } catch (error) {
        console.error('callStatic error:', error);
        // Handle the error or return early
      }
      const usdcContract = new ethers.Contract(TOKEN_ADDRESS, ['function allowance(address,address) view returns (uint256)', 'function approve(address,uint256)'], signer);
const allowance = await usdcContract.allowance(account, PERMIT2_ADDRESS);
console.log('Current USDC allowance for Permit2:', allowance.toString());
if (allowance.lt(amountWei)) {
  console.log('Insufficient allowance, approving Permit2...');
  const approveTx = await usdcContract.approve(PERMIT2_ADDRESS, ethers.constants.MaxUint256);
  await approveTx.wait();
  console.log('Permit2 approved for USDC');
}

      console.log('UserManager address:', USER_MANAGER_ADDRESS);
console.log('Permit2 address:', PERMIT2_ADDRESS);
console.log('Token address:', TOKEN_ADDRESS);
console.log('Amount:', amountWei.toString());
console.log('Deadline:', deadline);
console.log('Nonce:', nonce.toString());
console.log('PermitTransferFrom data:', permitTransferFromData);
console.log('Signature:', signature);
  
      setStatus('Processing transaction...');
      await permitTx.wait();
  
      await updateUSDCBalance();
      setStatus('Deposit successful!');
      alert('Deposit successful!');
    } catch (error: any) {
      console.error('Deposit error:', error);
      handleDepositError(error);
    } finally {
      setLoading(false);
    }
  }

  // Handle deposit errors
  function handleDepositError(error: any) {
    if (error.data) {
      try {
        const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, UserManagerABI, provider);
        const decodedError = userManager.interface.parseError(error.data);
        console.log('Decoded Error:', decodedError);
        setStatus(`Deposit failed: ${decodedError.name}`);
      } catch (parseError) {
        console.log('Failed to parse error:', parseError);
        setStatus('Deposit failed. Check console for details.');
      }
    } else {
      setStatus('Deposit failed. Check console for details.');
    }
  }

  // Render component
  return (
    <div style={{ maxWidth: '400px', margin: '0 auto', padding: '20px' }}>
      <h2>Deposit USDC</h2>
      {isActive ? (
        <>
          <p><strong>Account:</strong> {account}</p>
          <p><strong>USDC Balance:</strong> {usdcBalance}</p>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="USDC Amount"
            style={{ width: '100%', padding: '8px', marginBottom: '10px' }}
          />
          <button
            onClick={handleDeposit}
            disabled={loading}
            style={{
              width: '100%',
              padding: '10px',
              backgroundColor: '#4CAF50',
              color: 'white',
              border: 'none',
              cursor: 'pointer',
            }}
          >
            {loading ? 'Processing...' : 'Deposit'}
          </button>
          <p>Status: {status}</p>
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