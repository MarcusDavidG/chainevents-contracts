use starknet::ContractAddress;

#[starknet::interface]
pub trait IGroupSaving<TContractState> {
    fn collect_payout(ref self: TContractState, group_id: felt252, member: ContractAddress);
}
