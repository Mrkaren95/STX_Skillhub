# SkillHub - Decentralized Talent Marketplace

A blockchain-based talent marketplace built on the Stacks blockchain that enables secure, transparent engagements between clients and talent with built-in dispute resolution and reputation systems.

## Overview

SkillHub revolutionizes the freelancing industry by leveraging blockchain technology to create a trustless, decentralized platform where clients can engage talent without intermediaries. Smart contracts handle payments, escrow, and dispute resolution, ensuring fair and secure transactions for all parties.

## Key Features

###  Secure Engagement Management
- **Escrow System**: Payments are held in smart contract escrow until project completion
- **Automated Releases**: Funds are automatically released upon mutual agreement
- **Dispute Resolution**: Built-in mediation system for conflict resolution

###  Reputation System
- **Talent Profiles**: Comprehensive profiles with ratings, reviews, and project history
- **Reputation Scoring**: Dynamic scoring based on completed projects and client reviews
- **Transparency**: All ratings and reviews are stored on-chain for transparency

###  Fair Fee Structure
- **Low Platform Fees**: Default 2.5% platform fee (adjustable by admin)
- **No Hidden Costs**: All fees are transparent and calculated upfront
- **Direct Payments**: Payments go directly to talent without intermediary custody

###  Dispute Resolution
- **Mediation System**: Either party can request mediation for disputes
- **Neutral Arbitrators**: Third-party mediators can resolve payment disputes
- **Final Resolution**: Mediators have authority to direct payment allocation

## Smart Contract Architecture

### Core Data Structures

#### Engagements
```clarity
{
    client: principal,
    talent: principal,
    payment-amount: uint,
    project-description: string-ascii,
    engagement-status: string-ascii,
    created-block: uint,
    finalized-block: uint,
    mediator: optional principal
}
```

#### Talent Profiles
```clarity
{
    total-reviews: uint,
    review-score-sum: uint,
    projects-completed: uint,
    reputation-score: uint
}
```

### Engagement Lifecycle

1. **Creation**: Client creates engagement with escrow payment
2. **Active**: Project work begins, funds held in escrow
3. **Completion**: Either party can finalize successful engagement
4. **Mediation**: Dispute resolution process if needed
5. **Resolution**: Final payment allocation by mediator

## Public Functions

### Core Engagement Functions

#### `create-engagement`
```clarity
(create-engagement talent-address payment-amount project-description)
```
Creates a new engagement with automatic escrow of payment plus platform fee.

#### `finalize-engagement`
```clarity
(finalize-engagement engagement-id)
```
Completes an engagement and releases payment to talent (callable by client or talent).

#### `submit-review`
```clarity
(submit-review talent-address review-score)
```
Submits a 1-5 star review for talent, updating their reputation score.

### Dispute Resolution Functions

#### `request-mediation`
```clarity
(request-mediation engagement-id mediator-address)
```
Initiates mediation process for disputed engagement.

#### `resolve-mediation`
```clarity
(resolve-mediation engagement-id payment-recipient)
```
Mediator resolves dispute by directing payment to specified recipient.

### Administrative Functions

#### `update-platform-fee`
```clarity
(update-platform-fee new-fee-rate)
```
Admin-only function to adjust platform fee rate (max 10%).

## Read-Only Functions

### `get-engagement`
Returns complete engagement details for a given engagement ID.

### `get-talent-profile`
Returns talent profile including average rating, total reviews, and reputation score.

### `get-platform-fee-rate`
Returns current platform fee rate in basis points.

### `is-engagement-active`
Checks if an engagement is currently active.

## Security Features

### Input Validation
- All inputs are validated for type, range, and business logic
- Prevents self-engagement (client cannot hire themselves)
- Ensures sufficient balance before creating engagements

### Access Control
- Function-level authorization checks
- Role-based access for admin functions
- Engagement-specific permissions for participants

### Error Handling
- Comprehensive error codes for all failure scenarios
- Graceful handling of edge cases
- Clear error messages for debugging

## Error Codes

| Code | Description |
|------|-------------|
| 100  | Unauthorized access |
| 101  | Invalid engagement ID |
| 102  | Insufficient balance |
| 103  | Engagement already finalized |
| 104  | Invalid rating (must be 1-5) |
| 105  | No mediator assigned |
| 106  | Invalid input parameters |
| 107  | Cannot create self-engagement |

## Getting Started

### Prerequisites
- Stacks wallet (e.g., Hiro Wallet)
- STX tokens for transactions
- Stacks blockchain testnet/mainnet access

### Deployment
1. Deploy the smart contract to Stacks blockchain
2. Note the contract address for frontend integration
3. Configure platform fee rate if needed

### Integration
```javascript
// Example frontend integration
const engagement = await callContractFunction({
    contractAddress: 'ST1234...ABCD',
    contractName: 'skillhub',
    functionName: 'create-engagement',
    functionArgs: [
        principalCV('ST5678...EFGH'), // talent address
        uintCV(1000000), // payment amount in microSTX
        stringAsciiCV('Build a React app') // project description
    ]
});
```

## Reputation Algorithm

The reputation system uses a weighted scoring algorithm:

```
reputation_score = (average_rating * 20) + projects_completed
```

This approach:
- Weights quality (ratings) more heavily than quantity
- Rewards consistent high-quality work
- Provides meaningful differentiation between talent

## Platform Economics

### Fee Structure
- **Platform Fee**: 2.5% of engagement amount (default)
- **Payment Processing**: Handled by Stacks blockchain
- **Dispute Resolution**: No additional fees

### Token Economics
- All payments in STX tokens
- Platform fees collected by contract admin
- No additional token required

## Security Considerations

### Audit Recommendations
- Professional smart contract audit before mainnet deployment
- Comprehensive testing of all edge cases
- Security review of mediation system

### Best Practices
- Regular monitoring of contract interactions
- Backup systems for dispute resolution
- Clear terms of service for platform usage

## Contributing

We welcome contributions to SkillHub! Please see our contributing guidelines for:
- Code style requirements
- Testing standards
- Pull request process
- Security considerations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support or questions:
- GitHub Issues: Report bugs and feature requests
- Documentation: Comprehensive guides and API reference
- Community Discord: Connect with other developers

---

**Built  on Stacks blockchain**