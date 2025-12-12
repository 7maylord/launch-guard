# LaunchGuard AVS Operator

Decentralized operator for the LaunchGuard Actively Validated Service (AVS) built on EigenLayer.

## Overview

The LaunchGuard AVS Operator is responsible for:
1. **Registering** with the AVS by staking ETH
2. **Listening** for auction settlement tasks
3. **Decrypting** encrypted bids using threshold FHE
4. **Ranking** bids and selecting winners
5. **Submitting** task responses to achieve consensus
6. **Monitoring** reputation and detecting malicious activity

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   LaunchGuard AVS Operator                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Operator   │    │     FHE      │    │  Consensus   │  │
│  │ Registration│───▶│  Decryption  │───▶│   & Voting   │  │
│  └─────────────┘    └──────────────┘    └──────────────┘  │
│         │                   │                    │         │
│         ▼                   ▼                    ▼         │
│  ┌─────────────────────────────────────────────────────┐  │
│  │           Task Response Submission                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                              │                             │
└──────────────────────────────┼─────────────────────────────┘
                               ▼
                    ┌─────────────────────┐
                    │ LaunchGuardService  │
                    │      Manager        │
                    │   (AVS Contract)    │
                    └─────────────────────┘
```

## Setup

### Prerequisites

- Node.js v18+
- pnpm (recommended) or npm
- Private key with ETH for staking (minimum 1 ETH)

### Installation

```bash
cd operator
pnpm install
```

### Configuration

Create a `.env` file in the `operator` directory:

```env
# Network
RPC_URL=https://rpc.sepolia.org
OPERATOR_ID=1

# Operator wallet (must have ETH for staking)
PRIVATE_KEY=0x...

# Stake amount (minimum 1 ETH)
STAKE_AMOUNT=2

# Contract addresses
SERVICE_MANAGER_ADDRESS=0x...
AUCTION_ADDRESS=0x...
REPUTATION_ADDRESS=0x...
```

### Running the Operator

Build and run:

```bash
# Build TypeScript
pnpm run build

# Start operator
pnpm start
```

Or use development mode with auto-reload:

```bash
pnpm run dev
```

## How It Works

### 1. Operator Registration

When the operator starts, it automatically registers with the AVS:

```typescript
// Registers with stake
await serviceManager.registerOperator({ value: stakeAmount });
```

The operator's stake is locked in the ServiceManager contract and can be slashed for malicious behavior.

### 2. Task Processing

When an auction ends, anyone can call `createSettlementTask()` which emits a `TaskCreated` event:

```solidity
event TaskCreated(uint32 indexed taskId, bytes32 indexed poolId, uint256 totalBidders);
```

The operator listens for this event and:

1. **Fetches encrypted bids** for the pool
2. **Decrypts bids** using threshold FHE (requires multiple operators)
3. **Ranks bids** by amount to select top N winners
4. **Computes winnersRoot** (Merkle root) for consensus
5. **Submits response** to the ServiceManager

```typescript
await serviceManager.respondToTask(taskId, winners, winnersRoot);
```

### 3. Consensus

The AVS requires 67% of operators to agree on the same `winnersRoot`:

```solidity
uint256 requiredVotes = (totalActiveOperators * 67) / 100;
bool hasQuorum = responseVotes[taskId][winnersRoot] >= requiredVotes;
```

Once quorum is reached:
- Task is marked complete
- Settlement can be finalized
- Winners can execute priority swaps

### 4. Slashing

Operators can be slashed for:
- Submitting incorrect decryption results
- Not responding to tasks
- Byzantine behavior

Challenges can be submitted during the 7-day challenge window:

```solidity
function challengeResponse(uint32 taskId, address operator, bytes proof);
```

## Project Structure

```
operator/
├── src/
│   ├── LaunchGuardOperator.ts    # Main operator logic
│   ├── FHEDecryptor.ts           # Threshold FHE decryption
│   ├── Consensus.ts              # Bid ranking and consensus
│   └── ReputationMonitor.ts      # Reputation tracking
├── .env                          # Configuration
├── package.json
└── tsconfig.json
```

## Key Functions

### `registerOperator()`
Stakes ETH and registers operator with AVS.

### `handleTaskCreated(taskId, poolId, totalBidders)`
Processes new settlement tasks:
1. Fetches encrypted bids
2. Decrypts using threshold FHE
3. Ranks and selects winners
4. Submits response with winnersRoot

### `respondToTask(taskId, winners, winnersRoot)`
Submits task response to ServiceManager and checks for quorum.

### `decryptBids(poolId, bids)`
Threshold decryption of encrypted bid amounts using FHE.

## Monitoring

The operator logs all activities:

```
🚀 Starting LaunchGuard AVS Operator 1...
✅ Already registered as operator
✅ Operator 1 is running and listening for tasks...

🎯 New AVS Task #1 created for pool 0x4610...
📋 Processing AVS Task #1
Retrieved 5 encrypted bids
Decrypted 5 bids
Selected 3 winners
Winners root: 0x0d6e...

📤 Submitting response to Task #1...
✅ Response submitted for Task #1
🎉 Quorum reached for Task #1! Settlement will be finalized.
```

## Troubleshooting

### Operator not registered
```
Error: OperatorNotRegistered
```
**Solution**: Ensure your wallet has enough ETH for the stake amount.

### Insufficient stake
```
Error: InsufficientStake
```
**Solution**: Increase `STAKE_AMOUNT` in `.env` to at least 1 ETH.

### Task response failed
```
Error: InvalidResponse
```
**Solution**: Check that you haven't already responded to this task.

### Decryption failed
```
Failed to decrypt bid from 0x...
```
**Solution**: Ensure threshold FHE is properly configured with other operators.

## Security Considerations

1. **Private Key**: Never commit your `.env` file. Use a secure key management system in production.

2. **Stake Management**: Your staked ETH can be slashed for malicious behavior. Ensure your operator software is running correctly.

3. **Network Connectivity**: Maintain reliable RPC connection to avoid missing tasks.

4. **Consensus**: Coordinate with other operators to ensure threshold decryption works properly.

## Development

Run tests:

```bash
pnpm test
```

Lint code:

```bash
pnpm lint
```

Build:

```bash
pnpm build
```

## References

- [EigenLayer Documentation](https://docs.eigenlayer.xyz/)
- [Fhenix FHE Documentation](https://docs.fhenix.zone/)
- [Uniswap v4 Documentation](https://docs.uniswap.org/contracts/v4/overview)

## License

MIT
