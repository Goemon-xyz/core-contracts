"use client";

import React, { useState, useCallback, useEffect } from 'react';
import { useWeb3React } from '@web3-react/core';
import { ethers } from 'ethers';
import IntentsEngineABI from '../abi/IntentsEngineABI.json';

// Constants
const INTENTS_ENGINE_ADDRESS = process.env.NEXT_PUBLIC_INTENTS_ENGINE_ADDRESS!;

const SetMaxIntentsComponent = () => {
    const { account, isActive, provider } = useWeb3React();
    const [isOwner, setIsOwner] = useState<boolean>(false);
    const [maxIntentsCount, setMaxIntentsCount] = useState<string>('');

     // Check if connected wallet is contract owner
     const checkOwnership = useCallback(async () => {
        if (!account || !provider) return;

        try {
            const tradeExecutor = new ethers.Contract(
                INTENTS_ENGINE_ADDRESS,
                IntentsEngineABI,
                provider
            );
            
            const owner = await tradeExecutor.owner();
            setIsOwner(owner.toLowerCase() === account.toLowerCase());
        } catch (error) {
            console.error('Error checking ownership:', error);
        }
    }, [account, provider]);

    useEffect(() => {
        if (isActive) {
            checkOwnership();
        }
    }, [isActive, checkOwnership]);

    const setMaxIntents = async() => {
       
    }

    return(
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
                <label htmlFor="intentIndex" className="block">Intent Index</label>
                <input
                    id="intentIndex"
                    type="number"
                    value={maxIntentsCount}
                    onChange={(e) => setMaxIntentsCount(e.target.value)}
                    placeholder="0"
                    className="border-2 rounded-lg w-full my-1 px-4 py-1.5"
                    min="0"
                />
            </div>

            <button
                onClick={setMaxIntents}
                disabled={loading || !isOwner}
                className="w-full p-3 bg-blue-500 hover:bg-blue-600 text-white cursor-pointer disabled:bg-gray-400"
            >
                {loading ? 'Processing...' : 'Set Max Intents'}
            </button>

            <p className="mt-2"><strong>Status:</strong> {status}</p>
        </div>
    </div>
    )
}

export default SetMaxIntentsComponent