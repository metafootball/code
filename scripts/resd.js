// var XLSX = require("xlsx");
var XLSX = require('node-xlsx');


async function main() {
    var workbook = XLSX.parse(`${__dirname}/initdata/init.csv`);
    console.log(workbook[0].data)
    const data = workbook[0].data
    const initP = []
    let totalAmount = 0
    for(let i = 0 ;i < data.length; i++) {
        initP.push({
            address: data[i][4],
            amount: data[i][2]
        })
        totalAmount += data[i][2] * 1
    }
    console.table(initP)
    console.log(totalAmount)

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });