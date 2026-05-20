import { useState } from "react";
import { ethers } from "ethers";

const ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
const SUBGRAPH_URL = import.meta.env.VITE_SUBGRAPH_URL || "";

const CONTRACTS = {
  GovToken:
    import.meta.env.VITE_GOV_TOKEN ||
    "0x518f029A4E7BE8B9CE5bDd7188E80eA71B404b63",
  Governor:
    import.meta.env.VITE_GOVERNOR ||
    "0x7309A96DE45c3e1f70b59c4FE205786Bf50DE8ac",
  AMM: import.meta.env.VITE_AMM || "0x8F5856FF91503BcE897712952D9152cd424EFB24",
  YieldVault:
    import.meta.env.VITE_YIELD_VAULT ||
    "0x207Cb0DD0567f8F861b4F16785fc9034E1e2CF9F",
  Treasury:
    import.meta.env.VITE_TREASURY ||
    "0xfcf24222be9a73de841F4Fd93460361439CF38Fa",
  WETH:
    import.meta.env.VITE_WETH || "0x980B62Da83eFf3D4576C647993b0c1D7faf17c73",
  USDC:
    import.meta.env.VITE_USDC || "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d",
};

const GOV_TOKEN_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function getVotes(address) view returns (uint256)",
  "function delegates(address) view returns (address)",
  "function delegate(address delegatee)",
  "function transfer(address to, uint256 amount) returns (bool)",
];

const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
];

const AMM_ABI = [
  "function reserveA() view returns (uint256)",
  "function reserveB() view returns (uint256)",
  "function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) returns (uint256)",
  "function addLiquidity(uint256 amountA, uint256 amountB) returns (uint256)",
];

const VAULT_ABI = [
  "function totalAssets() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function deposit(uint256 assets, address receiver) returns (uint256)",
];

const GOVERNOR_ABI = [
  "function state(uint256 proposalId) view returns (uint8)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
];

const PROPOSAL_STATES = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed",
];

function shortAddress(value) {
  if (!value) return "-";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function fixedNumber(value, digits = 2) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return "0";
  return parsed.toFixed(digits);
}

function formatError(error) {
  const message =
    error?.shortMessage ||
    error?.info?.error?.message ||
    error?.reason ||
    error?.message ||
    "Unknown error";

  const lower = message.toLowerCase();
  if (lower.includes("user rejected")) return "Transaction rejected in wallet.";
  if (lower.includes("insufficient funds"))
    return "Insufficient balance for this transaction.";
  if (lower.includes("network changed"))
    return "Network changed. Please refresh and reconnect.";
  return message.replace(/^execution reverted: /i, "");
}

export default function App() {
  const [account, setAccount] = useState("");
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [chainId, setChainId] = useState(null);
  const [status, setStatus] = useState("");

  const [tokenBalance, setTokenBalance] = useState("0");
  const [votingPower, setVotingPower] = useState("0");
  const [delegateAddr, setDelegateAddr] = useState("");
  const [poolReserves, setPoolReserves] = useState({ weth: "0", usdc: "0" });
  const [vaultShares, setVaultShares] = useState("0");
  const [vaultAssets, setVaultAssets] = useState("0");
  const [walletBalances, setWalletBalances] = useState({
    weth: "0",
    usdc: "0",
  });

  const [delegateTo, setDelegateTo] = useState("");
  const [transferTo, setTransferTo] = useState("");
  const [transferAmount, setTransferAmount] = useState("");
  const [swapToken, setSwapToken] = useState("WETH");
  const [swapAmount, setSwapAmount] = useState("");
  const [swapMinOut, setSwapMinOut] = useState("0");
  const [liquidityWeth, setLiquidityWeth] = useState("");
  const [liquidityUsdc, setLiquidityUsdc] = useState("");
  const [vaultDeposit, setVaultDeposit] = useState("");

  const [proposals, setProposals] = useState([]);
  const [swaps, setSwaps] = useState([]);
  const [subgraphStatus, setSubgraphStatus] = useState("");

  const connectWallet = async () => {
    if (!window.ethereum) {
      setStatus("MetaMask not found!");
      return;
    }

    try {
      const browserProvider = new ethers.BrowserProvider(window.ethereum);
      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts",
      });
      const network = await browserProvider.getNetwork();
      const walletSigner = await browserProvider.getSigner();

      setAccount(accounts[0]);
      setProvider(browserProvider);
      setSigner(walletSigner);
      setChainId(Number(network.chainId));

      if (Number(network.chainId) !== ARBITRUM_SEPOLIA_CHAIN_ID) {
        setStatus("Wrong network! Please switch to Arbitrum Sepolia.");
        return;
      }

      setStatus("Connected!");
      await loadAll(browserProvider, accounts[0]);
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const switchNetwork = async () => {
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: `0x${ARBITRUM_SEPOLIA_CHAIN_ID.toString(16)}` }],
      });
      setStatus("Network switched. Reconnect wallet to refresh state.");
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const loadAll = async (
    activeProvider = provider,
    activeAccount = account
  ) => {
    if (!activeProvider || !activeAccount) return;
    await Promise.all([
      loadProtocolData(activeProvider, activeAccount),
      loadSubgraphData(activeProvider),
    ]);
  };

  const loadProtocolData = async (activeProvider, activeAccount) => {
    try {
      const token = new ethers.Contract(
        CONTRACTS.GovToken,
        GOV_TOKEN_ABI,
        activeProvider
      );
      const weth = new ethers.Contract(
        CONTRACTS.WETH,
        ERC20_ABI,
        activeProvider
      );
      const usdc = new ethers.Contract(
        CONTRACTS.USDC,
        ERC20_ABI,
        activeProvider
      );
      const amm = new ethers.Contract(CONTRACTS.AMM, AMM_ABI, activeProvider);
      const vault = new ethers.Contract(
        CONTRACTS.YieldVault,
        VAULT_ABI,
        activeProvider
      );

      const [bal, votes, del, resA, resB, shares, assets, wethBal, usdcBal] =
        await Promise.all([
          token.balanceOf(activeAccount),
          token.getVotes(activeAccount),
          token.delegates(activeAccount),
          amm.reserveA(),
          amm.reserveB(),
          vault.balanceOf(activeAccount),
          vault.totalAssets(),
          weth.balanceOf(activeAccount),
          usdc.balanceOf(activeAccount),
        ]);

      setTokenBalance(ethers.formatEther(bal));
      setVotingPower(ethers.formatEther(votes));
      setDelegateAddr(del);
      setPoolReserves({
        weth: ethers.formatEther(resA),
        usdc: ethers.formatUnits(resB, 6),
      });
      setVaultShares(ethers.formatEther(shares));
      setVaultAssets(ethers.formatUnits(assets, 6));
      setWalletBalances({
        weth: ethers.formatEther(wethBal),
        usdc: ethers.formatUnits(usdcBal, 6),
      });
    } catch (error) {
      setStatus(`Load error: ${formatError(error)}`);
    }
  };

  const loadSubgraphData = async (activeProvider = provider) => {
    if (!SUBGRAPH_URL) {
      setSubgraphStatus(
        "Set VITE_SUBGRAPH_URL to load indexed swaps and proposals."
      );
      return;
    }

    try {
      const query = `
        query DashboardData {
          swaps(first: 5, orderBy: timestamp, orderDirection: desc) {
            id
            user
            tokenIn
            amountIn
            amountOut
            timestamp
          }
          proposals(first: 10, orderBy: createdAt, orderDirection: desc) {
            id
            proposer
            description
            voteStart
            voteEnd
            state
          }
        }
      `;

      const response = await fetch(SUBGRAPH_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query }),
      });
      const payload = await response.json();
      if (payload.errors?.length) throw new Error(payload.errors[0].message);

      const governor = activeProvider
        ? new ethers.Contract(CONTRACTS.Governor, GOVERNOR_ABI, activeProvider)
        : null;

      const hydrated = await Promise.all(
        (payload.data.proposals || []).map(async (proposal) => {
          if (!governor) return proposal;
          try {
            const state = await governor.state(proposal.id);
            return {
              ...proposal,
              state: PROPOSAL_STATES[Number(state)] || proposal.state,
            };
          } catch {
            return proposal;
          }
        })
      );

      setProposals(hydrated);
      setSwaps(payload.data.swaps || []);
      setSubgraphStatus("Indexed data loaded from The Graph.");
    } catch (error) {
      setSubgraphStatus(`Subgraph error: ${formatError(error)}`);
    }
  };

  const ensureAllowance = async (tokenAddress, spender, amount) => {
    const token = new ethers.Contract(tokenAddress, ERC20_ABI, signer);
    const allowance = await token.allowance(account, spender);
    if (allowance >= amount) return;

    const tx = await token.approve(spender, amount);
    await tx.wait();
  };

  const handleDelegate = async (delegatee = delegateTo) => {
    if (!signer || !delegatee) return;
    try {
      setStatus("Delegating...");
      const token = new ethers.Contract(
        CONTRACTS.GovToken,
        GOV_TOKEN_ABI,
        signer
      );
      const tx = await token.delegate(delegatee);
      await tx.wait();
      setStatus(`Delegated! TX: ${tx.hash}`);
      await loadAll();
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const handleTransfer = async () => {
    if (!signer || !transferTo || !transferAmount) return;
    try {
      const amount = ethers.parseEther(transferAmount);
      const currentBalance = ethers.parseEther(tokenBalance || "0");
      if (amount > currentBalance) {
        setStatus("Insufficient DGT balance.");
        return;
      }

      setStatus("Transferring...");
      const token = new ethers.Contract(
        CONTRACTS.GovToken,
        GOV_TOKEN_ABI,
        signer
      );
      const tx = await token.transfer(transferTo, amount);
      await tx.wait();
      setStatus(`Transferred! TX: ${tx.hash}`);
      await loadAll();
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const handleSwap = async () => {
    if (!signer || !swapAmount) return;
    try {
      const isWethIn = swapToken === "WETH";
      const tokenIn = isWethIn ? CONTRACTS.WETH : CONTRACTS.USDC;
      const decimals = isWethIn ? 18 : 6;
      const amountIn = ethers.parseUnits(swapAmount, decimals);
      const minOut = ethers.parseUnits(swapMinOut || "0", isWethIn ? 6 : 18);
      const readableBalance = isWethIn
        ? walletBalances.weth
        : walletBalances.usdc;

      if (amountIn > ethers.parseUnits(readableBalance || "0", decimals)) {
        setStatus(`Insufficient ${swapToken} balance.`);
        return;
      }

      setStatus("Approving swap...");
      await ensureAllowance(tokenIn, CONTRACTS.AMM, amountIn);

      setStatus("Swapping...");
      const amm = new ethers.Contract(CONTRACTS.AMM, AMM_ABI, signer);
      const tx = await amm.swap(tokenIn, amountIn, minOut);
      await tx.wait();
      setStatus(`Swap complete! TX: ${tx.hash}`);
      await loadAll();
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const handleAddLiquidity = async () => {
    if (!signer || !liquidityWeth || !liquidityUsdc) return;
    try {
      const amountWeth = ethers.parseEther(liquidityWeth);
      const amountUsdc = ethers.parseUnits(liquidityUsdc, 6);

      setStatus("Approving liquidity tokens...");
      await ensureAllowance(CONTRACTS.WETH, CONTRACTS.AMM, amountWeth);
      await ensureAllowance(CONTRACTS.USDC, CONTRACTS.AMM, amountUsdc);

      setStatus("Adding liquidity...");
      const amm = new ethers.Contract(CONTRACTS.AMM, AMM_ABI, signer);
      const tx = await amm.addLiquidity(amountWeth, amountUsdc);
      await tx.wait();
      setStatus(`Liquidity added! TX: ${tx.hash}`);
      await loadAll();
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const handleVaultDeposit = async () => {
    if (!signer || !vaultDeposit) return;
    try {
      const amount = ethers.parseUnits(vaultDeposit, 6);
      if (amount > ethers.parseUnits(walletBalances.usdc || "0", 6)) {
        setStatus("Insufficient USDC balance.");
        return;
      }

      setStatus("Approving vault deposit...");
      await ensureAllowance(CONTRACTS.USDC, CONTRACTS.YieldVault, amount);

      setStatus("Depositing...");
      const vault = new ethers.Contract(
        CONTRACTS.YieldVault,
        VAULT_ABI,
        signer
      );
      const tx = await vault.deposit(amount, account);
      await tx.wait();
      setStatus(`Vault deposit complete! TX: ${tx.hash}`);
      await loadAll();
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const handleVote = async (proposalId, support) => {
    if (!signer) return;
    try {
      setStatus("Voting...");
      const governor = new ethers.Contract(
        CONTRACTS.Governor,
        GOVERNOR_ABI,
        signer
      );
      const tx = await governor.castVote(proposalId, support);
      await tx.wait();
      setStatus(`Vote submitted! TX: ${tx.hash}`);
      await loadAll();
    } catch (error) {
      setStatus(formatError(error));
    }
  };

  const wrongNetwork = account && chainId !== ARBITRUM_SEPOLIA_CHAIN_ID;

  return (
    <div style={pageStyle}>
      <h1 style={titleStyle}>DeFi Super-App</h1>
      <p style={subtitleStyle}>Arbitrum Sepolia Testnet</p>

      {!account ? (
        <button onClick={connectWallet} style={btnStyle("#4f46e5")}>
          Connect MetaMask
        </button>
      ) : (
        <div style={connectedStyle}>
          <p>
            Connected: <b>{shortAddress(account)}</b>
          </p>
          <button onClick={() => loadAll()} style={btnStyle("#475569")}>
            Refresh
          </button>
          {wrongNetwork && (
            <button onClick={switchNetwork} style={btnStyle("#dc2626")}>
              Switch to Arbitrum Sepolia
            </button>
          )}
        </div>
      )}

      {status && <div style={noticeStyle}>{status}</div>}

      {account && (
        <>
          <section style={cardStyle}>
            <h2>Governance Token (DGT)</h2>
            <p>
              Balance: <b>{fixedNumber(tokenBalance)} DGT</b>
            </p>
            <p>
              Voting Power: <b>{fixedNumber(votingPower)}</b>
            </p>
            <p>
              Delegate: <b>{shortAddress(delegateAddr)}</b>
            </p>
            <button
              onClick={() => handleDelegate(account)}
              style={btnStyle("#059669")}
            >
              Self-Delegate
            </button>
            <div style={rowStyle}>
              <input
                placeholder="Delegate to address"
                value={delegateTo}
                onChange={(event) => setDelegateTo(event.target.value)}
                style={inputStyle}
              />
              <button
                onClick={() => handleDelegate()}
                style={btnStyle("#7c3aed")}
              >
                Delegate
              </button>
            </div>
            <div style={rowStyle}>
              <input
                placeholder="Transfer to address"
                value={transferTo}
                onChange={(event) => setTransferTo(event.target.value)}
                style={inputStyle}
              />
              <input
                placeholder="Amount"
                value={transferAmount}
                onChange={(event) => setTransferAmount(event.target.value)}
                style={smallInputStyle}
              />
              <button onClick={handleTransfer} style={btnStyle("#0ea5e9")}>
                Transfer
              </button>
            </div>
          </section>

          <section style={cardStyle}>
            <h2>AMM Pool (WETH/USDC)</h2>
            <p>
              Reserve WETH: <b>{fixedNumber(poolReserves.weth, 6)}</b>
            </p>
            <p>
              Reserve USDC: <b>{fixedNumber(poolReserves.usdc, 2)}</b>
            </p>
            <p>
              Wallet WETH: <b>{fixedNumber(walletBalances.weth, 6)}</b>
            </p>
            <p>
              Wallet USDC: <b>{fixedNumber(walletBalances.usdc, 2)}</b>
            </p>
            <div style={rowStyle}>
              <select
                value={swapToken}
                onChange={(event) => setSwapToken(event.target.value)}
                style={smallInputStyle}
              >
                <option>WETH</option>
                <option>USDC</option>
              </select>
              <input
                placeholder="Amount in"
                value={swapAmount}
                onChange={(event) => setSwapAmount(event.target.value)}
                style={smallInputStyle}
              />
              <input
                placeholder="Min out"
                value={swapMinOut}
                onChange={(event) => setSwapMinOut(event.target.value)}
                style={smallInputStyle}
              />
              <button onClick={handleSwap} style={btnStyle("#0891b2")}>
                Swap
              </button>
            </div>
            <div style={rowStyle}>
              <input
                placeholder="WETH"
                value={liquidityWeth}
                onChange={(event) => setLiquidityWeth(event.target.value)}
                style={smallInputStyle}
              />
              <input
                placeholder="USDC"
                value={liquidityUsdc}
                onChange={(event) => setLiquidityUsdc(event.target.value)}
                style={smallInputStyle}
              />
              <button onClick={handleAddLiquidity} style={btnStyle("#0f766e")}>
                Add Liquidity
              </button>
            </div>
          </section>

          <section style={cardStyle}>
            <h2>Yield Vault</h2>
            <p>
              Your Shares: <b>{fixedNumber(vaultShares, 6)}</b>
            </p>
            <p>
              Total Assets: <b>{fixedNumber(vaultAssets, 2)} USDC</b>
            </p>
            <div style={rowStyle}>
              <input
                placeholder="USDC amount"
                value={vaultDeposit}
                onChange={(event) => setVaultDeposit(event.target.value)}
                style={inputStyle}
              />
              <button onClick={handleVaultDeposit} style={btnStyle("#16a34a")}>
                Deposit
              </button>
            </div>
          </section>

          <section style={cardStyle}>
            <h2>Governance Proposals</h2>
            <p style={mutedStyle}>{subgraphStatus}</p>
            {proposals.length === 0 ? (
              <p>No indexed proposals loaded.</p>
            ) : (
              proposals.map((proposal) => (
                <div key={proposal.id} style={itemStyle}>
                  <p>
                    <b>{proposal.description || `Proposal ${proposal.id}`}</b>
                  </p>
                  <p>
                    State: <b>{proposal.state}</b> | Proposer:{" "}
                    {shortAddress(proposal.proposer)}
                  </p>
                  <button
                    onClick={() => handleVote(proposal.id, 1)}
                    style={btnStyle("#059669")}
                  >
                    For
                  </button>
                  <button
                    onClick={() => handleVote(proposal.id, 0)}
                    style={btnStyle("#b91c1c")}
                  >
                    Against
                  </button>
                  <button
                    onClick={() => handleVote(proposal.id, 2)}
                    style={btnStyle("#64748b")}
                  >
                    Abstain
                  </button>
                </div>
              ))
            )}
          </section>

          <section style={cardStyle}>
            <h2>Indexed Swaps From The Graph</h2>
            {swaps.length === 0 ? (
              <p>No indexed swaps loaded.</p>
            ) : (
              swaps.map((swap) => (
                <div key={swap.id} style={itemStyle}>
                  <p>
                    User: <b>{shortAddress(swap.user)}</b>
                  </p>
                  <p>Token in: {shortAddress(swap.tokenIn)}</p>
                  <p>
                    In: {swap.amountIn} | Out: {swap.amountOut}
                  </p>
                </div>
              ))
            )}
          </section>

          <section style={cardStyle}>
            <h2>Contract Addresses</h2>
            {Object.entries(CONTRACTS).map(([name, address]) => (
              <p key={name}>
                {name}:{" "}
                <a
                  href={`https://sepolia.arbiscan.io/address/${address}`}
                  target="_blank"
                  rel="noreferrer"
                  style={{ color: "#60a5fa" }}
                >
                  {shortAddress(address)}
                </a>
              </p>
            ))}
          </section>
        </>
      )}
    </div>
  );
}

const pageStyle = {
  fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
  padding: "2rem",
  maxWidth: "800px",
  margin: "0 auto",
  textAlign: "left",
};

const titleStyle = {
  marginBottom: "0.25rem",
};

const subtitleStyle = {
  color: "#888",
  marginBottom: "1.5rem",
};

const connectedStyle = {
  marginBottom: "1rem",
};

const noticeStyle = {
  background: "#1e293b",
  padding: "1rem",
  borderRadius: "8px",
  margin: "1rem 0",
  color: "#94a3b8",
  border: "1px solid #334155",
};

const cardStyle = {
  background: "#0f172a",
  border: "1px solid #1e293b",
  borderRadius: "12px",
  padding: "1.5rem",
  marginTop: "1.5rem",
  color: "#cbd5e1",
};

const itemStyle = {
  borderTop: "1px solid #1e293b",
  paddingTop: "1rem",
  marginTop: "1rem",
};

const mutedStyle = {
  color: "#94a3b8",
  marginBottom: "0.75rem",
};

const rowStyle = {
  display: "flex",
  gap: "0.5rem",
  flexWrap: "wrap",
  alignItems: "center",
  marginTop: "1rem",
};

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
  minWidth: "250px",
  flex: "1 1 250px",
};

const smallInputStyle = {
  background: "#1e293b",
  color: "white",
  border: "1px solid #334155",
  padding: "0.5rem",
  borderRadius: "6px",
  width: "120px",
};
