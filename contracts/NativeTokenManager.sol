pragma solidity >0.4.99 <0.6.0;
pragma experimental ABIEncoderV2;


contract NativeTokenManager {

    struct Fraction {
        uint256 numerator;
        uint256 denominator;
    }

    struct Bid {
        // new token
        uint256 tokenId;
        uint256 newTokenPrice;
        Fraction exchangeRate;
    }

    struct Auction {
        address highestBidder;
        Bid highestBid;
        Bid minBid;  // for new token, compare w/ price; for gas reserve, compare w/ reserve
        uint256 minIncrement;
        uint256 overtimePeriod;
        uint256 overtimeLimit;
        uint256 endTime;
        uint256 hardEndTime;
    }

    struct NativeToken {
        address owner;
        uint256 totalSupply;
    }

    Auction newTokenAuction;
    uint256 auctionPeriod;
    uint256 longestPeriod;

    mapping (uint256 => Auction) gasReserveAuctions;
    uint256 minBidReserve;
    uint256 minReserve;

    mapping (uint256 => NativeToken) nativeTokens;
    mapping (address => uint256) newTokenAuctionBalance;
    mapping (uint256 => mapping (address => uint)) gasReserveAuctionBalance;
    mapping (uint256 => mapping (address => uint)) nativeTokenBalances;

    constructor (
        uint256 _minTokenAuctionPrice,
        uint256 _minIncrement,
        uint256 _overtimePeriod,
        uint256 _overtimeLimit
    ) public {
        newTokenAuction.minBid.newTokenPrice = _minTokenAuctionPrice;
        newTokenAuction.minIncrement = _minIncrement;
        newTokenAuction.overtimePeriod = _overtimePeriod;
        newTokenAuction.overtimeLimit = _overtimeLimit;
    }

    function newTokenAuctionStart() public {
        // set end time
        newTokenAuction.hardEndTime = now + newTokenAuction.overtimeLimit;
        newTokenAuction.endTime = now + newTokenAuction.overtimePeriod;
    }

    function bidNewToken(Bid memory bid) public payable {
        // pre check
        if (nativeTokens[bid.tokenId].owner != address(0)) {
            revert();
        }
        require(now < newTokenAuction.endTime);
        require(bid.newTokenPrice >= newTokenAuction.minBid.newTokenPrice);
        require(
            bid.newTokenPrice >= newTokenAuctionBalance[newTokenAuction.highestBidder] +
                                 newTokenAuction.minIncrement
        );

        address bidder = msg.sender;
        // bid(newTokenAuction, bid, bidder);
        newTokenAuctionBalance[bidder] += msg.value;
        require(newTokenAuctionBalance[bidder] >= bid.newTokenPrice);

        newTokenAuction.highestBid = bid;
        newTokenAuction.highestBidder = bidder;

        newTokenAuction.endTime = min(
            now + newTokenAuction.overtimePeriod, newTokenAuction.hardEndTime
        );
    }

    function newTokenAuctionEnd() public {
        require(now >= newTokenAuction.endTime);
        Bid memory highestBid = newTokenAuction.highestBid;
        // TODO:
        // 1. deduct bid price from balance
        // 2. update new token info (owner etc)
        // 3. set newTokenAuction to default 0
    }

    function mintNewToken(uint256 tokenId) public {
        require(msg.sender == nativeTokens[tokenId].owner);
        // TODO
    }

    function transferOwnership(uint256 tokenId, address newOwner) public payable {
        require(msg.sender == nativeTokens[tokenId].owner);
        nativeTokens[tokenId].owner = newOwner;
    }

    function withdrawTokenBid() public {
        // Those doesn't win the bid should be able to get back their funds
        // Note: losing bidders may withdraw their funds at any time, even before the action is over
        require(msg.sender != newTokenAuction.highestBidder);
        // uint256 amount = nativeTokenBalances[msg.sender];
        // nativeTokenBalances[msg.sender] = 0;
        // msg.sender.transfer(amount);
    }
    
    function proposeNewExchangeRate(
        uint256 tokenId,
        uint256 rateNumerator,
        uint256 rateDenominator
    )
        public payable
    {
        require(rateNumerator < 10^21);
        require(rateNumerator > 0);
        require(rateDenominator > 0);
        Fraction memory exchangeRate;
        exchangeRate.numerator = rateNumerator;
        exchangeRate.denominator = rateDenominator;
        Bid memory currentBid;
        currentBid.tokenId = tokenId;
        currentBid.exchangeRate = exchangeRate;

        require(gasReserveAuctionBalance[tokenId][msg.sender] + msg.value > minBidReserve);
        Auction storage auction = gasReserveAuctions[currentBid.tokenId];
        mapping (address => uint) storage balance = gasReserveAuctionBalance[currentBid.tokenId];
        Bid memory highestBid = auction.highestBid;
        require(compareBid(highestBid, currentBid, auction.highestBidder));
        balance[msg.sender] += msg.value;
        auction.highestBidder = msg.sender;
        auction.highestBid = currentBid;
    }

    function depositGasReserve(uint256 tokenId) public payable {
        gasReserveAuctionBalance[tokenId][msg.sender] += msg.value;
    }

    function withdrawGasReserve(uint256 tokenId) public {
        require(msg.sender != gasReserveAuctions[tokenId].highestBidder);
        uint256 amount = gasReserveAuctionBalance[tokenId][msg.sender];
        gasReserveAuctionBalance[tokenId][msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function withdrawNativeToken(uint256 tokenId) public {
        uint256 amount = nativeTokenBalances[tokenId][msg.sender];
        require(amount > 0);
        // Transfer native token
        nativeTokenBalances[tokenId][msg.sender] = 0;
        transferMNT(uint256(msg.sender), tokenId, amount);
    }
    
    function getUtilityInfo(uint256 tokenId) public view returns (uint256, uint256) {
        Auction memory auction = gasReserveAuctions[tokenId];
        Fraction memory ratio = auction.highestBid.exchangeRate;
        return (ratio.numerator, ratio.denominator);
    }

    // Return equivalent QKC for a specified multi native token
    function payTokenAsUtility(uint256 tokenId, uint256 amount) public returns (uint256) {
        // Change the smart contract state first. Then return the Equivalent QKC
        // Revert if it fails.
        Auction storage auction = gasReserveAuctions[tokenId];
        address highestBidder = auction.highestBidder;
        require(highestBidder != address(0));

        Fraction memory ratio = auction.highestBid.exchangeRate;
        // Avoid overflow of uint256
        require(ratio.denominator > 0);
        require(ratio.numerator * amount >= ratio.numerator && ratio.numerator * amount >= amount);

        uint256 gasAmount = ratio.numerator * amount / ratio.denominator;
        require(gasAmount <= gasReserveAuctionBalance[tokenId][highestBidder]);

        gasReserveAuctionBalance[tokenId][highestBidder] -= gasAmount;
        nativeTokenBalances[tokenId][highestBidder] += amount;
        return (gasAmount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function compareBid(
        Bid memory highestBid,
        Bid memory currentBid,
        address highestBidder
    ) private view returns (bool) 
    {
        // compare Bid helper function
        if (gasReserveAuctionBalance[highestBid.tokenId][highestBidder] < minReserve ||
             highestBid.exchangeRate.numerator == 0) {
            return true;
        }
        require(currentBid.exchangeRate.numerator > 0);
        // Avoid overflow of uint256
        uint256 leftItem = highestBid.exchangeRate.numerator * currentBid.exchangeRate.denominator;
        uint256 rightItem = currentBid.exchangeRate.numerator * highestBid.exchangeRate.denominator;
        require(
            leftItem / highestBid.exchangeRate.numerator == 
            currentBid.exchangeRate.denominator
        );
        require(
            rightItem / currentBid.exchangeRate.numerator == 
            highestBid.exchangeRate.denominator
        );
        return (leftItem > rightItem);
    }
    
    function transferMNT(uint256 addr, uint256 tokenId, uint256 value) private returns (uint p) {
        uint256[3] memory input;
        input[0] = addr;
        input[1] = tokenId;
        input[2] = value;
        /* solium-disable-next-line */
        assembly {
           if iszero(call(not(0), 0x514b430002, 0, input, 0x60, p, 0x20)){
               revert(0, 0)
           }
        }
    }
}