const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

const main = {
    "ConractAt" : {
        "FY": "0x79B71F321D44F5a6c2208D74197CACf7364DA3d7",
        "HFUSDT": "0xa6906DF013821e8c435bDb49bc5725F5C75e8bED",
        "SmartAMM": "0xc71C9Ee545F1884E4C61d3f3dc6661691FF49EE7",
        "FuGouYun": "0x4C62b492f182141969325fFB73C26e18FA7C867d"
    }
}



async function Attach(conractName, addresss) {
    const conract = await ethers.getContractFactory(conractName);
    if ( !addresss ) {
        addresss = main.ConractAt[conractName]
    }
    return conract.attach(addresss)
}

function Accounts() {
    return ethers.getSigners()
}

const E18 = "0x"+(1e18).toString(16)
const E6 = "0x"+(1e6).toString(16)

function numberToGig(num, e = E18) {
    return   BigNumber.from(num).mul(e)
}

module.exports = {
    Attach,
    Accounts,
    E18,
    E6,
    numberToGig
}