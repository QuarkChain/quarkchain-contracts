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

    Auction private _auction;

    AuctionParams public auctionParams = AuctionParams({
        duration: OVERTIME_PERIOD,
        minIncrementInPercent: 1,
        minPriceInQKC: 100
    });

    mapping (uint128 => NativeToken) public nativeTokens;
    mapping (address => uint256) public balances;
    mapping (uint128 => bool) public whitelistedTokenId;

    event AuctionEnded(
        address winner,
        uint128 newTokenId
    );

    constructor (address _supervisor) public {
        supervisor = _supervisor;

        // The contract will not work unless set up by the supervisor.
        _auction.isPaused = true;

        // QKC (0x8bb0) is already created.
        nativeTokens[0x8bb0].createAt = 1;
        nativeTokens[0x8bb0].owner = address(0x1);
    }

    modifier onlySupervisor {
        require(msg.sender == supervisor, "Only supervisor is allowed.");
        _;
    }

    function updateSupervisor(address newSupervisor) public onlySupervisor {
        supervisor = newSupervisor;
    }

    function whitelistTokenId(uint128 tokenId, bool whitelisted) public onlySupervisor {
        whitelistedTokenId[tokenId] = whitelisted;
    }

    function abandonTokenId(uint128 tokenId) public onlySupervisor {
        require(nativeTokens[tokenId].createAt == 0);
        require (_auction.highestBid.tokenId != tokenId);

        nativeTokens[tokenId].createAt = uint64(now);
        nativeTokens[tokenId].owner = address(0x1);
    }

    function setAuctionParams(
        uint64 minPriceInQKC,
        uint64 minIncrementInPercent,
        uint64 duration
    )
        public onlySupervisor
    {
        require(
            _auction.startTime == 0,
            "Auction setting cannot be modified when it is ongoing."
        );
        require(duration > OVERTIME_PERIOD, "Duration should be longer than 5 minutes.");

        auctionParams.minPriceInQKC = minPriceInQKC;
        auctionParams.minIncrementInPercent = minIncrementInPercent;
        auctionParams.duration = duration;
    }

    function pauseAuction() public onlySupervisor {
        _auction.isPaused = true;
    }

    function resumeAuction() public onlySupervisor {
        if (_canEnd()) {
            // The auction result is regarded as invalid.
            _resetAuction();
        }
        _auction.isPaused = false;
    }

    function getAuctionState() public view returns (uint128, uint128, address,uint64, uint128) {
        return (
            _auction.highestBid.tokenId,
            _auction.highestBid.newTokenPrice,
            _auction.highestBid.bidder,
            _auction.round,
            _endTime()
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
        return _auction.isPaused;
    }

    function bidNewToken(uint128 tokenId, uint128 price, uint64 round) public payable {
        require(!_auction.isPaused, "Auction is paused.");
        if (_canEnd()) {
            // Automatically end last round of auction, such that stale round will be rejected.
            endAuction();
            // Start a new round of auction.
            assert(_auction.startTime == 0);
        }

        if (_auction.startTime == 0) {
            // Auction hasn't started. Start now.
            _auction.startTime = uint128(now);
        }

        _validateTokenId(tokenId);

        require(nativeTokens[tokenId].createAt == 0, "Token Id already exists");
        require(
            round == _auction.round,
            "Target round of auction has ended or not started."
        );

        require(
            price >= uint256(auctionParams.minPriceInQKC) * 1 ether,
            "Bid price should be larger than minimum bid price."
        );
        require(
            price >= _auction.highestBid.newTokenPrice + _auction.highestBid.newTokenPrice * auctionParams.minIncrementInPercent / 100,
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
        _auction.highestBid = bid;

        // Extend the auction if the last bid is too close to end time.
        uint128 remainingTime = _endTime() - uint128(now);
        if (remainingTime < OVERTIME_PERIOD) {
            _auction.overtime += (OVERTIME_PERIOD - uint64(remainingTime));
        }
    }

    function endAuction() public {
        require(!_auction.isPaused, "Auction is paused.");
        require(_canEnd(), "Auction has not ended.");
        assert (balances[_auction.highestBid.bidder] >= _auction.highestBid.newTokenPrice);

        balances[_auction.highestBid.bidder] -= _auction.highestBid.newTokenPrice;
        nativeTokens[_auction.highestBid.tokenId].owner = _auction.highestBid.bidder;
        nativeTokens[_auction.highestBid.tokenId].createAt = uint64(now);
        emit AuctionEnded(_auction.highestBid.bidder, _auction.highestBid.tokenId);

        // Set auction to default values.
        _resetAuction();
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

    function transferOwnership(uint128 tokenId, address newOwner) public {
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
            msg.sender != _auction.highestBid.bidder,
            "Highest bidder cannot withdraw balance till the end of this auction."
        );

        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance available to withdraw.");
        balances[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function _resetAuction() private {
        _auction.highestBid.tokenId = 0;
        _auction.highestBid.newTokenPrice = 0;
        _auction.highestBid.bidder = address(0);
        _auction.startTime = 0;
        _auction.overtime = 0;
        _auction.round += 1;
    }

    function _canEnd() private view returns (bool) {
        return uint128(now) >= _endTime() && _auction.startTime != 0;
    }

    function _endTime() private view returns (uint128) {
        return _auction.startTime + auctionParams.duration + _auction.overtime;
    }

    function _validateTokenId(uint128 tokenId) private view {
        if (!whitelistedTokenId[tokenId]) {
            // The token id of "ZZZZ" is 1727603.
            require(
                tokenId > 1727603,
                "The length of token name MUST be larger than 4."
            );
        }
        // The token id of "ZZZZZZZZZZZZ"
        require(tokenId <= 4873763662273663091);
    }
}
