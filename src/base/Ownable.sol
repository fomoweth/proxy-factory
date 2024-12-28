// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Ownable
/// @dev Implementation from https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol

abstract contract Ownable {
	/// bytes32(~uint256(uint32(bytes4(keccak256("OWNER_SLOT_NOT")))))
	bytes32 private constant OWNER_SLOT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927;

	/// keccak256(bytes("OwnershipTransferred(address,address)"))
	bytes32 private constant OWNERSHIP_TRANSFERRED_TOPIC =
		0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;

	modifier onlyOwner() {
		_checkOwner();
		_;
	}

	function owner() public view virtual returns (address account) {
		assembly ("memory-safe") {
			account := sload(OWNER_SLOT)
		}
	}

	function transferOwnership(address newOwner) public virtual onlyOwner {
		_checkNewOwner(newOwner);
		_setOwner(newOwner);
	}

	function renounceOwnership() public virtual onlyOwner {
		_setOwner(address(0));
	}

	function _initializeOwner(address newOwner) internal virtual {
		if (_initializeOwnerGuard()) {
			assembly ("memory-safe") {
				if sload(OWNER_SLOT) {
					mstore(0x00, 0x0dc149f0) // AlreadyInitialized()
					revert(0x1c, 0x04)
				}

				newOwner := shr(0x60, shl(0x60, newOwner))

				sstore(OWNER_SLOT, or(newOwner, shl(0xff, iszero(newOwner))))

				log3(0x00, 0x00, OWNERSHIP_TRANSFERRED_TOPIC, 0x00, newOwner)
			}
		} else {
			assembly ("memory-safe") {
				newOwner := shr(0x60, shl(0x60, newOwner))

				sstore(OWNER_SLOT, newOwner)

				log3(0x00, 0x00, OWNERSHIP_TRANSFERRED_TOPIC, 0x00, newOwner)
			}
		}
	}

	function _setOwner(address newOwner) internal virtual {
		if (_initializeOwnerGuard()) {
			assembly ("memory-safe") {
				newOwner := shr(0x60, shl(0x60, newOwner))

				log3(0x00, 0x00, OWNERSHIP_TRANSFERRED_TOPIC, sload(OWNER_SLOT), newOwner)

				sstore(OWNER_SLOT, or(newOwner, shl(0xff, iszero(newOwner))))
			}
		} else {
			assembly ("memory-safe") {
				newOwner := shr(0x60, shl(0x60, newOwner))

				log3(0x00, 0x00, OWNERSHIP_TRANSFERRED_TOPIC, sload(OWNER_SLOT), newOwner)

				sstore(OWNER_SLOT, newOwner)
			}
		}
	}

	function _checkOwner() internal view virtual {
		assembly ("memory-safe") {
			if iszero(eq(caller(), sload(OWNER_SLOT))) {
				mstore(0x00, 0x82b42900) // Unauthorized()
				revert(0x1c, 0x04)
			}
		}
	}

	function _checkNewOwner(address newOwner) internal pure virtual {
		assembly ("memory-safe") {
			if iszero(shl(0x60, newOwner)) {
				mstore(0x00, 0x54a56786) // InvalidNewOwner()
				revert(0x1c, 0x04)
			}
		}
	}

	function _initializeOwnerGuard() internal pure virtual returns (bool guard) {}
}
