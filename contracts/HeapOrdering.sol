// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

library HeapOrdering {
    struct Account {
        address id; // The address of the account.
        uint256 value; // The value of the account.
    }

    struct HeapArray {
        Account[] accounts; // All the accounts.
        uint256 size; // The size of the heap portion of the structure, should be less than accounts length, the rest is an unordered array.
        mapping(address => uint256) ranks; // A mapping from an address to an rank in accounts.
    }

    /// ERRORS ///

    /// @notice Thrown when the address is zero at insertion.
    error AddressIsZero();

    /// GETTERS ///

    /// @notice Returns the number of users in the `_heap`.
    /// @param _heap The heap parameter.
    /// @return The length of the heap.
    function length(HeapArray storage _heap) internal view returns (uint256) {
        return _heap.accounts.length;
    }

    /// @notice Returns the value of the account linked to `_id`.
    /// @param _heap The heap to search in.
    /// @param _id The address of the account.
    /// @return The value of the account.
    function getValueOf(HeapArray storage _heap, address _id) internal view returns (uint256) {
        uint256 rank = _heap.ranks[_id];
        if (rank == 0) return 0;
        else return _heap.accounts[rank - 1].value;
    }

    /// @notice Returns the address at the head of the `_heap`.
    /// @param _heap The heap to get the head.
    /// @return The address of the head.
    function getHead(HeapArray storage _heap) internal view returns (address) {
        if (_heap.accounts.length > 0) return _heap.accounts[0].id;
        else return address(0);
    }

    /// @notice Returns the address at the tail of the `_heap`.
    /// @param _heap The heap to get the tail.
    /// @return The address of the tail.
    function getTail(HeapArray storage _heap) internal view returns (address) {
        if (_heap.accounts.length > 0) return _heap.accounts[_heap.accounts.length - 1].id;
        else return address(0);
    }

    /// @notice Returns the address coming before `_id` in accounts.
    /// @dev The account associated to the returned address does not necessarily have a lower value than the one of the account associated to `_id`.
    /// @param _heap The heap to search in.
    /// @param _id The address of the account.
    /// @return The address of the previous account.
    function getPrev(HeapArray storage _heap, address _id) internal view returns (address) {
        uint256 rank = _heap.ranks[_id];
        if (rank > 1) return _heap.accounts[rank - 2].id;
        else return address(0);
    }

    /// @notice Returns the address coming after `_id` in accounts.
    /// @dev The account associated to the returned address does not necessarily have a greater value than the one of the account associated to `_id`.
    /// @param _heap The heap to search in.
    /// @param _id The address of the account.
    /// @return The address of the next account.
    function getNext(HeapArray storage _heap, address _id) internal view returns (address) {
        uint256 rank = _heap.ranks[_id];
        if (rank < _heap.accounts.length) return _heap.accounts[rank].id;
        else return address(0);
    }

    /// INTERNAL ///

    /// @notice Updates an account in the `_heap`.
    /// @dev Only call this function when `_id` is in the `_heap` with value `_formerValue` or when `_id` is not in the `_heap` with `_formerValue` equal to 0.
    /// @param _heap The heap to modify.
    /// @param _id The address of the account to update.
    /// @param _formerValue The former value of the account to update.
    /// @param _newValue The new value to use to update the account.
    /// @param _maxSortedUsers The maximum size of the heap.
    function update(
        HeapArray storage _heap,
        address _id,
        uint256 _formerValue,
        uint256 _newValue,
        uint256 _maxSortedUsers
    ) internal {
        uint256 size = _heap.size;
        uint256 newSize = computeSize(size, _maxSortedUsers);
        if (size != newSize) _heap.size = newSize;

        uint256 rank = _heap.ranks[_id];
        if (rank == 0 && _newValue > 0) insert(_heap, _id, _newValue, _maxSortedUsers);
        else if (rank > 0 && _formerValue != _newValue) {
            if (_newValue == 0) remove(_heap, _id, _formerValue);
            else if (_formerValue < _newValue) increase(_heap, _id, _newValue, _maxSortedUsers);
            else decrease(_heap, _id, _newValue);
        }
    }

    /// PRIVATE ///

    /// @notice Computes a new suitable size from `_size` that is smaller than `_maxSortedUsers`.
    /// @dev We use division by 2 because the biggest elements of the heap are in the first half (rounded down) of the heap.
    /// @param _size The old size of the heap.
    /// @param _maxSortedUsers The maximum size of the heap.
    /// @return The new size computed.
    function computeSize(uint256 _size, uint256 _maxSortedUsers) private pure returns (uint256) {
        while (_size >= _maxSortedUsers) _size /= 2;
        return _size;
    }

    /// @notice Sets `_rank` in the `_heap` to be `_account`.
    /// @dev The heap may lose its invariant about the order of the values stored.
    /// @dev Only call this function with an rank within array's bounds.
    /// @param _heap The heap to modify.
    /// @param _rank The rank of the account in the heap to be set.
    /// @param _account The account to set the `_rank` to.
    function set(
        HeapArray storage _heap,
        uint256 _rank,
        Account memory _account
    ) private {
        unchecked {
            _heap.accounts[_rank - 1] = _account;
        }
        _heap.ranks[_account.id] = _rank;
    }

    /// @notice Swaps two accounts in the `_heap`.
    /// @dev The heap may lose its invariant about the order of the values stored.
    /// @dev Only call this function with ranks within array's bounds.
    /// @param _heap The heap to modify.
    /// @param _rank1 The rank of the first account in the heap.
    /// @param _rank2 The rank of the second account in the heap.
    function swap(
        HeapArray storage _heap,
        uint256 _rank1,
        uint256 _rank2
    ) private {
        Account memory accountOldRank1;
        Account memory accountOldRank2;
        unchecked {
            accountOldRank1 = _heap.accounts[_rank1 - 1];
            accountOldRank2 = _heap.accounts[_rank2 - 1];
        }
        set(_heap, _rank1, accountOldRank2);
        set(_heap, _rank2, accountOldRank1);
    }

    /// @notice Moves an account up the heap until its value is smaller than the one of its parent.
    /// @dev This functions restores the invariant about the order of the values stored when the account at `_rank` is the only one with value greater than what it should be.
    /// @param _heap The heap to modify.
    /// @param _rank The rank of the account to move.
    function shiftUp(HeapArray storage _heap, uint256 _rank) private {
        Account memory initAccount;
        unchecked {
            initAccount = _heap.accounts[_rank - 1];

            uint256 initValue = initAccount.value;
            while (_rank > 1 && initValue > _heap.accounts[_rank / 2 - 1].value) {
                set(_heap, _rank, _heap.accounts[_rank / 2 - 1]);
                _rank /= 2;
            }
        }

        set(_heap, _rank, initAccount);
    }

    /// @notice Moves an account down the heap until its value is greater than the ones of its children.
    /// @dev This functions restores the invariant about the order of the values stored when the account at `_rank` is the only one with value smaller than what it should be.
    /// @param _heap The heap to modify.
    /// @param _rank The rank of the account to move.
    function shiftDown(HeapArray storage _heap, uint256 _rank) private {
        Account memory initAccount;
        unchecked {
            initAccount = _heap.accounts[_rank - 1];
        }

        Account memory childAccount;
        uint256 size = _heap.size;
        uint256 childRank = _rank * 2;
        while (childRank <= size) {
            if (
                // Compute the rank of the child with largest value.
                childRank + 1 <= size &&
                _heap.accounts[childRank].value > _heap.accounts[childRank - 1].value
            ) childRank++;

            childAccount = _heap.accounts[childRank - 1];

            if (childAccount.value > initAccount.value) {
                set(_heap, _rank, childAccount);
                _rank = childRank;
                childRank *= 2;
            } else break;
        }

        set(_heap, _rank, initAccount);
    }

    /// @notice Inserts an account in the `_heap`.
    /// @dev Only call this function when `_id` is in the `_heap`.
    /// @dev Reverts with AddressIsZero if `_value` is 0.
    /// @param _heap The heap to modify.
    /// @param _id The address of the account to insert.
    /// @param _value The value of the account to insert.
    /// @param _maxSortedUsers The maximum size of the heap.
    function insert(
        HeapArray storage _heap,
        address _id,
        uint256 _value,
        uint256 _maxSortedUsers
    ) private {
        // `_heap` cannot contain the 0 address
        if (_id == address(0)) revert AddressIsZero();

        // Put the account at the end of accounts.
        _heap.accounts.push(Account(_id, _value));
        uint256 accountsLength = _heap.accounts.length;
        _heap.ranks[_id] = accountsLength;

        // Move the account at the end of the heap and restore the invariant.
        uint256 newSize = _heap.size + 1;
        swap(_heap, newSize, accountsLength);
        shiftUp(_heap, newSize);
        _heap.size = computeSize(newSize, _maxSortedUsers);
    }

    /// @notice Decreases the amount of an account in the `_heap`.
    /// @dev Only call this function when `_id` is in the `_heap` with a value greater than `_newValue`.
    /// @param _heap The heap to modify.
    /// @param _id The address of the account to decrease the amount.
    /// @param _newValue The new value of the account.
    function decrease(
        HeapArray storage _heap,
        address _id,
        uint256 _newValue
    ) private {
        uint256 rank = _heap.ranks[_id];
        unchecked {
            _heap.accounts[rank - 1].value = _newValue;
        }

        if (rank <= _heap.size) shiftDown(_heap, rank);
    }

    /// @notice Increases the amount of an account in the `_heap`.
    /// @dev Only call this function when `_id` is in the `_heap` with a smaller value than `_newValue`.
    /// @param _heap The heap to modify.
    /// @param _id The address of the account to increase the amount.
    /// @param _newValue The new value of the account.
    /// @param _maxSortedUsers The maximum size of the heap.
    function increase(
        HeapArray storage _heap,
        address _id,
        uint256 _newValue,
        uint256 _maxSortedUsers
    ) private {
        uint256 rank = _heap.ranks[_id];
        unchecked {
            _heap.accounts[rank - 1].value = _newValue;
        }

        uint256 size = _heap.size;
        if (rank <= size) shiftUp(_heap, rank);
        else if (size < _heap.accounts.length) {
            uint256 newSize = _heap.size + 1;

            swap(_heap, newSize, rank);
            shiftUp(_heap, newSize);
            _heap.size = computeSize(newSize, _maxSortedUsers);
        }
    }

    /// @notice Removes an account in the `_heap`.
    /// @dev Only call when this function `_id` is in the `_heap` with value `_removedValue`.
    /// @param _heap The heap to modify.
    /// @param _id The address of the account to remove.
    /// @param _removedValue The value of the account to remove.
    function remove(
        HeapArray storage _heap,
        address _id,
        uint256 _removedValue
    ) private {
        uint256 rank = _heap.ranks[_id];
        uint256 accountsLength = _heap.accounts.length;

        // Swap the last account and the account to remove, then pop it.
        swap(_heap, rank, accountsLength);
        _heap.accounts.pop();
        delete _heap.ranks[_id];

        // If the swapped account is in the heap, restore the invariant: its value can be smaller or larger than the removed value.
        if (_heap.size == accountsLength) _heap.size--;
        if (rank <= _heap.size) {
            if (_removedValue > _heap.accounts[rank - 1].value) shiftDown(_heap, rank);
            else shiftUp(_heap, rank);
        }
    }
}
