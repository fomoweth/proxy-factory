// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "src/base/Initializable.sol";
import {Ownable} from "src/base/Ownable.sol";

contract CounterV1 is Initializable, Ownable {
	uint256 public constant REVISION = 0x01;

	uint256 public value;

	constructor() {
		disableInitializer();
	}

	function initialize(address initialOwner) external initializer {
		_checkNewOwner(initialOwner);
		_setOwner(initialOwner);
	}

	function getValue() public view returns (uint256) {
		return value;
	}

	function setValue(uint256 x) public {
		value = x;
	}

	function getRevision() internal pure virtual override returns (uint256) {
		return REVISION;
	}
}

contract CounterV2 is Initializable, Ownable {
	uint256 public constant REVISION = 0x02;

	uint256 public value;

	constructor() {
		disableInitializer();
	}

	function initialize(address initialOwner) external initializer {
		_checkNewOwner(initialOwner);
		_setOwner(initialOwner);
	}

	function getValue() public view returns (uint256) {
		return value;
	}

	function setValue(uint256 x) public {
		value = x;
	}

	function getRevision() internal pure virtual override returns (uint256) {
		return REVISION;
	}
}
