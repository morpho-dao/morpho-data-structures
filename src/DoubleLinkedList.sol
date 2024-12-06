// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// @title Double Linked List.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice Modified double linked list with capped sorting insertion.
library DoubleLinkedList {
    /* STRUCTS */

    struct Account {
        address prev;
        address next;
        uint256 value;
    }

    struct List {
        mapping(address => Account) accounts;
    }

    /* ERRORS */

    /// @notice Thrown when the account is already inserted in the double linked list.
    error AccountAlreadyInserted();

    /// @notice Thrown when the account to remove does not exist.
    error AccountDoesNotExist();

    /// @notice Thrown when the address is zero at insertion.
    error AddressIsZero();

    /// @notice Thrown when the value is zero at insertion.
    error ValueIsZero();

    /* INTERNAL */

    /// @notice Returns the value of the account linked to `id`.
    /// @param list The list to search in.
    /// @param id The address of the account.
    /// @return The value of the account.
    function getValueOf(List storage list, address id) internal view returns (uint256) {
        return list.accounts[id].value;
    }

    /// @notice Returns the address at the head of the `list`.
    /// @param list The list to get the head.
    /// @return The address of the head.
    function getHead(List storage list) internal view returns (address) {
        return list.accounts[address(0)].next;
    }

    /// @notice Returns the address at the tail of the `list`.
    /// @param list The list to get the tail.
    /// @return The address of the tail.
    function getTail(List storage list) internal view returns (address) {
        return list.accounts[address(0)].prev;
    }

    /// @notice Returns the next id address from the current `id`.
    /// @param list The list to search in.
    /// @param id The address of the account.
    /// @return The address of the next account.
    function getNext(List storage list, address id) internal view returns (address) {
        return list.accounts[id].next;
    }

    /// @notice Returns the previous id address from the current `id`.
    /// @param list The list to search in.
    /// @param id The address of the account.
    /// @return The address of the previous account.
    function getPrev(List storage list, address id) internal view returns (address) {
        return list.accounts[id].prev;
    }

    /// @notice Removes an account of the `list`.
    /// @param list The list to search in.
    /// @param id The address of the account.
    function remove(List storage list, address id) internal {
        Account memory account = list.accounts[id];
        if (id == address(0)) revert AddressIsZero();
        if (account.value == 0) revert AccountDoesNotExist();

        list.accounts[account.prev].next = account.next;
        list.accounts[account.next].prev = account.prev;

        delete list.accounts[id];
    }

    /// @notice Inserts an account in the `list` at the right slot based on its `value`.
    /// @param list The list to search in.
    /// @param id The address of the account.
    /// @param value The value of the account.
    /// @param maxIterations The max number of iterations.
    function insertSorted(List storage list, address id, uint256 value, uint256 maxIterations) internal {
        if (value == 0) revert ValueIsZero();
        if (id == address(0)) revert AddressIsZero();
        if (list.accounts[id].value != 0) revert AccountAlreadyInserted();

        address next = getHead(list); // `id` will be inserted before `next`.

        uint256 numberOfIterations;
        for (; numberOfIterations < maxIterations; numberOfIterations++) {
            if (next == address(0) || list.accounts[next].value < value) break;
            next = getNext(list, next);
        }

        if (numberOfIterations == maxIterations) next = address(0);

        address prev = getPrev(list, next);
        list.accounts[id] = Account(prev, next, value);
        list.accounts[prev].next = id;
        list.accounts[next].prev = id;
    }
}
