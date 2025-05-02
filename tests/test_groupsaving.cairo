use core::starknet::{ContractAddress, get_caller_address};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use crate::src::group::groupsaving::GroupSaving;

fn setup_group(contract: &mut GroupSaving::ContractState, group_id: felt252, total_rounds: felt252, payout_order: [ContractAddress; 2]) {
    let group = GroupSaving::Group {
        group_id,
        status: GroupSaving::STATUS_ACTIVE,
        current_round: 1.into(),
        total_rounds,
        payout_order_len: 2.into(),
    };
    contract.groups.write(group_id, group);

    let mut i = 0;
    while i < 2 {
        let member = payout_order[i];
        contract.payout_order.write((group_id, (i + 1).into()), member);
        contract.contributions_expected.write((group_id, (i + 1).into()), 1.into());
        contract.contributions_received.write((group_id, (i + 1).into()), 1.into());
        contract.payout_collected.write((group_id, (i + 1).into()), 0.into());
        i = i + 1;
    }
}

#[test]
fn test_collect_payout_success() {
    let mut contract = GroupSaving::ContractState::default();
    let group_id = 1.into();
    let payout_order = [ContractAddress::default(), ContractAddress::default()];
    setup_group(&mut contract, group_id, payout_order.len().into(), payout_order);

    start_cheat_caller_address(payout_order[0]);
    contract.collect_payout(group_id, payout_order[0]);
    stop_cheat_caller_address();

    let group = contract.groups.read(group_id);
    assert(group.current_round == 2.into(), "Round did not advance");
    assert(group.status == GroupSaving::STATUS_ACTIVE, "Group status incorrect");

    let collected = contract.payout_collected.read((group_id, 1.into()));
    assert(collected == 1.into(), "Payout not marked collected");
}

#[test]
#[should_panic(expected: "Not all contributions received")]
fn test_collect_payout_incomplete_contributions() {
    let mut contract = GroupSaving::ContractState::default();
    let group_id = 2.into();
    let payout_order = [ContractAddress::default()];
    setup_group(&mut contract, group_id, payout_order.len().into(), payout_order);

    contract.contributions_received.write((group_id, 1.into()), 0.into());

    start_cheat_caller_address(payout_order[0]);
    contract.collect_payout(group_id, payout_order[0]);
    stop_cheat_caller_address();
}

#[test]
#[should_panic(expected = "Member is not the designated recipient")]
fn test_collect_payout_wrong_member() {
    let mut contract = GroupSaving::ContractState::default();
    let group_id = 3.into();
    let payout_order = [ContractAddress::default()];
    setup_group(&mut contract, group_id, payout_order.len().into(), payout_order);

    start_cheat_caller_address(ContractAddress::default());
    contract.collect_payout(group_id, ContractAddress::default());
    stop_cheat_caller_address();
}

#[test]
#[should_panic(expected = "Payout already collected for this round")]
fn test_collect_payout_duplicate() {
    let mut contract = GroupSaving::ContractState::default();
    let group_id = 4.into();
    let payout_order = [ContractAddress::default()];
    setup_group(&mut contract, group_id, payout_order.len().into(), payout_order);

    start_cheat_caller_address(payout_order[0]);
    contract.collect_payout(group_id, payout_order[0]);
    contract.collect_payout(group_id, payout_order[0]);
    stop_cheat_caller_address();
}

#[test]
fn test_collect_payout_group_completed() {
    let mut contract = GroupSaving::ContractState::default();
    let group_id = 5.into();
    let payout_order = [ContractAddress::default()];
    setup_group(&mut contract, group_id, payout_order.len().into(), payout_order);

    let mut group = contract.groups.read(group_id);
    group.current_round = 1.into();
    group.total_rounds = 1.into();
    contract.groups.write(group_id, group);

    start_cheat_caller_address(payout_order[0]);
    contract.collect_payout(group_id, payout_order[0]);
    stop_cheat_caller_address();

    let group = contract.groups.read(group_id);
    assert(group.status == GroupSaving::STATUS_COMPLETED, "Group not marked completed");
}
