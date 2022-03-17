// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IRandom {
    function canSteal(uint256 _count, uint256 stealPercentage)
        external
        returns (bool);

    function getMonsterId(
        uint256[] memory _tokenIds,
        uint256 stealPercentage,
        uint256 _count
    ) external view returns (uint256);
}
