// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";



/// @title A title that should describe the contract/interface
/// @author developeruche
contract MultiSigWallet is Initializable {


    // CUSTOM ERRORS


    /// Wallet has not been Intialized
    error HasNotBeenInitialized();

    /// A base wallet contract cannot call Initalize
    error CannotCallInitalized();

    /// Invalid Number Of Comfirmation
    error InvalidNumberOfComfirmation();

    /// Owners Cannot Be Empty
    error OwnersCannotBeEmpty();

    /// Invalid Owner Address
    error InvalidOwnerAddress();

    /// Owners must be unique
    error OwnersMustBeUnique();

    /// Contract Already Initialized 
    error ContractAlreadyInitailized();





    // EVENTS



    /// @dev this event would be logged when a deposit is  made
    event Deposit(address indexed sender, uint amount, uint balance);
    /// @dev this event would be logged when a transaction is submitted by any of the owner
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    /// @dev this event would be logged when a tranaction is confirmed
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    /// @dev this event would be logged when a transaction is terminated
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    /// @dev this would be logged when a transaction is finally excuted
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);


    //STATE VARIABLES


    /// @dev this array hold the list of owner in this contract
    address[] public owners;
    /// @dev this mapping would be used to see if an address is part of the user (i am using a mapping because it is EFFICENT)
    mapping(address => bool) public isOwner;
    /// @dev this is the nubmer of comfirmations need before a transaction would go through
    uint public numConfirmationsRequired;    
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }
    bool private isBase;
    bool private isInitialized;
    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed;
    /// @dev storing all the transaction in an array
    Transaction[] public transactions;


    // MODIFERS


    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    modifier shouldBeInit() {
        if(!isInitialized) {
            revert HasNotBeenInitialized();
        }
        _;
    }

    modifier cantInitBase() {
        if(isBase) {
            revert CannotCallInitalized();
        }
        _;
    }



    // CONSTRUCTOR

    constructor() {
        isBase = true;
    }




    // ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB"]
    
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    fallback() external payable {}

    function submitTransaction (
        address _to,
        uint _value,
        bytes memory _data // 0xdef4532
    ) shouldBeInit public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex)
        public
        shouldBeInit
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
        public
        shouldBeInit
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint _txIndex)
        public
        shouldBeInit
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view shouldBeInit returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view shouldBeInit returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        public
        view
        shouldBeInit
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    function initialize(address[] memory _owners, uint _numConfirmationsRequired) public cantInitBase {

        // the input owner must be more than zero
        if (_owners.length < 0) {
            revert OwnersCannotBeEmpty();
        }

        // require the number of comfirmation is not greater than the number of owners
        if(_numConfirmationsRequired < 0 || _numConfirmationsRequired >= _owners.length) {
            revert InvalidNumberOfComfirmation();
        }

        
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];


            if(owner == address(0)) {
                revert InvalidOwnerAddress();
            }

            if(isOwner[owner]) {
                revert OwnersMustBeUnique();
            }

            isOwner[owner] = true;
            owners.push(owner);
        }

        if(isInitialized) {
            revert ContractAlreadyInitailized();
        }

        numConfirmationsRequired = _numConfirmationsRequired;

        isInitialized = true;
    }
}



// todo


/*
Handle data coming from excute function (handle the data coming from the call method)
*/
