const {ethers} = require("hardhat");

async function main() {
  const Ledger = await ethers.getContractFactory("FintrustLedger");
  const ledger = await Ledger.deploy();

  await ledger.waitForDeployment();

  const address = await ledger.getAddress();
  console.log(`FintrustLedger deployed to: ${address}`);
  console.log(`Sepolia Etherscan: https://sepolia.etherscan.io/address/${address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
