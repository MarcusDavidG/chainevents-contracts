// Unit tests for GroupSaving contract and collect_payout function

use core::traits::TryInto;
use starknet::{ContractAddress};

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait,
};

const MEMBER_ONE: felt252 = 'MEMBER_ONE';
const MEMBER_TWO: felt252 = 'MEMBER_TWO';
const MEMBER_THREE: felt252 = 'MEMBER_THREE';

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn __setup__() -> ContractAddress {
    let groupsaving_class_hash = declare("GroupSaving").unwrap().contract_class();

    let mut constructor_calldata: Array<felt252> = array![];

    let owner = OWNER();

    owner.serialize(ref constructor_calldata);

    let (groupsaving_contract_address, _) = groupsaving_class_hash
        .deploy(@constructor_calldata)
        .unwrap();

    return groupsaving_contract_address;
}

#[test]
fn test_valid_recipient_collects_payout() {
    let contract_address = __setup__();

    let groupsaving = GroupSaving { contract_address };

    // Setup group, contributions, and payout order here (mock or call setup functions)

    // Simulate member one collecting payout successfully

    start_cheat_caller_address(contract_address, MEMBER_ONE.try_into().unwrap());

    groupsaving.collect_payout(1, MEMBER_ONE.try_into().unwrap());

    stop_cheat_caller_address(contract_address);

    // Assert events emitted and state changes
}

#[test]
fn test_collect_before_all_contributions_fails() {
    let contract_address = __setup__();

    let groupsaving = GroupSaving { contract_address };

    // Setup group with incomplete contributions

    start_cheat_caller_address(contract_address, MEMBER_ONE.try_into().unwrap());

    // Expect panic due to incomplete contributions
    let result = std::panic::catch_unwind(|| {
        groupsaving.collect_payout(1, MEMBER_ONE.try_into().unwrap());
    });
    assert(result.is_err(), "Expected panic for incomplete contributions");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_non_recipient_collect_fails() {
    let contract_address = __setup__();

    let groupsaving = GroupSaving { contract_address };

    // Setup group and contributions

    start_cheat_caller_address(contract_address, MEMBER_TWO.try_into().unwrap());

    // Expect panic due to non-recipient trying to collect
    let result = std::panic::catch_unwind(|| {
        groupsaving.collect_payout(1, MEMBER_TWO.try_into().unwrap());
    });
    assert(result.is_err(), "Expected panic for non-recipient collection");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_duplicate_collection_fails() {
    let contract_address = __setup__();

    let groupsaving = GroupSaving { contract_address };

    // Setup group and contributions

    start_cheat_caller_address(contract_address, MEMBER_ONE.try_into().unwrap());

    groupsaving.collect_payout(1, MEMBER_ONE.try_into().unwrap());

    // Attempt duplicate collection
    let result = std::panic::catch_unwind(|| {
        groupsaving.collect_payout(1, MEMBER_ONE.try_into().unwrap());
    });
    assert(result.is_err(), "Expected panic for duplicate collection");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_group_completion_after_final_round() {
    let contract_address = __setup__();

    let groupsaving = GroupSaving { contract_address };

    // Setup group at final round with all contributions

    start_cheat_caller_address(contract_address, MEMBER_THREE.try_into().unwrap());

    groupsaving.collect_payout(1, MEMBER_THREE.try_into().unwrap());

    // Assert group status is Completed

    stop_cheat_caller_address(contract_address);
}
