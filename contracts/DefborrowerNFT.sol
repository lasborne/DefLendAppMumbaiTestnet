// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

string constant name = "DefborrowerNFT";
string constant symbol = "DFLB";

contract DefborrowerNFT is ERC721(name, symbol){
    //The library of String operations and used here for uint256
    using Strings for uint256;
    
    //Total Supply of the NFTs, updated only after function mintAll is called
    uint256 public totalSupply;

    //Smart Contract Deployer
    address owner;

    // Struct holding NFT's tokenId and uri
    struct AllMints {
        address _borrower;
        uint256 _tokenId;
        string _uri;
    }

    // Variable for storing user-defined data type struct
    AllMints saveMint;
    // Array containing user-defined variables of data type struct
    AllMints[] saveMints;

    // This function runs only once at the beginning and running of the contract
    constructor() {
        owner = msg.sender;
    }

    // This enforces that the msg.sender must be same address as the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, 'Must be DefLend deployer');
        _;
    }

    event Mint(address indexed _to, uint256 _tokenId, string _tokenURI);

    // An Internal function overriding the parent function _baseURI() from ERC721 for
    // returning the base URI unto which tokenId is added to give URL of each NFT
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/Deflend-borrower/";
    }
    
    // The publicly viewable function returning the baseURI
    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    function mint(address _to, uint256 _tokenId, bytes memory _data) external returns (bool) {
        
        //The uri i.e. IPFS storage path for the NFT
        string memory uri_ = string(
            abi.encodePacked(_baseURI(), Strings.toString(_tokenId))
        );
        // Store the tokenId, uri into the variable saveMint
        saveMint = AllMints(_to, _tokenId, uri_);
        // Store the variable saveMint (and its content) into the array saaveMints
        saveMints.push(saveMint);

        //Mint the token, update the total supply, and emit a mint event
        _safeMint(_to, _tokenId, _data);
        totalSupply++;
        emit Mint(_to, _tokenId, uri_);
            
        return true;
    }

    // Disables transfer of this NFT by overriding ERC721 transferFrom function
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {}

    // Disables approval of this NFT by overriding ERC721 approve function
    function approve(address to, uint256 tokenId) public virtual override {}

    // Disables ERC721's setApprovalForAll function
    function setApprovalForAll(address operator, bool approved) public virtual override {}

    // Returns the array of struct AllMints and all that has been stored in it
    function allMintsShow() public view returns (AllMints[] memory) {
        return saveMints;
    }

    // Burns lender's NFT after withdrawal of deposited fund
    function burn(uint256 _tokenId) external virtual {
        _burn(_tokenId);
    }
}