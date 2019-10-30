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
        uint128 tokenId;
        uint128 newTokenPrice;
        // gas reserve
        Fraction exchangeRate;
        uint256 reserve;
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

    mapping (uint256 => NativeToken) public nativeTokens;
    mapping (address => uint256) public newTokenAuctionBalance;
    mapping (uint256 => mapping (address => uint256)) public gasReserveBalance;
    mapping (address => mapping (uint256 => uint256)) public nativeTokenBalances;

    constructor (address _supervisor, bool _allowMint) public {
        supervisor = _supervisor;
        allowMint = _allowMint;
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
            newTokenPrice >= newTokenAuction.highestBid.newTokenPrice +
                             newTokenAuctionParams.minIncrementInQKC * 1 ether,
            "Bid price should be larger than current highest bid with increment."
        );

        Bid memory bid;
        bid.tokenId = uint128(tokenId);
        bid.newTokenPrice = uint128(newTokenPrice);

        address bidder = msg.sender;
        newTokenAuctionBalance[bidder] += msg.value;
        require(newTokenAuctionBalance[bidder] >= bid.newTokenPrice, "Not enough balance to bid.");

        // Win the bid!
        newTokenAuction.highestBid = bid;
        newTokenAuction.highestBidder = bidder;

        // Extend the auction if the last bid is too close to end time.
        if (endTime - now < OVERTIME_PERIOD) {
            newTokenAuctionParams.duration += OVERTIME_PERIOD;
        }
    }

    function newTokenAuctionEnd() public {
        uint64 endTime = newTokenAuctionParams.startTime + newTokenAuctionParams.duration;
        require(now >= endTime, "Auction has not ended.");

        address highestBidder = newTokenAuction.highestBidder;
        Bid memory highestBid = newTokenAuction.highestBid;
        newTokenAuctionBalance[highestBidder] -= highestBid.newTokenPrice;
        nativeTokens[highestBid.tokenId].owner = highestBidder;

        // Set newTokenAuction to default 0
        newTokenAuction.highestBidder = address(0);
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

    function bidUtility(Bid memory bid) public payable {
        require(bid.reserve == msg.value);
        // Auction storage auction = gasReserves[bid.tokenId];
        // bid(auction, bid, msg.sender);
        // gasReserveAuctionBalance[msg.sender][bid.tokenId] += msg.value;
    }

    function withdrawGasReserve(uint256 tokenId) public {
        require(msg.sender != gasReserves[tokenId].highestBidder);
        // uint256 amount = gasReserveAuctionBalance[msg.sender][tokenId];
        // gasReserveAuctionBalance[msg.sender][tokenId] -= amount;
        // msg.sender.transfer(amount);
    }

    function withdrawNativeToken(uint256 tokenId) public {
        uint256 amount = nativeTokenBalances[msg.sender][tokenId];
        require(amount > 0);
        // Transfer native token
        nativeTokenBalances[msg.sender][tokenId] -= amount;
        transferMNT(uint256(msg.sender), tokenId, amount);
    }

    function transferMNT(uint256 addr, uint256 tokenId, uint256 value) public returns(uint p) {
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

    function getUtilityInfo(uint256 tokenId) public view returns (uint256, uint256) {
        Auction memory auction = gasReserves[tokenId];
        Fraction memory ratio = auction.highestBid.exchangeRate;
        return (ratio.numerator, ratio.denominator);
    }

    // This function is called by miner.
    // Return equivalent QKC for a specified multi native token
    function payTokenAsUntility(uint256 tokenId, uint256 amount) public returns (uint256) {
        // Change the smart contract state first. Then return the Equivalent QKC
        // Revert if it fails.
        Auction storage auction = gasReserves[tokenId];
        address highestBidder = auction.highestBidder;
        require(highestBidder != address(0));

        Fraction memory ratio = auction.highestBid.exchangeRate;
        // Avoid overflow of uint256
        require(ratio.denominator != 0);
        require(ratio.numerator * amount >= ratio.numerator && ratio.numerator * amount >= amount);

        uint256 gasAmount = ratio.numerator * amount / ratio.denominator;
        require(gasAmount <= auction.highestBid.reserve);

        // gasReserveAuctionBalance[highestBidder][tokenId] -= gasAmount;  // commented to pass compile
        auction.highestBid.reserve -= gasAmount;
        nativeTokenBalances[highestBidder][tokenId] += amount;
        return (gasAmount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function bid(
        Auction storage auction,
        Bid memory bid,
        address bidder,
        mapping (address => uint) storage balance
    )
        private returns (bool success)
    {
    	// make sure balances have been updated
    	// compare with auction’s highest bid
        // preCheck();
        Bid memory highestBid = auction.highestBid;
        require(_compareBid(highestBid, bid));
        // balance[bid.tokenId] += bid.reserve;
        auction.highestBidder = bidder;
        auction.highestBid = bid;

        return true;
    }

    function _compareBid(Bid memory highestBid, Bid memory currentBid) private view returns (bool) {
        // compare Bid helper function
        if (highestBid.reserve < minGasReserve) {
            return true;
        }
        // Avoid overflow of uint256
        uint256 leftItem = highestBid.exchangeRate.numerator * currentBid.exchangeRate.denominator;
        uint256 rightItem = currentBid.exchangeRate.numerator * highestBid.exchangeRate.denominator;
        require(
            leftItem >= highestBid.exchangeRate.numerator &&
            leftItem >= currentBid.exchangeRate.denominator
        );
        require(
            rightItem >= currentBid.exchangeRate.numerator &&
            rightItem >= highestBid.exchangeRate.denominator
        );
        return (leftItem > rightItem);
    }
}
