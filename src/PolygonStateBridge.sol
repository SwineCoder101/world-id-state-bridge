// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Optimism interface for cross domain messaging
import {IPolygonWorldID} from "./interfaces/IPolygonWorldID.sol";
import {IWorldIDIdentityManager} from "./interfaces/IWorldIDIdentityManager.sol";
import {IRootHistory} from "./interfaces/IRootHistory.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {FxBaseRootTunnel} from "fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";

/// @title Polygon World ID State Bridge
/// @author Worldcoin
/// @notice Distributes new World ID Identity Manager roots to World ID supported networks
/// @dev This contract lives on Ethereum mainnet and is called by the World ID Identity Manager contract
/// in the registerIdentities method
/// @dev Ownable2Step allows for transferOwnership to the zero address
contract PolygonStateBridge is FxBaseRootTunnel, Ownable2Step {
    ///////////////////////////////////////////////////////////////////
    ///                           STORAGE                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice WorldID Identity Manager contract
    IWorldIDIdentityManager public immutable worldID;

    ///////////////////////////////////////////////////////////////////
    ///                            EVENTS                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Emmitted when the the StateBridge sets the root history expiry for OpWorldID and PolygonWorldID
    /// @param rootHistoryExpiry The new root history expiry
    event SetRootHistoryExpiry(uint256 rootHistoryExpiry);

    /// @notice Emmitted when a root is sent to PolygonWorldID
    /// @param root The latest WorldID Identity Manager root.
    event RootPropagated(uint256 root);

    ///////////////////////////////////////////////////////////////////
    ///                            ERRORS                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Emitted when an attempt is made to renounce ownership.
    error CannotRenounceOwnership();

    ///////////////////////////////////////////////////////////////////
    ///                         CONSTRUCTOR                         ///
    ///////////////////////////////////////////////////////////////////

    /// @notice constructor
    /// @param _checkpointManager address of the checkpoint manager contract
    /// @param _fxRoot address of Polygon's fxRoot contract, part of the FxPortal bridge (Goerli or Mainnet)
    /// @param _worldIDIdentityManager Deployment address of the WorldID Identity Manager contract
    constructor(address _checkpointManager, address _fxRoot, address _worldIDIdentityManager)
        FxBaseRootTunnel(_checkpointManager, _fxRoot)
    {
        worldID = IWorldIDIdentityManager(_worldIDIdentityManager);
    }

    ///////////////////////////////////////////////////////////////////
    ///                          PUBLIC API                         ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Sends the latest WorldIDIdentityManager root
    /// to Polygon's StateChild contract (PolygonWorldID)
    function propagateRoot() external {
        uint256 latestRoot = worldID.latestRoot();

        bytes memory message = abi.encodeCall(IPolygonWorldID.receiveRoot, (latestRoot));

        /// @notice FxBaseRootTunnel method to send bytes payload to FxBaseChildTunnel contract
        _sendMessageToChild(message);

        emit RootPropagated(latestRoot);
    }

    /// @notice Sets the root history expiry for PolygonWorldID
    /// @param _rootHistoryExpiry The new root history expiry
    function setRootHistoryExpiryPolygon(uint256 _rootHistoryExpiry) external onlyOwner {
        bytes memory message =
            abi.encodeCall(IRootHistory.setRootHistoryExpiry, (_rootHistoryExpiry));

        /// @notice FxBaseRootTunnel method to send bytes payload to FxBaseChildTunnel contract
        _sendMessageToChild(message);

        emit SetRootHistoryExpiry(_rootHistoryExpiry);
    }

    /// @notice boilerplate function to satisfy FxBaseRootTunnel inheritance (not going to be used)
    function _processMessageFromChild(bytes memory) internal override {
        /// WorldID 🌎🆔 State Bridge
    }

    ///////////////////////////////////////////////////////////////////////////////
    ///                            ADDRESS MANAGEMENT                           ///
    ///////////////////////////////////////////////////////////////////////////////

    /// @notice Sets the `fxChildTunnel` address if not already set.
    /// @dev This implementation replicates the logic from `FxBaseRootTunnel` due to the inability
    ///      to call `external` superclass methods when overriding them.
    ///
    /// @param _fxChildTunnel The address of the child (non-L1) tunnel contract.
    ///
    /// @custom:reverts string If the root tunnel has already been set.
    function setFxChildTunnel(address _fxChildTunnel) public virtual override onlyOwner {
        require(fxChildTunnel == address(0x0), "FxBaseRootTunnel: CHILD_TUNNEL_ALREADY_SET");
        fxChildTunnel = _fxChildTunnel;
    }

    ///////////////////////////////////////////////////////////////////
    ///                          OWNERSHIP                          ///
    ///////////////////////////////////////////////////////////////////
    /// @notice Ensures that ownership of WorldID implementations cannot be renounced.
    /// @dev This function is intentionally not `virtual` as we do not want it to be possible to
    ///      renounce ownership for any WorldID implementation.
    /// @dev This function is marked as `onlyOwner` to maintain the access restriction from the base
    ///      contract.
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
    }
}
