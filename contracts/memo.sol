/**
    * @dev Creates or Updates condition for lending a NFT.
    */ 
    function updateCondition(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _feePerDay,
        uint256 _lendLimitDate,
        uint16 _minimumPeriod,
        uint16 _affiliateReward
    ) public isApprovedOrOwner(_tokenAddress, _tokenId) {
        _checkApproval(_tokenAddress, _tokenId);
        require(
            _affiliateReward < 1000 - protocolFee,
            "Affiliate reward exceeds the limit."
        );
        require(
            IERC4907(_tokenAddress).userExpires(_tokenId) < _lendLimitDate,
            "_lendLimitDate must be after the current expire date"
        );
        getCondition[_tokenAddress][_tokenId] = Condition(
            _feePerDay,
            _lendLimitDate,
            _minimumPeriod,
            _affiliateReward
        );
    }

    /**
    * @dev Lends NFT to a users.
    */ 
    function borrowNFT(
        address _affiliate,
        address _tokenAddress,
        uint256 _tokenId,
        uint16 _days
    ) public payable {
        _checkApproval(_tokenAddress, _tokenId);
        Condition memory condition = getCondition[_tokenAddress][_tokenId];
        require(
            msg.value == condition.feePerDay * _days,
            "ETH value does not match the fee."
        );
        require(
            block.timestamp + (_days * 1 days) < condition.lendLimitDate,
            "It exceeds the rental available date."
        );
        IERC4907 token = IERC4907(_tokenAddress);
        require(
            token.userExpires(_tokenId) < block.timestamp,
            "Someone else is currently renting this NFT."
        );
        token.setUser(_tokenId, _msgSender(), uint64(block.timestamp + (_days * 1 days)));
        uint256 fee1 = msg.value * protocolFee / 1000;
        uint256 fee2 = msg.value * condition.affiliateReward / 1000;
        protocolBalance = protocolBalance + fee1;
        getAffiliateBalance[_affiliate] = getAffiliateBalance[_affiliate] + fee2;
        getTokenBalance[_tokenAddress][_tokenId] = getTokenBalance[_tokenAddress][_tokenId] + (msg.value - fee1 - fee2);
    }

    /**
    * @dev Lets current borrower extend the expire date.
    */ 
    function extendRental(
        address _affiliate,
        address _tokenAddress,
        uint256 _tokenId,
        uint16 _days
    ) public payable {
        _checkApproval(_tokenAddress, _tokenId);
        Condition memory condition = getCondition[_tokenAddress][_tokenId];
        require(
            msg.value == condition.feePerDay * _days,
            "ETH value does not match the fee."
        );
        IERC4907 token = IERC4907(_tokenAddress);
        require(
            token.userOf(_tokenId) == _msgSender(),
            "Only the current borrower could call this function."
        );
        require(
            token.userExpires(_tokenId) + (_days * 1 days) < condition.lendLimitDate,
            "It exceeds the rental available date."
        );
        token.setUser(_tokenId, _msgSender(), uint64(token.userExpires(_tokenId) + (_days * 1 days)));
        uint256 fee1 = msg.value * protocolFee / 1000;
        uint256 fee2 = msg.value * condition.affiliateReward / 1000;
        protocolBalance = protocolBalance + fee1;
        getAffiliateBalance[_affiliate] = getAffiliateBalance[_affiliate] + fee2;
        getTokenBalance[_tokenAddress][_tokenId] = getTokenBalance[_tokenAddress][_tokenId] + (msg.value - fee1 - fee2);
    }

    /**
    * @dev Sends the token's ETH balance to its owner.
    */ 
    function claimTokenBalance(
        address _tokenAddress,
        uint256 _tokenId
    ) public isApprovedOrOwner(_tokenAddress, _tokenId) {
        uint256 amount = getTokenBalance[_tokenAddress][_tokenId];
        getTokenBalance[_tokenAddress][_tokenId] = 0;
        payable(IERC4907(_tokenAddress).ownerOf(_tokenId)).transfer(amount);
    }

    /**
    * @dev Sends the affiliates ETH balance to its owner.
    */ 
    function claimAffiliateBalance() public {
        uint256 amount = getAffiliateBalance[_msgSender()];
        getAffiliateBalance[_msgSender()] = 0;
        payable(_msgSender()).transfer(amount);
    }


    /***
    *
    * Private Functions
    *
    ***/

    function _checkApproval(address _tokenAddress, uint256 _tokenId) private view {
        IERC4907 token = IERC4907(_tokenAddress);
        require(
            token.getApproved(_tokenId) == address(this) || 
            token.isApprovedForAll(_msgSender(), address(this)) == true,
            "Owner has not approved this protocol to lend the NFT."
        );
    }
}