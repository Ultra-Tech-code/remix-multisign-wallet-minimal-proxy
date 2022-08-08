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
    event ExecuteTransaction(address indexed owner, uint indexed txIndex, bytes data);


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




    /// @dev enabling the contract recieve ether
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /// @dev taking the funds should a function that does not exist be called with funds
    fallback() external payable {}


    /// @dev this function would push new transactions to the transactons array 
    /// @param _to: this is the address that the low level call would be sent to
    /// @param _value: this is the amount of ether that would be passed to the low level transaction call when the transaction have been excecuted
    /// @param _data: this is the low level representation of the transaction which would be passed to the .call method to the _to address
    function submitTransaction (
        address _to,
        uint _value,
        bytes memory _data // this would be a function signature
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

    /// @dev using this function, a user can consent to a transaction that has been submited
    /// @param _txIndex: this is the transaction index
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

    /// @dev here the transaction would be excuted
    /// @notice the transaction can only be excecuted is the number of quorum is satified!!
    /// @param _txIndex: this is the index of the transaction that is to be excecuted
    function executeTransaction(uint _txIndex)
        public
        shouldBeInit
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        returns (bytes memory)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, bytes memory data) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex, data);

        return data;
    }

    /// @dev using this function, the user can cancel the revoke his/her vote given to a transaction
    /// @param _txIndex: this is the index of the tranaction to be revoked
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

    /// @dev this is a function to return all the owners in a wallet quorum
    function getOwners() public view shouldBeInit returns (address[] memory) {
        return owners;
    }

    /// @dev obtaining the length of the transactions of the wallet
    function getTransactionCount() public view shouldBeInit returns (uint) {
        return transactions.length;
    }

    /// @dev this function would return a transaction on input of the transaction id
    /// @param _txIndex: this is the id of the transaction to be returned
    function getTransaction(uint _txIndex)
        public
        view
        shouldBeInit
        onlyOwner
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


    /// @dev this function is meant for owners to qurey the balance of the contract
    function getWalletBalance()
        public
        view
        shouldBeInit
        onlyOwner
        returns (
            uint
        )
    {
        return address(this).balance;
    }


    /// @dev this is a function to returns and transaction (How would i implement this, I dont feel conformatable returning an array)



    /// @dev this is acting as the constructor (because this contract is implemented using the EIP-1167) (this function can only run once and it must be on deployment)
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


// ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB"]
    



// todo


/*


Functions to return all the tranaction so the frontend guy can make use of the data. or the frontend guy can make use on the event logs?
*/
