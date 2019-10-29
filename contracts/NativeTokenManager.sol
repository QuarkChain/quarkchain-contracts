pragma solidity >0.4.99 <0.6.0;
pragma experimental ABIEncoderV2;


contract NativeTokenManager {

    // 5 min overtime auction extension to avoid sniping
    uint64 constant OVERTIME_PERIOD = 300;

    struct Fraction {
        uint128 numerator;
        uint128 denominator;
    }

    // Union type for auction bids (new token or gas reserve)
    struct Bid {
        // new token
        uint256 tokenId;
        uint256 newTokenPrice;
        // gas reserve
        Fraction exchangeRate;
    }

    struct Auction {
        address highestBidder;
        Bid highestBid;
    }

    struct AuctionParams {
        uint64 startTime;
        uint64 duration;
        // Following are new token auction specific
        uint64 minIncrementInQKC;
        uint64 minPriceInQKC;
    }

    struct NativeToken {
        address owner;
        uint256 totalSupply;
    }

    // Auction superviosor. Could be DAO in the future
    address public supervisor;
    // Whether to allow token auction winners to mint. Should only enable in shard 0
    bool public allowMint;

    // Parameters for new token auction
    Auction public newTokenAuction;
    AuctionParams public newTokenAuctionParams;

    mapping (uint256 => Auction) public gasReserves;
    uint256 public minGasReserve;

    mapping (uint256 => NativeToken) nativeTokens;
    mapping (address => uint256) newTokenAuctionBalance;
    mapping (uint256 => mapping (address => uint)) gasReserveBalance;
    mapping (uint256 => mapping (address => uint)) nativeTokenBalances;

    constructor (address _supervisor, bool _allowMint) public {
        supervisor = _supervisor;
        allowMint = _allowMint;
    }

    function setMinReserve(uint256 _minGasReserve) public {
        require(msg.sender == supervisor, "Only supervisor can set minGasReserve");
        minGasReserve = _minGasReserve;
    }

    function newTokenAuctionSetter(
        uint64 _minPriceInQKC,
        uint64 _minIncrementInQKC,
        uint64 _duration
    )
        public
    {
        require(msg.sender == supervisor, "Only account in whitelist can set auction details.");
        require(
            newTokenAuctionParams.startTime == 0,
            "Auction setting cannot be modified when it is ongoing."
        );
        newTokenAuctionParams.minPriceInQKC = _minPriceInQKC;
        newTokenAuctionParams.minIncrementInQKC = _minIncrementInQKC;
        newTokenAuctionParams.duration = _duration;
    }

    function newTokenAuctionStart() public {
        newTokenAuctionParams.startTime = uint64(now);
    }

    function bidNewToken(uint256 tokenId, uint256 newTokenPrice) public payable {
        require(nativeTokens[tokenId].owner == address(0), "Token should be available.");
        require(newTokenAuctionParams.startTime > 0, "Auction should be ongoing.");
        uint64 endTime = newTokenAuctionParams.startTime + newTokenAuctionParams.duration;
        require(now <= endTime, "Auction has ended.");
        require(
            newTokenPrice >= newTokenAuctionParams.minPriceInQKC * 1 ether,
            "Bid price should be larger than minimum bid price."
        );
        require(
            newTokenPrice >= newTokenAuctionBalance[newTokenAuction.highestBidder] +
                             newTokenAuctionParams.minIncrementInQKC * 1 ether,
            "Bidding price should be larger than current highest bid."
        );

        Bid memory bid;
        bid.tokenId = uint128(tokenId);
        bid.newTokenPrice = uint128(newTokenPrice);

        address bidder = msg.sender;
        // bid(newTokenAuction, bid, bidder);
        newTokenAuctionBalance[bidder] += msg.value;
        require(newTokenAuctionBalance[bidder] >= bid.newTokenPrice, "Not enough balance to bid.");

        newTokenAuction.highestBid = bid;
        newTokenAuction.highestBidder = bidder;

        if (endTime - now < OVERTIME_PERIOD) {
            newTokenAuctionParams.duration += OVERTIME_PERIOD;
        }
    }

    function newTokenAuctionEnd() public {
        uint64 endTime = newTokenAuctionParams.startTime + newTokenAuctionParams.duration;
        require(now >= endTime, "Auction should have ended.");
        Bid memory highestBid = newTokenAuction.highestBid;
        // TODO:
        // 1. deduct bid price from balance
        // 2. update new token info (owner etc)
        // 3. set newTokenAuction to default 0
        newTokenAuctionParams.startTime = 0;
    }

    function mintNewToken(uint256 tokenId) public {
        require(msg.sender == nativeTokens[tokenId].owner, "Only the owner can mint new token.");
        // TODO
    }

    function transferOwnership(uint256 tokenId, address newOwner) public payable {
        require(
            msg.sender == nativeTokens[tokenId].owner,
            "Only the owner can transfer ownership."
        );
        nativeTokens[tokenId].owner = newOwner;
    }

    function withdrawTokenBid() public {
        // Those doesn't win the bid should be able to get back their funds
        // Note: losing bidders may withdraw their funds at any time, even before the action is over
        require(
            msg.sender != newTokenAuction.highestBidder,
            "Highest bidder cannot withdraw balance till the end of this auction."
        );
        // uint256 amount = nativeTokenBalances[msg.sender];
        // nativeTokenBalances[msg.sender] = 0;
        // msg.sender.transfer(amount);
    }

    function proposeNewExchangeRate(
        uint256 tokenId,
        uint128 rateNumerator,
        uint128 rateDenominator
    )
        public payable
    {
        require(rateNumerator > 0, "numerator should be a valid term");
        require(rateDenominator > 0, "denominator should be a valid term");
        require(
            rateNumerator * 21000 <= minGasReserve * rateDenominator,
            "ratio * 21000 <= minGasReserve"
        );
        Fraction memory exchangeRate;
        exchangeRate.numerator = rateNumerator;
        exchangeRate.denominator = rateDenominator;
        Bid memory currentBid;
        currentBid.tokenId = tokenId;
        currentBid.exchangeRate = exchangeRate;

        require(
            gasReserveBalance[tokenId][msg.sender] +
            msg.value >= minGasReserve, "should have amount >= minimum"
        );
        Auction storage auction = gasReserves[tokenId];
        mapping (address => uint) storage balance = gasReserveBalance[tokenId];
        Bid memory highestBid = auction.highestBid;
        require(
            gasReserveBalance[tokenId][auction.highestBidder] < minGasReserve ||
            isHigher(highestBid, currentBid), "not allowed if it is lower ratio"
        );
        uint256 newBalance = balance[msg.sender] + msg.value;
        require(newBalance >= msg.value, "should be a valid term");
        balance[msg.sender] = newBalance;
        auction.highestBidder = msg.sender;
        auction.highestBid = currentBid;
    }

    function depositGasReserve(uint256 tokenId) public payable {
        require(gasReserveBalance[tokenId][msg.sender] > 0, "should be an exited token");
        uint256 newBalance = gasReserveBalance[tokenId][msg.sender] + msg.value;
        require(newBalance >= msg.value, "should be a valid term");
        gasReserveBalance[tokenId][msg.sender] = newBalance;
    }

    function withdrawGasReserve(uint256 tokenId) public {
        require(
            msg.sender != gasReserves[tokenId].highestBidder,
            "not allowed when highest bidder"
        );
        uint256 amount = gasReserveBalance[tokenId][msg.sender];
        require(amount > 0, "should be a valid account");
        gasReserveBalance[tokenId][msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function withdrawNativeToken(uint256 tokenId) public {
        uint256 amount = nativeTokenBalances[tokenId][msg.sender];
        require(amount > 0, "should be a valid account");
        // Transfer native token
        nativeTokenBalances[tokenId][msg.sender] = 0;
        transferMNT(uint256(msg.sender), tokenId, amount);
    }

    function getUtilityInfo(uint256 tokenId) public view returns (uint256, uint256) {
        Auction memory auction = gasReserves[tokenId];
        Fraction memory ratio = auction.highestBid.exchangeRate;
        return (ratio.numerator, ratio.denominator);
    }

    // Return equivalent QKC for a specified multi native token
    function payAsGasUtility(uint256 tokenId, uint256 amount) public returns (uint256) {
        // Change the smart contract state first. Then return the Equivalent QKC
        // Revert if it fails.
        Auction storage auction = gasReserves[tokenId];
        address highestBidder = auction.highestBidder;
        require(highestBidder != address(0), "should be a valid token");

        Fraction memory ratio = auction.highestBid.exchangeRate;
        // Avoid overflow of uint256
        require(ratio.denominator > 0, "denominator non-zero");
        require(
            ratio.numerator * amount >= ratio.numerator &&
            ratio.numerator * amount >= amount, "avoid overflow of uint256"
        );

        uint256 gasAmount = ratio.numerator * amount / ratio.denominator;
        require(
            gasAmount <= gasReserveBalance[tokenId][highestBidder],
            "should have amount >= gasAmount"
        );

        gasReserveBalance[tokenId][highestBidder] -= gasAmount;
        nativeTokenBalances[tokenId][highestBidder] += amount;
        return (gasAmount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function isHigher(
        Bid memory highestBid,
        Bid memory currentBid
    ) private pure returns (bool)
    {
        // compare Bid helper function
        if (highestBid.exchangeRate.numerator == 0) {
            return true;
        }
        require(currentBid.exchangeRate.numerator > 0, "not allowed for zero ratio");
        // Avoid overflow of uint256
        uint256 leftItem = highestBid.exchangeRate.numerator * currentBid.exchangeRate.denominator;
        uint256 rightItem = currentBid.exchangeRate.numerator * highestBid.exchangeRate.denominator;
        require(
            leftItem >= highestBid.exchangeRate.numerator, "avoid overflow of uint256"
        );
        require(
            rightItem >= currentBid.exchangeRate.numerator, "avoid overflow of uint256"
        );
        return (rightItem > leftItem);
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