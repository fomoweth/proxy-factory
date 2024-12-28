// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Initializable
/// @dev Modified from https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol

abstract contract Initializable {
	/// keccak256(bytes("Initialized(uint64)"))
	bytes32 private constant INITIALIZED_TOPIC = 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2;

	/// bytes32(uint256(keccak256("Initializing")) - 1)
	bytes32 private constant INITIALIZING_SLOT = 0x9536fd274b1da513899715f101ac7dd4165956a4323c575571d0d2c5d0ec45f8;

	/// bytes32(uint256(keccak256("LastRevision")) - 1)
	bytes32 private constant LAST_REVISION_SLOT = 0x2dcf4d2fa80344eb3d0178ea773deb29f1742cf017431f9ee326c624f742669b;

	uint64 private constant MAX_UINT64 = (1 << 64) - 1;

	modifier initializer() {
		uint256 revision = getRevision();
		bool isTopLevelCall;

		assembly ("memory-safe") {
			isTopLevelCall := iszero(tload(INITIALIZING_SLOT))

			if and(
				iszero(gt(revision, sload(LAST_REVISION_SLOT))),
				not(or(iszero(isTopLevelCall), iszero(extcodesize(address()))))
			) {
				mstore(0x00, 0xf92ee8a9) // InvalidInitialization()
				revert(0x1c, 0x04)
			}

			if isTopLevelCall {
				tstore(INITIALIZING_SLOT, 0x01)
				sstore(LAST_REVISION_SLOT, and(revision, MAX_UINT64))
			}

			sstore(LAST_REVISION_SLOT, and(MAX_UINT64, revision))
		}

		_;

		assembly ("memory-safe") {
			if isTopLevelCall {
				tstore(INITIALIZING_SLOT, 0x00)
				mstore(0x20, revision)
				log1(0x20, 0x20, INITIALIZED_TOPIC)
			}
		}
	}

	function disableInitializer() internal virtual {
		assembly ("memory-safe") {
			if tload(INITIALIZING_SLOT) {
				mstore(0x00, 0xf92ee8a9) // InvalidInitialization()
				revert(0x1c, 0x04)
			}

			if iszero(eq(sload(LAST_REVISION_SLOT), MAX_UINT64)) {
				sstore(LAST_REVISION_SLOT, MAX_UINT64)
				mstore(0x20, MAX_UINT64)
				log1(0x20, 0x20, INITIALIZED_TOPIC)
			}
		}
	}

	function getRevision() internal pure virtual returns (uint256);
}
