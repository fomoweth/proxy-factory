// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {ProxyFactory} from "src/ProxyFactory.sol";

import {CounterV1, CounterV2} from "./mocks/Counter.sol";

contract ProxyFactoryTest is Test {
	error InvalidProxy(address proxy);
	error InvalidImplementation();
	error InvalidInitialization();
	error Unauthorized();

	event Deployed(address indexed proxy, address indexed implementation);
	event Upgraded(address indexed proxy, address indexed implementation);
	event Initialized(uint64 revision);

	bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

	bytes32 internal constant LAST_REVISION_SLOT = 0x2dcf4d2fa80344eb3d0178ea773deb29f1742cf017431f9ee326c624f742669b;

	address internal immutable invalidOwner = makeAddr("InvalidOwner");

	ProxyFactory internal factory;

	address internal v1Impl;
	address internal v2Impl;

	function setUp() public virtual {
		factory = new ProxyFactory(address(this));

		v1Impl = address(new CounterV1());
		v2Impl = address(new CounterV2());
	}

	function test_deploy() public virtual {
		vm.prank(invalidOwner);
		vm.expectRevert(Unauthorized.selector);
		factory.deploy(v1Impl);

		vm.expectRevert(InvalidImplementation.selector);
		factory.deploy(address(0));

		address proxy = factory.deploy(v1Impl);
		checkImplementationSlot(proxy, v1Impl);

		expectEmitInitialized(1);
		CounterV1(proxy).initialize(address(this));

		checkRevisionSlot(proxy, 1);
	}

	function test_deployAndCall() public virtual {
		bytes memory data = abi.encodeCall(CounterV1.initialize, (address(this)));

		vm.prank(invalidOwner);
		vm.expectRevert(Unauthorized.selector);
		factory.deployAndCall(v1Impl, data);

		vm.expectRevert(InvalidImplementation.selector);
		factory.deployAndCall(address(0), data);

		expectEmitInitialized(1);
		address proxy = factory.deployAndCall(v1Impl, data);

		checkImplementationSlot(proxy, v1Impl);
		checkRevisionSlot(proxy, 1);

		vm.expectRevert(InvalidInitialization.selector);
		CounterV1(proxy).initialize(address(this));
	}

	function test_deployDeterministic() public virtual {
		bytes32 salt = randomSalt();
		address predicted = factory.predictDeterministicAddress(salt);

		expectEmitDeployed(predicted, v1Impl);

		address proxy = factory.deployDeterministic(v1Impl, salt);
		assertEq(proxy, predicted);

		expectEmitInitialized(1);
		CounterV1(proxy).initialize(address(this));

		checkImplementationSlot(proxy, v1Impl);
		checkRevisionSlot(proxy, 1);
	}

	function test_deployDeterministicAndCall() public virtual {
		bytes memory data = abi.encodeCall(CounterV1.initialize, (address(this)));

		bytes32 salt = randomSalt();
		address predicted = factory.predictDeterministicAddress(salt);

		expectEmitInitialized(1);
		expectEmitDeployed(predicted, v1Impl);

		address proxy = factory.deployDeterministicAndCall(v1Impl, salt, data);
		assertEq(proxy, predicted);

		checkImplementationSlot(proxy, v1Impl);
		checkRevisionSlot(proxy, 1);
	}

	function test_upgrade() public virtual {
		bytes memory data = abi.encodeCall(CounterV1.setValue, (10));

		bytes32 salt = randomSalt();
		address predicted = factory.predictDeterministicAddress(salt);
		address invalidProxy = factory.predictDeterministicAddress(randomSalt());

		expectEmitDeployed(predicted, v1Impl);

		address proxy = factory.deployDeterministicAndCall(v1Impl, salt, data);
		assertEq(proxy, predicted);

		expectEmitInitialized(1);
		CounterV1(proxy).initialize(address(this));

		checkImplementationSlot(proxy, v1Impl);
		checkRevisionSlot(proxy, 1);
		checkCounterValue(proxy, 10);

		vm.prank(invalidOwner);
		vm.expectRevert(Unauthorized.selector);
		factory.upgrade(proxy, v2Impl);

		vm.expectRevert(InvalidImplementation.selector);
		factory.upgrade(proxy, address(0));

		vm.expectRevert(abi.encodeWithSelector(InvalidProxy.selector, invalidProxy));
		factory.upgrade(invalidProxy, v2Impl);

		expectEmitUpgraded(predicted, v2Impl);
		factory.upgrade(proxy, v2Impl);

		expectEmitInitialized(2);
		CounterV2(proxy).initialize(address(this));

		checkImplementationSlot(proxy, v2Impl);
		checkRevisionSlot(proxy, 2);
		checkCounterValue(proxy, 10);

		CounterV2(proxy).setValue(20);
		checkCounterValue(proxy, 20);
	}

	function test_upgradeAndCall() public virtual {
		bytes memory v1Data = abi.encodeCall(CounterV1.setValue, (10));
		bytes memory v2Data = abi.encodeCall(CounterV2.setValue, (20));

		bytes32 salt = randomSalt();
		address predicted = factory.predictDeterministicAddress(salt);
		address invalidProxy = factory.predictDeterministicAddress(randomSalt());

		address proxy = factory.deployDeterministicAndCall(v1Impl, salt, v1Data);
		assertEq(proxy, predicted);

		expectEmitInitialized(1);
		CounterV1(proxy).initialize(address(this));

		checkImplementationSlot(proxy, v1Impl);
		checkRevisionSlot(proxy, 1);
		checkCounterValue(proxy, 10);

		vm.prank(invalidOwner);
		vm.expectRevert(Unauthorized.selector);
		factory.upgradeAndCall(proxy, v2Impl, v2Data);

		vm.expectRevert(InvalidImplementation.selector);
		factory.upgradeAndCall(proxy, address(0), v2Data);

		vm.expectRevert(abi.encodeWithSelector(InvalidProxy.selector, invalidProxy));
		factory.upgradeAndCall(invalidProxy, v2Impl, v2Data);

		expectEmitUpgraded(predicted, v2Impl);
		factory.upgradeAndCall(proxy, v2Impl, v2Data);

		expectEmitInitialized(2);
		CounterV2(proxy).initialize(address(this));

		checkImplementationSlot(proxy, v2Impl);
		checkRevisionSlot(proxy, 2);
		checkCounterValue(proxy, 20);
	}

	function expectEmitDeployed(address proxy, address implementation) internal {
		vm.expectEmit(true, true, true, true, address(factory));
		emit Deployed(proxy, implementation);
	}

	function expectEmitUpgraded(address proxy, address implementation) internal {
		vm.expectEmit(true, true, true, true, address(factory));
		emit Upgraded(proxy, implementation);
	}

	function expectEmitInitialized(uint64 revision) internal {
		vm.expectEmit(true, true, true, true);
		emit Initialized(revision);
	}

	function checkImplementationSlot(address proxy, address implementation) internal view {
		assertEq(factory.implementationOf(proxy), implementation);
		assertEq(address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT)))), implementation);
	}

	function checkRevisionSlot(address proxy, uint64 revision) internal view {
		assertEq(uint256(vm.load(proxy, LAST_REVISION_SLOT)), revision);
	}

	function checkCounterValue(address proxy, uint256 value) internal view {
		assertEq(CounterV1(proxy).getValue(), value);
	}

	function randomSalt() internal virtual returns (bytes32) {
		return keccak256(abi.encode(vm.randomUint()));
	}
}
