// const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

// fy销毁地址
const burnTo = "0x000000000000000000000000000000000000dead"
const coin = BigNumber.from("1000000000000000000")
// fy自用router，页面中的买卖也是用此router，刚开始时，将lp锁定到该router，
// 然后再锁定此router，通过白名单进行购买
// 后开放lp，则其他交易所自己的router，与页面中的router都可自由买卖
const router = "0x4E4Ad21A42B79b3452a1b545173DC99867277A87"
const fatcory = "0x2217DD76600b1e3386450d376bC4ebB79b8ea860"
// 测试运营地址
const operating = "0x594661A07AC1349CDEa97999931ea1A1ad61BCfB"
// 测试发开地址
const development = "0x3b0DE9F6F627eda5471584ec8eD5Aa4509788B42"

const huaufuMint = "0x4d5757b7dECF79C96d0166113AE09ef8D728ce30"

// 0x5Ea7C96660B2BB5efA4CF2c5940d4a890D002Fb0 owen
// 0x4440Ea4F79D904874efb2a60bfBFE4dB10da0C4b  mint
// 0x4d5757b7dECF79C96d0166113AE09ef8D728ce30 hufu mint
function numberToGig(num) {
    return   BigNumber.from(num).mul(coin)
}


async function main() {
    let accounts =  await ethers.getSigners()
    let owner = accounts[0]
    console.log(
        owner.address
    )
        // return
    // 发布FY
    let FY = await ethers.getContractFactory("FY");
    FY = await FY.deploy(
        "0x9486c3FB490E827F47d282793Fe43440292ed218",
        owner.address,
        burnTo
    );
    await FY.deployed();
    console.log("FY", FY.address);

    // 发布HFU
    let HFU = await ethers.getContractFactory("HFUSDT");
    HFU =  await HFU.deploy();
    await HFU.deployed();
    console.log("HFU", HFU.address);

    // // // 铸币hfu，此处测试，数量随意
    // tx = await HFU.mint(owner.address, numberToGig(1_000_000))
    // await tx.wait()
    // console.log("HFU mint");

    // //  发布做市场合约
    // let SmartAMM = await ethers.getContractFactory("SmartAMM");
    // SmartAMM =  await SmartAMM.deploy(HFU.address, FY.address, router);
    // await SmartAMM.deployed();
    // console.log("SmartAMM", SmartAMM.address);

    
    // // 发布fugouyun合约
    // let FuGouYun = await ethers.getContractFactory("FuGouYun");
    // FuGouYun =  await FuGouYun.deploy(
    //   SmartAMM.address, router,fatcory,
    //   FY.address,
    //   HFU.address,
    //   operating,
    //   development,
    //   owner.address,
    //   99999999999
    // );
    // await FuGouYun.deployed();
    // console.log("FuGouYun", FuGouYun.address);

    // // 授权绑定的权限关系给fugouyun，用来绑定默认的关系
    // tx = await FY.grantRole(await FY.BINDER_ROLE(), FuGouYun.address)
    // await tx.wait()
    // console.log("FY grantRole BINDER_ROLE to FuGouYun");
    
    // 此处需要将fugouyun合约，samrtAMM合约地址添加到Router的白名单
    // 然后执行初始化底池脚本-initpool.js
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});


// FY 0xe59d7005E4e9816b254a581D1CC233d120F239C0
// HFU 0xa6906DF013821e8c435bDb49bc5725F5C75e8bED
// SmartAMM 0x722c3AeB789851BAfc2486D84B4c147c405b0D75
// FuGouYun 0x79B71F321D44F5a6c2208D74197CACf7364DA3d7