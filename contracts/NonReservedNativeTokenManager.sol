pragma solidity >0.4.99 <0.6.0;
pragma experimental ABIEncoderV2;


contract NonReservedNativeTokenManager {

    // 5 min overtime auction extension to avoid sniping
    uint64 constant OVERTIME_PERIOD = 300;

    struct Bid {
        uint128 tokenId;
        uint128 newTokenPrice;
        address bidder;
    }

    struct Auction {
        uint64 round;
        uint64 overtime;
        uint128 startTime;
        Bid highestBid;
    }

    struct AuctionParams {
        uint128 duration;
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

    Auction public auction;
    AuctionParams public auctionParams;

    mapping (uint128 => NativeToken) public nativeTokens;
    mapping (address => uint256) public balance;

    event AuctionEnded(
        address winner,
        uint128 newTokenId
    );

    constructor (address _supervisor, bool _allowMint) public {
        supervisor = _supervisor;
        allowMint = _allowMint;
    }

    function setAuctionParams(
        uint64 _minPriceInQKC,
        uint64 _minIncrementInQKC,
        uint64 _duration
    )
        public
    {
        require(msg.sender == supervisor, "Only account in whitelist can set auction details.");
        require(
            auction.startTime == 0,
            "Auction setting cannot be modified when it is ongoing."
        );
        auctionParams.minPriceInQKC = _minPriceInQKC;
        auctionParams.minIncrementInQKC = _minIncrementInQKC;
        auctionParams.duration = _duration;
    }

    function bidNewToken(uint128 tokenId, uint128 price, uint64 round) public payable {
        if (auction.startTime == 0) {
            // Auction hasn't started. Start now
            auction.startTime = uint64(now);
        } else if (uint64(now) > auction.startTime + auctionParams.duration +
                   auction.overtime) {
            // End last round of auction, such that stale round will be rejected
            endAuction();
            // Start a new round of auction
            auction.startTime = uint64(now);
        }

        require(nativeTokens[tokenId].owner == address(0), "Token Id already exists");
        require(
            round == auction.round,
            "Target round of auction has ended or not started."
        );

        uint128 endTime = auction.startTime +
            auctionParams.duration + auction.overtime;

        require(
            price >= auctionParams.minPriceInQKC * 1 ether,
            "Bid price should be larger than minimum bid price."
        );
        require(
            price >= auction.highestBid.newTokenPrice +
                auctionParams.minIncrementInQKC * 1 ether,
            "Bid price should be larger than current highest bid with increment."
        );

        address bidder = msg.sender;
        Bid memory bid = Bid({
            tokenId: uint128(tokenId),
            newTokenPrice: uint128(price),
            bidder: bidder
        });
        uint256 newBalance = balance[bidder] + msg.value;
        require(newBalance >= msg.value, "Addition overflow.");
        balance[bidder] = newBalance;
        require(balance[bidder] >= bid.newTokenPrice, "Not enough balance to bid.");

        // Win the bid!
        auction.highestBid = bid;

        // Extend the auction if the last bid is too close to end time.
        if (endTime - now < OVERTIME_PERIOD) {
            auction.overtime += OVERTIME_PERIOD;
        }
    }

    function endAuction() public {
        uint128 endTime = auction.startTime +
            auctionParams.duration + auction.overtime;
        require(now >= endTime, "Auction has not ended.");

        require(
            balance[auction.highestBid.bidder] >= auction.highestBid.newTokenPrice,
            "Should have enough balance."
        );
        balance[auction.highestBid.bidder] -= auction.highestBid.newTokenPrice;
        nativeTokens[auction.highestBid.tokenId].owner = auction.highestBid.bidder;
        emit AuctionEnded(auction.highestBid.bidder, auction.highestBid.tokenId);

        // Set auction to default values
        auction.highestBid.newTokenPrice = 0;
        auction.highestBid.bidder = address(0);
        auction.startTime = 0;
        auction.overtime = 0;

        // Auction counter increasement
        auction.round += 1;
    }

    function mintNewToken(uint128 tokenId) public {
        require(msg.sender == nativeTokens[tokenId].owner, "Only the owner can mint new token.");
        // TODO
    }

    function transferOwnership(uint128 tokenId, address newOwner) public payable {
        require(
            msg.sender == nativeTokens[tokenId].owner,
            "Only the owner can transfer ownership."
        );
        nativeTokens[tokenId].owner = newOwner;
    }

    function withdraw() public {
        // Those doesn't win the bid should be able to get back their funds
        // Note: losing bidders may withdraw their funds at any time, even before the action is over
        require(
            msg.sender != auction.highestBid.bidder,
            "Highest bidder cannot withdraw balance till the end of this auction."
        );

        uint256 amount = balance[msg.sender];
        require(amount > 0, "No balance available to withdraw.");
        balance[msg.sender] = 0;
        msg.sender.transfer(amount);
    }
}
