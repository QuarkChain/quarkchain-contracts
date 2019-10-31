pragma solidity >0.4.99 <0.6.0;
pragma experimental ABIEncoderV2;


contract GeneralNativeTokenManager {

    struct Fraction {
        uint128 numerator;
        uint128 denominator;
    }

    // Gas reserve record, packed into 2 256-bit words.
    struct GasReserve {
        address admin;
        uint64 refundPercentage;
        Fraction exchangeRate;
    }

    // Required caller for using native token to pay gas in QKC.
    // Defaulting to the contract address itself will make sure the invocation can
    // only be done in consensus, while allowing mock for unit testing.
    address public payGasCaller = address(this);

    // Contract admin in early stage. Capabilities are limited and may be unset.
    address public supervisor;

    // Token ID -> gas reserves.
    mapping (uint128 => GasReserve) public gasReserves;
    // Minimum amount of QKC to maintain the gas utility.
    uint256 public minGasReserveMaintain;
    // Minimum amount of QKC to start functioning as gas reserve.
    uint256 public minGasReserveInit;

    // Balance accounting: token ID -> token admin -> QKC balance.
    mapping (uint128 => mapping (address => uint256)) public gasReserveBalance;
    // Token ID -> token admin -> native token balance.
    mapping (uint128 => mapping (address => uint256)) public nativeTokenBalance;

    constructor (address _supervisor) public {
        supervisor = _supervisor;
    }

    function setMinGasReserve(
        uint256 _minGasReserveMaintain,
        uint256 _minGasReserveInit
    ) public
    {
        require(msg.sender == supervisor, "Only supervisor can set min gas reserve.");
        minGasReserveMaintain = _minGasReserveMaintain;
        minGasReserveInit = _minGasReserveInit;
    }

    // Should only be for testing, otherwise no incentive to change.
    function setCaller(address _payGasCaller) public {
        require(msg.sender == supervisor, "Only supervisor can set caller.");
        payGasCaller = _payGasCaller;
    }

    function proposeNewExchangeRate(
        uint128 tokenId,
        uint128 rateNumerator,
        uint128 rateDenominator
    )
        public payable
    {
        require(0 < rateNumerator && rateNumerator < 1e10, "Value should be reasonable.");
        require(0 < rateDenominator && rateDenominator < 1e10, "Value should be reasonable.");
        require(
            rateNumerator * 21000 < minGasReserveMaintain * rateDenominator,
            "Requires exchange rate * 21000 < minGasReserveMaintain."
        );
        Fraction memory exchangeRate;
        exchangeRate.numerator = rateNumerator;
        exchangeRate.denominator = rateDenominator;

        require(
            gasReserveBalance[tokenId][msg.sender] +
            msg.value >= minGasReserveInit, "Should have reserve amount greater than minimum."
        );
        GasReserve storage reserve = gasReserves[tokenId];
        mapping (address => uint256) storage balance = gasReserveBalance[tokenId];
        require(
            balance[reserve.admin] < minGasReserveMaintain ||
            compareFraction(reserve.exchangeRate.numerator, reserve.exchangeRate.denominator, rateNumerator, rateDenominator),
            "Invalid new exchange rate proposal."
        );
        uint256 newBalance = balance[msg.sender] + msg.value;
        require(newBalance >= msg.value, "Addition overflow.");
        balance[msg.sender] = newBalance;
        reserve.admin = msg.sender;
        reserve.exchangeRate.numerator = rateNumerator;
        reserve.exchangeRate.denominator = rateDenominator;
        // Default refund percentage.
        reserve.refundPercentage = 50;
    }

    function depositGasReserve(uint128 tokenId) public payable {
        require(gasReserveBalance[tokenId][msg.sender] > 0, "should be an exited token");
        uint256 newBalance = gasReserveBalance[tokenId][msg.sender] + msg.value;
        require(newBalance >= msg.value, "should be a valid term");
        gasReserveBalance[tokenId][msg.sender] = newBalance;
    }

    function setRefundPercentage(
        uint128 tokenId,
        uint64 refundPercentage
    ) public
    {
        require(
            msg.sender == gasReserves[tokenId].admin,
            "Only admin can set refund rate."
        );
        require(0 < refundPercentage && refundPercentage <= 100, "Should be between 0 and 100%.");
        gasReserves[tokenId].refundPercentage = refundPercentage;
    }

    function withdrawGasReserve(uint128 tokenId) public {
        require(
            msg.sender != gasReserves[tokenId].admin,
            "Not allowed for native token admin."
        );
        uint256 amount = gasReserveBalance[tokenId][msg.sender];
        require(amount > 0, "Should have non-zero value.");
        gasReserveBalance[tokenId][msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function withdrawNativeToken(uint128 tokenId) public {
        uint256 amount = nativeTokenBalance[tokenId][msg.sender];
        require(amount > 0, "Should have non-zero value.");
        nativeTokenBalance[tokenId][msg.sender] = 0;
        transferMNT(uint256(msg.sender), uint256(tokenId), amount);
    }

    function calculateGas(uint128 tokenId, uint256 amount) public view returns (uint256) {
        GasReserve memory reserve = gasReserves[tokenId];
        if (reserve.admin == address(0)) {
            // Invalid token.
            return 0;
        }
        Fraction memory ratio = reserve.exchangeRate;
        uint256 gasAmount = ratio.numerator * amount;
        require(gasAmount / ratio.numerator == amount, "Multiplication overflow.");
        gasAmount /= ratio.denominator;
        return gasAmount;
    }

    // Should only be called in consensus as the caller is set to the contract itself.
    function payAsGas(uint128 tokenId, uint256 amount) public {
        require(msg.sender == payGasCaller, "Only caller can invoke this function.");
        GasReserve storage reserve = gasReserves[tokenId];
        require(reserve.admin != address(0), "Should have a valie gas reserve record.");

        Fraction memory ratio = reserve.exchangeRate;
        uint256 gasAmount = ratio.numerator * amount;
        require(gasAmount / ratio.numerator == amount, "Multiplication overflow.");

        gasAmount /= ratio.denominator;
        require(
            gasAmount <= gasReserveBalance[tokenId][reserve.admin],
            "Should have enough reserves to pay."
        );

        gasReserveBalance[tokenId][reserve.admin] -= gasAmount;
        nativeTokenBalance[tokenId][reserve.admin] += amount;
    }

    // True if fraction 1 < fraction 2.
    function compareFraction(
        uint128 numerator1,
        uint128 denominator1,
        uint128 numerator2,
        uint128 denominator2
    ) private pure returns (bool)
    {
        // Avoid overflow of uint256.
        uint128 left = numerator1 * denominator2;
        uint128 right = numerator2 * denominator1;
        require(
            left / numerator1 == denominator2, "Multiplication overflow."
        );
        require(
            right / numerator2 == denominator1, "Multiplication overflow."
        );
        return left < right;
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
