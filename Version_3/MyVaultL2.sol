// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "contracts/MyVault.sol";

/// @title My Vault - A multisignature wallet with support for confirmations using signed messages based on ERC191.
contract MyVaultL2 is MyVault {
    event VaultMultiSigTransaction(
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 vaultTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes signatures,
        // We combine nonce, sender and threshold into one to avoid stack too deep
        // Dev note: additionalInfo should not contain `bytes`, as this complicates decoding
        bytes additionalInfo
    );

    event VaultModuleTransaction(address module, address to, uint256 value, bytes data, Enum.Operation operation);

    /// @dev Allows to execute a Vault transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @param to Destination address of Vault transaction.
    /// @param value Ether value of Vault transaction.
    /// @param data Data payload of Vault transaction.
    /// @param operation Operation type of Vault transaction.
    /// @param vaultTxGas Gas that should be used for the Vault transaction.
    /// @param baseGas Gas costs that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
    /// @param gasPrice Gas price that should be used for the payment calculation.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 vaultTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) public payable override returns (bool) {
        bytes memory additionalInfo;
        {
            additionalInfo = abi.encode(nonce, msg.sender, threshold);
        }
        emit VaultMultiSigTransaction(
            to,
            value,
            data,
            operation,
            vaultTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures,
            additionalInfo
        );
        return super.execTransaction(to, value, data, operation, vaultTxGas, baseGas, gasPrice, gasToken, refundReceiver, signatures);
    }

    /// @dev Allows a Module to execute a Vault transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public override returns (bool success) {
        emit VaultModuleTransaction(msg.sender, to, value, data, operation);
        success = super.execTransactionFromModule(to, value, data, operation);
    }
}
