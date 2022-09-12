const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
var XLSX = require('node-xlsx');

const {
    Attach,
    Accounts,
    numberToGig
} = require("./deployed")


const coin = BigNumber.from("1000000000000000000")

const fugouyun = "0x7af27EEe12CD963FB443AC3dD5e6cF5559EF92F2"
const fy = "0x7BE93498fE3aa2D934405291eAFF8A5521635248"
const hfu = "0x425F397A02830Ed4bA967748049Cd049599c2fce"
// FY 0x7BE93498fE3aa2D934405291eAFF8A5521635248
// HFU 0x425F397A02830Ed4bA967748049Cd049599c2fce
// HFU mint
// SmartAMM 0x6896d337784B96FDB55ABA5a3b4F8D20a2342BB5
// FuGouYun 0x7af27EEe12CD963FB443AC3dD5e6cF5559EF92F2
// function numberToGig(num) {
//     return   BigNumber.from(num).mul(coin)
// }

function getUserData() {
  var workbook = XLSX.parse(`${__dirname}/initdata/init.csv`);
  const data = workbook[0].data
  const initP = []
  let totalAmount = 0
  for(let i = 0 ;i < data.length; i++) {
      initP.push({
          address: data[i][4],
          amount: numberToGig(data[i][2] * 1)
      })
      totalAmount += data[i][2] * 1
  }
  return initP
}

async function main() {

    const userData = getUserData()
    
    let accounts =  await ethers.getSigners()
    let owner = accounts[0]


    // 加载hfu
    let HFU = await Attach("HFUSDT")

    let tx = await HFU.mint('0xB84213B84F047b76A2F83ddF7FF1A99B7E25b949', numberToGig(200_000))
    console.log(tx.hash)
    await tx.wait()
    // console.log("HFU", HFU.address);
   
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});
