//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract SelectorAndSignature {
    address _someAddress;
    uint256 _amount;

    function getSelectorOne() public pure returns (bytes4 selector) {
        selector = bytes4(keccak256("transfer(address,uint256)"));
    }

    function getSelectorTwo() public view returns (bytes4 selector) {
        bytes memory functionCallData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(this),
            123
        );
        selector = bytes4(
            bytes.concat(
                functionCallData[0],
                functionCallData[1],
                functionCallData[2],
                functionCallData[3]
            )
        );
    }

    function transfer(address someAddress, uint256 amount) public {
        _someAddress = someAddress;
        _amount = amount;
    }

    function getSelectorThree() public pure returns (bytes4 selector) {
        return this.transfer.selector;
    }

    function getSignatureOne() public pure returns (string memory) {
        return "transfer(address,uint256)";
    }
}
