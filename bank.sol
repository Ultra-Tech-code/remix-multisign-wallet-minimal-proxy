
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/Pausable.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
 
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BankToken is Pausable {
    address owner;

    /// @dev this a mapping of the users address to their ether balances
    mapping(address => uint) public balance;
    /// @dev this is a mapping for tracking user address to erc20 token address to their value
    mapping(address => mapping(address => uint)) public tokenList;



    event _transfer_ether(address indexed from, address indexed to, uint amount); // event to log transfer
    event _deposit_ether(address indexed _owner, uint amount); // event to log withdraw
    event _transfer_erc20(address token, address indexed _owner, address indexed to, uint amount); // event to log withdraw
    event _deposit_erc20(address token, address indexed owner, uint amount);
    event _recover(address indexed _to, address indexed _tokenAddress, uint _amt); // event to log recovered funds

    constructor() {
        owner = msg.sender;
    }

    // only owner modifier
    modifier onlyOwner(){
        require(msg.sender == owner, "You can't perform this transaction");
        _;
    }
    
    // modifier to verify address and amount
    modifier verifyAddress(uint _amount){
        require(msg.sender != address(0), "You can't withdraw here!!");
        require(balance[msg.sender] >= _amount, "Insufficeint balance");
        _;
    }

    /// @dev this function will deposit erc20 token into the contract
    function depositERC20Token(address _tokenAddress, uint amount) external {
       bool transfer_status = IERC20(_tokenAddress).transferFrom(msg.sender, address(this), amount); // this is the line that is failing
       require(transfer_status, "Transfer failed");

       tokenList[msg.sender][_tokenAddress] += amount;

       emit _deposit_erc20(_tokenAddress,msg.sender,amount);
    }

    /// @dev this function will withdraw erc20 token from the contract
    function transferERC20Token(address _to, address _tokenAddress, uint _amount) external {
        require(msg.sender != _to, "sender can't be reciever");
        uint userBalance = tokenList[msg.sender][_tokenAddress];
        require(userBalance >= _amount, "Insufficient fund");
        tokenList[msg.sender][_tokenAddress] -= _amount;
        bool transfer_status = IERC20(_tokenAddress).transfer(_to, _amount);

        // question: revert changes the state of a contract to the init tate right? if this transaction fails, the money deducted from the bal, would it be reverted to the init state

       require(transfer_status, "Withdraw Error");
       emit _transfer_erc20(_tokenAddress, msg.sender, _to, _amount); 
    }

    // function to deposit ether into the contract
    function deposit() public payable {
        require(msg.value > 0, "Zero not allowed");
        balance[msg.sender] += msg.value;
        emit _deposit_ether(msg.sender, msg.value);
    }

    receive() external payable {
        deposit();
    }

    // function to transfer ether from one address to another
    function transfer(address _to, uint _amt) external payable verifyAddress(_amt) {
        require(_to != address(0), "Invalid address");
        balance[msg.sender] -= _amt;
        payable(_to).transfer(_amt);
        emit _transfer_ether(msg.sender, _to, _amt);
    }

}
