import { useState, useEffect } from "react";
import { ethers } from "ethers";

const CONTRACTS = {
  GovToken: "0x518f029A4E7BE8B9CE5bDd7188E80eA71B404b63",
  Governor: "0x7309A96DE45c3e1f70b59c4FE205786Bf50DE8ac",
  AMM: "0x8F5856FF91503BcE897712952D9152cd424EFB24",
  YieldVault: "0x207Cb0DD0567f8F861b4F16785fc9034E1e2CF9F",
  Treasury: "0xfcf24222be9a73de841F4Fd93460361439CF38Fa",
};

const GOV_TOKEN_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function getVotes(address) view returns (uint256)",
  "function delegates(address) view returns (address)",
  "function delegate(address delegatee)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function approve(address spender, uint256 amount) returns (bool)",
];

const AMM_ABI = [
  "function reserveA() view returns (uint256)",
  "function reserveB() view returns (uint256)",
  "function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) returns (uint256)",
  "function addLiquidity(uint256 amountA, uint256 amountB) returns (uint256)",
];

const VAULT_ABI = [
  "function totalAssets() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function deposit(uint256 assets, address receiver) returns (uint256)",
  "function redeem(uint256 shares, address receiver, address owner) returns (uint256)",
];

const GOVERNOR_ABI = [
  "function proposalCount() view returns (uint256)",
  "function state(uint256 proposalId) view returns (uint8)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
];

const ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

const PROPOSAL_STATES = [
  "Pending", "Active", "Canceled", "Defeated",
  "Succeeded", "Queued", "Expired", "Executed"
];

export default function App() {
  const [account, setAccount] = useState(null);
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [chainId, setChainId] = useState(null);
  const [tokenBalance, setTokenBalance] = useState("0");
  const [votingPower, setVotingPower] = useState("0");
  const [delegateAddr, setDelegateAddr] = useState("");
  const [poolReserves, setPoolReserves] = useState({ a: "0", b: "0" });
  const [vaultShares, setVaultShares] = useState("0");
  const [vaultAssets, setVaultAssets] = useState("0");
  const [status, setStatus] = useState("");
  const [delegateTo, setDelegateTo] = useState("");
  const [transferTo, setTransferTo] = useState("");
  const [transferAmount, setTransferAmount] = useState("");

  const connectWallet = async () => {
    if (!window.ethereum) {
      setStatus("MetaMask not found!");
      return;
    }
    try {
      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts",
      });
      const prov = new ethers.BrowserProvider(window.ethereum);
      const sign = await prov.getSigner();
      const network = await prov.getNetwork();

      setAccount(accounts[0]);
      setProvider(prov);
      setSigner(sign);
      setChainId(Number(network.chainId));

      if (Number(network.chainId) !== ARBITRUM_SEPOLIA_CHAIN_ID) {
        setStatus("Wrong network! Please switch to Arbitrum Sepolia.");
        await switchNetwork();
        return;
      }

      setStatus("Connected!");
      await loadData(prov, accounts[0]);
    } catch (err) {
      setStatus("Error: " + err.message);
    }
  };

  const switchNetwork = async () => {
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: "0x" + ARBITRUM_SEPOLIA_CHAIN_ID.toString(16) }],
      });
    } catch {
      setStatus("Please switch to Arbitrum Sepolia manually.");
    }
  };

  const loadData = async (prov, addr) => {
    try {
      const token = new ethers.Contract(CONTRACTS.GovToken, GOV_TOKEN_ABI, prov);
      const amm = new ethers.Contract(CONTRACTS.AMM, AMM_ABI, prov);
      const vault = new ethers.Contract(CONTRACTS.YieldVault, VAULT_ABI, prov);

      const [bal, votes, del, resA, resB, shares, assets] = await Promise.all([
        token.balanceOf(addr),
        token.getVotes(addr),
        token.delegates(addr),
        amm.reserveA(),
        amm.reserveB(),
        vault.balanceOf(addr),
        vault.totalAssets(),
      ]);

      setTokenBalance(ethers.formatEther(bal));
      setVotingPower(ethers.formatEther(votes));
      setDelegateAddr(del);
      setPoolReserves({
        a: ethers.formatEther(resA),
        b: ethers.formatEther(resB),
      });
      setVaultShares(ethers.formatEther(shares));
      setVaultAssets(ethers.formatEther(assets));
    } catch (err) {
      setStatus("Load error: " + err.message);
    }
  };

  const handleDelegate = async () => {
    if (!signer || !delegateTo) return;
    try {
      setStatus("Delegating...");
      const token = new ethers.Contract(CONTRACTS.GovToken, GOV_TOKEN_ABI, signer);
      const tx = await token.delegate(delegateTo);
      await tx.wait();
      setStatus("Delegated! TX: " + tx.hash);
      await loadData(provider, account);
    } catch (err) {
      setStatus("Error: " + err.message);
    }
  };

  const handleTransfer = async () => {
    if (!signer || !transferTo || !transferAmount) return;
    try {
      setStatus("Transferring...");
      const token = new ethers.Contract(CONTRACTS.GovToken, GOV_TOKEN_ABI, signer);
      const tx = await token.transfer(transferTo, ethers.parseEther(transferAmount));
      await tx.wait();
      setStatus("Transferred! TX: " + tx.hash);
      await loadData(provider, account);
    } catch (err) {
      setStatus("Error: " + err.message);
    }
  };

  const handleSelfDelegate = async () => {
    if (!signer || !account) return;
    try {
      setStatus("Self-delegating...");
      const token = new ethers.Contract(CONTRACTS.GovToken, GOV_TOKEN_ABI, signer);
      const tx = await token.delegate(account);
      await tx.wait();
      setStatus("Self-delegated! TX: " + tx.hash);
      await loadData(provider, account);
    } catch (err) {
      setStatus("Error: " + err.message);
    }
  };

  return (
    <div style={{ fontFamily: "monospace", padding: "2rem", maxWidth: "800px", margin: "0 auto" }}>
      <h1>🏦 DeFi Super-App</h1>
      <p style={{ color: "#888" }}>Arbitrum Sepolia Testnet</p>

      {!account ? (
        <button onClick={connectWallet} style={btnStyle("#4f46e5")}>
          Connect MetaMask
        </button>
      ) : (
        <div>
          <p>✅ Connected: {account.slice(0, 6)}...{account.slice(-4)}</p>
          {chainId !== ARBITRUM_SEPOLIA_CHAIN_ID && (
            <button onClick={switchNetwork} style={btnStyle("#dc2626")}>
              Switch to Arbitrum Sepolia
            </button>
          )}
        </div>
      )}

      {status && (
        <div style={{ background: "#1e293b", padding: "1rem", borderRadius: "8px", margin: "1rem 0", color: "#94a3b8" }}>
          {status}
        </div>
      )}

      {account && (
        <>
          {/* Governance Token */}
          <section style={cardStyle}>
            <h2>🗳️ Governance Token (DGT)</h2>
            <p>Balance: <b>{Number(tokenBalance).toFixed(2)} DGT</b></p>
            <p>Voting Power: <b>{Number(votingPower).toFixed(2)}</b></p>
            <p>Delegate: <b>{delegateAddr.slice(0, 10)}...</b></p>
            <button onClick={handleSelfDelegate} style={btnStyle("#059669")}>
              Self-Delegate
            </button>
            <div style={{ marginTop: "1rem" }}>
              <input
                placeholder="Delegate to address"
                value={delegateTo}
                onChange={(e) => setDelegateTo(e.target.value)}
                style={inputStyle}
              />
              <button onClick={handleDelegate} style={btnStyle("#7c3aed")}>
                Delegate
              </button>
            </div>
            <div style={{ marginTop: "1rem" }}>
              <input
                placeholder="Transfer to address"
                value={transferTo}
                onChange={(e) => setTransferTo(e.target.value)}
                style={inputStyle}
              />
              <input
                placeholder="Amount"
                value={transferAmount}
                onChange={(e) => setTransferAmount(e.target.value)}
                style={{ ...inputStyle, width: "100px" }}
              />
              <button onClick={handleTransfer} style={btnStyle("#0ea5e9")}>
                Transfer
              </button>
            </div>
          </section>

          {/* AMM Pool */}
          <section style={cardStyle}>
            <h2>💱 AMM Pool (WETH/USDC)</h2>
            <p>Reserve A (WETH): <b>{Number(poolReserves.a).toFixed(6)}</b></p>
            <p>Reserve B (USDC): <b>{Number(poolReserves.b).toFixed(6)}</b></p>
          </section>

          {/* Yield Vault */}
          <section style={cardStyle}>
            <h2>🏛️ Yield Vault</h2>
            <p>Your Shares: <b>{Number(vaultShares).toFixed(6)}</b></p>
            <p>Total Assets: <b>{Number(vaultAssets).toFixed(6)}</b></p>
          </section>

          {/* Contracts */}
          <section style={cardStyle}>
            <h2>📋 Contract Addresses</h2>
            {Object.entries(CONTRACTS).map(([name, addr]) => (
              <p key={name}>
                {name}:{" "}
                <a
                  href={`https://sepolia.arbiscan.io/address/${addr}`}
                  target="_blank"
                  rel="noreferrer"
                  style={{ color: "#60a5fa" }}
                >
                  {addr.slice(0, 10)}...
                </a>
              </p>
            ))}
          </section>
        </>
      )}
    </div>
  );
}

const btnStyle = (bg) => ({
  background: bg,
  color: "white",
  border: "none",
  padding: "0.5rem 1rem",
  borderRadius: "6px",
  cursor: "pointer",
  marginRight: "0.5rem",
  marginTop: "0.5rem",
});

const inputStyle = {
  background: "#1e293b",
  color: "white",
  border: "1px solid #334155",
  padding: "0.5rem",
  borderRadius: "6px",
  marginRight: "0.5rem",
  width: "250px",
};

const cardStyle = {
  background: "#0f172a",
  border: "1px solid #1e293b",
  borderRadius: "12px",
  padding: "1.5rem",
  marginTop: "1.5rem",
};