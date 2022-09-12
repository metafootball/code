0x9486c3FB490E827F47d282793Fe43440292ed218

// const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

const {
    Attach,
    Accounts,
    numberToGig
} = require("./deployed")


async function main() {
    const fy = await Attach("FY")
    console.log(fy.address)
    const amount50 = numberToGig(50)
    
    tx = await fy.transfer("0x9486c3FB490E827F47d282793Fe43440292ed218", amount50)
    console.log(tx.hash)
    await tx.wait()
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});