pragma solidity >0.4.99 <0.6.0;


contract GeneralNativeTokenManager {

    // Gas reserve record, packed into 2 256-bit words.
    struct GasReserve {
        address admin;
        uint64 refundPercentage;
        uint128 numerator;
        uint128 denominator;
    }

    // Required caller for using native token to pay gas in QKC.
    // Setting to the contract address itself will make sure the invocation can
    // only be done in consensus, while allowing mock for unit testing. Configured in cstor.
    address public payGasCaller;

    // Contract admin in early stage. Capabilities are limited and may be unset.
    address public supervisor;

    // Token ID -> gas reserves.
    mapping (uint128 => GasReserve) public gasReserves;
    // Minimum amount of QKC to maintain the gas utility.
    // If the current QKC gas reserved is lower than the value, then the gas reserved can be
    // replaced and potentially decrease the current exchange rate.
    uint128 public minGasReserveMaintain = 10 ether;
    // Minimum amount of QKC to start functioning as gas reserve, i.e.,
    // the minimum amount of QKC to replace gas reserve and increase the current exchange rate.
    uint128 public minGasReserveInit = 100 ether;

    // Switch for token registration.
    bool public registrationRequired;
    // Balance accounting: token ID -> token admin -> QKC balance.
    mapping (uint128 => mapping (address => uint256)) public gasReserveBalance;
    // Token ID -> token admin -> native token balance.
    mapping (uint128 => mapping (address => uint256)) public nativeTokenBalance;
    // Token ID -> token registered or not.
    mapping (uint128 => bool) public registeredTokens;
    // A flag to freeze current gas reserve to prepare for migration.
    bool public frozen = false;

    constructor (address _supervisor, address _payGasCaller) public {
        supervisor = _supervisor;
        // If caller not specified, should be the contract address itself.
        if (_payGasCaller == address(0)) {
            payGasCaller = address(this);
        } else {
            payGasCaller = _payGasCaller;
        }
        registrationRequired = true;
    }

    modifier onlySupervisor {
        require(msg.sender == supervisor, "Only supervisor is allowed.");
        _;
    }

    function setFrozen(bool _frozen) public onlySupervisor {
        frozen = _frozen;
    }

    function setMinGasReserve(
        uint128 _minGasReserveMaintain,
        uint128 _minGasReserveInit
    ) public onlySupervisor
    {
        minGasReserveMaintain = _minGasReserveMaintain;
        minGasReserveInit = _minGasReserveInit;
    }

    function updateSupervisor(address newSupervisor) public onlySupervisor {
        supervisor = newSupervisor;
    }

    function requireTokenRegistration(bool req) public onlySupervisor {
        registrationRequired = req;
    }

    function registerToken() public payable {
        uint256[1] memory output;

        // Call precompiled contract to query current native token id
        // as a proof of the existence of this token.
        /* solium-disable-next-line */
        assembly {
           if iszero(call(not(0), 0x514b430001, 0, 0, 0, output, 0x20)){
               revert(0, 0)
           }
        }
        // Token ID is guaranteed to be less than maximum of uint128.
        uint128 tokenId = uint128(output[0]);
        require(tokenId != 0x8bb0, "Default token cannot be registered.");
        require(!registeredTokens[tokenId], "Token already registered.");
        registeredTokens[tokenId] = true;
        // Update native token balance for future withdrawal.
        nativeTokenBalance[tokenId][msg.sender] = msg.value;
    }

    function proposeNewExchangeRate(
        uint128 tokenId,
        uint128 rateNumerator,
        uint128 rateDenominator
    )
        public payable
    {
        require(!frozen, "Contract frozen.");
        if (registrationRequired) {
            require(registeredTokens[tokenId], "Token ID does not exist.");
        }
        // Token id of "ZZZZZZZZZZZZ"
        require(tokenId <= 4873763662273663091, "Max token ID reached.");
        // Token id of 'QKC'
        require(tokenId != 0x8bb0, "Can't be default token");
        require(0 < rateNumerator, "Value should be non-zero.");
        require(0 < rateDenominator, "Value should be non-zero.");
        // Prevent an attack that the attacker offers an extremely high rate while maintain is too low
        // to pay the fee in QKC.
        // Assuming for a tx, the gas price of a native token = 1, and thus minimum token as fee is 21000
        // After converted to QKC, the amount of QKC should be smaller than maintain so that
        // the rate can be replaced after reducing the reserved QKC to be lower than maintain by
        // sending tx with gas price = 1.
        require(
            uint256(rateNumerator) * 21000 < uint256(minGasReserveMaintain) * rateDenominator,
            "Requires exchange rate * 21000 < minGasReserveMaintain."
        );

        require(
            gasReserveBalance[tokenId][msg.sender] +
            msg.value >= minGasReserveInit, "Should have reserve amount greater than minimum."
        );
        GasReserve storage reserve = gasReserves[tokenId];
        mapping (address => uint256) storage balance = gasReserveBalance[tokenId];
        require(
            balance[reserve.admin] < minGasReserveMaintain ||
            _compareFraction(reserve.numerator, reserve.denominator, rateNumerator, rateDenominator),
            "Invalid new exchange rate proposal."
        );
        uint256 newBalance = balance[msg.sender] + msg.value;
        require(newBalance >= msg.value, "Addition overflow.");
        balance[msg.sender] = newBalance;
        reserve.admin = msg.sender;
        reserve.numerator = rateNumerator;
        reserve.denominator = rateDenominator;
        // Default refund percentage.
        reserve.refundPercentage = 50;
    }

    function depositGasReserve(uint128 tokenId) public payable {
        require(gasReserveBalance[tokenId][msg.sender] > 0, "Should be an existed token");
        uint256 newBalance = gasReserveBalance[tokenId][msg.sender] + msg.value;
        require(newBalance >= msg.value, "Reserved balance overflow");
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
        require(
            10 <= refundPercentage && refundPercentage <= 100,
            "Refund pertentage should be between 10 and 100."
        );
        gasReserves[tokenId].refundPercentage = refundPercentage;
    }

    function withdrawGasReserve(uint128 tokenId) public {
        require(
            // If contract frozen, allow withdraw at any time.
            frozen || msg.sender != gasReserves[tokenId].admin,
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
        _transferMNT(uint256(msg.sender), uint256(tokenId), amount);
    }

    function calculateGasPrice(
        uint128 tokenId,
        uint128 gasPrice
    ) public view returns (uint64, uint256, address)
    {
        GasReserve memory reserve = gasReserves[tokenId];
        require(reserve.admin != address(0), "Invalid token.");
        uint256 convertedGasPrice = uint256(reserve.numerator) * gasPrice;
        convertedGasPrice /= reserve.denominator;
        require(convertedGasPrice > 0, "Should have non-zero value.");
        return (reserve.refundPercentage, convertedGasPrice, reserve.admin);
    }

    // Should only be called in consensus as the caller is set to the contract itself.
    function payAsGas(
        uint128 tokenId,
        uint128 gas,
        uint128 gasPrice
    ) public returns (uint64, uint256)
    {
        require(!frozen, "Contract frozen.");
        require(msg.sender == payGasCaller, "Only caller can invoke this function.");
        uint64 refundPercentage;
        uint256 convertedGasPrice;
        address admin;
        (refundPercentage, convertedGasPrice, admin) = calculateGasPrice(tokenId, gasPrice);
        uint256 nativeTokenCost = uint256(gas) * gasPrice;
        uint256 qkcGasAmount = gas * convertedGasPrice;
        require(
            qkcGasAmount / gas == convertedGasPrice,
            "Avoid uint256 overflow."
        );
        require(
            qkcGasAmount <= gasReserveBalance[tokenId][admin],
            "Should have enough reserves to pay."
        );
        uint256 newBalance = nativeTokenBalance[tokenId][admin] + nativeTokenCost;
        require(
            newBalance >= nativeTokenBalance[tokenId][admin],
            "Avoid addition overflow."
        );

        gasReserveBalance[tokenId][admin] -= qkcGasAmount;
        nativeTokenBalance[tokenId][admin] = newBalance;
        return (refundPercentage, convertedGasPrice);
    }

    // True if fraction 1 < fraction 2.
    function _compareFraction(
        uint128 numerator1,
        uint128 denominator1,
        uint128 numerator2,
        uint128 denominator2
    ) private pure returns (bool)
    {
        uint256 left = uint256(numerator1) * denominator2;
        uint256 right = uint256(numerator2) * denominator1;
        return left < right;
    }

    function _transferMNT(uint256 addr, uint256 tokenId, uint256 value) private returns (uint p) {
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
