// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IBananaBar {
    function burn(address user, uint256 amount) external;

    function updateReward(address _from, address _to) external;

    function rewardOnMint(address user) external;

    function _tipBabyApeHolder(
        address from,
        address to,
        uint256 amount
    ) external;

    function updateRewardOnMint(address _user) external;
}
