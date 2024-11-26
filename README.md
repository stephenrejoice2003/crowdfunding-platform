# crowdfunding-platform
 

# Crowdfunding Smart Contract Project

## Overview

This project implements a Crowdfunding Smart Contract on the Stacks blockchain using Clarity. The contract allows users to create projects, stake tokens, track milestones, and claim refunds if projects do not meet their goals.

## Features

- **Project Creation**: Users can create new crowdfunding projects with a defined goal and deadline.
- **Staking**: Participants can stake tokens to support projects.
- **Milestones**: Projects can have multiple milestones, which are tracked for completion and funding allocation.
- **Refund Mechanism**: Participants can claim refunds if the project fails to reach its goal by the deadline.

## Smart Contract Structure

### Data Structures

1. **Projects**: Contains details about each project, including the owner, goal, current amount, deadline, and status.
2. **Milestones**: Tracks milestones associated with each project, including description, amount, and completion status.
3. **Stakes**: Records the stakes made by participants for each project.
4. **Last Milestone ID**: Keeps track of the last milestone ID used for each project.
5. **Token Trait**: Defines the necessary functions for interacting with a token contract (transfer and get balance).

### Key Functions

- `create-project(goal, deadline)`: Creates a new project.
- `get-project(project-id)`: Retrieves project details.
- `update-project-amount(project-id, amount)`: Updates the funding amount for a project.
- `stake(amount, project-id, token)`: Stakes an amount to a project.
- `add-milestone(project-id, description, amount)`: Adds a milestone to a project.
- `complete-milestone(project-id, milestone-id)`: Marks a milestone as completed.
- `claim-refund(project-id, token)`: Claims a refund if the project fails to meet its goal.

## Testing

The project includes unit tests for the smart contract using Vitest.

### Test Cases

1. **Create a New Project**: Tests the creation of a project and verifies the expected output.
2. **Stake an Amount**: Tests the staking functionality to ensure that it works as intended.
3. **Add a Milestone**: Verifies the addition of milestones to a project.
4. **Complete a Milestone**: Checks the completion of a milestone.
5. **Claim a Refund**: Tests the refund process for unsuccessful projects.

## Installation

To set up the project, follow these steps:

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run tests:
   ```bash
   npm test
   ```

## Usage

To use the smart contract, deploy it to the Stacks blockchain and interact with it through the defined functions. Ensure that you have the necessary token contract deployed as well.

## License

This project is licensed under the MIT License.
