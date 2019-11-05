pragma solidity >=0.4.21 <0.6.0;


contract SelfDestruct {
    constructor() public payable {}

    function forceSend(address payable target) external {
        selfdestruct(target);
    }
}
