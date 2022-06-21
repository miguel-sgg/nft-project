//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";  
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./CryptoAvatar.sol";

contract Battle {

    AvatarCore private ppal;
    uint256 public constant MAX_LEVEL = 75;

    event LevelUp(uint256 indexed tokenId, address indexed owner, uint8 indexed newLevel);
    event Battle(uint256 _tokenId, uint256 _targetId, uint8 _level, uint8 _strength, uint8 _targetLevel, uint8 _targetStrength, uint8 _successfulAttacks, uint8 _successsfulDefenses);
    modifier onlyOwnerOf(uint _tokenId) {
        require(msg.sender == ppal.tokenIdToOwner(_tokenId), "You are not the owner of this token");
        _;
    }

    constructor(address _contract_addr) {
        ppal = AvatarCore(_contract_addr);
    }

    function _levelUp(uint256 _tokenId) private {
        uint8 level = ppal.getCharacters(_tokenId).level; 
        uint8 strength = ppal.getCharacters(_tokenId).strength;
        if(level + 1 <= MAX_LEVEL) {
            level++;
            strength += 2;
            emit LevelUp(_tokenId, ppal.tokenIdToOwner(_tokenId), level);
        }
    }

    function attack(uint256 _tokenId, uint256 _targetId) external payable onlyOwnerOf(_tokenId) { 
        //returns (uint256 tokenId, uint256 targetId, uint8 level, uint8 strength, uint8 targetLevel, uint8 targetStrength, uint8 successfulAttacks, uint8 successsfulDefenses) {
        require(ppal.tokenCount() > 2, "There is only one token");
        AvatarCore.Avatar memory myAvatar = ppal.getCharacters(_tokenId);
        AvatarCore.Avatar memory enemyAvatar = ppal.getCharacters(_targetId);
        // en caso de empate en fuerza ganará el defensor
        if (myAvatar.strength > enemyAvatar.strength) {
            // si ganas 10 ataques subes de nivel
            myAvatar.successfulAttacks++;
            if (myAvatar.successfulAttacks % 10 == 0) {
                myAvatar.successfulAttacks = 0;
                _levelUp(_tokenId);
            }
        } else {
            // si ganas 15 defensas, subes de nivel
            enemyAvatar.successfulDefences++;
            if (enemyAvatar.successfulDefences % 15 == 0) {
                enemyAvatar.successfulDefences = 0;
                _levelUp(_targetId);
            }
        }
        emit Battle(_tokenId, _targetId, myAvatar.level, myAvatar.strength, enemyAvatar.level, enemyAvatar.strength, myAvatar.successfulAttacks, enemyAvatar.successfulDefences);
    }
    
}