pragma solidity >0.4.99 <0.6.0;
pragma experimental ABIEncoderV2;


contract NonReservedNativeTokenManager {

    // 5 min overtime auction extension to avoid sniping
    uint64 constant OVERTIME_PERIOD = 300;

    // Union type for auction bids (new token or gas reserve)
    struct Bid {
        // new token
        uint128 tokenId;
        uint128 newTokenPrice;
    }

    struct Auction {
        address highestBidder;
        Bid highestBid;
    }

    struct AuctionParams {
        uint64 startTime;
        uint64 duration;
        uint64 overtime;
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

    mapping (uint128 => Auction) public gasReserves;
    uint256 public minGasReserve;

    mapping (uint128 => NativeToken) public nativeTokens;
    mapping (address => uint256) public newTokenAuctionBalance;
    mapping (uint128 => mapping (address => uint256)) public gasReserveBalance;
    mapping (uint128 => mapping (address => uint256)) public nativeTokenBalances;

    event AuctionEnded(
        address winner,
        uint128 newTokenId
    );

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

    function bidNewToken(uint128 tokenId, uint128 newTokenPrice) public payable {
        require(nativeTokens[tokenId].owner == address(0), "Token should be available.");

        if (newTokenAuctionParams.startTime == 0) {
            // Auction hasn't started. Start now.
            newTokenAuctionParams.startTime = uint64(now);
        } else if (uint64(now) > newTokenAuctionParams.startTime + newTokenAuctionParams.duration +
                   newTokenAuctionParams.overtime) {
            // End last round of auction.
            newTokenAuctionEnd();
            // Start a new round of auction.
            newTokenAuctionParams.startTime = uint64(now);
        }
        uint64 endTime = newTokenAuctionParams.startTime +
            newTokenAuctionParams.duration + newTokenAuctionParams.overtime;

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
        uint256 newBalance = newTokenAuctionBalance[bidder] + msg.value;
        require(newBalance >= msg.value, "Addition overflow");
        newTokenAuctionBalance[bidder] = newBalance;
        require(newTokenAuctionBalance[bidder] >= bid.newTokenPrice, "Not enough balance to bid.");

        // Win the bid!
        newTokenAuction.highestBid = bid;
        newTokenAuction.highestBidder = bidder;

        // Extend the auction if the last bid is too close to end time.
        if (endTime - now < OVERTIME_PERIOD) {
            newTokenAuctionParams.overtime += OVERTIME_PERIOD;
        }
    }

    function newTokenAuctionEnd() public {
        uint64 endTime = newTokenAuctionParams.startTime +
            newTokenAuctionParams.duration + newTokenAuctionParams.overtime;
        require(now >= endTime, "Auction has not ended.");

        address highestBidder = newTokenAuction.highestBidder;
        Bid memory highestBid = newTokenAuction.highestBid;
        newTokenAuctionBalance[highestBidder] -= highestBid.newTokenPrice;
        nativeTokens[highestBid.tokenId].owner = highestBidder;
        emit AuctionEnded(highestBidder, highestBid.tokenId);

        // Set newTokenAuction to default 0
        newTokenAuction.highestBidder = address(0);
        newTokenAuctionParams.startTime = 0;
        newTokenAuctionParams.overtime = 0;
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
}
