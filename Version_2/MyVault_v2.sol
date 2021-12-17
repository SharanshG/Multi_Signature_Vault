// SPDX-License-Identifier: MIT

pragma solidity ^0.4.25;

/**
 * Team Token Lockup
*/

contract Token {
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function approveAndCall(address spender, uint tokens, bytes data) external returns (bool success);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function getPendingItems() external returns (uint[]);
}

contract ERC721Token {
	function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(
        address from, address to, uint256 tokenId
    ) external;
    function transferFrom(
        address from, address to, uint256 tokenId
    ) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(
        address from, address to, uint256 tokenId, bytes data
    ) external;
}


interface ERC1155Token {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] accounts, uint256[] ids)
        external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);  
    function safeTransferFrom(
        address from, address to, uint256 id, uint256 amount, bytes data
    ) external;
    function safeBatchTransferFrom(
        address from, address to, uint256[] ids, uint256[] amounts, bytes data
    ) external;
}


library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }

  function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
    uint256 c = add(a,m);
    uint256 d = sub(c,1);
    return mul(div(d,m),m);
  }
}

/// @title OwnerManager - Manages a set of owners and a threshold to perform actions.

contract OwnerManager {
    event AddedOwner(address owner);
    event RemovedOwner(address owner);
    event ChangedThreshold(uint256 threshold);

    address internal constant DEFAULT_OWNERS = address(0x1);

    mapping(address => address) internal owners;
    uint256 internal ownerCount;
    uint256 internal threshold;

    /// @dev Setup function sets initial storage of contract.
    /// @param _owners List of Safe owners.
    /// @param _threshold Number of required confirmations for a Safe transaction.
    function setupOwners(address[] memory _owners, uint256 _threshold) internal {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        require(threshold == 0, "Initial Threshold is not 0");
        // Validate that threshold is smaller than number of added owners.
        require(_threshold <= _owners.length, "Threshold is more than number of owners");
        // There has to be at least one Safe owner.
        require(_threshold >= 1, "Less than 1 Owner");
        // Initializing Safe owners.
        address currentOwner = DEFAULT_OWNERS;
        for (uint256 i = 0; i < _owners.length; i++) {
            // Owner address cannot be null.
            address owner = _owners[i];
            require(owner != address(0) && owner != DEFAULT_OWNERS && owner != address(this) && currentOwner != owner, "Owner address can't be null");
            // No duplicate owners allowed.
            require(owners[owner] == address(0), "Duplicate Owners not allowed");
            owners[currentOwner] = owner;
            currentOwner = owner;
        }
        owners[currentOwner] = DEFAULT_OWNERS;
        ownerCount = _owners.length;
        threshold = _threshold;
    }

    /// @dev Allows to add a new owner to the Safe and update the threshold at the same time.
    ///      This can only be done via a Safe transaction.
    /// @notice Adds the owner `owner` to the Safe and updates the threshold to `_threshold`.
    /// @param owner New owner address.
    /// @param _threshold New threshold.
    function addOwnerWithThreshold(address owner, uint256 _threshold) public  {
        // Owner address cannot be null, the default or the Safe itself.
        require(owner != address(0) && owner != DEFAULT_OWNERS && owner != address(this), "Owner address cannot be null, the default or the Safe itself");
        // No duplicate owners allowed.
        require(owners[owner] == address(0), "Duplicate Owners not allowed");
        owners[owner] = owners[DEFAULT_OWNERS];
        owners[DEFAULT_OWNERS] = owner;
        ownerCount++;
        emit AddedOwner(owner);
        // Change threshold if threshold was changed.
        if (threshold != _threshold) changeThreshold(_threshold);
    }

    /// @dev Allows to remove an owner from the Safe and update the threshold at the same time.
    /// This can only be done via a Safe transaction.
    /// @notice Removes the owner `owner` from the Safe and updates the threshold to `_threshold`.
    /// @param prevOwner Owner that pointed to the owner to be removed in the linked list
    /// @param owner Owner address to be removed.
    /// @param _threshold New threshold.
    function removeOwner(
        address prevOwner,
        address owner,
        uint256 _threshold
    ) public  {
        // Only allow to remove an owner, if threshold can still be reached.
        require(ownerCount - 1 >= _threshold, "Exceeded Threshold");
        // Validate owner address and check that it corresponds to owner index.
        require(owner != address(0) && owner != DEFAULT_OWNERS, "Invalid Owner");
        require(owners[prevOwner] == owner, "Does not Correspond to Owner Index");
        owners[prevOwner] = owners[owner];
        owners[owner] = address(0);
        ownerCount--;
        emit RemovedOwner(owner);
        // Change threshold if threshold was changed.
        if (threshold != _threshold) changeThreshold(_threshold);
    }

    /// @dev Allows to swap/replace an owner from the Safe with another address.
    ///      This can only be done via a Safe transaction.
    /// @notice Replaces the owner `oldOwner` in the Safe with `newOwner`.
    /// @param prevOwner Owner that pointed to the owner to be replaced in the linked list
    /// @param oldOwner Owner address to be replaced.
    /// @param newOwner New owner address.
    function swapOwner(
        address prevOwner,
        address oldOwner,
        address newOwner
    ) public  {
        // Owner address cannot be null, the default or the Safe itself.
        require(newOwner != address(0) && newOwner != DEFAULT_OWNERS && newOwner != address(this), "Invalid Address");
        // No duplicate owners allowed.
        require(owners[newOwner] == address(0), "Duplicate Owner not allowed");
        // Validate oldOwner address and check that it corresponds to owner index.
        require(oldOwner != address(0) && oldOwner != DEFAULT_OWNERS, "Invalid Owner");
        require(owners[prevOwner] == oldOwner, "Does not correspond to Owner Index");
        owners[newOwner] = owners[oldOwner];
        owners[prevOwner] = newOwner;
        owners[oldOwner] = address(0);
        emit RemovedOwner(oldOwner);
        emit AddedOwner(newOwner);
    }

    /// @dev Allows to update the number of required confirmations by Safe owners.
    ///      This can only be done via a Safe transaction.
    /// @notice Changes the threshold of the Safe to `_threshold`.
    /// @param _threshold New threshold.
    function changeThreshold(uint256 _threshold) public  {
        // Validate that threshold is smaller than number of owners.
        require(_threshold <= ownerCount, "Threshold exceeds Number of Owners");
        // There has to be at least one Safe owner.
        require(_threshold >= 1, "Threshold should atleast be 1");
        threshold = _threshold;
        emit ChangedThreshold(threshold);
    }

    function getThreshold() public view returns (uint256) {
        return threshold;
    }

    function isOwner(address owner) public view returns (bool) {
        return owner != DEFAULT_OWNERS && owners[owner] != address(0);
    }

    /// @dev Returns array of owners.
    /// @return Array of Safe owners.
    function getOwners() public view returns (address[] memory) {
        address[] memory array = new address[](ownerCount);

        // populate return array
        uint256 index = 0;
        address currentOwner = owners[DEFAULT_OWNERS];
        while (currentOwner != DEFAULT_OWNERS) {
            array[index] = currentOwner;
            currentOwner = owners[currentOwner];
            index++;
        }
        return array;
    }
}

contract owned {
        address public owner;

        constructor() public {
            owner = msg.sender;
        }

        modifier onlyOwner {
            require(msg.sender == owner);
            _;
        }

        function transferOwnership(address newOwner) onlyOwner public {
            owner = newOwner;
        }
}

contract lockToken is owned, OwnerManager {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes data
    ) external pure returns (bytes4) {
        return 0xf23a6e61;
    }
    
    using SafeMath for uint256;
    //minimum signatures required
    //uint constant MIN_SIGN = 2;
    /*
     * deposit vars
    */
    struct Items {
        address tokenAddress;
        address withdrawalAddress;
        uint256 tokenAmount;
        uint8 signatureCount;
        uint256 unlockTime;
        bool withdrawn;
        mapping (address => uint8) signatures;
    }
    
    uint256 public depositId;
    uint256[] public allDepositIds;
    mapping (address => uint256[]) public depositsByWithdrawalAddress;
    mapping (uint256 => Items) public lockedToken;
    mapping (address => mapping(address => uint256)) public walletTokenBalance;
    mapping (uint => Items) private _items;
    uint[] private _pendingItems;
    
    event LogWithdrawal(address SentToAddress, uint256 AmountTransferred);
    event WithdrawalCreated(address tokenAddress, address withdrawalAddress, uint tokenAmount, uint transactionId);
    event WithdrawalCompleted(address tokenAddress, address withdrawalAddress, uint tokenAmount, uint transactionId);
    event WithdrawalSigned(address by, uint transactionId);

        
    /**
     * Constrctor function
    */
    constructor() public {
        
    }
    
    /**
     *lock tokens
    */
    function lockTokens(address _tokenAddress, uint256 _amount, uint256 _unlockTime) public returns (uint256 _id) {
        require(_amount > 0, 'token amount is Zero');
        require(_unlockTime < 10000000000, 'Enter an unix timestamp in seconds, not miliseconds');
        require(Token(_tokenAddress).approve(this, _amount), 'Approve tokens failed');
        require(Token(_tokenAddress).transferFrom(msg.sender, this, _amount), 'Transfer of tokens failed');
        
        //update balance in address
        walletTokenBalance[_tokenAddress][msg.sender] = walletTokenBalance[_tokenAddress][msg.sender].add(_amount);
        
        address _withdrawalAddress = msg.sender;
        _id = ++depositId;
        lockedToken[_id].tokenAddress = _tokenAddress;
        lockedToken[_id].withdrawalAddress = _withdrawalAddress;
        lockedToken[_id].tokenAmount = _amount;
        lockedToken[_id].unlockTime = _unlockTime;
        lockedToken[_id].withdrawn = false;
        
        allDepositIds.push(_id);
        depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
    }
    
    
    
    struct ERC721Items {
        address tokenAddress;
        address withdrawalAddress;
        uint256 tokenId;
        uint256 unlockTime;
        bool withdrawn;
    }
    mapping(uint256 => ERC721Items) public ERC721Locker;
    mapping(address => mapping(address => uint256)) public walletERC721Balance;
    event LogERC721Withdrawal(address SentToAddress, uint256 TokenId);
    
    function lockERC721Tokens(address _tokenAddress, uint256 _tokenId, uint256 _unlockTime) public returns (uint256 _id) {
        require(_unlockTime < 10000000000, 'Enter an unix timestamp in seconds, not miliseconds');
        // approval should be already given
        ERC721Token(_tokenAddress).transferFrom(msg.sender, this, _tokenId);
        
        //update balance in address
        walletERC721Balance[_tokenAddress][msg.sender] = walletERC721Balance[_tokenAddress][msg.sender].add(1);
        
        address _withdrawalAddress = msg.sender;
        _id = ++depositId;
        ERC721Locker[_id].tokenAddress = _tokenAddress;
        ERC721Locker[_id].withdrawalAddress = _withdrawalAddress;
        ERC721Locker[_id].tokenId = _tokenId;
        ERC721Locker[_id].unlockTime = _unlockTime;
        ERC721Locker[_id].withdrawn = false;
        
        allDepositIds.push(_id);
        depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
    }
    
    
    
    struct ERC1155Items {
        address tokenAddress;
        address withdrawalAddress;
        uint tokenId;
        uint tokenAmount;
        uint256 unlockTime;
        bool withdrawn;
    }
    mapping(uint256 => ERC1155Items) public ERC1155Locker;
    mapping(address => mapping(address => uint256)) public walletERC1155Balance;
    
    function lockERC1155Tokens(address _tokenAddress, uint256 _tokenId, uint256 _tokenAmount, uint256 _unlockTime) public returns (uint256 _id) {
        require(_unlockTime < 10000000000, 'Enter an unix timestamp in seconds, not miliseconds');
        require(_tokenAmount > 0, 'number of tokens must be >0');
        // approval should be already given
        
        
        ERC1155Token(_tokenAddress).safeTransferFrom(
            msg.sender, this, _tokenId, _tokenAmount, abi.encodePacked(_tokenAddress)
        );
        
        //update balance in address
        walletERC1155Balance[_tokenAddress][msg.sender] = walletERC1155Balance[_tokenAddress][msg.sender].add(_tokenAmount);
        
        address _withdrawalAddress = msg.sender;
        _id = ++depositId;
        ERC1155Locker[_id].tokenAddress = _tokenAddress;
        ERC1155Locker[_id].withdrawalAddress = _withdrawalAddress;
        ERC1155Locker[_id].tokenId = _tokenId;
        ERC1155Locker[_id].tokenAmount = _tokenAmount;
        ERC1155Locker[_id].unlockTime = _unlockTime;
        ERC1155Locker[_id].withdrawn = false;
        
        allDepositIds.push(_id);
        depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
    }
    
    /**
     *withdraw tokens
    */
    function withdrawTokens(uint256 _id) public {
        require(block.timestamp >= lockedToken[_id].unlockTime, 'Tokens are locked');
        require(msg.sender == lockedToken[_id].withdrawalAddress, 'Can withdraw by withdrawal Address only');
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn');
        require(Token(lockedToken[_id].tokenAddress).transfer(msg.sender, lockedToken[_id].tokenAmount), 'Transfer of tokens failed');
        
        lockedToken[_id].withdrawn = true;
        //increase transaction id
        uint transactionId = depositId++;
        
        //init item struct
        Items memory item;
        item.tokenAddress = msg.sender;
        item.withdrawalAddress = lockedToken[_id].withdrawalAddress;
        item.tokenAmount = lockedToken[_id].tokenAmount;
        item.signatureCount = 0;
        
        emit WithdrawalCreated(msg.sender, lockedToken[_id].withdrawalAddress, lockedToken[_id].tokenAmount, transactionId);
    }
    
    function getPendingItems() view public returns(uint[]) {
        return _pendingItems;
    }
    
    function signWithdrawal(uint transactionId, uint256 _id) public {
        Items storage item = _items[transactionId];

        //Transaction must exist
        require(0x0 != item.tokenAddress);
        //Creator cannot sign the transaction
        require(msg.sender != item.tokenAddress);
        //Cannot sign a transaction more than once
        require(item.signatures[msg.sender] != 1);

        item.signatures[msg.sender] = 1;

        item.signatureCount++;

        emit WithdrawalSigned(msg.sender, transactionId);

        if (item.signatureCount >= getThreshold()){//MIN_SIGN){
            //check if balance is enough
            require(address(this).balance >= item.tokenAmount);
            //item.withdrawalAddress.transfer(item.tokenAmount);
            //update balance in address
            walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender] = walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender].sub(lockedToken[_id].tokenAmount);
            //remove this id from this address
            uint256 i; uint256 j;
            for(j=0; j<depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length; j++){
                if(depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] == _id){
                    for (i = j; i<depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length-1; i++){
                        depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][i] = depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][i+1];
                    }
                    depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length--;
                    break;
                }
            }
            emit LogWithdrawal(msg.sender, lockedToken[_id].tokenAmount);
            emit WithdrawalCompleted(item.tokenAddress, item.withdrawalAddress, item.tokenAmount, transactionId);

        }

    }
    
    
    function withdrawERC721Tokens(uint256 _id) public {
        require(block.timestamp >= ERC721Locker[_id].unlockTime, 'Unlock time is still in future');
        require(msg.sender == ERC721Locker[_id].withdrawalAddress, 'Can withdraw by withdrawal Address only');
        require(!ERC721Locker[_id].withdrawn, 'ERC721Token already withdrawn');
        uint _tokenId = ERC721Locker[_id].tokenId;
        address _tokenAddress = ERC721Locker[_id].tokenAddress;
        ERC721Token(_tokenAddress).transferFrom(this, msg.sender, _tokenId);
        
        ERC721Locker[_id].withdrawn = true;
        
        //increase transaction id
        uint transactionId = depositId++;
        
        //init item struct
        Items memory item;
        item.tokenAddress = msg.sender;
        item.withdrawalAddress = lockedToken[_id].withdrawalAddress;
        item.tokenAmount = lockedToken[_id].tokenAmount;
        item.signatureCount = 0;
        
        emit WithdrawalCreated(msg.sender, lockedToken[_id].withdrawalAddress, lockedToken[_id].tokenAmount, transactionId);
    }
    

    
    event LogERC1155Withdrawal(address to, uint tokenId, uint tokenAmount);
    
    function withdrawERC1155Tokens(uint256 _id) public {
        require(block.timestamp >= ERC1155Locker[_id].unlockTime, 'Unlock time is still in future');
        require(msg.sender == ERC1155Locker[_id].withdrawalAddress, 'Can withdraw by withdrawal Address only');
        require(!ERC1155Locker[_id].withdrawn, 'ERC1155Token already withdrawn');
        
        
        address _tokenAddress = ERC1155Locker[_id].tokenAddress;
        uint _tokenId = ERC1155Locker[_id].tokenId;
        uint _tokenAmount = ERC1155Locker[_id].tokenAmount;
        ERC1155Token(_tokenAddress).safeTransferFrom(
            this, msg.sender, _tokenId, _tokenAmount, abi.encodePacked(_tokenAddress)
        );
        ERC1155Locker[_id].withdrawn = true;
        
        //increase transaction id
        uint transactionId = depositId++;
        
        //init item struct
        Items memory item;
        item.tokenAddress = msg.sender;
        item.withdrawalAddress = lockedToken[_id].withdrawalAddress;
        item.tokenAmount = lockedToken[_id].tokenAmount;
        item.signatureCount = 0;
        
        emit WithdrawalCreated(msg.sender, lockedToken[_id].withdrawalAddress, lockedToken[_id].tokenAmount, transactionId);
    }
    

     /*get total token balance in contract*/
    function getTotalTokenBalance(address _tokenAddress) view public returns (uint256)
    {
       return Token(_tokenAddress).balanceOf(this);
    }
    
    /*get total token balance by address*/
    function getTokenBalanceByAddress(address _tokenAddress, address _walletAddress) view public returns (uint256)
    {
       return walletTokenBalance[_tokenAddress][_walletAddress];
    }
    
    /*get allDepositIds*/
    function getAllDepositIds() view public returns (uint256[] memory)
    {
        return allDepositIds;
    }
    
    /*get getDepositDetails*/
    function getDepositDetails(uint256 _id) view public returns (address, address, uint256, uint256, bool)
    {
        return(lockedToken[_id].tokenAddress,lockedToken[_id].withdrawalAddress,lockedToken[_id].tokenAmount,
        lockedToken[_id].unlockTime,lockedToken[_id].withdrawn);
    }
    
    /*get DepositsByWithdrawalAddress*/
    function getDepositsByWithdrawalAddress(address _withdrawalAddress) view public returns (uint256[] memory)
    {
        return depositsByWithdrawalAddress[_withdrawalAddress];
    }
}
