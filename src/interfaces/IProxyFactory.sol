// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IProxyFactory {
	function upgrade(address proxy, address implementation) external payable;

	function upgradeAndCall(address proxy, address implementation, bytes calldata data) external payable;

	function deploy(address implementation) external payable returns (address);

	function deployAndCall(address implementation, bytes calldata data) external payable returns (address);

	function deployDeterministic(address implementation, bytes32 salt) external payable returns (address);

	function deployDeterministicAndCall(
		address implementation,
		bytes32 salt,
		bytes calldata data
	) external payable returns (address);

	function predictDeterministicAddress(bytes32 salt) external view returns (address);

	function implementationOf(address proxy) external view returns (address);

	function initCodeHash() external view returns (bytes32);
}
