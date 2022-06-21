//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/utils/Strings.sol";

contract Utilities {

    function stringsEquals(string memory _a, string memory _b) public pure returns (bool) {
        return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
    }

    function substring(string memory _str, uint startIndex, uint endIndex) public pure returns (string memory ) {
        bytes memory strBytes = bytes(_str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _calculateStrength(uint256 _dna) public pure returns (uint8) {
        string memory _strDna = Strings.toString(_dna);
        string memory _strengthSetter = substring(_strDna, 0, 4);
        uint256 strength = uint256(keccak256(abi.encodePacked(_strengthSetter)));
        return uint8(strength) % 51; // la máxima fuerza será 100, pero al nivel 1 tendrán una fuerza de 1 a 50
    }


}