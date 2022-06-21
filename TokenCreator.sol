//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";  
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BaseToken is ERC721, Ownable {
    uint256 private token_count;
    string private baseURI;
    mapping(uint256 => string) private ipfs_cids;
    uint8 constant TOTAL_PIECES = 20;
    uint8 constant MAX_PIECES_TX = 20; // modificado para poder subir una colección completa de 20 CryptoEmojis a Rinkeby
    event newToken(address owner, uint256 token_id);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        token_count = 0;
        baseURI = "https://ipfs.io/ipfs/";
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Only the owner of this token is authorized to do this");
        _;
    }

    modifier validId(uint256 tokenId) {
        require(_exists(tokenId), "Nonexistent token");
        _;
    }

    function appendTwoStrings(string memory _a, string memory _b) internal pure returns (string memory) {
        return string(abi.encodePacked(_a, _b));
    }

    function stringsEquals(string memory _a, string memory _b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
    }

    function containsAddress(address[] memory _a, address _b) internal pure returns (bool) {
        for (uint256 i = 0; i < _a.length; i++) {
            if (keccak256(abi.encodePacked(_a[i])) == keccak256(abi.encodePacked(_b))) return true;
        }
        return false;
    }
    
    function alreadyMinted(string memory _cid) internal view returns (bool) {
        for (uint256 i = 0; i < token_count; i++) {
            if (stringsEquals(_cid, ipfs_cids[i]) == true) return true;
        }
        return false;
    }

    function setURI(string memory _a, string memory _b) internal view virtual returns (string memory) {
        require(stringsEquals(_a, baseURI) == true, "Invalid URL: not valid baseURL");
        require(alreadyMinted(_b) == false, "NFT already minted");
        if (bytes(_a).length > 0 && bytes(_b).length > 0) return appendTwoStrings(_a, _b);
        else return "Invalid URL";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return setURI(baseURI, ipfs_cids[tokenId]);
        //return (bytes(baseURI).length > 0 && bytes(ipfs_cids[tokenId]).length > 0) ? appendTwoStrings(baseURI, ipfs_cids[tokenId]) : "Invalid URL";
        //return uri; // esta es la URL del JSON de la imagen, no de la imagen en sí.
    }

    // Visualize the balance of the Smart Contract (ethers)
    function getContractInfo() public view returns (address, uint256) {
        address SC_addr = address(this);
        uint256  SC_balance = address(this).balance;
        return (SC_addr, SC_balance);
    }

    function mintToken(address _to, string memory _cid) private onlyOwner {
        require(stringsEquals(setURI(baseURI, _cid), "Invalid URL") == false, "Forbidden mint: not valid CID or baseURL, or both");
        token_count++;
        ipfs_cids[token_count] = _cid;
        _safeMint(_to, token_count); // acuña el NFT
        tokenURI(token_count);
    }

}

contract CollectionCreator is BaseToken {
    uint256 private token_count;
    string private baseURI;
    mapping(uint256 => string) private ipfs_cids;
    uint256 private mint_price;
    mapping(uint256 => uint256) private token_prices;
    mapping(uint256 => PurchaseRequest[]) private token_offers;
    mapping(uint256 => address[]) private addr_offers;
    mapping(uint256 => PurchaseRequest) private accepted_offers;
    event tokenSale(address from, address to, uint256 tokenId);
    event offerAccepted(address to, uint256 tokenId);
    event newTokenForSale(uint256 tokenId, address payable owner, uint256 token_price);
    struct TokenFeatures {
        address payable previous_owner;
        address payable owner;
        uint256 id;
        uint256 token_price;
        string cid;
        string url;
    }
    struct PurchaseRequest {
        uint256 offer;
        address customer;
        uint256 tokenId;
    }
    TokenFeatures[] public token_v;

    constructor(string memory _name, string memory _symbol) BaseToken(_name, _symbol) {
        token_count = 0;
        baseURI = "https://ipfs.io/ipfs/";
        mint_price = 50 gwei;
    }

    function getOffers(uint256 tokenId) external view onlyOwner returns(PurchaseRequest[] memory) {
        return token_offers[tokenId];
    }

    function getTokenPrice(uint256 tokenId) public view returns (uint256) {
        return token_v[tokenId].token_price;
    }

    function sumPrices(uint256[] memory _tokenIds) internal view returns (uint256) {
        uint256 total_price = 0;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            total_price += token_v[_tokenIds[i]].token_price;
        }
        return total_price;
    }

    function searchOffer(address customer, uint256 tokenId) internal view returns (PurchaseRequest memory) {
        uint256 aux = 0;
        for (uint256 i = 0; i < token_offers[tokenId].length; i++) {
            if (keccak256(abi.encodePacked(token_offers[tokenId][i].customer)) == keccak256(abi.encodePacked(customer))) aux = i;
        }
        return token_offers[tokenId][aux];
    }

    function updateMintPrice(uint256 _newPrice) external onlyOwner {
        mint_price = _newPrice;
    }

    function updateTokenPrice(uint256 tokenId, uint256 _newPrice) external onlyTokenOwner(tokenId) {
        bool tokenForSale = false;
        if (token_prices[tokenId] == 0) tokenForSale = true;
        token_prices[tokenId] = _newPrice;
        token_v[tokenId].token_price = _newPrice;
        if (tokenForSale) emit newTokenForSale(tokenId, token_v[tokenId].owner, token_prices[tokenId]);
    }

    function containsOffer(address addr_offer, uint256 tokenId) public view returns (bool) {
        for (uint256 i = 0; i < token_offers[tokenId].length; i++) {
            if(keccak256(abi.encodePacked(addr_offers[tokenId][i])) == keccak256(abi.encodePacked(addr_offer))) return true;
        }
        return false;
    }

    function acceptOffer(address _customer, uint256 tokenId) public validId(tokenId) onlyTokenOwner(tokenId){
        PurchaseRequest memory _a = searchOffer(_customer, tokenId);
        require(containsOffer(_customer, tokenId) == true, "This offer does not exist");
        require(_a.offer >= token_v[tokenId].token_price, "The offer is lower than the price. Update the token price to accept the offer");
        approve(_customer, tokenId);
        delete token_offers[tokenId];
        for (uint256 i = 0; i < addr_offers[tokenId].length; i++) {
            if(keccak256(abi.encodePacked(addr_offers[tokenId][i])) == keccak256(abi.encodePacked(_customer))) delete addr_offers[tokenId][i];
        }
        accepted_offers[tokenId] = _a;
        emit offerAccepted(_customer, tokenId);
    }

    // By default, a token is not for sale when it is minted
    function _mintToken(address _to, string[] memory _cids) internal returns (uint256, uint256){
        uint8 _amount = uint8(_cids.length);
        uint8 _auxCounter = 0;
        uint256 _auxTokenCount;
        TokenFeatures memory new_token;
        require(token_count < TOTAL_PIECES && (token_count+_amount) < TOTAL_PIECES, "The maximum of mintable tokens is a total of 20 tokens.");
        require(_amount > 0 && _amount <= MAX_PIECES_TX, "Not allowed to mint more than 5 tokens at a time.");
        for (uint8 i = 0; i < _amount; i++) {
            require(stringsEquals(setURI(baseURI, _cids[i]), "Invalid URL: no valid CID or baseURL") == false, "Forbidden mint: not valid CID or baseURL, or both");
            _auxTokenCount = token_count + _auxCounter;
            _safeMint(_to, _auxTokenCount);
            tokenURI(_auxTokenCount);
            ipfs_cids[_auxTokenCount] = _cids[i];
            new_token = TokenFeatures(payable(address(0)), payable(ownerOf(_auxTokenCount)), _auxTokenCount, 0, _cids[i], setURI(baseURI, _cids[i]));
            token_prices[_auxTokenCount] = new_token.token_price;
            token_v.push(new_token);
            emit newToken(_to, _auxTokenCount);
            _auxCounter++;
        }
        token_count += _auxCounter;
        _auxCounter = 0;
        _auxTokenCount = 0;
       return (_amount, token_count);
    }

    function _buy1Token(uint256 tokenId) public payable validId(tokenId) {
        require(token_v[tokenId].token_price != 0, "At least one of the tokens is not for sale");
        require(keccak256(abi.encodePacked(getApproved(tokenId))) == keccak256(abi.encodePacked(msg.sender)) == true, "Invalid operation. You don't have the needed permission");
        require(msg.value >= accepted_offers[tokenId].offer, "The funds provided are lower than the offer you made");
        address newOwner = msg.sender;
        token_v[tokenId].owner = payable(newOwner);
        address oldOwner = ownerOf(tokenId);
        token_v[tokenId].previous_owner = payable(oldOwner);
        safeTransferFrom(oldOwner, newOwner, tokenId);
        emit tokenSale(oldOwner, newOwner, tokenId);
        delete accepted_offers[tokenId];
        delete token_offers[tokenId];
        token_v[tokenId].previous_owner.transfer(token_v[tokenId].token_price);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return setURI(baseURI, ipfs_cids[tokenId]);
    }

    function mintToken(address _to, string[] memory _cids) public payable returns (uint256, uint256) {
        require(mint_price*_cids.length <= msg.value, "Not enough ether to mint your collection.");
        return _mintToken(_to, _cids);
    }

    function makeOffer(uint256 offer, uint256 tokenId) external returns (PurchaseRequest memory) {
        require(ownerOf(tokenId) != msg.sender, "The owner of the token cannot make itself an offer");
        require(msg.sender.balance >= offer, "You don't have enough funds to buy this token");
        PurchaseRequest memory aux = PurchaseRequest(offer, msg.sender, tokenId);
        token_offers[tokenId].push(aux);
        addr_offers[tokenId].push(msg.sender);
        return aux;
    }

    function buyMultipleTokens(uint256[] memory _tokenIds) external payable {
        uint256 _amount = _tokenIds.length;
        require(sumPrices(_tokenIds) >= msg.value, "The funds provided are lower than the total price of the tokens you are trying to buy");
        for (uint256 i = 0; i < _amount; i++) {
            _buy1Token(_tokenIds[i]);
        }
    }

    function burn(uint256 _tokenId) external onlyTokenOwner(_tokenId) {
        _burn(_tokenId);
    }

    // Withdraw the ethers from the Smart Contract: only the owner of the contract can execute this function
    function withdraw() external payable onlyOwner {
        address payable _owner = payable(owner()); // owner() is an internal function of Ownable. We define owner address like a payable address
        _owner.transfer(address(this).balance); // this line makes the transfer from the current contract to the owner of the contract
    }

}