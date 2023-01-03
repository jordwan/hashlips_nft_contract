
                        
/*
 /$$$$$$$$                                /$$$$$$                  /$$           /$$   /$$ /$$$$$$$$ /$$$$$$$$
|_____ $$                                /$$__  $$                | $$          | $$$ | $$| $$_____/|__  $$__/
     /$$/   /$$$$$$   /$$$$$$   /$$$$$$ | $$  \__/  /$$$$$$   /$$$$$$$  /$$$$$$ | $$$$| $$| $$         | $$
    /$$/   /$$__  $$ /$$__  $$ /$$__  $$| $$       /$$__  $$ /$$__  $$ /$$__  $$| $$ $$ $$| $$$$$      | $$
   /$$/   | $$$$$$$$| $$  \__/| $$  \ $$| $$      | $$  \ $$| $$  | $$| $$$$$$$$| $$  $$$$| $$__/      | $$
  /$$/    | $$_____/| $$      | $$  | $$| $$    $$| $$  | $$| $$  | $$| $$_____/| $$\  $$$| $$         | $$
 /$$$$$$$$|  $$$$$$$| $$      |  $$$$$$/|  $$$$$$/|  $$$$$$/|  $$$$$$$|  $$$$$$$| $$ \  $$| $$         | $$
|________/ \_______/|__/       \______/  \______/  \______/  \_______/ \_______/|__/  \__/|__/         |__/

Drop Your NFT Collection With ZERO Coding Skills at https://zerocodenft.com
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

contract SquirrelyMonz is ERC721A, Ownable, DefaultOperatorFilterer {
    enum SaleStatus{ PAUSED, PRESALE, PUBLIC }

    uint public constant COLLECTION_SIZE = 7500;
    uint public constant FIRSTXFREE = 1;
    uint public constant TOKENS_PER_TRAN_LIMIT = 10;
    uint public constant TOKENS_PER_PERSON_PUB_LIMIT = 20;
    uint public constant TOKENS_PER_PERSON_WL_LIMIT = 10;
    uint public constant PRESALE_MINT_PRICE = 0 ether;
    uint public MINT_PRICE = 0.001 ether;
    SaleStatus public saleStatus = SaleStatus.PAUSED;
    bytes32 public merkleRoot;
    string private _baseURL;
    string public preRevealURL = "ipfs://QmdaWN3TtT1UTGssGuoTo7SvpRQtLs7ADaX1h5jgSMHFCu";
    mapping(address => uint) private _mintedCount;
    mapping(address => uint) private _whitelistMintedCount;

    constructor() ERC721A("SquirrelyMonz", "SQMZ"){}
    
    
    function contractURI() public pure returns (string memory) {
        return "data:application/json;base64,eyJuYW1lIjoiU3F1aXJyZWx5TW9uenoiLCJkZXNjcmlwdGlvbiI6IlRoZSBTcXVpcnJlbHlNb256IGFyZSBhIGdyb3VwIG9mIHNxdWlycmVscyB3aG8gbmVzdCBjbG9zZSB0byBhIG51Y2xlYXIgcGxhbnQuIFRoZXkgYXJlIGFsd2F5cyBoYXBweSBhbmQgZW5lcmdldGljLCBhbmQgdGhleSBsb3ZlIHRvIHBsYXkgYW5kIGV4cGxvcmUgdGhlaXIgc3Vycm91bmRpbmdzLiBXaGF0IHdpbGwgdGhlc2UgZXZvbHZlIGludG8uLi4/IiwiZXh0ZXJuYWxfdXJsIjpudWxsLCJmZWVfcmVjaXBpZW50IjoiMHg4QTkyMTY5MjRGOTIzMDEyOWNlMTUxMmEyZWQ5ODc1NTQ4NzhBZjVGIiwic2VsbGVyX2ZlZV9iYXNpc19wb2ludHMiOjI1MH0=";
    }
    
    /// @notice Update the merkle tree root
    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
    }
    
    /// @notice Reveal metadata for all the tokens
    function reveal(string calldata url) external onlyOwner {
        _baseURL = url;
    }
    
     /// @notice Set Pre Reveal URL
    function setPreRevealUrl(string calldata url) external onlyOwner {
        preRevealURL = url;
    }
    

    /// @dev override base uri. It will be combined with token ID
    function _baseURI() internal view override returns (string memory) {
        return _baseURL;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Update current sale stage
    function setSaleStatus(SaleStatus status) external onlyOwner {
        saleStatus = status;
    }

    /// @notice Update public mint price
    function setPublicMintPrice(uint price) external onlyOwner {
        MINT_PRICE = price;
    }

    /// @notice Withdraw contract balance
    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        require(balance &gt; 0, "No balance");
        payable(owner()).transfer(balance);
    }

    /// @notice Allows owner to mint tokens to a specified address
    function airdrop(address to, uint count) external onlyOwner {
        require(_totalMinted() + count &lt;= COLLECTION_SIZE, "Request exceeds collection size");
        _safeMint(to, count);
    }

    /// @notice Get token URI. In case of delayed reveal we give user the json of the placeholer metadata.
    /// @param tokenId token ID
    function tokenURI(uint tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();

        return bytes(baseURI).length &gt; 0 
            ? string(abi.encodePacked(baseURI, "/", _toString(tokenId), ".json")) 
            : preRevealURL;
    }
    
    function calcTotal(uint count) public view returns(uint) {
        require(saleStatus != SaleStatus.PAUSED, "SquirrelyMonz: Sales are off");

        
        require(msg.sender != address(0));
        uint totalMintedCount = _whitelistMintedCount[msg.sender] + _mintedCount[msg.sender];

        if(FIRSTXFREE &gt; totalMintedCount) {
            uint freeLeft = FIRSTXFREE - totalMintedCount;
            if(count &gt; freeLeft) {
                // just pay the difference
                count -= freeLeft;
            }
            else {
                count = 0;
            }
        }

        
        uint price = saleStatus == SaleStatus.PRESALE 
            ? PRESALE_MINT_PRICE 
            : MINT_PRICE;

        return count * price;
    }
    
    
    function redeem(bytes32[] calldata merkleProof, uint count) external payable {
        require(saleStatus != SaleStatus.PAUSED, "SquirrelyMonz: Sales are off");
        require(_totalMinted() + count &lt;= COLLECTION_SIZE, "SquirrelyMonz: Number of requested tokens will exceed collection size");
        require(count &lt;= TOKENS_PER_TRAN_LIMIT, "SquirrelyMonz: Number of requested tokens exceeds allowance (10)");
        require(msg.value &gt;= calcTotal(count), "SquirrelyMonz: Ether value sent is not sufficient");
        if(saleStatus == SaleStatus.PRESALE) {
            require(_whitelistMintedCount[msg.sender] + count &lt;= TOKENS_PER_PERSON_WL_LIMIT, "SquirrelyMonz: Number of requested tokens exceeds allowance (10)");
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "SquirrelyMonz: You are not whitelisted");
            _whitelistMintedCount[msg.sender] += count;
        }
        else {
            require(_mintedCount[msg.sender] + count &lt;= TOKENS_PER_PERSON_PUB_LIMIT, "SquirrelyMonz: Number of requested tokens exceeds allowance (20)");
            _mintedCount[msg.sender] += count;
        }
        _safeMint(msg.sender, count);
    }
    
    /// @notice DefaultOperatorFilterer OpenSea overrides    
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public payable override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        payable
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}

                    