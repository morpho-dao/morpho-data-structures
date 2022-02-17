// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./DoubleLinkedList.sol";

contract TestDoubleLinkedList {
    using DoubleLinkedList for DoubleLinkedList.List;

    DoubleLinkedList.List public list;

    function remove(address _id) external {
        list.remove(_id);
    }

    function getNext(address _id) external view {
        list.getNext(_id);
    }

    function getHead() external view {
        list.getHead();
    }
}
