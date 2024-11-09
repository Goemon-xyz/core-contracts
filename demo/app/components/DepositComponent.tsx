"use client";

import React, { useState, useEffect, useCallback } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers, BigNumber } from 'ethers';
import UserManagerABI from '../abi/UserManagerABI.json';

// Constants
const USER_MANAGER_ADDRESS = process.env.NEXT_PUBLIC_USER_MANAGER_ADDRESS!;
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';
const TOKEN_ADDRESS = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238'; // Sepolia USDC address
const USDC_DECIMALS = 6;

export function DepositComponent() {
  const { account, isActive, provider, chainId } = useWeb3React();
  const [amount, setAmount] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [status, setStatus] = useState<string>('');
  const [usdcBalance, setUsdcBalance] = useState<string>('0.0');


  // Get USDC balance for an address
  const  getUSDCBalance = useCallback(async (address: string): Promise<BigNumber> => {
    if (!provider) return BigNumber.from(0);
    const usdcContract = new ethers.Contract(
      TOKEN_ADDRESS,
      ['function balanceOf(address) view returns (uint256)'],
      provider
    );
    return usdcContract.balanceOf(address);
  }, [provider]);


  // Update USDC balance in the UI
  const updateUSDCBalance = useCallback(async() => {
    if (!account) return;
    const balance = await getUSDCBalance(account);
    setUsdcBalance(ethers.utils.formatUnits(balance, USDC_DECIMALS));
  }, [account, getUSDCBalance]);

  useEffect(() => {
    if (isActive && account) {
      updateUSDCBalance();
    }
  }, [isActive, account, provider, updateUSDCBalance]);


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

      console.log("provider is =====>", provider)

      const signer = provider.getSigner();
      const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, UserManagerABI, signer);
      // const permit2Contract = new ethers.Contract(PERMIT2_ADDRESS, Permit2ABI, signer);
      
      const amountWei = ethers.utils.parseUnits(amount, USDC_DECIMALS);
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const nonce = 16;
  
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
  
      const permitTx = await userManager.permitDeposit(
        amountWei,
        deadline,
        nonce,
        permitTransferFromData,
        signature,
        { gasLimit: 500000 }
      );
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
    <div>
      <h2 className="text-xl font-semibold">Deposit USDC</h2>
      <hr className='mt-2 mb-4'/>
          <p className='mb-2'><strong>USDC Balance :</strong> {usdcBalance}</p>
          <label htmlFor="deposit">USDC Amount</label>
          <input
            id="deposit"
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0"
            className='border-2 rounded-lg w-full my-1 px-4 py-1.5'
          />
          <button
            onClick={handleDeposit}
            disabled={loading}
            className='w-full p-3 bg-[#4CAF50] hover:bg-green-600 text-white cursor-pointer my-4'
          >
            {loading ? 'Processing...' : 'Deposit'}
          </button>
          <p>Status : {status}</p>
    </div>
  );
}