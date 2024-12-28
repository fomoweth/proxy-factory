// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IProxyFactory} from "src/interfaces/IProxyFactory.sol";
import {Ownable} from "src/base/Ownable.sol";

/// @title ProxyFactory
/// @dev Modified from https://github.com/Vectorized/solady/blob/main/src/utils/ERC1967Factory.sol

contract ProxyFactory is IProxyFactory, Ownable {
	/// keccak256(bytes("Deployed(address,address)"))
	bytes32 internal constant DEPLOYED_TOPIC = 0x09e48df7857bd0c1e0d31bb8a85d42cf1874817895f171c917f6ee2cea73ec20;

	/// keccak256(bytes("Upgraded(address,address)"))
	bytes32 internal constant UPGRADED_TOPIC = 0x5d611f318680d00598bb735d61bacf0c514c6b50e1e5ad30040a4df2b12791c7;

	/// uint256(keccak256("eip1967.proxy.implementation")) - 1
	bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

	function() internal view returns (bytes32) internal immutable initCode;

	constructor(address initialOwner) {
		_checkNewOwner(initialOwner);
		_initializeOwner(initialOwner);

		initCode = uint160(address(this)) >> 112 != 0 ? _initCode : _initCodePacked;
	}

	function upgrade(address proxy, address implementation) external payable {
		upgradeAndCall(proxy, implementation, emptyData());
	}

	function upgradeAndCall(
		address proxy,
		address implementation,
		bytes calldata data
	) public payable virtual onlyOwner {
		assembly ("memory-safe") {
			if iszero(sload(shl(0x60, proxy))) {
				mstore(0x00, shl(0xe0, 0xa58d8d67)) // InvalidProxy(address)
				mstore(0x04, and(proxy, 0xffffffffffffffffffffffffffffffffffffffff))
				revert(0x00, 0x24)
			}

			if iszero(implementation) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, implementation)
			mstore(add(ptr, 0x20), IMPLEMENTATION_SLOT)
			calldatacopy(add(ptr, 0x40), data.offset, data.length)

			if iszero(call(gas(), proxy, callvalue(), ptr, add(data.length, 0x40), 0x00, 0x00)) {
				if iszero(returndatasize()) {
					mstore(0x00, 0x55299b49) // UpgradeFailed()
					revert(0x1c, 0x04)
				}

				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			sstore(shl(0x60, proxy), implementation)

			log3(0x00, 0x00, UPGRADED_TOPIC, proxy, implementation)
		}
	}

	function deploy(address implementation) external payable returns (address) {
		return _deploy(implementation, 0, emptyData());
	}

	function deployAndCall(address implementation, bytes calldata data) external payable returns (address) {
		return _deploy(implementation, 0, data);
	}

	function deployDeterministic(address implementation, bytes32 salt) external payable returns (address) {
		return _deploy(implementation, salt, emptyData());
	}

	function deployDeterministicAndCall(
		address implementation,
		bytes32 salt,
		bytes calldata data
	) external payable returns (address) {
		return _deploy(implementation, salt, data);
	}

	function _deploy(
		address implementation,
		bytes32 salt,
		bytes calldata data
	) internal virtual onlyOwner returns (address proxy) {
		bytes32 ptr = initCode();

		assembly ("memory-safe") {
			if iszero(implementation) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}

			switch salt
			case 0x00 {
				proxy := create(0x00, add(ptr, 0x13), 0x88)
			}
			default {
				proxy := create2(0x00, add(ptr, 0x13), 0x88, salt)
			}

			if iszero(proxy) {
				mstore(0x00, 0xd49e7d74) // ProxyCreationFailed()
				revert(0x1c, 0x04)
			}

			mstore(ptr, implementation)
			mstore(add(ptr, 0x20), IMPLEMENTATION_SLOT)
			calldatacopy(add(ptr, 0x40), data.offset, data.length)

			if iszero(call(gas(), proxy, callvalue(), ptr, add(data.length, 0x40), 0x00, 0x00)) {
				if iszero(returndatasize()) {
					mstore(0x00, 0x30116425) // DeploymentFailed()
					revert(0x1c, 0x04)
				}

				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			sstore(shl(0x60, proxy), implementation)

			log3(0x00, 0x00, DEPLOYED_TOPIC, proxy, implementation)
		}
	}

	function predictDeterministicAddress(bytes32 salt) external view returns (address predicted) {
		bytes32 ptr = initCode();

		assembly ("memory-safe") {
			mstore8(0x00, 0xff)
			mstore(0x35, keccak256(add(ptr, 0x13), 0x88))
			mstore(0x01, shl(0x60, address()))
			mstore(0x15, salt)
			predicted := keccak256(0x00, 0x55)
			mstore(0x35, 0x00)
		}
	}

	function implementationOf(address proxy) external view returns (address implementation) {
		assembly ("memory-safe") {
			implementation := sload(shl(0x60, proxy))
		}
	}

	function initCodeHash() external view returns (bytes32 hash) {
		bytes32 ptr = initCode();

		assembly ("memory-safe") {
			hash := keccak256(add(ptr, 0x13), 0x88)
		}
	}

	function _initCodePacked() internal view returns (bytes32 ptr) {
		assembly ("memory-safe") {
			ptr := mload(0x40)

			mstore(add(ptr, 0x75), 0x604c573d6000fd)
			mstore(add(ptr, 0x6e), 0x3d3560203555604080361115604c5736038060403d373d3d355af43d6000803e)
			mstore(add(ptr, 0x4e), 0x3735a920a3ca505d382bbc545af43d6000803e604c573d6000fd5b3d6000f35b)
			mstore(add(ptr, 0x2e), 0x14605157363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc)
			mstore(add(ptr, 0x0e), address())
			mstore(ptr, 0x60793d8160093d39f33d3d336d)
		}
	}

	function _initCode() internal view returns (bytes32 ptr) {
		assembly ("memory-safe") {
			ptr := mload(0x40)

			mstore(add(ptr, 0x7b), 0x6052573d6000fd)
			mstore(add(ptr, 0x74), 0x3d356020355560408036111560525736038060403d373d3d355af43d6000803e)
			mstore(add(ptr, 0x54), 0x3735a920a3ca505d382bbc545af43d6000803e6052573d6000fd5b3d6000f35b)
			mstore(add(ptr, 0x34), 0x14605757363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc)
			mstore(add(ptr, 0x14), address())
			mstore(ptr, 0x607f3d8160093d39f33d3d3373)
		}
	}

	function emptyData() internal pure returns (bytes calldata data) {
		assembly ("memory-safe") {
			data.length := 0
		}
	}

	function _initializeOwnerGuard() internal pure virtual override returns (bool guard) {
		return true;
	}
}
