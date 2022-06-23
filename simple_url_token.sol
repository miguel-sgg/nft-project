//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
//implementación de ERC-721 de Open Zeppelin
import "../.deps/npm/@openzeppelin/contracts@4.6.0/access/Ownable.sol";  
import "../.deps/npm/@openzeppelin/contracts@4.6.0/token/ERC721/ERC721.sol";

contract URL_token is ERC721, Ownable {
    uint256 private token_count;
    string private baseURI;
    mapping(uint256 => string) private ipfs_cids;
    uint8 constant TOTAL_PIECES = 20;
    event newToken(address owner, uint256 token_id);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        token_count = 0;
        baseURI = _baseURI("https://ipfs.io/ipfs/");
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

    function _baseURI(string memory _newBaseURI) internal view virtual returns (string memory) {
        return _newBaseURI;
    }

    
    // Visualize the balance of the Smart Contract (ethers)
    function getContractInfo() public view returns (address, uint256) {
        address SC_addr = address(this);
        uint256  SC_balance = address(this).balance/10**18;
        return (SC_addr, SC_balance);
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

    // function of ERC721Metadata
    // A function that allows an inheriting contract to override its behavior will be marked as virtual
    // The function that overrides that base function should be marked as override
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return setURI(baseURI, ipfs_cids[tokenId]);
        //return (bytes(baseURI).length > 0 && bytes(ipfs_cids[tokenId]).length > 0) ? appendTwoStrings(baseURI, ipfs_cids[tokenId]) : "Invalid URL";
        //return uri; // esta es la URL del JSON de la imagen, no de la imagen en sí.
    }

    function mintToken(address _to, string memory _cid) public onlyOwner {
        require(stringsEquals(setURI(baseURI, _cid), "Invalid URL") == false, "Forbidden mint: not valid CID or baseURL, or both");
        token_count++;
        ipfs_cids[token_count] = _cid;
        _safeMint(_to, token_count); // acuña el NFT
        tokenURI(token_count);
    }
}