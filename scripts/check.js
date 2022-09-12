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
    // console.log(fy.address)
    // const amount50 = numberToGig(50)
    
    // tx = await fy.transfer("0x9486c3FB490E827F47d282793Fe43440292ed218", amount50)
    // console.log(tx.hash)
    // await tx.wait()

    // function getChildren(address account) public view returns (address[] memory) {
    //     return children[account];
    // }

    // function getChildrenCount(address account) external view returns (uint256){
    //     return children[account].length;
    // }

    // function getParent(address account) external view returns (address) {
    //     return parent[account];
    // }

    console.log(
        await fy.getChildren("0x78614db1e666c7ee4D11E1c41D716d94E7Fc545A"),
        await fy.getChildren("0x1DbB9990D30077f5Cc985e6B0fb4480804B90D5B"),
        await fy.getChildren("0x78614db1e666c7ee4D11E1c41D716d94E7Fc545A"),
    )
}


main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});