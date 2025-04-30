#[starknet::contract]
/// @title Group Saving Contract (ROSCA)
/// @notice Implements rotating savings and credit association group saving logic
/// @dev Implements collect_payout function for member withdrawals

pub mod GroupSaving {
    use core::starknet::{
        ContractAddress, get_caller_address, contract_address_const,
        storage::{Map, StorageMapWriteAccess, StorageMapReadAccess},
    };
    use core::num::traits::zero::Zero;
    use core::option::OptionTrait;

    // Group status enum
    #[derive(Copy, Drop, PartialEq, Eq)]
    pub enum GroupStatus {
        Active = 0,
        Completed = 1,
    }

    // Group struct
    #[derive(Copy, Drop)]
    pub struct Group {
        pub group_id: felt252,
        pub status: GroupStatus,
        pub total_rounds: felt252,
        pub current_round: felt252,
        pub payout_order: Array<ContractAddress>,
        pub contributions_received: Map<(felt252, felt252, ContractAddress), bool>, // (group_id, round, member) -> bool
        pub funds_collected: Map<(felt252, felt252), bool>, // (group_id, round) -> bool
    }

    #[storage]
    struct Storage {
        groups: Map<felt252, Group>, // group_id -> Group
        group_members: Map<(felt252, ContractAddress), bool>, // (group_id, member) -> bool
        group_funds: Map<(felt252, ContractAddress), felt252>, // (group_id, member) -> amount contributed
        group_total_contribution: Map<felt252, felt252>, // group_id -> total contribution per round
        group_balances: Map<(felt252, ContractAddress), felt252>, // (group_id, member) -> balance available to withdraw
    }

    #[event]
    pub struct PayoutCollected {
        pub group_id: felt252,
        pub round: felt252,
        pub member: ContractAddress,
        pub amount: felt252,
    }

    #[event]
    pub struct GroupCompleted {
        pub group_id: felt252,
    }

    impl GroupSaving {
        /// @notice Collect payout for the current round if eligible
        /// @param group_id The ID of the group
        /// @param member The member address attempting to collect payout
        fn collect_payout(ref self: ContractState, group_id: felt252, member: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == member, "Caller must be the member");

            // Read group
            let mut group = self.groups.read(group_id);
            assert(group.status == GroupStatus::Active, "Group must be active");

            let current_round = group.current_round;

            // Validate member is in group
            let is_member = self.group_members.read((group_id, member));
            assert(is_member, "Member not in group");

            // Validate all contributions received for current round
            let mut all_contributed = true;
            let payout_order = &group.payout_order;
            let num_members = payout_order.len();
            let mut i = 0;
            while i < num_members {
                let m = payout_order.at(i);
                let contributed = self.contributions_received.read((group_id, current_round, m));
                if !contributed {
                    all_contributed = false;
                    break;
                }
                i += 1;
            }
            assert(all_contributed, "Not all contributions received for current round");

            // Validate member is the designated recipient for current round
            let designated_member = payout_order.at((current_round - 1) as usize);
            assert(member == designated_member, "Member not designated recipient for this round");

            // Prevent duplicate collection
            let already_collected = self.funds_collected.read((group_id, current_round));
            assert(!already_collected, "Funds already collected for this round");

            // Calculate payout amount (total contribution * number of members)
            let total_contribution = self.group_total_contribution.read(group_id);
            let payout_amount = total_contribution * num_members as felt252;

            // Mark funds as collected
            self.funds_collected.write((group_id, current_round), true);

            // Update group balance for member
            let prev_balance = self.group_balances.read((group_id, member));
            self.group_balances.write((group_id, member), prev_balance + payout_amount);

            // Advance round or complete group
            if current_round == group.total_rounds {
                group.status = GroupStatus::Completed;
                self.groups.write(group_id, group);
                self.emit(GroupCompleted { group_id });
            } else {
                group.current_round = current_round + 1;
                self.groups.write(group_id, group);
            }

            self.emit(PayoutCollected { group_id, round: current_round, member, amount: payout_amount });
        }
    }
}
