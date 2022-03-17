// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IBabyApesRescue {
    function getMonsterOwners() external view returns (address[] memory);

    function cloneBalance(address owner) external view returns (uint256);

    function ogBalance(address owner) external view returns (uint256);
}
