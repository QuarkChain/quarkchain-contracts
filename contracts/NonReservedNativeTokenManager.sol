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

    function bidNewToken(uint128 tokenId, uint128 newTokenPrice) public payable {
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
