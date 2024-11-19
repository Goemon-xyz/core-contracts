"use client";
import { shortenIfAddress, useEthers } from "@usedapp/core";

type ConnectButtonProps = {
  className?: string;
};

export const ConnectButton = ({ className }: ConnectButtonProps) => {
  const { account, active, activateBrowserWallet, deactivate } = useEthers();
  const connected = !!account && !!active;

  return (
    <div className={className}>
      {(() => {
        if (!connected) {
          return <HamburgerButton onClick={activateBrowserWallet} />;
        }
        return (
          <div className="flex items-center gap-2">
            <button
              className="flex gap-1 border p-2"
              onClick={deactivate}
            >
              <span className="max-w-[120px] truncate">
                {shortenIfAddress(account)}
              </span>
            </button>
          </div>
        );
      })()}
    </div>
  );
};

type ButtonProps = {
  onClick: () => void;
};

const HamburgerButton = ({ onClick }: ButtonProps) => {
  return (
    <button
      onClick={onClick}
      className="h-[40px] w-[40px] border p-2 flex items-center justify-center"
    >
      <div className="h-[20px] w-[20px] text-text/75">☰</div>
    </button>
  );
};