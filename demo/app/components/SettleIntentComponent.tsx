"use client";

import React, { useState, useCallback, useEffect } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers } from 'ethers';
import TradeExecutorABI from '../abi/TradeExecutorABI.json';
import IntentsEngineABI from '../abi/IntentsEngineABI.json';

// Constants
const TRADE_EXECUTOR_ADDRESS = process.env.NEXT_PUBLIC_TRADE_EXECUTOR_ADDRESS!; 
const INTENTS_ENGINE_ADDRESS = process.env.NEXT_PUBLIC_INTENTS_ENGINE_ADDRESS!;
const USDC_DECIMALS = 6;

const SettleIntentComponent = () => {
    const { account, isActive, provider } = useWeb3React();
    const [userAddress, setUserAddress] = useState<string>('');
    const [intentIndex, setIntentIndex] = useState<string>('');
    const [pnl, setPnl] = useState<string>('');
    const [loading, setLoading] = useState<boolean>(false);
    const [status, setStatus] = useState<string>('');
    const [userIntents, setUserIntents] = useState<any[]>([]);
    const [isOwner, setIsOwner] = useState<boolean>(false);

    // Check if connected wallet is contract owner
    const checkOwnership = useCallback(async () => {
        if (!account || !provider) return;

        try {
            const tradeExecutor = new ethers.Contract(
                TRADE_EXECUTOR_ADDRESS,
                TradeExecutorABI,
                provider
            );
            
            const owner = await tradeExecutor.owner();
            setIsOwner(owner.toLowerCase() === account.toLowerCase());
        } catch (error) {
            console.error('Error checking ownership:', error);
        }
    }, [account, provider]);

    // Get user intents
    const fetchUserIntents = useCallback(async () => {
        if (!provider || !userAddress) return;
        
        try {
            const intentsEngine = new ethers.Contract(
                INTENTS_ENGINE_ADDRESS,
                IntentsEngineABI,
                provider
            );
            
            const intents = await intentsEngine.getUserIntents(userAddress);
            setUserIntents(intents);
        } catch (error) {
            console.error('Error fetching intents:', error);
            setStatus('Error fetching user intents');
        }
    }, [provider, userAddress]);

    useEffect(() => {
        if (isActive) {
            checkOwnership();
        }
    }, [isActive, checkOwnership]);

    useEffect(() => {
        if (userAddress) {
            fetchUserIntents();
        }
    }, [userAddress, fetchUserIntents]);

    // Main settle function
    async function handleSettle() {
        if (!isActive || !provider) {
            alert('Please connect your wallet');
            return;
        }
        
        if (!isOwner) {
            alert('Only contract owner can settle intents');
            return;
        }

        if (!userAddress || !ethers.utils.isAddress(userAddress)) {
            alert('Please enter a valid user address');
            return;
        }

        if (!intentIndex || isNaN(Number(intentIndex))) {
            alert('Please enter a valid intent index');
            return;
        }

        if (!pnl || isNaN(Number(pnl))) {
            alert('Please enter a valid PnL value');
            return;
        }

        setLoading(true);
        setStatus('Starting settlement process...');

        try {
            const signer = provider.getSigner();
            const tradeExecutor = new ethers.Contract(
                TRADE_EXECUTOR_ADDRESS,
                TradeExecutorABI,
                signer
            );

            // Convert PnL to Wei format
            const pnlWei = ethers.utils.parseUnits(pnl, USDC_DECIMALS);
            
            setStatus('Submitting settlement transaction...');
            const tx = await tradeExecutor.settleIntent(
                userAddress,
                intentIndex,
                pnlWei,
                { gasLimit: 2000000 }
            );

            setStatus('Processing transaction...');
            await tx.wait();
            
            await fetchUserIntents();
            
            setStatus('Intent settled successfully!');
            alert('Intent settled successfully!');
        } catch (error: any) {
            console.error('Settlement error:', error);
            handleSettleError(error);
        } finally {
            setLoading(false);
        }
    }

    // Handle settlement errors
    function handleSettleError(error: any) {
        if (error.reason) {
            setStatus(`Transaction failed: ${error.reason}`);
        } else if (error.message) {
            setStatus(`Error: ${error.message}`);
        } else {
            setStatus('Settlement failed. Check console for details.');
        }

        if (error.data) {
            try {
                const tradeExecutor = new ethers.Contract(
                    TRADE_EXECUTOR_ADDRESS,
                    TradeExecutorABI,
                    provider
                );
                const decodedError = tradeExecutor.interface.parseError(error.data);
                console.log('Decoded Error:', decodedError);
                setStatus(`Settlement failed: ${decodedError.name}`);
            } catch (parseError) {
                console.log('Failed to parse error:', parseError);
            }
        }
    }

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
            <h2 className="text-xl font-semibold">Settle Intent</h2>
            <hr className="mt-2 mb-4"/>
            
            {!isOwner && (
                <div className="bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700 p-4 mb-4">
                    Warning: Only the contract owner can settle intents
                </div>
            )}

            <div className="space-y-4">
                <div>
                    <label htmlFor="userAddress" className="block">User Address</label>
                    <input
                        id="userAddress"
                        type="text"
                        value={userAddress}
                        onChange={(e) => setUserAddress(e.target.value)}
                        placeholder="0x..."
                        className="border-2 rounded-lg w-full my-1 px-4 py-1.5"
                    />
                </div>

                {userIntents.length > 0 && (
                    <div>
                        <h3 className="font-medium mb-2">User's Active Intents</h3>
                        <div className="max-h-40 overflow-y-auto">
                        {userIntents.map((intent, index) => (
                        <div key={index} className="border p-2 my-1 rounded">
                        <p>Index: {index}</p>
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

                <div>
                    <label htmlFor="intentIndex" className="block">Intent Index</label>
                    <input
                        id="intentIndex"
                        type="number"
                        value={intentIndex}
                        onChange={(e) => setIntentIndex(e.target.value)}
                        placeholder="0"
                        className="border-2 rounded-lg w-full my-1 px-4 py-1.5"
                        min="0"
                    />
                </div>

                <div>
                    <label htmlFor="pnl" className="block">PnL (USDC)</label>
                    <input
                        id="pnl"
                        type="number"
                        value={pnl}
                        onChange={(e) => setPnl(e.target.value)}
                        placeholder="0.00"
                        className="border-2 rounded-lg w-full my-1 px-4 py-1.5"
                        step="0.000001"
                    />
                    <p className="text-sm text-gray-500">Use negative values for losses</p>
                </div>

                <button
                    onClick={handleSettle}
                    disabled={loading || !isOwner}
                    className="w-full p-3 bg-blue-500 hover:bg-blue-600 text-white cursor-pointer disabled:bg-gray-400"
                >
                    {loading ? 'Processing...' : 'Settle Intent'}
                </button>

                <p className="mt-2"><strong>Status:</strong> {status}</p>
            </div>
        </div>
    );
}

export default SettleIntentComponent;