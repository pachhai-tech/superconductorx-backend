const hre = require("hardhat");

async function main() {
	const Contract = await hre.ethers.getContractFactory("SuperconductorX");
	const contract = await Contract.deploy();

	await contract.deployed();

	console.log("SuperconductorX deployed to:", contract.address);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});