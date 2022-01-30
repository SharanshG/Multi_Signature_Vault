// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "../../common/Enum.sol";
import "../../base/GuardManager.sol";
import "../../MyVault.sol";

/// @title Debug Transaction Guard - A guard that will emit events with extended information.
/// @notice This guard is only meant as a development tool and example
/// @author Sharansh Guha
contract DebugTransactionGuard is BaseGuard {
    // solhint-disable-next-line payable-fallback
    fallback() external {
        // We don't revert on fallback to avoid issues in case of a Vault upgrade
        // E.g. The expected check method might change and then the Vault would be locked.
    }

    event TransactionDetails(
        address indexed vault,
        bytes32 indexed txHash,
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 vaultTxGas,
        bool usesRefund,
        uint256 nonce
    );

    event GasUsage(address indexed vault, bytes32 indexed txHash, uint256 indexed nonce, bool success);

    mapping(bytes32 => uint256) public txNonces;

    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 vaultTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        // solhint-disable-next-line no-unused-vars
        address payable refundReceiver,
        bytes memory,
        address
    ) external override {
        uint256 nonce;
        bytes32 txHash;
        {
            MyVault vault = MyVault(payable(msg.sender));
            nonce = vault.nonce() - 1;
            txHash = vault.getTransactionHash(to, value, data, operation, vaultTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce);
        }
        emit TransactionDetails(msg.sender, txHash, to, value, data, operation, vaultTxGas, gasPrice > 0, nonce);
        txNonces[txHash] = nonce;
    }

    function checkAfterExecution(bytes32 txHash, bool success) external override {
        uint256 nonce = txNonces[txHash];
        require(nonce != 0, "Could not get nonce");
        txNonces[txHash] = 0;
        emit GasUsage(msg.sender, txHash, nonce, success);
    }
}
