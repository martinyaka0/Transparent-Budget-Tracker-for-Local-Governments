# 🏛️ Transparent Budget Tracker for Local Governments

A decentralized solution for transparent public fund management using Clarity smart contracts on Stacks blockchain.

## 🎯 Features

- Create and manage public projects with budgets
- Set project milestones with specific fund allocations
- Community voting on milestone completions
- Transparent fund release mechanism
- Real-time tracking of project progress

## 🚀 Getting Started

### Prerequisites

- Clarinet installed
- Stacks wallet for testing

### Contract Functions

#### Creating Projects
```clarity
(create-project name description total-budget)
```

#### Adding Milestones
```clarity
(add-milestone project-id description amount due-date)
```

#### Voting on Milestones
```clarity
(vote-milestone project-id milestone-id)
```

#### Releasing Funds
```clarity
(release-funds project-id milestone-id)
```

## 📊 Project Structure

- Projects are created with unique IDs
- Each project can have multiple milestones
- Community members vote on milestone completion
- Funds are released after reaching vote threshold

## 🔒 Security Features

- Authorization checks for project creation
- Vote tracking to prevent double voting
- Minimum vote threshold for fund release
- Principal-based ownership verification

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📜 License

MIT
```

