"use client";

import React, { useState, useEffect } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers, BigNumber } from 'ethers';
import { metaMask } from '../connector';
import UserManagerABI from '../../../out/UserManager.sol/UserManager.json';
import IntentsEngineABI from '../../../out/IntentsEngine.sol/IntentsEngine.json';
import TradeExecutorABI from '../../../out/TradeExecutor.sol/TradeExecutor.json';
import Permit2ABI from '../Permit2ABI.json';
import { SignatureTransfer } from '@uniswap/permit2-sdk';

// Extract only the ABI from UserManagerABI
const userManagerABI = UserManagerABI.abi;
const intentsEngineABI = IntentsEngineABI.abi;
const tradeExecutorABI = TradeExecutorABI.abi;

// Constants
const USER_MANAGER_ADDRESS = '0x59B965027197bC3eb367e51D556983D4efC4dcc4';
const PERMIT2_ADDRESS = '0xFb890A782737F5Fc06bCF868306905501c5C3A80';
const TOKEN_ADDRESS = '0x81778d52EBd0CC38BC84B8Ec15051ade2EEAc814';
const INTENTS_ENGINE_ADDRESS = '0x0A3Ae72501b4e07414B1c8DEC56C792B989820E3';
const TRADE_EXECUTOR_ADDRESS = '0x43cAaB13F1f60954D56F273304A002825ECB8C16';
const POWER_TRADE_ADDRESS = '0x5365598ba13e9f40AB2181dCB843Fa7875dA08a4';
const USDC_DECIMALS = 6;  

export function DepositComponent() {
  const { account, isActive, provider, chainId } = useWeb3React();
  const [amount, setAmount] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [status, setStatus] = useState<string>('');
  const [usdcBalance, setUsdcBalance] = useState<string>('0.0');
  const [depositedBalance, setDepositedBalance] = useState<string>('0.0');
  const [lockedBalance, setLockedBalance] = useState<string>('0.0');
  const [powerTradeBalance, setPowerTradeBalance] = useState<string>('0.0');
  const [intents, setIntents] = useState<any[]>([]);

  useEffect(() => {
    if (isActive && account) {
      updateUSDCBalance();
      updateUserBalances();
      fetchUserIntents();
      updatePowerTradeBalance();
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
  // async function getNonce() {
  //   if (!provider || !account) return BigNumber.from(0);
  //   const permit2Contract = new ethers.Contract(PERMIT2_ADDRESS, Permit2ABI, provider);
    
  //   let nonce;
  //   try {
  //     // Try to use the nonces function first
  //     nonce = await permit2Contract.nonces(account);
  //   } catch (error) {
  //     console.log('Error fetching nonce from nonces function:', error);
  //     // If nonces function fails, fall back to allowance
  //     const [, , allowanceNonce] = await permit2Contract.allowance(account, TOKEN_ADDRESS, USER_MANAGER_ADDRESS);
  //     nonce = allowanceNonce;
  //   }
  
  //   // For Anvil testing, increment the nonce
  //   if (process.env.NEXT_PUBLIC_NETWORK === 'anvil') {
  //     nonce = nonce.add(1); // Increment by 1 instead of 3 for more predictable behavior
  //   }
  
  //   console.log('Current nonce:', nonce.toString());
  //   return nonce;
  // }

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

  // Fetch deposited and locked balances from UserManager
  async function updateUserBalances() {
    if (!account || !provider) return;
    const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, userManagerABI, provider);
    const [availableBalance, lockedBalance] = await userManager.getUserBalance(account);
    setDepositedBalance(ethers.utils.formatUnits(availableBalance, USDC_DECIMALS));
    setLockedBalance(ethers.utils.formatUnits(lockedBalance, USDC_DECIMALS));
  }

  // Fetch PowerTrade USDC balance
  async function updatePowerTradeBalance() {
    if (!provider) return;
    const balance = await getUSDCBalance(POWER_TRADE_ADDRESS);
    setPowerTradeBalance(ethers.utils.formatUnits(balance, USDC_DECIMALS));
  }

  async function fetchUserIntents() {
    if (!account || !provider) return;
    const intentsEngine = new ethers.Contract(INTENTS_ENGINE_ADDRESS, intentsEngineABI, provider);
    const userIntents = await intentsEngine.getUserIntents(account);
    setIntents(userIntents);
  }

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
    setStatus('Depositing...');
    try {
      const signer = provider.getSigner();
      const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, userManagerABI, signer);
      const permit2Contract = new ethers.Contract(PERMIT2_ADDRESS, Permit2ABI, signer);
      
      const amountWei = ethers.utils.parseUnits(amount, USDC_DECIMALS);
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      
      // Fetch nonce from provider
      const nonce = await provider.getTransactionCount(account as string); // Fetch nonce from provider

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

//       console.log('UserManager address:', USER_MANAGER_ADDRESS);
// console.log('Permit2 address:', PERMIT2_ADDRESS);
// console.log('Token address:', TOKEN_ADDRESS);
// console.log('Amount:', amountWei.toString());
// console.log('Deadline:', deadline);
// console.log('Nonce:', nonce.toString());
// console.log('PermitTransferFrom data:', permitTransferFromData);
// console.log('Signature:', signature);
  
      setStatus('Processing transaction...');
      await permitTx.wait();
      console.log(permitTx);
  
      await updateUSDCBalance();
      await updateUserBalances();
      await updatePowerTradeBalance();
      setStatus('Deposit successful!');
      alert('Deposit successful!');
      await updateUserBalances();
    } catch (error: any) {
      console.error('Deposit error:', error);
      setStatus('Deposit failed. Check console for details.');
    } finally {
      setLoading(false);
    }
  }

  // // Handle deposit errors
  // function handleDepositError(error: any) {
  //   if (error.data) {
  //     try {
  //       const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, userManagerABI, provider);
  //       const decodedError = userManager.interface.parseError(error.data);
  //       console.log('Decoded Error:', decodedError);
  //       setStatus(`Deposit failed: ${decodedError.name}`);
  //     } catch (parseError) {
  //       console.log('Failed to parse error:', parseError);
  //       setStatus('Deposit failed. Check console for details.');
  //     }
  //   } else {
  //     setStatus('Deposit failed. Check console for details.');
  //   }
  // }

  // Handle BUY action
  async function handleIntent(intentType: string) {
    if (!isActive || !provider) {
      alert('Please connect your wallet');
      return;
    }
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      alert('Enter a valid USDC amount');
      return;
    }
    setLoading(true);
    setStatus(`Submitting ${intentType} intent...`);
    try {
      const signer = provider.getSigner();
      const intentsEngine = new ethers.Contract(INTENTS_ENGINE_ADDRESS, intentsEngineABI, signer);
      const amountWei = ethers.utils.parseUnits(amount, USDC_DECIMALS);
      const testBytes = ethers.utils.toUtf8Bytes("test");
      
      // Pass the PowerTrade address as an argument
      await intentsEngine.submitIntent(amountWei, intentType, testBytes, POWER_TRADE_ADDRESS);
      setStatus('Intent submitted successfully!');
      alert('Intent submitted successfully!');
      await updateUserBalances();
      await fetchUserIntents();
      await updatePowerTradeBalance();
    } catch (error: any) {
      console.error('Submit intent error:', error);
      setStatus('Submit intent failed. Check console for details.');
    } finally {
      setLoading(false);
    }
  }

  async function handleBatchSettleIntents() {
    if (!isActive || !provider) {
      alert('Please connect your wallet');
      return;
    }
    setLoading(true);
    setStatus('Batch settling intents...');
    try {
      const signer = provider.getSigner();
      const tradeExecutor = new ethers.Contract(TRADE_EXECUTOR_ADDRESS, tradeExecutorABI, signer);

      // Filter non-executed intents and keep track of their original indices
      const nonExecutedIntents = intents
        .map((intent, index) => ({ intent, index }))
        .filter(({ intent }) => !intent.isExecuted);

      const users = nonExecutedIntents.map(() => account);
      const intentIndices = nonExecutedIntents.map(({ index }) => index);
      const pnls = nonExecutedIntents.map(({ intent }) => intent.intentType === "BUY" ? 5000000 : -5000000);

      console.log("Users:", users);
      console.log("Intent Indices:", intentIndices);
      console.log("Pnls:", pnls);

      // Pass the PowerTrade address as an argument
      await tradeExecutor.batchSettleIntents(users, intentIndices, pnls, POWER_TRADE_ADDRESS);
      setStatus('Intents settled successfully!');
      alert('Intents settled successfully!');
      await updateUserBalances();
      await fetchUserIntents();
      await updatePowerTradeBalance();
    } catch (error: any) {
      console.error('Batch settle intents error:', error);
      setStatus('Batch settle intents failed. Check console for details.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: '400px', margin: '0 auto', padding: '20px' }}>
      <h2>Deposit USDC</h2>
      {isActive ? (
        <>
          <p><strong>Account:</strong> {account}</p>
          <p><strong>Connected Account USDC Balance:</strong> {usdcBalance}</p>
          <p><strong>Deposited USDC Balance:</strong> {depositedBalance}</p>
          <p><strong>Locked USDC Balance:</strong> {lockedBalance}</p>
          <p><strong>PowerTrade USDC Balance:</strong> {powerTradeBalance}</p>
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
              marginBottom: '10px'
            }}
          >
            {loading ? 'Processing...' : 'Deposit'}
          </button>
          <button
            onClick={() => handleIntent("BUY")}
            disabled={loading}
            style={{
              width: '100%',
              padding: '10px',
              backgroundColor: '#FFA500',
              color: 'white',
              border: 'none',
              cursor: 'pointer',
              marginBottom: '10px'
            }}
          >
            {loading ? 'Processing...' : 'BUY'}
          </button>
          <button
            onClick={() => handleIntent("SELL")}
            disabled={loading}
            style={{
              width: '100%',
              padding: '10px',
              backgroundColor: '#FF6347',
              color: 'white',
              border: 'none',
              cursor: 'pointer',
              marginBottom: '10px'
            }}
          >
            {loading ? 'Processing...' : 'SELL'}
          </button>
          <button
            onClick={handleBatchSettleIntents}
            disabled={loading}
            style={{
              width: '100%',
              padding: '10px',
              backgroundColor: '#FF4500',
              color: 'white',
              border: 'none',
              cursor: 'pointer',
            }}
          >
            {loading ? 'Processing...' : 'Batch Settle Intents'}
          </button>
          <p>Status: {status}</p>
          <h3>User Intents</h3>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th style={{ border: '1px solid black', padding: '8px' }}>Index</th>
                <th style={{ border: '1px solid black', padding: '8px' }}>Amount</th>
                <th style={{ border: '1px solid black', padding: '8px' }}>Type</th>
                <th style={{ border: '1px solid black', padding: '8px' }}>Executed</th>
                <th style={{ border: '1px solid black', padding: '8px' }}>PnL</th>
              </tr>
            </thead>
            <tbody>
              {intents.map((intent, index) => (
                <tr key={index}>
                  <td style={{ border: '1px solid black', padding: '8px' }}>{index}</td>
                  <td style={{ border: '1px solid black', padding: '8px' }}>{ethers.utils.formatUnits(intent.amount, USDC_DECIMALS)}</td>
                  <td style={{ border: '1px solid black', padding: '8px' }}>{intent.intentType}</td>
                  <td style={{ border: '1px solid black', padding: '8px' }}>{intent.isExecuted ? 'Yes' : 'No'}</td>
                  <td style={{ border: '1px solid black', padding: '8px' }}>{intent.intentType === "BUY" ? "+5USDC" : "-5USDC"}</td>
                </tr>
              ))}
            </tbody>
          </table>
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