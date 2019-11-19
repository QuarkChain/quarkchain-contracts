pragma solidity >0.4.99 <0.6.0;


contract NonReservedNativeTokenManager {

    // 5 min overtime auction extension to avoid sniping.
    uint64 constant OVERTIME_PERIOD = 300;

    struct Bid {
        uint128 tokenId;
        uint128 newTokenPrice;
        address bidder;
    }

    struct Auction {
        bool isPaused;
        uint32 round;
        uint64 overtime;
        uint128 startTime;
        Bid highestBid;
    }

    struct AuctionParams {
        uint128 duration;
        uint64 minIncrementInPercent;
        uint64 minPriceInQKC;
    }

    struct NativeToken {
        uint64 createAt;
        address owner;
        uint256 totalSupply;
    }

    // Auction superviosor. Could be DAO in the future.
    address public supervisor;
    // Whether to allow token auction winners to mint. Should only enable in shard 0.
    bool public allowMint;

    Auction auction;
    AuctionParams public auctionParams;

    mapping (uint128 => NativeToken) public nativeTokens;
    mapping (address => uint256) public balances;

    event AuctionEnded(
        address winner,
        uint128 newTokenId
    );

    constructor (address _supervisor, bool _allowMint) public {
        supervisor = _supervisor;
        allowMint = _allowMint;

        // The contract will not work unless set up by the supervisor.
        auction.isPaused = true;
    }

    modifier onlySupervisor {
        require(msg.sender == supervisor, "Only supervisor is allowed.");
        _;
    }

    function setAuctionParams(
        uint64 _minPriceInQKC,
        uint64 _minIncrementInPercent,
        uint64 _duration
    )
        public onlySupervisor
    {
        require(
            auction.startTime == 0,
            "Auction setting cannot be modified when it is ongoing."
        );
        auctionParams.minPriceInQKC = _minPriceInQKC;
        auctionParams.minIncrementInPercent = _minIncrementInPercent;
        auctionParams.duration = _duration;
    }

    function pauseAuction() public onlySupervisor {
        auction.isPaused = true;
    }

    function resumeAuction() public onlySupervisor {
        if (canEnd()) {
            // The auction result is regarded as invalid.
            resetAuction();
        }
        auction.isPaused = false;
    }

    function getAuctionState() public view returns (uint128, uint128, address,uint64, uint128) {
        return (
            auction.highestBid.tokenId,
            auction.highestBid.newTokenPrice,
            auction.highestBid.bidder,
            auction.round,
            endTime()
        );
    }

    function getNativeTokenInfo(uint128 tokenId) public view returns (uint64, address, uint256) {
        NativeToken storage token = nativeTokens[tokenId];

        return (
            token.createAt,
            token.owner,
            token.totalSupply
        );
    }

    function isPaused() public view returns (bool) {
        return auction.isPaused;
    }

    function bidNewToken(uint128 tokenId, uint128 price, uint64 round) public payable {
        require(!auction.isPaused, "Auction is paused.");
        if (canEnd()) {
            // Automatically end last round of auction, such that stale round will be rejected.
            endAuction();
            // Start a new round of auction.
            assert(auction.startTime == 0);
        }

        if (auction.startTime == 0) {
            // Auction hasn't started. Start now.
            auction.startTime = uint128(now);
        }

        // The token id of "ZZZZ" is 1727603.
        require(
            tokenId > 1727603,
            "The length of token name MUST be larger than 4."
        );
        require(nativeTokens[tokenId].createAt == 0, "Token Id already exists");
        require(
            round == auction.round,
            "Target round of auction has ended or not started."
        );

        require(
            price >= auctionParams.minPriceInQKC * 1 ether,
            "Bid price should be larger than minimum bid price."
        );
        require(
            price >= auction.highestBid.newTokenPrice + auction.highestBid.newTokenPrice * auctionParams.minIncrementInPercent / 100,
            "Bid price should be larger than current highest bid with increment."
        );

        address bidder = msg.sender;
        Bid memory bid = Bid({
            tokenId: uint128(tokenId),
            newTokenPrice: uint128(price),
            bidder: bidder
        });
        uint256 newBalance = balances[bidder] + msg.value;
        require(newBalance >= msg.value, "Addition overflow.");
        balances[bidder] = newBalance;
        require(balances[bidder] >= bid.newTokenPrice, "Not enough balance to bid.");

        // Win the bid!
        auction.highestBid = bid;

        // Extend the auction if the last bid is too close to end time.
        uint128 remainingTime = endTime() - uint128(now);
        if (remainingTime < OVERTIME_PERIOD) {
            auction.overtime += (OVERTIME_PERIOD - uint64(remainingTime));
        }
    }

    function endAuction() public {
        require(!auction.isPaused, "Auction is paused.");
        require(canEnd(), "Auction has not ended.");
        assert (balances[auction.highestBid.bidder] >= auction.highestBid.newTokenPrice);

        balances[auction.highestBid.bidder] -= auction.highestBid.newTokenPrice;
        nativeTokens[auction.highestBid.tokenId].owner = auction.highestBid.bidder;
        nativeTokens[auction.highestBid.tokenId].createAt = uint64(now);
        emit AuctionEnded(auction.highestBid.bidder, auction.highestBid.tokenId);

        // Set auction to default values.
        resetAuction();
    }

    function mintNewToken(uint128 tokenId, uint256 amount) public {
        NativeToken storage token = nativeTokens[tokenId];
        require(token.createAt != 0, "Token ID doesn't exist.");
        require(msg.sender == token.owner, "Only the owner can mint new token.");

        token.totalSupply += amount;
        require(token.totalSupply >= amount, "Addition overflow.");

        uint256[3] memory input;
        input[0] = uint256(address(token.owner));
        input[1] = tokenId;
        input[2] = amount;
        /* solium-disable-next-line */
        assembly {
            if iszero(call(not(0), 0x514b430004, 0, input, 0x60, 0, 0)) {
                revert(0, 0)
            }
        }
    }

    function transferOwnership(uint128 tokenId, address newOwner) public payable {
        require(
            msg.sender == nativeTokens[tokenId].owner,
            "Only the owner can transfer ownership."
        );
        nativeTokens[tokenId].owner = newOwner;
    }

    function withdraw() public {
        // Those doesn't win the bid should be able to get back their funds.
        // Note: losing bidders may withdraw their funds at any time, even before the action is over.
        require(
            msg.sender != auction.highestBid.bidder,
            "Highest bidder cannot withdraw balance till the end of this auction."
        );

        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance available to withdraw.");
        balances[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function resetAuction() private {
        auction.highestBid.tokenId = 0;
        auction.highestBid.newTokenPrice = 0;
        auction.highestBid.bidder = address(0);
        auction.startTime = 0;
        auction.overtime = 0;
        auction.round += 1;
    }

    function canEnd() private view returns (bool) {
        return uint128(now) >= endTime() && auction.startTime != 0;
    }

    function endTime() private view returns (uint128) {
        return auction.startTime + auctionParams.duration + auction.overtime;
    }
}
