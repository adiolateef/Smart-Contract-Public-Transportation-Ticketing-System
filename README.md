# Smart Contract Public Transportation Ticketing System

A comprehensive blockchain-based public transportation ticketing and fare collection system built on Stacks using Clarity smart contracts.

## System Overview

This system consists of five interconnected smart contracts that handle all aspects of public transportation fare management:

### 1. Fare Payment Integration Contract (`fare-payment.clar`)
- Enables passengers to pay for transit using various methods
- Supports mobile payments, smart cards, and cryptocurrency
- Handles payment processing and validation
- Maintains payment history and receipts

### 2. Fare Capping Contract (`fare-capping.clar`)
- Automatically caps fares at daily or monthly limits
- Ensures affordability for frequent riders
- Tracks usage patterns and applies appropriate caps
- Prevents overcharging beyond set limits

### 3. Reduced Fare Eligibility Verification Contract (`reduced-fare.clar`)
- Verifies eligibility for reduced fares
- Supports seniors, students, and low-income riders
- Manages eligibility documentation and verification
- Applies appropriate discounts based on rider category

### 4. Revenue Distribution Contract (`revenue-distribution.clar`)
- Distributes fare revenue among different transit agencies
- Calculates distribution based on ridership data
- Handles inter-agency settlements
- Provides transparent revenue tracking

### 5. Real-time Transit Information Contract (`transit-info.clar`)
- Provides real-time updates on schedules and delays
- Manages service disruption notifications
- Tracks vehicle locations and estimated arrival times
- Maintains route and schedule information

## Key Features

- **Multi-payment Support**: Accept various payment methods including STX tokens
- **Automatic Fare Capping**: Daily and monthly fare limits to protect riders
- **Eligibility Verification**: Automated reduced fare qualification
- **Revenue Transparency**: Clear distribution of funds between agencies
- **Real-time Updates**: Live transit information and service alerts
- **Audit Trail**: Complete transaction history for all operations

## Contract Architecture

The contracts are designed to work together while maintaining modularity:

- Each contract handles a specific domain of functionality
- Contracts can interact through public functions
- Data integrity is maintained through proper validation
- Error handling ensures system reliability

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for deployment

### Installation
\`\`\`bash
git clone <repository-url>
cd transit-ticketing-system
npm install
\`\`\`

### Testing
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy
\`\`\`

## Usage Examples

### Making a Fare Payment
\`\`\`clarity
(contract-call? .fare-payment pay-fare u100 "bus-route-1" tx-sender)
\`\`\`

### Checking Fare Cap Status
\`\`\`clarity
(contract-call? .fare-capping get-daily-usage tx-sender)
\`\`\`

### Verifying Reduced Fare Eligibility
\`\`\`clarity
(contract-call? .reduced-fare verify-eligibility tx-sender "student")
\`\`\`

## Security Considerations

- All contracts include proper access controls
- Input validation prevents malicious data
- Overflow protection for numerical operations
- Emergency pause functionality for critical issues

## Contributing

Please read the PR-DETAILS.md file for contribution guidelines and development workflow.

## License

This project is licensed under the MIT License.

