// SPDX-License-Identifier: MIT
// ATSUSHI MANDAI CRDIT Contracts

pragma solidity ^0.8.0;

import "./libraries/token/ERC4907/ERC4907.sol";
import "./libraries/token/ERC4907/IERC4907.sol";
import "./libraries/access/Ownable.sol";

/// @title NFT Lending Platform Core
/// @author Atsushi Mandai
/// @notice sample code for NFT lending platform.
contract Core is Ownable, ERC4907 {

    constructor() ERC4907("stakedNFT", "stNFT") {}

    /***
    *
    * Events
    *
    ***/

    


    /***
    *
    * VARIABLES
    *
    ***/

    /**
    * @dev {protocolFee / 1000} will be payed to the protocol.
    */
    uint16 public protocolFee;
    uint256 public protocolBalance;
    uint256 public totalSupply;

    /**
     * @Author Atsushi Mandai
     * @dev Users receive stNFT by staking ERC4907 tokens in this contract.
     * Each stNFT holds information such as lending conditions and amount earned by lending.
     */
    struct Metadata {
        address nftContract;
        uint256 nftId;
        uint256 balance;
        uint256 feePerDay;
        uint256 lendLimitDate;
        uint16 affiliateReward;
    }
    mapping(uint256 => Metadata) public getMetadata;
    mapping(address => uint256) public getAffiliateBalance;


    /***
    *
    * MODIFIERS
    *
    ***/

    /**
    * @dev Restricts the use of functions to the NFT holder.
    */

    modifier isApprovedOrOwner(address _tokenAddress, uint256 _tokenId) {
        IERC4907 token = IERC4907(_tokenAddress);
        require(
            token.ownerOf(_tokenId) == _msgSender() || 
            token.getApproved(_tokenId) == _msgSender() || 
            token.isApprovedForAll(token.ownerOf(_tokenId), _msgSender()) == true,
            "Only the owner or the approved operator could use this function."
        );
        _;
    }

    modifier onlyNFTOwner(uint256 _tokenId) {
        require(
            ownerOf(_tokenId) == _msgSender(),
            "Only the owner of staked NFT could use this function."
        );
        _;
    }


    /***
    *
    * PUBLIC GOVERNANCE FUNCTIONS
    *
    ***/

    /**
    * @dev Sets new protocolFee.
    */ 
    function setProtocolFee(uint16 _newFee) public onlyOwner {
        protocolFee = _newFee;
    }

    /**
    * @dev Sends the protocolBalance to owner of the protocol.
    */ 
    function withdraw() public onlyOwner {
        uint256 amount = protocolBalance;
        protocolBalance = 0;
        payable(_msgSender()).transfer(amount);
    }


    /***
    *
    * PUBLIC USER FUNCTIONS FOR LENDERS
    *
    ***/

    /**
     * @dev Transfers ERC4907 NFT from the owner to this contract.
     * Then mints stNFT with Metadata to the owner.
     */
    function stakeNFT(
        address _nftOwner,
        address _nftContract,
        uint256 _nftId,
        uint256 _feePerDay,
        uint256 _lendLimitDate,
        uint16 _affiliateReward
    ) public isApprovedOrOwner(_nftContract, _nftId) {
        IERC4907 nft = IERC4907(_nftContract);
        nft.transferFrom(_nftOwner, address(this), _nftId);
        _mint(_nftOwner, totalSupply);
        getMetadata[totalSupply] = Metadata(
            _nftContract,
            _nftId,
            0,
            _feePerDay,
            _lendLimitDate,
            _affiliateReward
        );
        totalSupply = totalSupply + 1;
    }

    function changeFeePerDay(
        uint256 _tokenId,
        uint256 _feePerDay
    ) public onlyNFTOwner(_tokenId) {
        getMetadata[_tokenId].feePerDay = _feePerDay;
    }

    function changeLendLimitDate(
        uint256 _tokenId,
        uint256 _lendLimitDate
    ) public onlyNFTOwner(_tokenId) {
        getMetadata[_tokenId].lendLimitDate = _lendLimitDate;
    }

    function changeAffiliateReward(
        uint256 _tokenId,
        uint16 _affiliateReward
    ) public onlyNFTOwner(_tokenId) {
        getMetadata[_tokenId].affiliateReward = _affiliateReward;
    }

    function withdrawNFT(
        uint256 _tokenId
    ) public onlyNFTOwner(_tokenId) {
        IERC4907 nft = IERC4907(getMetadata[_tokenId].nftContract);
        _burn(_tokenId);
        nft.transferFrom(
            address(this),
            ownerOf(_tokenId),
            getMetadata[_tokenId].nftId
        );
    }

    function withdrawBalance(
        uint256 _tokenId
    ) public onlyNFTOwner(_tokenId) {
        uint256 amount = getMetadata[_tokenId].balance;
        getMetadata[_tokenId].balance = 0;
        payable(ownerOf(_tokenId)).transfer(amount);
    }

} 