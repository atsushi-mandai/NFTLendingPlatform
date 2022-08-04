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
    * @dev Lending fee multiplied by {protocolFee / 1000} will be payed to the protocol.
    * Lending fee multiplied by {brokerFee / 1000} will be payed to the broker.
    */
    uint16 public protocolFee;
    uint16 public brokerFee;
    uint256 public protocolBalance;
    uint256 public totalSupply;

    /**
     * @Author Atsushi Mandai
     * @dev Users receive stNFT by staking ERC4907 tokens in this contract.
     * Each stNFT holds information such as lending conditions and amount earned by lending.
     * Lending fee multiplied by {affiliateReward / 1000} will be payed to the affiliate.
     */
    struct Metadata {
        address nftContract;
        uint256 nftId;
        uint256 balance;
        uint256 feePerDay;
        uint256 lendLimitDate;
        uint16 affiliateReward;
        bool stake;
    }
    mapping(uint256 => Metadata) public getMetadata;
    mapping(address => uint256) public getBrokerBalance;
    mapping(address => uint256) public getAffiliateBalance;
    mapping(address => uint256) public stakedNFTsByOwner;
    mapping(address => uint256) public stakedNFTsByContract;


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
    * @dev Sets new brokerFee.
    */ 
    function setbrokerFee(uint16 _newFee) public onlyOwner {
        brokerFee = _newFee;
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
            _affiliateReward,
            true
        );
        totalSupply = totalSupply + 1;
        stakedNFTsByContract[_nftContract] = stakedNFTsByContract[_nftContract] + 1;
    }

    /**
     * @dev Changes feePerDay of the staked NFT.
     */
    function changeFeePerDay(
        uint256 _tokenId,
        uint256 _feePerDay
    ) public onlyNFTOwner(_tokenId) {
        getMetadata[_tokenId].feePerDay = _feePerDay;
    }

    /**
     * @dev Changes lendLimitDate of the staked NFT.
     */
    function changeLendLimitDate(
        uint256 _tokenId,
        uint256 _lendLimitDate
    ) public onlyNFTOwner(_tokenId) {
        getMetadata[_tokenId].lendLimitDate = _lendLimitDate;
    }

    /**
     * @dev Changes affiliateReward of the staked NFT.
     */
    function changeAffiliateReward(
        uint256 _tokenId,
        uint16 _affiliateReward
    ) public onlyNFTOwner(_tokenId) {
        getMetadata[_tokenId].affiliateReward = _affiliateReward;
    }

    /**
     * @dev Lets the owner withdraw his staked NFT.
     */
    function withdrawNFT(
        uint256 _tokenId
    ) public onlyNFTOwner(_tokenId) {
        _checkUserExistance(_tokenId);
        address nftContract = getMetadata[_tokenId].nftContract;
        IERC4907 nft = IERC4907(nftContract);
        address nftOwner = ownerOf(_tokenId);
        uint256 nftId = getMetadata[_tokenId].nftId;
        getMetadata[_tokenId].stake = false;
        _burn(_tokenId);
        nft.transferFrom(
            address(this),
            nftOwner,
            nftId
        );
        stakedNFTsByContract[nftContract] = stakedNFTsByContract[nftContract] - 1;
    }

    /**
     * @dev Lets the owner claim earned balance.
     */
    function withdrawBalance(
        uint256 _tokenId
    ) public onlyNFTOwner(_tokenId) {
        uint256 amount = getMetadata[_tokenId].balance;
        getMetadata[_tokenId].balance = 0;
        payable(ownerOf(_tokenId)).transfer(amount);
    }

    /**
     * @dev Returns _tokenIds of stNFTs.
     */
    function getTokenIdsByOwner(
        address _address
    ) public view returns(uint256[] memory) {
        uint256[] memory result = new uint256[](balanceOf(_address));
        uint256 counter = 0;
        for(uint256 i = 0; i < totalSupply; i++) { 
            if(_address == ownerOf(i)) {
                result[counter] = i;
                counter = counter + 1;
            }
        }
        return result;
    }


    /***
    *
    * PUBLIC USER FUNCTIONS FOR BORROWERS
    *
    ***/

    /**
     * @dev Lets a user borrow NFT.
     */
    function borrowNFT(
        uint256 _tokenId,
        uint64 _expireDate,
        address _broker,
        address _affiliate
    ) public payable {
        require(
            _expireDate < getMetadata[_tokenId].lendLimitDate,
            "expireDate must be before lendLimitDate."
        );
        _checkUserExistance(_tokenId);
        uint256 lendFee = ((_expireDate - block.timestamp) / 60 / 60 / 24) * getMetadata[_tokenId].feePerDay;
        uint256 feeToProtocol = lendFee * protocolFee / 1000;
        uint256 feeToBroker = lendFee * brokerFee / 1000;
        uint256 feeToAffiliate = lendFee * getMetadata[_tokenId].affiliateReward / 1000;
        uint256 feeToOwner = lendFee - feeToAffiliate;
        require(
            msg.value > lendFee + feeToProtocol + feeToBroker,
            "ETH value does not match the fee."
        );
        if(feeToProtocol > 0) {
            protocolBalance = protocolBalance + feeToProtocol;
        }
        if(feeToBroker > 0) {
            getBrokerBalance[_broker] = getBrokerBalance[_broker] + feeToBroker;
        }
        if(feeToAffiliate > 0) {
            getAffiliateBalance[_affiliate] = getAffiliateBalance[_affiliate] + feeToAffiliate;
        }
        getMetadata[_tokenId].balance = getMetadata[_tokenId].balance + feeToOwner;
        ERC4907 nft = ERC4907(getMetadata[_tokenId].nftContract);
        nft.setUser(getMetadata[_tokenId].nftId, _msgSender(), _expireDate);
    }

    /**
     * @dev Returns tokenId of the stNFT.
     */
    function getTokenId(
        address _nftContract,
        uint256 _nftId
    ) public view returns(bool, uint256) {
        bool isStaked = false;
        uint256 tokenId;
        for(uint256 i = 0; i < totalSupply; i++) { 
            if(
                _nftContract == getMetadata[i].nftContract &&
                _nftId == getMetadata[i].nftId &&
                getMetadata[i].stake == true
            ) {
                isStaked = true;
                tokenId = i;
            }
        }
        return(isStaked, tokenId);
    }

    /**
     * @dev Returns tokenIds of the stNFTs.
     */
    function getTokenIdsByContract(
        address _nftContract
    ) public view returns(uint256[] memory) {
        uint256[] memory result = new uint256[](stakedNFTsByContract[_nftContract]);
        uint256 counter = 0;
        for(uint256 i = 0; i < totalSupply; i++) { 
            if(
                _nftContract == getMetadata[i].nftContract &&
                getMetadata[i].stake == true
            ) {
                result[counter] = i;
                counter = counter + 1;
            }
        }
        return result;
    }

    /**
     * @dev Returns total fee to borrow the NFT.
     */
    function getTotalFee(
        uint256 _tokenId,
        uint256 _expireDate
    ) public view returns(uint256) {
        uint256 lendFee = ((_expireDate - block.timestamp) / 60 / 60 / 24) * getMetadata[_tokenId].feePerDay;
        uint256 feeToProtocol = lendFee * protocolFee / 1000;
        uint256 feeToBroker = lendFee * brokerFee / 1000;
        return lendFee + feeToProtocol + feeToBroker;
    }


    /***
    *
    * PUBLIC USER FUNCTIONS FOR BROKERS
    *
    ***/

    /**
     * @dev Lets broker withdraw his/her balance.
     */
    function withdrawBrokerReward() public {
        uint256 balance = getBrokerBalance[_msgSender()];
        getBrokerBalance[_msgSender()] = 0;
        payable(address(this)).transfer(balance);
    }


    /***
    *
    * PUBLIC USER FUNCTIONS FOR AFFILIATES
    *
    ***/

    /**
     * @dev Lets affiliate withdraw his/her balance.
     */
    function withdrawAffiliateReward() public {
        uint256 balance = getAffiliateBalance[_msgSender()];
        getAffiliateBalance[_msgSender()] = 0;
        payable(address(this)).transfer(balance);
    }


    /***
    *
    * PRIVATE FUNCTIONS
    *
    ***/

    function _checkUserExistance(uint256 _tokenId) private view {
        ERC4907 nft = ERC4907(getMetadata[_tokenId].nftContract);
        require(
            nft.userExpires(getMetadata[_tokenId].nftId) < block.timestamp,
            "This NFT has not yet ended its rental period for users."
        );
    }

} 