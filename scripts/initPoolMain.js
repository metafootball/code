const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
var XLSX = require('node-xlsx');


const {
    Attach,
    Accounts,
    numberToGig
} = require("./deployed")

// const coin = BigNumber.from("1000000000000000000")

const fugouyun = "0x7af27EEe12CD963FB443AC3dD5e6cF5559EF92F2"
const fy = "0x7BE93498fE3aa2D934405291eAFF8A5521635248"
const hfu = "0x425F397A02830Ed4bA967748049Cd049599c2fce"
// FY 0x7BE93498fE3aa2D934405291eAFF8A5521635248
// HFU 0x425F397A02830Ed4bA967748049Cd049599c2fce
// HFU mint
// SmartAMM 0x6896d337784B96FDB55ABA5a3b4F8D20a2342BB5
// FuGouYun 0x7af27EEe12CD963FB443AC3dD5e6cF5559EF92F2

function getUserData() {
  var workbook = XLSX.parse(`${__dirname}/initdata/init.csv`);
  const data = workbook[0].data
  const initP = []
  let totalAmount = 0
  for(let i = 0 ;i < data.length; i++) {
      initP.push({
        user: data[i][4],
        amount: numberToGig(data[i][2] * 1)
      })
      totalAmount += data[i][2] * 1
  }
  return initP
}

async function main() {

    const userData = getUserData()

    const accounts = await Accounts()
    
    let owner = accounts[0]
    console.log(owner.address)
    // return
    // 加载FuGouYun
    let FuGouYun = await Attach("FuGouYun")
    let FY = await Attach("FY")
    let HFU = await Attach("HFUSDT")

    let total = numberToGig(0)
    // 初始化底池用户
    // for (var i = 0;i < userData.length;i++){
    //   total = total.add(userData[i].amount)
    // //   tx = await FuGouYun.initPoolUser(userData[i].address, userData[i].amount)
    // //   console.log("initPoolUser ", userData[i].address, userData[i].amount);
    // }
    // console.log(userData)
    // return
    // tx = await FuGouYun.initPoolUsers(userData)
    // console.log("initPoolUsers")
    // await tx.wait()
    // // console.log("total amount", total.toString())
    // // console.log(FuGouYun.address)
    // // mint 地址授权给 FuGouYun
    // tx = await FY.approve(FuGouYun.address, numberToGig(10000000000000))
    // await tx.wait()
    // console.log("FY approve");

    // tx = await HFU.approve(FuGouYun.address, numberToGig(100000000000000))
    // await tx.wait()
    // console.log("HFU approve");


    // // // // 铸币hfu，此处测试，数量随意
    // // tx = await HFU.mint(owner.address, numberToGig(1_000_000))
    // // await tx.wait()
    // // console.log("HFU mint");
    // // 将lp地址设置为，转入收费地址，以收取卖币手续费
    // tx = await FY.transferToFee(await FuGouYun.lpToken())
    // await tx.wait()
    // console.log("transferToFee lp");
    // return


    // 初始化底池，开始计算挖矿
    tx = await FuGouYun.initPool()
    console.log(tx.hash)
    await tx.wait()
    console.log("FuGouYun initPool 10000u, 100000fy");

    
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});
