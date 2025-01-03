"use client";
import { DAppProvider, Arbitrum, Config, Mainnet } from "@usedapp/core";
import * as React from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <DAppProvider config={config}>{children}</DAppProvider>
  );
}

const config: Config = {
  readOnlyChainId: Mainnet.chainId,
  readOnlyUrls: {
    [Mainnet.chainId]: "https://eth.llamarpc.com",
    [Arbitrum.chainId]: "https://arbitrum.llamarpc.com",
  },
};
