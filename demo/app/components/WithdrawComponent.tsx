
import React, { useState } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers } from 'ethers';
import UserManagerABI from '../abi/UserManagerABI.json';


// Constants
const USER_MANAGER_ADDRESS = '';
const USDC_DECIMALS = 6;

const WithdrawComponent = () => {
const { isActive, provider } = useWeb3React();
const [amount, setAmount] = useState<string>('');
const [loading, setLoading] = useState<boolean>(false);
const [status, setStatus] = useState<string>('');


const handleWithdraw = async() => {
      if (!isActive || !provider) {
        alert('Please connect your wallet');
        return;
      }
      if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
        alert('Enter a valid USDC amount');
        return;
      }
      setLoading(true);
      setStatus('Starting withdraw...');

      try {
        console.log("provider is =====>", provider)

      const signer = provider.getSigner();
      const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, UserManagerABI, signer);
      // const permit2Contract = new ethers.Contract(PERMIT2_ADDRESS, Permit2ABI, signer);
      
      const amountWei = ethers.utils.parseUnits(amount, USDC_DECIMALS);
      const withdrawTx = await userManager.withdraw(amountWei,  { gasLimit: 500000 })

      await withdrawTx.wait()
      setStatus('Withdraw successful!');
      alert('Withdraw successful!');
        
      } catch (error: any) {
        console.error('Withdraw error:', error);
        handleWithdrawError(error);
      } finally {
        setLoading(false);
      }
}


 // Handle deposit errors
 function handleWithdrawError(error: any) {
    if (error.data) {
      try {
        const userManager = new ethers.Contract(USER_MANAGER_ADDRESS, UserManagerABI, provider);
        const decodedError = userManager.interface.parseError(error.data);
        console.log('Decoded Error:', decodedError);
        setStatus(`Withdraw failed: ${decodedError.name}`);

      } catch (parseError) {

        console.log('Failed to parse error:', parseError);
        setStatus('Withdraw failed. Check console for details.');
      }

    } else {
      setStatus('Withdraw failed. Check console for details.');
    }
  }
    
  return (
    <div>
      <h2 className="text-xl font-semibold">Withdraw USDC From Contract: UserManager.sol</h2>
      <hr className='mt-2 mb-4'/>
          {/* <p className='mb-2'><strong>USDC Balance in Contract :</strong> {usdcBalance}</p> */}
          <label htmlFor="withdraw">USDC Amount</label>
          <input
            id="withdraw"
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0"
            className='border-2 rounded-lg w-full my-1 px-4 py-1.5'
          />
          <button
            onClick={handleWithdraw}
            disabled={loading}
            className='w-full p-3 bg-[#4CAF50] hover:bg-green-600 text-white cursor-pointer my-4'
          >
            {loading ? 'Processing...' : 'Withdraw'}
          </button>
          <p>Status : {status}</p>
    </div>
  )
}

export default WithdrawComponent