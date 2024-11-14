import { createAppKit } from '@reown/appkit/react'
import { Ethers5Adapter } from '@reown/appkit-adapter-ethers5'
import { mainnet, arbitrum, sepolia, bscTestnet } from '@reown/appkit/networks'

// 1. Get projectId
const projectId = 'bc27af3861acc49b7b805385219a1fe3'

// 2. Create a metadata object - optional
const metadata = {
  name: 'My Website',
  description: 'My Website description',
  url: 'https://mywebsite.com', // origin must match your domain & subdomain
  icons: ['https://avatars.mywebsite.com/']
}

// 4. Create the AppKit instance
createAppKit({
  adapters: [new Ethers5Adapter()],
  metadata: metadata,
  networks: [ mainnet, arbitrum, sepolia, bscTestnet], // Include localhost in the networks array
  projectId,
  features: {
    analytics: true // Optional - defaults to your Cloud configuration
  }
})

export default function App() {
  return <App /> //make sure you have configured the <w3m-button> inside
}
