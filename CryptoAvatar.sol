//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Utilities.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/utils/Strings.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";  
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
using SafeMath for uint256;


contract AvatarCreator is ERC721, Ownable {
    Utilities private aux;

    // diseñamos un adn con 16 cifras
    uint256 internal modDNA = 10 ** 16;
    uint256 public mintPrice;
    uint8 constant public MAX_LEVEL = 75;
    struct Avatar {
        string name;
        uint32 id;
        uint256 dna;
        uint8 level;
        uint8 strength;
        uint8 successfulAttacks;
        uint8 successfulDefences;
        uint256 price;
    }

    Avatar[] public characters;
    uint256 public tokenCount;

    mapping (uint256 => address) public tokenIdToOwner;
    mapping (address => uint256) public ownerTokenCount;

    event NewAvatar(uint tokenId, string name, uint256 dna);
    event NewName(uint256 indexed tokenId, address indexed owner, string indexed newName);

    modifier onlyOwnerOf(uint _tokenId) {
        require(msg.sender == tokenIdToOwner[_tokenId], "You are not the owner of this token");
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        mintPrice = 100 gwei;
    }

    function getCharacters(uint256 _tokenId) public view returns (Avatar memory) {
        return characters[_tokenId];
    }

    function repeatedName(string memory _name) internal view returns (bool) {
        for (uint256 i = 0; i < characters.length; i++) {
            if (aux.stringsEquals(characters[i].name, _name)) return true;
        }
        return false;
    }

    function _generateDNA(string memory _name) private view returns (uint256) {
        require(repeatedName(_name) == false, "Repeated name");
        return uint256(keccak256(abi.encodePacked(_name))) % modDNA;
    }

    function _createAvatar(string memory _name, uint256 _dna) internal {
        characters.push(Avatar(_name, uint32(tokenCount), _dna, 1, aux._calculateStrength(_dna), 0, 0, 0));
        _safeMint(msg.sender, tokenCount);
        tokenIdToOwner[tokenCount] = msg.sender;
        ownerTokenCount[msg.sender] = ownerTokenCount[msg.sender]++;
        emit NewAvatar(tokenCount, _name, _dna);
    }

    function createAvatar(string memory _name) public payable {
        require(msg.value == mintPrice, "Not the exact price");
        // Solo dejamos que el usuario cree de la nada un solo avatar. Si quiere tener más tendrá que cruzarlos con los de otro jugador
        require(ownerTokenCount[msg.sender] == 0);
        _createAvatar(_name, _generateDNA(_name));
        tokenCount++;
    }

    function getContractInfo() external view returns (address, uint256) {
        return (address(this), address(this).balance);
    }

    function setMintPrice(uint256 _newPrice) external onlyOwner {
        mintPrice = _newPrice;
    }

}

abstract contract AvatarFeatures is AvatarCreator {

    uint256 public nameChangeFee;

    function changeName(uint256 _tokenId, string memory _newName) external payable onlyOwnerOf(_tokenId) {
        require(msg.value >= nameChangeFee, "Not enough funds");
        require(characters[_tokenId].level >= 25, "Low level");
        require(repeatedName(_newName) == false, "Repeated name");
        characters[_tokenId].name = _newName;
        emit NewName(_tokenId, msg.sender, _newName);
    }

    function setNameChangeFee(uint256 _fee) external {
        nameChangeFee = _fee;
    }

    function withdraw() external payable onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}

abstract contract AvatarOffer is AvatarFeatures {

    mapping(uint256 => PurchaseRequest[]) internal token_offers;
    struct PurchaseRequest {
        uint256 offer;
        address customer;
        uint256 tokenId;
    }
    
    PurchaseRequest[] public total_offers;

    event OfferAccepted(address to, uint256 tokenId);

    function setTokenPrice(uint256 _tokenId, uint256 _newPrice) external onlyOwnerOf(_tokenId) {
        characters[_tokenId].price = _newPrice;
    }

    function makeOffer(uint256 _offer, uint256 _tokenId) external returns (PurchaseRequest memory) {
        require(ownerOf(_tokenId) != msg.sender, "Owner forbidden");
        PurchaseRequest memory myOffer = PurchaseRequest(_offer, msg.sender, _tokenId);
        token_offers[_tokenId].push(myOffer);
        return myOffer;
    }

    function searchOffer(address customer, uint256 tokenId) internal view returns (uint256) {
        for (uint256 i = 0; i < token_offers[tokenId].length; i++) {
            if (keccak256(abi.encodePacked(token_offers[tokenId][i].customer)) == keccak256(abi.encodePacked(customer))) return token_offers[tokenId][i].offer;
        }
        return 0;
    }

    function acceptOffer(address _customer, uint256 tokenId) public onlyOwnerOf(tokenId){
        require(_exists(tokenId), "Nonexistent token");
        require(searchOffer(_customer, tokenId) >= characters[tokenId].price, "Offer lower than price.");
        bool containsOffer = false;
        for (uint256 i = 0; i < total_offers.length; i++) {
            if((keccak256(abi.encodePacked(total_offers[i].customer)) == keccak256(abi.encodePacked(_customer))) && (i == tokenId)) {
                containsOffer = true;
                delete total_offers[i];
            }
        }
        require(containsOffer == true, "No offer match");
        approve(_customer, tokenId);
        delete token_offers[tokenId];
        emit OfferAccepted(_customer, tokenId);
    }

}

abstract contract AvatarBuy is AvatarOffer {

    uint8 internal royalties;

    event TokenSale(address from, address to, uint256 tokenId);

    function setPrice(uint256 _tokenId, uint256 _newPrice) external onlyOwnerOf(_tokenId) {
        characters[_tokenId].price = _newPrice;
    }

    function buyToken(uint256 tokenId) external payable {
        // Comprobamos que el token está a la venta
        require(characters[tokenId].price != 0, "Not for sale");
        // Comprobamos que el propietario ha aceptado la oferta del posible comprador
        require(getApproved(tokenId) == msg.sender, "Forbidden action");
        require(msg.value >= searchOffer(msg.sender, tokenId), "Lower funds than offer");
        address payable newOwner = payable(msg.sender);
        address payable oldOwner = payable(ownerOf(tokenId));
        // transfiere el dinero de la transacción al propietario, restando los royalties del propietario del contrato
        oldOwner.transfer(msg.value - uint256(msg.value*royalties/100));
        tokenIdToOwner[tokenId] = newOwner;
        safeTransferFrom(oldOwner, newOwner, tokenId);
        emit TokenSale(oldOwner, newOwner, tokenId);
        delete token_offers[tokenId];
        for (uint256 i = 0; i < total_offers.length; i++) if((keccak256(abi.encodePacked(total_offers[i].customer)) == keccak256(abi.encodePacked(newOwner))) && (i == tokenId)) delete total_offers[i];
    }

}

contract AvatarCore is AvatarBuy {
    
    uint256 private reproductionPrice;

    constructor(string memory _name, string memory _symbol) AvatarCreator(_name, _symbol) {
        royalties = 5;
        mintPrice = 1000 gwei;
        reproductionPrice = 10000 gwei;
        nameChangeFee = 10000 gwei;
    }

    function registerBattle(uint256 tokenId, uint256 targetId, uint8 level, uint8 strength, uint8 targetLevel, uint8 targetStrength, uint8 successfulAttacks, uint8 successfulDefences) external {
        characters[tokenId].level = level; 
        characters[tokenId].strength = strength;
        characters[tokenId].successfulAttacks = successfulAttacks;
        characters[targetId].level = targetLevel;
        characters[targetId].strength = targetStrength;
        characters[targetId].successfulDefences = successfulDefences;
    }

    function setReproductionPrice(uint256 _fee) external onlyOwner {
        reproductionPrice = _fee;
    }

    function reproduce(uint256 _tokenId, uint256 _tokenId2, string memory _childName) external payable onlyOwnerOf(_tokenId) {
        require(msg.value >= reproductionPrice, "Not enough ether");
        require(repeatedName(_childName) == false, "Repeated name");
        require(_exists(_tokenId) && _exists(_tokenId2), "One token does not exist");
        uint256 newDna = (characters[_tokenId].dna + (characters[_tokenId2].dna % modDNA)).div(2);
        // En este caso, el nombre no determina el dna del avatar, lo hacen sus padres
        _createAvatar(_childName, newDna);
        address payable _owner2 = payable(ownerOf(_tokenId2));
        _owner2.transfer(msg.value - uint256(msg.value*royalties/100));
    }

}
